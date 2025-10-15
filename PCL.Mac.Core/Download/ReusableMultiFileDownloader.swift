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
    private let urls: [URL]
    private let destinations: [URL]
    private let maxConnections: Int
    private let parameters: NWParameters
    private let endpoint: NWEndpoint
    private var taskIndex: Int = 0
    private let indexQueue = DispatchQueue(label: "ReusableMultiFileDownloader.index")
    private let connectionQueue = DispatchQueue(label: "ReusableMultiFileDownloader.connection")
    
    public init(
        urls: [URL],
        destinations: [URL],
        maxConnections: Int
    ) {
        let hostSet: Set<String> = Set(urls.compactMap({ $0.host() }))
        if hostSet.count != 1 {
            preconditionFailure()
        }
        self.host = hostSet.first!
        self.urls = urls
        self.destinations = destinations
        self.maxConnections = maxConnections
        
        let tlsOptions: NWProtocolTLS.Options = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, host)
        self.parameters = NWParameters(tls: tlsOptions)
        self.endpoint = .hostPort(host: .init(host), port: 443)
    }
    
    /// 开始下载所有文件。
    public func start() async throws {
        guard !urls.isEmpty, urls.count == destinations.count else { return }
        let total = urls.count
        let group = DispatchGroup()
        (0..<total).forEach { _ in group.enter() }
        
        @Sendable func nextTask() -> (URL, URL)? {
            var pair: (URL, URL)? = nil
            indexQueue.sync {
                guard taskIndex < total else { return }
                let i = taskIndex
                taskIndex += 1
                pair = (urls[i], destinations[i])
            }
            return pair
        }
        
        @Sendable func schedule(on connection: NWConnection) {
            if let (url, dest) = nextTask() {
                startDownload(connection: connection, url: url, destination: dest) {
                    group.leave()
                    schedule(on: connection)
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
    
    private func startDownload(connection: NWConnection, url: URL, destination: URL, completion: @escaping () -> Void) {
        let request: String =
        "GET \(url) HTTP/1.1\r\n" +
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
                    if !headersParsed, let range = buffer.range(of: separator) {
                        let headerData = buffer.subdata(in: 0..<range.upperBound)
                        headers = self.parseHTTPHeaders(from: headerData)
                        buffer.removeSubrange(0..<range.upperBound)
                        headersParsed = true
                    }
                    if headersParsed {
                        let contentLengthString = headers["Content-Length"] ?? headers["content-length"]
                        if let contentLengthString, let contentLength = Int(contentLengthString), buffer.count >= contentLength {
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
