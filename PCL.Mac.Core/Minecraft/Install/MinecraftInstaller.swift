//
//  MinecraftInstallerNew.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/31.
//

/**
 *                             _ooOoo_
 *                            o8888888o
 *                            88" . "88
 *                            (| -_- |)
 *                            O\  =  /O
 *                         ____/`---'\____
 *                       .'  \\|     |//  `.
 *                      /  \\|||  :  |||//  \
 *                     /  _||||| -:- |||||-  \
 *                     |   | \\\  -  /// |   |
 *                     | \_|  ''\---/''  |   |
 *                     \  .-\__  `-`  ___/-. /
 *                   ___`. .'  /--.--\  `. . __
 *                ."" '<  `.___\_<|>_/___.'  >'"".
 *               | | :  `- \`.;`\ _ /`;.`/ - ` : | |
 *               \  \ `-.   \_ __\ /__ _/   .-` /  /
 *          ======`-.____`-.___\_____/___.-`____.-'======
 *                             `=---='
 *          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
*/

import Foundation
import SwiftyJSON

public class MinecraftInstaller {
    private init() {}
    
    /// 下载客户端清单 (JSON) 文件并解析。
    /// 文件将保存至 `instanceURL.appending(path: "\(instanceURL.lastPathComponent).json")`。
    /// - Parameters:
    ///   - task: 安装任务，仅用于进度更新。
    ///   - version: 客户端版本。
    ///   - instanceURL: 实例运行目录。
    /// - Returns: 解析后的清单。
    public static func downloadClientManifest(
        task: InstallTask? = nil,
        version: MinecraftVersion,
        instanceURL: URL
    ) async throws -> ClientManifest {
        let url = try DownloadSourceManager.shared.getClientManifestURL(version).unwrap("无法获取 \(version.displayName) 的 JSON 下载 URL。")
        let destination = instanceURL.appending(path: "\(instanceURL.lastPathComponent).json")
        
        try await SingleFileDownloader.download(task: task, url: url, destination: destination, replaceMethod: .replace)
        
        if let manifest: ClientManifest = try .parse(url: destination, minecraftDirectory: nil) {
            return manifest
        } else {
            let content = try String(data: FileHandle(forReadingFrom: destination).readToEnd().unwrap(), encoding: .utf8).unwrap()
            err("无法解析客户端清单: \(content)")
            throw MyLocalizedError(reason: "无法解析客户端清单：\(content)")
        }
    }
    
    /// 下载客户端 JAR 文件。
    /// 文件将保存至 `instanceURL.appending(path: "\(instanceURL.lastPathComponent).jar")`。
    /// - Parameters:
    ///   - task: 安装任务，仅用于进度更新。
    ///   - version: 客户端版本。
    ///   - manifest: 客户端清单 (JSON)。
    ///   - instanceURL: 实例运行目录。
    public static func downloadClientJar(
        task: InstallTask? = nil,
        version: MinecraftVersion,
        manifest: ClientManifest,
        instanceURL: URL
    ) async throws {
        let url = try DownloadSourceManager.shared.getClientJARURL(version, manifest).unwrap("无法获取 \(version.displayName) 的客户端下载 URL。")
        
        try await SingleFileDownloader.download(
            task: task,
            url: url,
            destination: instanceURL.appending(path: "\(instanceURL.lastPathComponent).jar")
        )
    }
    
