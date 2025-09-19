//
//  FabricInstaller.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/15.
//

import Foundation
import ZIPFoundation

public class FabricInstaller {
    public static func installFabric(_ instance: MinecraftInstance, _ loaderVersion: String) async throws {
        try await installFabric(version: instance.version!, minecraftDirectory: instance.minecraftDirectory, runningDirectory: instance.runningDirectory, loaderVersion)
        
        instance.clientBrand = .fabric
        instance.saveConfig()
    }
    
    public static func installFabric(version: MinecraftVersion, minecraftDirectory: MinecraftDirectory, runningDirectory: URL, _ loaderVersion: String) async throws {
        let manifestURL = runningDirectory.appending(path: "\(runningDirectory.lastPathComponent).json")
        // 若 inheritsFrom 对应的实例 JSON 不存在，下载
        let baseManifestURL = minecraftDirectory.versionsURL.appending(path: version.displayName).appending(path: "\(version.displayName).json")
        if !FileManager.default.fileExists(atPath: baseManifestURL.path) {
            try? FileManager.default.createDirectory(at: baseManifestURL.parent(), withIntermediateDirectories: true)
            let _ = try await MinecraftInstaller.downloadClientManifest(version: version, instanceURL: baseManifestURL.parent())
            try? FileManager.default.copyItem(at: baseManifestURL, to: runningDirectory.appending(path: ".parent"))
        }
        
        try await SingleFileDownloader.download(url: "https://meta.fabricmc.net/v2/versions/loader/\(version.displayName)/\(loaderVersion)/profile/json".url, destination: manifestURL, replaceMethod: .replace)
    }
}
