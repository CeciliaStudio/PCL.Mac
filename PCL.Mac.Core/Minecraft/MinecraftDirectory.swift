//
//  MinecraftDirectory.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/30.
//

import Foundation

public class MinecraftDirectory: ObservableObject, Hashable, Equatable, Codable {
    public static let `default`: MinecraftDirectory = .init(rootURL: .applicationSupportDirectory.appending(path: "minecraft"), config: Config(name: "默认文件夹"))
    
    @Published public var instances: [InstanceInfo] = []
    public let rootURL: URL
    public var config: Config = .init(name: "")
    
    public var assetsURL: URL { rootURL.appendingPathComponent("assets") }
    public var librariesURL: URL { rootURL.appendingPathComponent("libraries") }
    public var versionsURL: URL { rootURL.appendingPathComponent("versions") }
    
    public init(rootURL: URL, config: Config) {
        self.rootURL = rootURL
        self.config = config
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rootURL)
    }
    
    public static func == (lhs: MinecraftDirectory, rhs: MinecraftDirectory) -> Bool {
        lhs.rootURL == rhs.rootURL
    }
    
    enum CodingKeys: CodingKey {
        case rootURL
    }
    
    public func loadInnerInstances(callback: ((Result<[InstanceInfo], Error>) -> Void)? = nil) {
        instances.removeAll()
        Task {
            do {
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
                            runningDirectory: instanceURL,
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
                    callback?(.success(self.instances))
                }
            } catch {
                err("读取实例目录失败: \(error.localizedDescription)")
                await MainActor.run {
                    callback?(.failure(error))
                }
            }
        }
    }
    
    public class Config: Codable {
        public var name: String
        public var defaultInstance: String?
        public var enableSymbolicLink: Bool
        
        public init(name: String, defaultInstance: String? = nil, enableSymbolicLink: Bool = false) {
            self.name = name
            self.defaultInstance = defaultInstance
            self.enableSymbolicLink = enableSymbolicLink
        }
    }
}

public struct InstanceInfo: Hashable {
    public let minecraftDirectory: MinecraftDirectory
    public let icon: String
    public let name: String
    public let version: MinecraftVersion
    public let runningDirectory: URL
    public let brand: ClientBrand
}