    /// 下载资源索引并解析。
    /// 文件将保存至 `directory.assetsURL.appending(path: "indexes/\(assetIndexId).json")`。
    /// - Parameters:
    ///   - task: 安装进度，仅用于进度更新。
    ///   - version: 客户端版本。
    ///   - manifest: 客户端清单。
    ///   - directory: 实例所在的 `MinecraftDirectory`。
    /// - Returns: 解析后的 `AssetIndex`。
    public static func downloadAssetIndex(
        task: InstallTask? = nil,
        version: MinecraftVersion,
        manifest: ClientManifest,
        directory: MinecraftDirectory
    ) async throws -> AssetIndex {
        let url: URL = try DownloadSourceManager.shared.getAssetIndexURL(version, manifest).unwrap("无法获取 \(version.displayName) 的 assetIndex 下载 URL。")
        let destination: URL = directory.assetsURL.appending(path: "indexes").appending(path: "\(manifest.assetIndex!.id).json")
        try await SingleFileDownloader.download(task: task, url: url, destination: destination)
        do {
            let data = try Data(contentsOf: destination)
            return try .parse(data)
        } catch {
            err("在解析 JSON 时发生错误: \(error.localizedDescription)")
            throw MyLocalizedError(reason: "在解析 JSON 时发生错误: \(error.localizedDescription)")
        }
    }
    
    /// 下载资源索引中的散列资源文件。
    /// 文件将保存至 `directory.assetsURL.appending(path: "objects")` 中。
    /// - Parameters:
    ///   - task: 安装任务，仅用于进度更新。
    ///   - assetIndex: 资源索引。
    ///   - directory: 目标 `MinecraftDirectory`。
    public static func downloadHashResourcesFiles(
        task: InstallTask? = nil,
        assetIndex: AssetIndex,
        directory: MinecraftDirectory
    ) async throws {
        var urls: [URL] = []
        var destinations: [URL] = []
        
        for object in assetIndex.objects {
            urls.append(object.appendTo(URL(string: "https://resources.download.minecraft.net")!))
            destinations.append(object.appendTo(directory.assetsURL.appending(path: "objects")))
        }
        
        try await MultiFileDownloader(task: task, urls: urls, destinations: destinations, concurrentLimit: 256).start()
    }
    
    /// 下载清单中的所有依赖项。
    /// 文件将保存至 `directory.librariesURL` 中。
    /// - Parameters:
    ///   - task: 安装任务，仅用于进度更新。
    ///   - manifest: 客户端清单。
    ///   - directory: 目标 `MinecraftDirectory`
    public static func downloadLibraries(
        task: InstallTask? = nil,
        manifest: ClientManifest,
        directory: MinecraftDirectory
    ) async throws {
        var libraryNames: [String] = []
        var items: [DownloadItem] = []
        
        for library in manifest.getNeededLibraries() {
            if let artifact = library.artifact {
                let dest = directory.librariesURL.appending(path: artifact.path)
                if CacheStorage.default.copyLibrary(name: library.name, to: dest) {
                    continue
                }
                
                libraryNames.append(library.name)
                items.append(.init(DownloadSourceManager.shared.getDownloadSource(), { $0.getLibraryURL(library)! }, destination: dest))
            }
        }
        
        try await MultiFileDownloader(task: task, items: items).start()
        
        for library in manifest.getNeededLibraries() {
            if libraryNames.contains(library.name) {
                CacheStorage.default.addLibrary(name: library.name, path: directory.librariesURL.appending(path: library.artifact!.path))
            }
        }
    }
    
