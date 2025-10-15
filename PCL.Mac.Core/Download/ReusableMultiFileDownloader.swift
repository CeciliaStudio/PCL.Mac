//
//  ReusableMultiFileDownloader.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/10/3.
//

import Foundation
import Network
import Security

public final class ReusableMultiFileDownloader: @unchecked Sendable {
    private let host: String
    private let task: InstallTask?
    private let urls: [URL]
    private let destinations: [URL]
    private let sha1: [String]
    private let maxConnections: Int
    private let parameters: NWParameters
    private let endpoint: NWEndpoint
    private var totalProgress: Double = 0
    private var taskIndex: Int = 0
    private let indexQueue = DispatchQueue(label: "ReusableMultiFileDownloader.index")
    private let connectionQueue = DispatchQueue(label: "ReusableMultiFileDownloader.connection")
    
    public init(
        task: InstallTask?,
        urls: [URL],
        destinations: [URL],
        sha1: [String],
        maxConnections: Int
    ) {
        let hostSet: Set<String> = Set(urls.compactMap({ $0.host() }))
        if hostSet.count != 1 {
            preconditionFailure("所有 URL 必须来自同一个主机")
        }
        self.host = hostSet.first!
        self.task = task
        self.urls = urls
        self.destinations = destinations
        self.sha1 = sha1
        self.maxConnections = maxConnections
        
        let tlsOptions: NWProtocolTLS.Options = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, host)
        self.parameters = NWParameters(tls: tlsOptions)
        self.endpoint = .hostPort(host: .init(host), port: 443)
    }
    
    /// 开始下载所有文件。
    public func start() async throws {
        // 检查参数是否合理
        guard !urls.isEmpty, urls.count == destinations.count, urls.count == sha1.count else { return }
        let total = urls.count
        let group = DispatchGroup()
        (0..<total).forEach { _ in group.enter() }
        
        // 创建进度同步任务
        var tickerTask: Task<Void, Error>? = nil
        if let task = task {
            tickerTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(0.1))
                    if Task.isCancelled { break }
                    await MainActor.run {
                        task.currentStageProgress = self.totalProgress / Double(total)
                    }
                }
            }
        }
        defer { tickerTask?.cancel() }
        
        @Sendable func nextTask() -> (URL, URL, String)? {
            var pair: (URL, URL, String)? = nil
            indexQueue.sync {
                guard taskIndex < total else { return }
                let i = taskIndex
                taskIndex += 1
                pair = (urls[i], destinations[i], sha1[i])
            }
            return pair
        }
        
        @Sendable func schedule(on connection: NWConnection) {
            if let (url, dest, sha1) = nextTask() {
                startDownload(connection: connection, url: url, destination: dest, sha1: sha1) {
                    group.leave()
                    DispatchQueue.main.async {
                        self.task?.completeOneFile()
                    }
                    self.connectionQueue.async {
                        schedule(on: connection)
                    }
                }
            } else {
                connection.cancel()
            }
        }
        
        let initial = min(maxConnections, total)
        for _ in 0..<initial {
            let connection = createConnection()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    schedule(on: connection)
                case .failed, .cancelled:
                    break
                default:
                    break
                }
            }
            connection.start(queue: connectionQueue)
        }
        
        await withCheckedContinuation { continuation in
            group.notify(queue: .global()) { continuation.resume() }
        }
    }
    
    /// `NWConnection` 创建函数。
    /// - Returns: 新的 `NWConnection`。
    private func createConnection() -> NWConnection {
        NWConnection(to: endpoint, using: parameters)
    }
    
    private func startDownload(
        connection: NWConnection,
        url: URL,
        destination: URL,
        sha1: String,
        completion: @escaping () -> Void
    ) {
        // 判断文件是否存在并校验 SHA-1
        if FileManager.default.fileExists(atPath: destination.path) {
            do {
                if try Util.getSHA1(url: destination) == sha1 {
                    completion()
                    return
                }
            } catch {
                err("无法计算 SHA-1: \(error.localizedDescription)")
            }
            try? FileManager.default.removeItem(at: destination)
        }
        let request: String =
        "GET \(url.path) HTTP/1.1\r\n" +
        "Host: \(host)\r\n" +
        "User-Agent: PCL-Mac/\(SharedConstants.shared.version)\r\n" +
        "Accept: */*\r\n" +
        "Accept-Encoding: identity\r\n" +
        "Connection: keep-alive\r\n" +
        "\r\n"
        connection.send(content: request.data(using: .utf8), completion: .contentProcessed { error in
            if let error = error {
                err("发送请求失败: \(error.localizedDescription)")
                completion()
            } else {
                self.receiveData(from: connection, to: destination, completion: completion)
            }
        })
    }
    
    private func receiveData(from connection: NWConnection, to destination: URL, completion: @escaping () -> Void) {
        var buffer = Data()
        var headers: [String: String] = [:]
        var contentLength: Int?
        var headersParsed = false
        let separator = "\r\n\r\n".data(using: .utf8)!
        
        func receiveChunk() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                if let error: NWError = error {
                    err("无法接收响应: \(error.localizedDescription)")
                    completion()
                    return
                }
                if let data = data, !data.isEmpty {
                    buffer.append(data)
                    Task {
                        await SpeedMeter.shared.addBytes(data.count)
                    }
                    var receivedByteCount: Int = data.count
                    if !headersParsed, let range = buffer.range(of: separator) {
                        let headerData = buffer.subdata(in: 0..<range.upperBound)
                        headers = self.parseHTTPHeaders(from: headerData)
                        contentLength = Int(headers["Content-Length"] ?? "")
                        buffer.removeSubrange(0..<range.upperBound)
                        receivedByteCount = buffer.count
                        headersParsed = true
                    }
                    if headersParsed, let contentLength = contentLength {
                        DispatchQueue.main.async {
                            self.totalProgress += Double(receivedByteCount) / Double(contentLength)
                        }
                        if buffer.count >= contentLength {
                            do {
                                try? FileManager.default.createDirectory(at: destination.parent(), withIntermediateDirectories: true)
                                let body = buffer.prefix(contentLength)
                                try body.write(to: destination)
                            } catch {
                                err("无法写入磁盘: \(error.localizedDescription)")
                            }
                            completion()
                            return
                        }
                    }
                }
                if isComplete {
                    completion()
                    return
                }
                receiveChunk()
            }
        }
        receiveChunk()
    }
    
    func parseHTTPHeaders(from headerData: Data) -> [String: String] {
        var headers: [String: String] = [:]
        guard let headerString: String = String(data: headerData, encoding: .utf8) else {
            return headers
        }
        let lines: [String] = headerString.components(separatedBy: "\r\n")
        for line in lines.dropFirst() {
            if let range: Range<String.Index> = line.range(of: ": ") {
                let key: String = String(line[..<range.lowerBound])
                let value: String = String(line[range.upperBound...])
                headers[key] = value
            }
        }
        return headers
    }
}
