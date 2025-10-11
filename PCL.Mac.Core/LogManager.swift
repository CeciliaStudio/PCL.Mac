//
//  LogManager.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/19.
//

import Foundation
import os

public class LogManager {
    public static let shared: LogManager = .init(fileURL: SharedConstants.shared.logURL)
    private let fileHandle: FileHandle
    
    private let logQueue: DispatchQueue = .init(label: "PCL.Mac.Log")
    private let logger: Logger = Logger()
    
    public init(fileURL: URL) {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.createDirectory(at: SharedConstants.shared.logURL.parent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        self.fileHandle = try! FileHandle(forWritingTo: fileURL)
        try? self.fileHandle.truncate(atOffset: 0)
    }
    
    public func log(message: Any, level: String, file: String = #file, line: Int = #line) {
        // 构建日志字符串
        let time: String = DateFormatters.shared.logDateFormatter.string(from: Date())
        let caller: String = "\(URL(fileURLWithPath: file).lastPathComponent):\(line)"
        let content: String = String(format: "%@ [%@] %@: %@", time, level, caller, String(describing: message))
        // 输出
        switch level {
        case "WARN": logger.error("\(content)")
        case "ERROR": logger.fault("\(content)")
        case "DEBUG": logger.debug("\(content)")
        default: print(content)
        }
        // 写入文件
        do {
            try fileHandle.write(contentsOf: (content + "\n").data(using: .utf8).unwrap("无法编码日志行。"))
        } catch {
            print("无法写入日志: \(error)")
        }
    }
    
    public func info(_ message: Any, file: String = #file, line: Int = #line) {
        log(message: message, level: "INFO", file: file, line: line)
    }
    
    public func warn(_ message: Any, file: String = #file, line: Int = #line) {
        log(message: message, level: "WARN", file: file, line: line)
    }
    
    public func error(_ message: Any, file: String = #file, line: Int = #line) {
        log(message: message, level: "ERROR", file: file, line: line)
    }
    
    public func debug(_ message: Any, file: String = #file, line: Int = #line) {
        log(message: message, level: "DEBUG", file: file, line: line)
    }
}

public func log(_ message: Any, file: String = #file, line: Int = #line) { LogManager.shared.info(message, file: file, line: line) }

public func warn(_ message: Any, file: String = #file, line: Int = #line) { LogManager.shared.warn(message, file: file, line: line) }

public func err(_ message: Any, file: String = #file, line: Int = #line) { LogManager.shared.error(message, file: file, line: line) }

public func debug(_ message: Any, file: String = #file, line: Int = #line) { LogManager.shared.debug(message, file: file, line: line) }