    /// 下载清单中的所有本地库 (natives)。
    /// 文件将保存至 `directory.librariesURL` 中。
    /// - Parameters:
    ///   - task: 安装任务，仅用于进度更新。
    ///   - manifest: 客户端清单。
    ///   - directory: 目标 `MinecraftDirectory`
    public static func downloadNatives(
        task: InstallTask? = nil,
        manifest: ClientManifest,
        directory: MinecraftDirectory
    ) async throws {
        var libraryNames: [String] = []
        var items: [DownloadItem] = []
        
        for (library, artifact) in manifest.getNeededNatives() {
            let dest = directory.librariesURL.appending(path: artifact.path)
            if CacheStorage.default.copyLibrary(name: library.name, to: dest) {
                continue
            }
            
            libraryNames.append(library.name)
            items.append(.init(DownloadSourceManager.shared.getDownloadSource(), { $0.getLibraryURL(library)! }, destination: dest))
        }
        
        try await MultiFileDownloader(task: task, items: items).start()
        
        for (library, artifact) in manifest.getNeededNatives() {
            if libraryNames.contains(library.name) {
                CacheStorage.default.addLibrary(name: library.name, path: directory.librariesURL.appending(path: artifact.path))
            }
        }
    }
    
    
    /// 解压清单中的所有本地库 (旧版)。
    /// 解压后的本地库 (dylib 与 jnilib) 将保存至 `instanceURL.appending(path: "natives")` 中。
    /// - Parameters:
    ///   - architecture: 运行时架构，用于过滤架构不兼容的本地库。
    ///   - manifest: 客户端清单。
    ///   - directory: 本地库的保存位置。
    ///   - instanceURL: 实例运行目录。
    public static func unzipNatives(
        architecture: Architecture,
        manifest: ClientManifest,
        directory: MinecraftDirectory,
        instanceURL: URL
    ) throws {
        let nativesURL: URL = instanceURL.appending(path: "natives")
        try? FileManager.default.createDirectory(at: nativesURL, withIntermediateDirectories: true)
        for (_, native) in manifest.getNeededNatives() {
            let jarURL: URL = directory.librariesURL.appending(path: native.path)
            Util.unzip(archiveURL: jarURL, destination: nativesURL, replace: true)
            do {
                try processLibs(architecture: architecture, nativesURL: nativesURL)
            } catch {
                err("处理 natives 失败")
                throw error
            }
        }
    }
    
    // MARK: 处理本地库解压结果
    private static func processLibs(architecture: Architecture, nativesURL: URL) throws {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: nativesURL, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "dylib" || fileURL.pathExtension == "jnilib",
                  let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                  !resourceValues.isDirectory! else { continue }
            
            // 验证架构
            if fileURL.pathExtension == "dylib" {
                let arch = Architecture.getArchOfFile(fileURL)
                guard arch.isCompatiable(with: architecture) else {
                    try? fileManager.removeItem(at: fileURL)
                    log("已清除架构不匹配的可执行文件: \(fileURL.lastPathComponent)")
                    continue
                }
            }
            
            // 拷贝到 natives 根目录
            let destinationURL = nativesURL.appendingPathComponent(fileURL.lastPathComponent)
            if destinationURL == fileURL { continue }
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: fileURL, to: destinationURL)
        }
        
        // 清理非 dylib 文件
        let contents = try fileManager.contentsOfDirectory(at: nativesURL, includingPropertiesForKeys: nil)
        for fileURL in contents {
            if !fileURL.pathExtension.lowercased().hasSuffix("dylib") && !fileURL.pathExtension.lowercased().hasSuffix("jnilib") {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    // MARK: 计算文件数
    public static func calculateFileCount(assetIndex: AssetIndex, manifest: ClientManifest) -> Int {
        let totalFiles = 3 + assetIndex.objects.count + manifest.getNeededLibraries().count + manifest.getNeededNatives().count
        log("总文件数: \(totalFiles)")
        return totalFiles - 2
    }
    
    /// 为实例补全资源文件。
    /// - Parameter instance: 目标实例。
    public static func completeResources(_ instance: MinecraftInstance) async throws {
        let arch: Architecture
        if Architecture.system == .x64 { arch = .x64 }
        else { arch = instance.isUsingRosetta ? .x64 : .arm64 }
        
        let version: MinecraftVersion = instance.version
        let manifest: ClientManifest = instance.manifest
        let directory: MinecraftDirectory = instance.minecraftDirectory
        let instanceURL: URL = instance.runningDirectory
        do {
            let assetIndex = try await downloadAssetIndex(version: version, manifest: manifest, directory: directory)
            try await downloadClientJar(version: version, manifest: manifest, instanceURL: instanceURL)
            try await downloadHashResourcesFiles(assetIndex: assetIndex, directory: directory)
            try await downloadLibraries(manifest: manifest, directory: directory)
            try await downloadNatives(manifest: manifest, directory: directory)
            try unzipNatives(architecture: arch, manifest: manifest, directory: directory, instanceURL: instanceURL)
        } catch {
            throw InstallingError.minecraftInstallFailed(error: error)
        }
    }
}
