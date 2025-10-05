//
//  MinecraftDirectory.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/30.
//

import Foundation

public class MinecraftDirectory: ObservableObject, Hashable, Equatable {
    public static let `default`: MinecraftDirectory = .init(rootURL: .applicationSupportDirectory.appending(path: "minecraft"), config: Config(name: "默认文件夹"))
    private static let sharedResourcesURL: URL = URL(fileURLWithUserPath: "~/Library/Application Support/minecraft/shared/")
    
    @Published public var instances: [InstanceInfo] = []
    public let rootURL: URL
    public let config: Config
    
    public var assetsURL: URL { rootURL.appendingPathComponent("assets") }
    public var librariesURL: URL { rootURL.appendingPathComponent("libraries") }
    public var versionsURL: URL { rootURL.appendingPathComponent("versions") }
    
    /// 根据根目录 `URL` 初始化并加载配置。
    /// - Parameter rootURL: 根目录 `URL`
    public init(rootURL: URL) {
        self.rootURL = rootURL
        let configURL: URL = rootURL.appending(path: ".config.json")
        if !FileManager.default.fileExists(atPath: configURL.path) {
            FileManager.default.createFile(atPath: configURL.path, contents: nil)
            self.config = .init(name: rootURL.lastPathComponent)
            saveConfig()
        } else {
            self.config = Self.loadConfig(url: configURL) ?? .init(name: rootURL.lastPathComponent)
        }
    }
    
    /// 根据根目录 `URL` 与配置创建 `MinecraftDirectory`。
    /// - Parameters:
    ///   - rootURL: 根目录 `URL`
    ///   - config: 初始配置
    public init(rootURL: URL, config: Config) {
        self.rootURL = rootURL
        self.config = config
        saveConfig()
    }
    
    public func enableSymbolicLink() throws {
        try FileManager.default.removeItem(at: librariesURL)
        try FileManager.default.createDirectory(at: Self.sharedResourcesURL.appending(path: "libraries"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: librariesURL, withDestinationURL: Self.sharedResourcesURL.appending(path: "libraries"))
        
        try FileManager.default.removeItem(at: assetsURL)
        try FileManager.default.createDirectory(at: Self.sharedResourcesURL.appending(path: "assets"), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: assetsURL, withDestinationURL: Self.sharedResourcesURL.appending(path: "assets"))
    }
    
    public func disableSymbolicLink() throws {
        try FileManager.default.removeItem(at: librariesURL)
        try FileManager.default.copyItem(at: Self.sharedResourcesURL.appending(path: "libraries"), to: librariesURL)
        
        try FileManager.default.removeItem(at: assetsURL)
        try FileManager.default.copyItem(at: Self.sharedResourcesURL.appending(path: "assets"), to: assetsURL)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rootURL)
    }
    
    public static func == (lhs: MinecraftDirectory, rhs: MinecraftDirectory) -> Bool {
        lhs.rootURL == rhs.rootURL
    }
    
    private static func loadConfig(url: URL) -> MinecraftDirectory.Config? {
        do {
            let decoder: JSONDecoder = JSONDecoder()
            let data: Data = try FileHandle(forReadingFrom: url).readToEnd().unwrap()
            return try decoder.decode(MinecraftDirectory.Config.self, from: data)
        } catch {
            err("无法加载配置: \(error.localizedDescription)")
            return nil
        }
    }
    
    public func saveConfig() {
        do {
            let encoder: JSONEncoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let handle: FileHandle = try FileHandle(forWritingTo: rootURL.appending(path: ".config.json"))
            try handle.truncate(atOffset: 0)
            try handle.write(encoder.encode(config))
        } catch {
            err("无法保存配置: \(error.localizedDescription)")
        }
    }
    
    /// 加载目录内部的实例并赋值。
    /// - Returns: 目录内的所有实例
    @discardableResult
    public func loadInstances() async throws -> [InstanceInfo] {
        // 避免异步操作导致的数据不同步
        let contents = try FileManager.default.contentsOfDirectory(at: versionsURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        let instanceURLs = contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        for instanceURL in instanceURLs {
            if let instance = MinecraftInstance.create(directory: self, runningDirectory: instanceURL, doCache: false) {
                let info = InstanceInfo(
                    minecraftDirectory: self,
                    icon: instance.getIconName(),
                    name: instance.name,
                    version: instance.version,
                    brand: instance.clientBrand
                )
                await MainActor.run {
                    self.instances.append(info)
                }
            }
        }
        await MainActor.run {
            self.instances.sort { instance1, instance2 in
                if instance1.brand == instance2.brand {
                    return instance1.version > instance2.version
                }
                return instance1.brand.index < instance2.brand.index
            }
        }
        return instances
    }
    
    public class Config: Codable {
        /// 目录名
        public var name: String
        /// 该目录的默认实例
        public var defaultInstance: String?
        /// 是否启用资源符号链接
        public var enableSymbolicLink: Bool
        
        public init(name: String, defaultInstance: String? = nil, enableSymbolicLink: Bool = false) {
            self.name = name
            self.defaultInstance = defaultInstance
            self.enableSymbolicLink = enableSymbolicLink
        }
    }
}

public class MinecraftDirectoryManager: ObservableObject {
    public static let shared = MinecraftDirectoryManager()
    
    @StoredProperty(.minecraft, "currentDirectoryID") private var currentDirectoryID: Int = 0 {
        didSet {
            objectWillChange.send()
        }
    }
    @Published public var directories: [MinecraftDirectory] = []
    public var current: MinecraftDirectory {
        get {
            if currentDirectoryID >= directories.count {
                currentDirectoryID = 0
            }
            return directories[currentDirectoryID]
        }
        set {
            currentDirectoryID = directories.firstIndex(of: newValue) ?? 0
        }
    }
    
    public func add(_ directory: MinecraftDirectory) {
        directories.append(directory)
        currentDirectoryID = directories.count - 1
    }
    
    public func remove(_ directory: MinecraftDirectory) {
        if let index = directories.firstIndex(of: directory) {
            directories.remove(at: index)
            if currentDirectoryID >= directories.count {
                currentDirectoryID = 0
            }
        }
    }
    
    public func getDefaultInstance() -> String? {
        return current.config.defaultInstance
    }
    
    public func setDefaultInstance(_ name: String) {
        current.config.defaultInstance = name
    }
    
    public func save() {
        AppSettings.shared.minecraftDirectoryURLs = directories.map { $0.rootURL }
        for directory in directories {
            directory.saveConfig()
        }
    }
    
    private init() {
        for url in AppSettings.shared.minecraftDirectoryURLs {
            directories.append(MinecraftDirectory(rootURL: url))
        }
        if currentDirectoryID >= directories.count {
            currentDirectoryID = 0
        }
    }
}

public struct InstanceInfo: Hashable {
    public let minecraftDirectory: MinecraftDirectory
    public let icon: String
    public let name: String
    public let version: MinecraftVersion
    public let brand: ClientBrand
}
