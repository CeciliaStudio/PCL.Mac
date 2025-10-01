//
//  MinecraftVersion.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/20.
//

import Foundation
import SwiftyJSON
import ZIPFoundation
import Cocoa

public class MinecraftInstance: Identifiable, Equatable, Hashable {
    private static var cache: [URL : MinecraftInstance] = [:]
    
    private static let RequiredJava16: MinecraftVersion = MinecraftVersion(displayName: "21w19a", type: .snapshot)
    private static let RequiredJava17: MinecraftVersion = MinecraftVersion(displayName: "1.18-pre2", type: .snapshot)
    private static let RequiredJava21: MinecraftVersion = MinecraftVersion(displayName: "24w14a", type: .snapshot)
    
    public let runningDirectory: URL
    public let minecraftDirectory: MinecraftDirectory
    public let configPath: URL
    public private(set) var version: MinecraftVersion! = nil
    public private(set) var manifest: ClientManifest!
    public var config: MinecraftConfig!
    public var clientBrand: ClientBrand!
    public var isUsingRosetta: Bool = false
    public var name: String { runningDirectory.lastPathComponent }
    
    public let id: UUID = UUID()
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: MinecraftInstance, rhs: MinecraftInstance) -> Bool {
        lhs.id == rhs.id
    }
    
    /// 初始化或从缓存中获取实例。
    /// - Parameters:
    ///   - directory: 实例所在的 `MinecraftDirectory`，在资源补全时会需要部分配置。
    ///   - name: 实例目录名。
    ///   - config: 实例初始配置。若缓存中存在该实例，则该参数被忽略。
    ///   - doCache: 是否将实例放入缓存。
    /// - Returns: 初始化或获取到的实例。如果实例初始化失败，返回 `nil`。
    public static func create(
        directory: MinecraftDirectory,
        name: String,
        config: MinecraftConfig? = nil,
        doCache: Bool = true
    ) -> MinecraftInstance? {
        return create(
            directory: directory,
            runningDirectory: directory.versionsURL.appending(path: name),
            config: config,
            doCache: doCache
        )
    }
    
    /// 初始化或从缓存中获取实例。
    /// - Parameters:
    ///   - directory: 实例所在的 `MinecraftDirectory`，在资源补全时会需要部分配置。
    ///   - runningDirectory: 实例运行目录，存放 JSON 与 JAR。
    ///   - config: 实例初始配置。若缓存中存在该实例，则该参数被忽略。
    ///   - doCache: 是否将实例放入缓存。
    /// - Returns: 初始化或获取到的实例。如果实例初始化失败，返回 `nil`。
    public static func create(
        directory: MinecraftDirectory,
        runningDirectory: URL,
        config: MinecraftConfig? = nil,
        doCache: Bool = true
    ) -> MinecraftInstance? {
        if let cached = cache[runningDirectory] {
            return cached
        }
        
        let instance: MinecraftInstance = .init(directory: directory, runningDirectory: runningDirectory, config: config)
        if instance.setup() {
            if doCache {
                cache[runningDirectory] = instance
            }
            return instance
        } else {
            err("实例初始化失败")
            return nil
        }
    }
    
    public static func clearCache(for runningDirectory: URL) {
        cache.removeValue(forKey: runningDirectory)
        log("已清理实例缓存: \(runningDirectory.lastPathComponent)")
    }
    
    private init(directory: MinecraftDirectory, runningDirectory: URL, config: MinecraftConfig? = nil) {
        self.runningDirectory = runningDirectory
        self.minecraftDirectory = directory
        self.configPath = runningDirectory.appending(path: ".PCL_Mac.json")
        self.config = config
    }
    
    private func setup() -> Bool {
        self.config = self.config ?? loadConfig() ?? MinecraftConfig()
        
        if !loadManifest() { return false }
        if let version = self.config.minecraftVersion {
            self.version = .init(displayName: version)
        } else {
            detectVersion()
            self.config.minecraftVersion = version.displayName
        }
        
        // 寻找可用 Java
        if self.config.javaURL == nil, let jvm = MinecraftInstance.findSuitableJava(version) {
            self.config.javaURL = jvm.executableURL
        }
        saveConfig()
        return true
    }
    
    public func loadConfig() -> MinecraftConfig? {
        let decoder = JSONDecoder()
        do {
            let config = try decoder.decode(MinecraftConfig.self, from: FileHandle(forReadingFrom: configPath).readToEnd().unwrap())
            if config.javaURL != nil && !config.javaURL.isFileURL {
                config.javaURL = URL(fileURLWithPath: config.javaURL.path)
            }
            return config
        } catch {
            err("无法加载配置: \(error.localizedDescription)")
            return nil
        }
    }
    
    public func saveConfig() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            try FileManager.default.createDirectory(
                at: runningDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try encoder.encode(config).write(to: configPath, options: .atomic)
        } catch {
            err("无法保存配置: \(error.localizedDescription)")
        }
    }
    
    private static func getClientBrand(_ manifestString: String) -> ClientBrand {
        if manifestString.contains("neoforged") {
            return .neoforge
        } else if manifestString.contains("fabric") {
            return .fabric
        } else if manifestString.contains("forge") {
            return .forge
        } else {
            return .vanilla
        }
    }
    
    public static func getMinJavaVersion(_ version: MinecraftVersion) -> Int {
        if version >= RequiredJava21 {
            return 21
        } else if version >= RequiredJava17 {
            return 17
        } else if version >= RequiredJava16 {
            return 16
        } else {
            return 8
        }
    }
    
    public static func findSuitableJava(_ version: MinecraftVersion) -> JavaVirtualMachine? {
        let minJavaVersion = getMinJavaVersion(version)
        var suitableJava: JavaVirtualMachine?
        for jvm in DataManager.shared.javaVirtualMachines.sorted(by: { $0.version < $1.version }) {
            if jvm.version < minJavaVersion { continue }
            
            suitableJava = jvm
            
            if jvm.callMethod == .direct {
                break
            }
        }
        
        if suitableJava == nil {
            warn("未找到可用 Java")
            debug("版本: \(version.displayName)")
            debug("最低 Java 版本: \(minJavaVersion)")
        }
        
        return suitableJava
    }
    
    public func launch(_ launchOptions: LaunchOptions, _ launchState: LaunchState) async {
        config.lastLaunch = Date()
        saveConfig()
        // 登录账号
        await launchState.setStage(.login)
        if let account = launchOptions.account {
            launchOptions.playerName = account.name
            launchOptions.uuid = account.uuid
            log("正在登录")
            await account.putAccessToken(options: launchOptions)
            if case .yggdrasil = account {
                try? await MinecraftLauncher.downloadAuthlibInjector() // 后面改成可抛出 + 多阶段
            }
        }
        launchOptions.javaPath = config.javaURL
        
        // 处理 Rosetta
        loadManifest()
        if Architecture.getArchOfFile(launchOptions.javaPath).isCompatiableWithSystem() {
            ArtifactVersionMapper.map(manifest)
            isUsingRosetta = false
        } else {
            ArtifactVersionMapper.map(manifest, arch: .x64)
            isUsingRosetta = true
            warn("正在使用 Rosetta 运行 Minecraft")
        }
        
        // 资源完整性检查
        if !config.skipResourcesCheck && !launchOptions.skipResourceCheck {
            await launchState.setStage(.resourcesCheck)
            log("正在进行资源完整性检查")
            try? await MinecraftInstaller.completeResources(self)
            log("资源完整性检查完成")
        }
        
        // 启动 Minecraft
        let launcher = MinecraftLauncher(self, state: launchState)!
        let exitCode = await launcher.launch(launchOptions)
        if exitCode != 0 && exitCode != 143 {
            log("检测到异常退出代码")
            hint("检测到 Minecraft 出现错误，错误分析已开始……")
            if await PopupManager.shared.showAsync(
                .init(.error, "Minecraft 出现错误", "很抱歉，PCL.Mac 暂时没有分析功能。\n如果要寻求帮助，请把错误报告文件发给对方，而不是发送这个窗口的照片或者截图。\n不要截图！不要截图！！不要截图！！！", [.ok, .init(label: "导出错误报告", style: .accent)])
            ) == 1 {
                await MainActor.run {
                    onCrash(options: launchOptions, state: launchState)
                }
            }
        }
    }
    
    private func onCrash(options: LaunchOptions, state: LaunchState) {
        let savePanel = NSSavePanel()
        savePanel.title = "选择导出位置"
        savePanel.prompt = "导出"
        savePanel.allowedContentTypes = [.zip]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-M-d_HH.mm.ss"
        savePanel.nameFieldStringValue = "错误报告-\(formatter.string(from: .init()))"
        savePanel.beginSheetModal(for: NSApplication.shared.windows.first!) { [unowned self] result in
            if result == .OK {
                if let url = savePanel.url {
                    MinecraftCrashHandler.exportErrorReport(instance: self, options: options, state: state, to: url)
                }
            }
        }
    }
    
    @discardableResult
    public func loadManifest() -> Bool {
        do {
            let manifestPath = runningDirectory.appending(path: runningDirectory.lastPathComponent + ".json")
            
            let data = try FileHandle(forReadingFrom: manifestPath).readToEnd()!
            self.clientBrand = MinecraftInstance.getClientBrand(String(data: data, encoding: .utf8) ?? "")
            
            guard let manifest = try ClientManifest.parse(
                url: manifestPath, minecraftDirectory: minecraftDirectory
            ) else { return false }
            self.manifest = manifest
        } catch {
            err("无法加载客户端清单: \(error.localizedDescription)")
            return false
        }
        
        return true
    }
    
    private func detectVersion() {
        guard version == nil else {
            return
        }
        do {
            let archive = try Archive(url: runningDirectory.appending(path: "\(name).jar"), accessMode: .read)
            guard let entry = archive["version.json"] else {
                throw MyLocalizedError(reason: "version.json 不存在")
            }
            
            var data = Data()
            _ = try archive.extract(entry, consumer: { (chunk) in
                data.append(chunk)
            })
            
            let version = MinecraftVersion(displayName: try JSON(data: data)["id"].stringValue)
            self.version = version
        } catch {
            err("无法检测版本: \(error.localizedDescription)，正在使用清单版本")
            self.version = .init(displayName: manifest.id)
        }
    }
    
    public func getIconName() -> String {
        if self.clientBrand == .vanilla {
            return self.version.getIconName()
        }
        return "\(self.clientBrand.rawValue.capitalized)Icon"
    }
}

public class MinecraftConfig: Codable {
    /// 实例使用的 Java 的路径
    public var javaURL: URL!
    /// 是否跳过资源完整性检查
    public var skipResourcesCheck: Bool = false
    /// 最大内存分配（MB）
    public var maxMemory: Int32 = 4096
    /// 实例进程 QoS
    public var qualityOfService: QualityOfService = .default
    /// 实例版本（缓存）
    public var minecraftVersion: String!
    /// 上次启动时间
    public var lastLaunch: Date?
    /// 模组列表，键为模组文件名，值为对应的 Modrinth Project `slug`
    public var mods: [String: String] = [:]
    
    public init() {}
}

public enum ClientBrand: String, Codable, Hashable {
    case vanilla = "vanilla"
    case fabric = "fabric"
    case quilt = "quilt"
    case forge = "forge"
    case neoforge = "neoforge"
    
    public func getName() -> String {
        if self == .neoforge {
            return "NeoForge"
        } else {
            return self.rawValue.capitalized
        }
    }
    
    public var index: Int {
        switch self {
        case .vanilla: 0
        case .fabric: 1
        case .quilt: 2
        case .forge: 3
        case .neoforge: 4
        }
    }
}

extension QualityOfService: Codable { }
