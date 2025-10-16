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
        willSet {
            guard let old = path.last, let new = newValue.last else { return }
            switch old {
            case .minecraftVersionList, .projectSearch(_): break
            default:
                if new == .download {
                    routeID = .init()
                }
            }
        }
    }
    private var routeID: UUID = UUID()
    
    public func append(_ route: AppRoute) {
        path.append(route)
    }
    
    public func makeView() -> any View {
        switch getLast() {
        case .launch:
            LaunchView()
        case .accountManagement, .accountList, .newAccount:
            AccountManagementView()
        case .download, .minecraftVersionList, .projectSearch(_):
            DownloadView().id(routeID)
        case .settings, .personalization, .javaSettings, .otherSettings:
            SettingsView()
        case .others, .about, .toolbox, .debug:
            OthersView()
        case .installing(let tasks):
            InstallingView(tasks: tasks)
        case .instanceSelect, .instanceList(_):
            InstanceSelectView()
        case .projectDownload(let summary):
            ProjectDownloadView(id: summary.modId)
        case .instanceSettings, .instanceOverview, .instanceConfig, .instanceMods:
            InstanceSettingsView()
        case .javaDownload:
            JavaInstallView()
        case .themeUnlock:
            ThemeUnlockView()
        case .directoryConfig(let directory):
            DirectoryConfigView(directory: directory)
        case .minecraftInstall(let version):
            MinecraftInstallView(version)
        }
    }
    
    public func getDebugText() -> String {
        return "/" + path.map { $0.name }.joined(separator: "/")
    }
    
    public func removeLast() {
        if path.count == 1 {
            path = [.launch]
        } else {
            path.removeLast()
        }
    }
    
    public func setRoot(_ root: AppRoute) {
        path = [root]
        PageState.shared.currentPageIndex = PageState.pages.firstIndex(of: root)!
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
