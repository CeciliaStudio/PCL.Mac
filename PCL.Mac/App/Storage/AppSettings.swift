//
//  LocalStorage.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/19.
//

import SwiftUI

public enum ColorSchemeOption: Codable {
    case light, dark, system
    func getLabel() -> String {
        switch self {
        case .light:
            "浅色模式"
        case .dark:
            "深色模式"
        case .system:
            "跟随系统"
        }
    }
}

public enum WindowControlButtonStyle: Codable {
    case pcl, macOS
    func getLabel() -> String {
        switch self {
        case .pcl:
            "PCL"
        case .macOS:
            "macOS"
        }
    }
}

public enum DownloadSourceOption: Codable {
    case official, mirror, both
}

public class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    // MARK: - App 设置
    
    /// 是否显示 PCL.Mac 弹窗
    @StoredProperty(.appSettings, "showPCLMacPopup") public var showPCLMacPopup: Bool = true
    
    /// 用户添加的 Java 路径
    @StoredProperty(.appSettings, "userAddedJvmPaths") public var userAddedJvmPaths: [URL] = []
    
    @Published public var theme: Theme!
    
    /// 主题 ID (文件名)
    @StoredProperty(.appSettings, "themeId") public var themeId: String = "pcl" {
        didSet {
            if themeId != self.theme.id {
                self.theme = .load(id: themeId)
                DataManager.shared.objectWillChange.send()
            }
        }
    }
    
    /// 配色方案
    @StoredProperty(.appSettings, "colorScheme") public var colorScheme: ColorSchemeOption = .light {
        didSet {
            DataManager.shared.objectWillChange.send()
        }
    }
    
    /// 窗口按钮样式
    @StoredProperty(.appSettings, "windowControlButtonStyle") public var windowControlButtonStyle: WindowControlButtonStyle = .pcl {
        didSet {
            DataManager.shared.objectWillChange.send()
        }
    }
    
    /// 下载自定义文件时的保存 URL
    @StoredProperty(.appSettings, "customFilesSaveURL") public var customFilesSaveURL: URL = URL(fileURLWithUserPath: "~/Downloads")
    
    /// 使用过的主题解锁码
    @StoredProperty(.appSettings, "usedThemeCodes") public var usedThemeCodes: [String] = []
    
    /// 是否启用超薄材质
    @StoredProperty(.appSettings, "useUltraThinMaterial") public var useUltraThinMaterial: Bool = false {
        didSet {
            DataManager.shared.objectWillChange.send()
        }
    }
    
    /// 用于更新检查的启动器版本 id，更新或跳过更新后更改
    @StoredProperty(.appSettings, "launcherVersionId") public var launcherVersionId: Int = -1
    
    // MARK: - Minecraft 相关
    
    /// 最后一次获取到的 VersionManifest，断网时使用
    @StoredProperty(.minecraft, "lastVersionManifest") public var lastVersionManifest: VersionManifest? = nil
    
    /// 所有 MinecraftDirectory 的 URL
    @StoredProperty(.minecraft, "minecraftDirectoryURLs") public var minecraftDirectoryURLs: [URL] = [URL(fileURLWithUserPath: "~/Library/Application Support/minecraft")]
    
    /// 累计启动次数
    @StoredProperty(.minecraft, "launchCount") public var launchCount: Int = 0
    
    /// 文件下载源
    @StoredProperty(.minecraft, "fileDownloadSource") public var fileDownloadSource: DownloadSourceOption = .both
    
    /// 版本列表源
    @StoredProperty(.minecraft, "versionManifestSource") public var versionManifestSource: DownloadSourceOption = .both
    
    // MARK: - 账号相关
    
    /// 是否登录过一次微软账号
    @StoredProperty(.account, "hasMicrosoftAccount") public var hasMicrosoftAccount: Bool = false
    
    public func updateColorScheme() {
        if colorScheme != .system {
            NSApp.appearance = colorScheme == .light ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
        } else {
            NSApp.appearance = nil
        }
        ColorConstants.colorScheme = colorScheme
        self.theme = .load(id: themeId)
        DataManager.shared.objectWillChange.send()
    }
    
    private init() {
        updateColorScheme()
        log("已加载启动器设置")
    }
}
