//
//  AppDelegate.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/19.
//

import Cocoa
import SwiftUI

class Window: NSWindow {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.level = .normal
        self.hasShadow = true
        self.contentView = contentView
        self.center()
    }
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        if let close = self.standardWindowButton(.closeButton),
           let min = self.standardWindowButton(.miniaturizeButton),
           let zoom = self.standardWindowButton(.zoomButton) {
            
            if AppSettings.shared.windowControlButtonStyle == .macOS {
                close.frame.origin = CGPoint(x: 16, y: -4)
            } else {
                close.frame.origin = CGPoint(x: 64, y: 64)
            }
            min.frame.origin = CGPoint(x: close.frame.maxX + 6, y: close.frame.minY)
            zoom.frame.origin = CGPoint(x: 64, y: 64)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private static let exitFlagURL = SharedConstants.shared.applicationSupportURL.appending(path: ".exit.flag")
    var window: Window!
    
    // MARK: 注册字体
    private func registerCustomFonts() {
        guard let fontURL = Bundle.main.url(forResource: "PCL", withExtension: "ttf") else {
            err("Bundle 内未找到字体")
            return
        }
        
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) == false {
            if let error = error?.takeUnretainedValue() {
                err("无法注册字体: \(error.localizedDescription)")
            } else {
                err("在注册字体时发生未知错误")
            }
        } else {
            log("成功注册字体")
        }
    }
    
    // MARK: 初始化 Java 列表
    private func initJavaList() {
        do {
            try JavaSearch.searchAndSet()
        } catch {
            err("无法初始化 Java 列表: \(error.localizedDescription)")
        }
    }
    
    private func checkOldPreferences() {
        let oldPreferencesURL = URL(fileURLWithUserPath: "~/Library/Preferences/io.github.pcl-communtiy.PCL-Mac.plist") // 原来这里的拼写一直是错的吗
        let newPreferencesURL = URL(fileURLWithUserPath: "~/Library/Preferences/org.ceciliastudio.PCL.Mac.plist")
        if FileManager.default.fileExists(atPath: oldPreferencesURL.path) {
            do {
                // 移动 Preferences
                try FileManager.default.removeItem(at: newPreferencesURL)
                try FileManager.default.moveItem(at: oldPreferencesURL, to: newPreferencesURL)
                
                // 重启 App
                let process = Process()
                process.executableURL = Bundle.main.bundleURL.appending(path: "Contents").appending(path: "MacOS").appending(path: "PCL.Mac")
                try? process.run()
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                err("无法导入旧设置")
            }
        }
    }
    
    // MARK: 初始化 App
    func applicationWillFinishLaunching(_ notification: Notification) {
        if !FileManager.default.fileExists(atPath: SharedConstants.shared.temperatureURL.path) {
            try? FileManager.default.createDirectory(at: SharedConstants.shared.temperatureURL, withIntermediateDirectories: true)
        }
        FileManager.default.createFile(atPath: Self.exitFlagURL.path, contents: nil)
        let start = Date().timeIntervalSince1970
        log("App 已启动")
        PropertyStorage.loadAll()
        checkOldPreferences()
        _ = AppSettings.shared
        registerCustomFonts()
        DataManager.shared.refreshVersionManifest()
        
        log("正在初始化 Java 列表")
        initJavaList()
        log("App 初始化完成, 耗时 \(Int((Date().timeIntervalSince1970 - start) * 1000))ms")
        
#if !DEBUG
        let daemonProcess = Process()
        daemonProcess.executableURL = SharedConstants.shared.applicationResourcesURL.appending(path: "daemon")
        daemonProcess.arguments = [
            String(describing: ProcessInfo.processInfo.processIdentifier),
            Self.exitFlagURL.path
        ]
        do {
            try daemonProcess.run()
            log("守护进程已启动")
        } catch {
            err("无法开启守护进程: \(error.localizedDescription)")
        }
#endif
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let swiftUIView = ContentView()
        let hostingView = NSHostingView(rootView: swiftUIView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 10
        hostingView.layer?.masksToBounds = true
        window = Window(contentView: hostingView)
        window.makeKeyAndOrderFront(nil)
        
        Task {
            await AnnouncementManager.shared.fetchAnnouncement()
            if AppSettings.shared.showPCLMacPopup {
                if await PopupManager.shared.showAsync(
                    .init(.normal, "欢迎使用 PCL.Mac！", "本启动器是 Plain Craft Launcher（作者：龙腾猫跃）的非官方衍生版。\n若要反馈问题，请在 GitHub 上开 Issue。", [.init(label: "永久关闭", style: .normal), .close])
                ) == 0 {
                    AppSettings.shared.showPCLMacPopup = false
                }
            }
            let list = try await UpdateChecker.fetchVersions()
            if !UpdateChecker.isLauncherUpToDate(list: list) {
                let latest = list.getLatestVersion()!
                let changelogURL = URL(string: "https://gitee.com/yizhimcqiu/PCL.Mac.Releases/blob/main/changelog/\(latest.tag).md")!
                await MainActor.run {
                    PopupManager.shared.show(
                        .init(.normal, "PCL.Mac 有更新可用", "发现新版本 \(latest.name)\n发布时间：\(DateFormatters.shared.displayDateFormatter.string(from: latest.time))\n更新日志：\(changelogURL.absoluteString)",
                              [.init(label: "打开更新日志", style: .normal, closeOnClick: false), .init(label: "跳过", style: .normal), .init(label: "更新", style: .accent)]),
                        callback: { id in
                            if id == 0 {
                                NSWorkspace.shared.open(changelogURL)
                            } else if id == 1 {
                                AppSettings.shared.launcherVersionId = latest.id
                            } else if id == 2 {
                                Task {
                                    try await UpdateChecker.update(to: list.getLatestVersion())
                                }
                                hint("开始下载更新，下载完成后将自动重启……")
                                AppSettings.shared.launcherVersionId = latest.id
                            }
                        })
                }
            }
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MinecraftDirectoryManager.shared.save()
        PropertyStorage.saveAll()
        log("PropertyStorage 保存完成")
        try? FileManager.default.removeItem(at: Self.exitFlagURL)
        return .terminateNow
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
