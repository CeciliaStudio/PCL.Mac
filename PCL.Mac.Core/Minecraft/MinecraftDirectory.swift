//
//  MinecraftDirectory.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/30.
//

import Foundation

public class MinecraftDirectory: Codable, Identifiable, Hashable, ObservableObject {
    public static let `default`: MinecraftDirectory = .init(rootURL: .applicationSupportDirectory.appending(path: "minecraft"), name: "默认文件夹")
    
    public var id: UUID
    public let rootURL: URL
    public var name: String?
    @Published public var instances: [InstanceInfo] = []
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rootURL)
    }
    
    public var versionsURL: URL {
        rootURL.appendingPathComponent("versions")
    }
    
    public var assetsURL: URL {
        rootURL.appendingPathComponent("assets")
    }
    
    public var librariesURL: URL {
        rootURL.appendingPathComponent("libraries")
    }
    
    public init(rootURL: URL, name: String?) {
        self.id = .init()
        self.rootURL = rootURL
        self.name = name
    }
    
    enum CodingKeys: CodingKey {
        case id
        case rootURL
        case name
    }
    
    public static func == (lhs: MinecraftDirectory, rhs: MinecraftDirectory) -> Bool {
        lhs.rootURL == rhs.rootURL
    }
    
    public func loadInnerInstances(callback: ((Result<[InstanceInfo], Error>) -> Void)? = nil) {
        instances.removeAll()
        Task {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: versionsURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                let instanceDirectories = contents.filter { url in
                    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                }
                for instanceDirectory in instanceDirectories {
                    if let instance = MinecraftInstance.create(instanceDirectory, doCache: false) {
                        let info = InstanceInfo(
                            minecraftDirectory: self,
                            icon: instance.getIconName(),
                            name: instance.name,
                            version: instance.version,
                            runningDirectory: instanceDirectory,
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
}

public struct InstanceInfo: Identifiable, Hashable {
    public let id: UUID = .init()
    public let minecraftDirectory: MinecraftDirectory
    public let icon: String
    public let name: String
    public let version: MinecraftVersion
    public let runningDirectory: URL
    public let brand: ClientBrand
}
