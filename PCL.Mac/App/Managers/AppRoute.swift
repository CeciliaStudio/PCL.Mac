//
//  AppRoute.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/29.
//

import SwiftUI

public enum AppRoute: Hashable {
    // 根页面
    case launch
    case download
    case settings
    case others
    
    // 子页面
    case accountManagement
    case accountList
    case newAccount
    case installing(tasks: InstallTasks)
    case instanceSelect
    case projectDownload(summary: ProjectSummary)
    case announcementHistory
    case instanceSettings(instance: MinecraftInstance)
    case directoryConfig(directory: MinecraftDirectory)
    case minecraftInstall(version: MinecraftVersion)
    
    // MyList 导航
    case minecraftVersionList
    case projectSearch(type: ProjectType)
    case instanceList(directory: MinecraftDirectory)
    case instanceOverview
    case instanceConfig
    case instanceMods
    case javaDownload
    
    case about
    case toolbox
    case debug
    
    case personalization
    case javaSettings
    case otherSettings
    case themeUnlock
    
    var isRoot: Bool {
        switch self {
        case .launch, .download, .settings, .others,
                .minecraftVersionList, .projectSearch(_),
                .about, .toolbox, .debug,
                .personalization, .javaSettings, .otherSettings:
            return true
        default:
            return false
        }
    }
    
    var name: String {
        switch self {
        case .installing(let task): "installing?task=\(task.id)"
        case .projectDownload(let summary): "projectDownload?summary=\(summary.modId)"
        case .instanceList(let directory): "versionList?rootURL=\(directory.rootURL.path)"
        case .instanceSettings(let instance): "versionSettings?instance=\(instance.name)"
        case .projectSearch(let type): "projectSearch?type=\(type)"
        default:
            String(describing: self)
        }
    }
    
    var title: String {
        switch self {
        case .installing(_): "下载管理"
        case .instanceSelect, .instanceList: "实例选择"
        case .projectDownload(let summary): "资源下载 - \(summary.name)"
        case .accountManagement, .accountList, .newAccount: "账号管理"
        case .announcementHistory: "历史公告"
        case .instanceSettings, .instanceOverview, .instanceConfig, .instanceMods: "实例设置 - \(MinecraftDirectoryManager.shared.current.config.defaultInstance ?? "")"
        case .javaDownload: "Java 下载"
        case .themeUnlock: "主题解锁"
        case .directoryConfig(let directory): "目录配置 - \(directory.config.name)"
        case .minecraftInstall(let version): "Minecraft 安装 - \(version.displayName)"
        default: "发现问题请在 https://github.com/CeciliaStudio/PCL.Mac/issues/new 上反馈！"
        }
    }
    
    func isSame(_ another: AppRoute) -> Bool {
        if case .instanceList(let directory1) = self,
           case .instanceList(let directory2) = another {
            return directory1.rootURL == directory2.rootURL
        }
        
        return self == another
    }
}

public class AppRouter: ObservableObject {
    @Published public var path: [AppRoute] = [.launch] {
        didSet {
            routeID = UUID()
        }
    }
    private var routeID: UUID = UUID()
    
    public func append(_ route: AppRoute) {
        path.append(route)
    }
    
    public func makeView() -> any View {
        switch getLast() {
        case .launch:
            LaunchView().id(routeID)
        case .accountManagement, .accountList, .newAccount:
            AccountManagementView().id(routeID)
        case .download, .minecraftVersionList, .projectSearch(_):
            DownloadView().id(routeID)
        case .settings, .personalization, .javaSettings, .otherSettings:
            SettingsView().id(routeID)
        case .others, .about, .toolbox, .debug:
            OthersView().id(routeID)
        case .installing(let tasks):
            InstallingView(tasks: tasks).id(routeID)
        case .instanceSelect, .instanceList(_):
            InstanceSelectView().id(routeID)
        case .projectDownload(let summary):
            ProjectDownloadView(id: summary.modId).id(routeID)
        case .announcementHistory:
            AnnouncementHistoryView().id(routeID)
        case .instanceSettings, .instanceOverview, .instanceConfig, .instanceMods:
            InstanceSettingsView().id(routeID)
        case .javaDownload:
            JavaInstallView().id(routeID)
        case .themeUnlock:
            ThemeUnlockView().id(routeID)
        case .directoryConfig(let directory):
            DirectoryConfigView(directory: directory).id(routeID)
        case .minecraftInstall(let version):
            MinecraftInstallView(version).id(routeID)
        }
    }
    
    public func getDebugText() -> String {
        return "/" + path.map { $0.name }.joined(separator: "/")
    }
    
    public func removeLast() {
        self.path.removeLast()
        if self.path.isEmpty {
            self.path.append(.launch)
        }
    }
    
    public func setRoot(_ root: AppRoute) {
        path.removeAll()
        path.append(root)
    }
    
    public func getLast() -> AppRoute {
        return path.last!
    }
    
    public func getRoot() -> AppRoute {
        return path.first!
    }
}

/// 若该视图为子页面，且有子路由，需要实现此协议以便正常返回。
protocol SubRouteContainer {
    func shouldPop() -> Bool
}

extension SubRouteContainer {
    func shouldPop() -> Bool { true }
}
