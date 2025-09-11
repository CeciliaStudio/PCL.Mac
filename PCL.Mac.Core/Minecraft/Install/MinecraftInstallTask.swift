//
//  MinecraftInstallTask.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/28.
//

import Foundation
import SwiftyJSON

public class MinecraftInstallTask: InstallTask {
    public let instanceURL: URL
    public let version: MinecraftVersion
    public let minecraftDirectory: MinecraftDirectory
    public let architecture: Architecture
    
    public init(
        instanceURL: URL,
        version: MinecraftVersion,
        minecraftDirectory: MinecraftDirectory,
        architecture: Architecture = .system,
    ) {
        self.instanceURL = instanceURL
        self.version = version
        self.minecraftDirectory = minecraftDirectory
        self.architecture = architecture
    }
    
    public override func startTask() async throws {
        do {
            setStage(.clientJson)
            let manifest: ClientManifest = try await MinecraftInstaller.downloadClientManifest(task: self, version: version, instanceURL: instanceURL)
            setStage(.clientIndex)
            let assetIndex: AssetIndex = try await MinecraftInstaller.downloadAssetIndex(task: self, version: version, manifest: manifest, directory: minecraftDirectory)
            setRemainingFiles(MinecraftInstaller.calculateFileCount(assetIndex: assetIndex, manifest: manifest))
            setStage(.clientJar)
            try await MinecraftInstaller.downloadClientJar(task: self, version: version, manifest: manifest, instanceURL: instanceURL)
            setStage(.clientResources)
            try await MinecraftInstaller.downloadHashResourcesFiles(task: self, assetIndex: assetIndex, directory: minecraftDirectory)
            setStage(.clientLibraries)
            try await MinecraftInstaller.downloadLibraries(task: self, manifest: manifest, directory: minecraftDirectory)
            setStage(.natives)
            try await MinecraftInstaller.downloadNatives(task: self, manifest: manifest, directory: minecraftDirectory)
            try MinecraftInstaller.unzipNatives(architecture: architecture, manifest: manifest, directory: minecraftDirectory, instanceURL: instanceURL)
            
            // 拷贝 log4j2.xml
            let _1_12_2 = MinecraftVersion(displayName: "1.12.2")
            let targetURL: URL = instanceURL.appending(path: "log4j2.xml")
            try? FileManager.default.copyItem(
                at: SharedConstants.shared.applicationResourcesURL.appending(path: version >= _1_12_2 ? "log4j2.xml" : "log4j2-1.12-.xml"),
                to: targetURL
            )
            
            // 修改清单中的 id
            let manifestURL = instanceURL.appending(path: "\(instanceURL.lastPathComponent).json")
            guard FileManager.default.fileExists(atPath: manifestURL.path),
                  let data = try FileHandle(forReadingFrom: manifestURL).readToEnd(),
                  var dict = try JSON(data: data).dictionaryObject else {
                return
            }
            dict["id"] = instanceURL.lastPathComponent
            try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted).write(to: manifestURL)
            
            // 初始化实例
            let instance = MinecraftInstance.create(instanceURL, config: MinecraftConfig(version: version))
            instance?.saveConfig()
        } catch {
            try? FileManager.default.removeItem(at: instanceURL)
            throw error
        }
    }
    
    override func getStages() -> [InstallStage] {
        [.clientJson, .clientIndex, .clientJar, .clientResources, .clientLibraries, .natives]
    }
    
    override func wrapError(error: any Error) -> any Error {
        InstallingError.minecraftInstallFailed(error: error)
    }
    
    public override func getTitle() -> String {
        "\(version.displayName) 安装"
    }
}
