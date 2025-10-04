//
//  PropertyStorage.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/10/1.
//

import Foundation

public final class PropertyStorage {
    /// App 设置
    public static let appSettings: PropertyStorage = .init(fileURL: SharedConstants.shared.configURL.appending(path: "app.json"))
    /// 账号相关
    public static let account: PropertyStorage = .init(fileURL: SharedConstants.shared.configURL.appending(path: "account.json"))
    /// Minecraft 相关
    public static let minecraft: PropertyStorage = .init(fileURL: SharedConstants.shared.configURL.appending(path: "minecraft.json"))
    
    public static func loadAll() {
        do {
            try appSettings.load()
            try account.load()
            try minecraft.load()
        } catch {
            err("无法加载 PropertyStorage: \(error.localizedDescription)")
        }
    }
    
    public static func saveAll() {
        do {
            try appSettings.save()
            try account.save()
            try minecraft.save()
        } catch {
            err("无法保存 PropertyStorage: \(error.localizedDescription)")
        }
    }
    
    private let fileURL: URL
    private var entries: [String: Data] = [:]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        self.encoder.outputFormatting = [.sortedKeys]
    }

    public func load() throws {
        let reachable = (try? fileURL.checkResourceIsReachable()) ?? false
        guard reachable else {
            entries = [:]
            return
        }

        let data = try Data(contentsOf: fileURL)
        let decoded = try decoder.decode([String: Data].self, from: data)
        entries = decoded
    }

    public func save() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func get<T: Codable>(key: String, type: T.Type) -> T? {
        guard let data = entries[key] else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            return nil
        }
    }
    
    public func contains(key: String) -> Bool {
        return entries[key] != nil
    }

    public func set<T: Codable>(key: String, value: T) {
        do {
            entries[key] = try encoder.encode(value)
        } catch {
            err("无法序列化 \(key) 的值: \(error.localizedDescription)")
        }
    }
}
