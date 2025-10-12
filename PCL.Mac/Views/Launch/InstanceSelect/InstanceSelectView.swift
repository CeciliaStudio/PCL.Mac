//
//  InstanceSelectView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/9/11.
//

import SwiftUI

struct InstanceSelectView: View, SubRouteContainer {
    @ObservedObject private var dataManager: DataManager = .shared
    
    var body: some View {
        Group {
            switch dataManager.router.getLast() {
            case .instanceList(let directory):
                InstanceListView(directory: directory)
                    .id(directory.rootURL)
            default:
                Spacer()
            }
        }
        .onAppear {
            dataManager.leftTab(300) {
                LeftTab()
            }
            dataManager.router.append(.instanceList(directory: MinecraftDirectoryManager.shared.current))
        }
    }
}

fileprivate struct LeftTab: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @ObservedObject private var settings: AppSettings = .shared
    @ObservedObject private var directoryManager: MinecraftDirectoryManager = .shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("文件夹列表")
                .font(.custom("PCL English", size: 12))
                .foregroundStyle(Color(hex: 0x8C8C8C))
                .padding(.leading, 12)
                .padding(.top, 20)
                .padding(.bottom, 4)
            MyList(
                cases: MinecraftDirectoryManager.shared.directories.map(AppRoute.instanceList(directory:)),
                height: 42,
            ) { route, isSelected in
                if case .instanceList(let directory) = route {
                    MinecraftDirectoryListItem(directory: directory)
                        .foregroundStyle(isSelected ? AnyShapeStyle(settings.theme.getTextStyle()) : AnyShapeStyle(Color("TextColor")))
                } else {
                    EmptyView()
                }
            }
            Text("添加或导入")
                .font(.custom("PCL English", size: 12))
                .foregroundStyle(Color(hex: 0x8C8C8C))
                .padding(.leading, 12)
                .padding(.top, 20)
                .padding(.bottom, 4)
            ButtonListItem(imageName: "PlusIcon", text: "添加已有文件夹")
                .onTapGesture {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowedContentTypes = [.folder]
                    
                    if panel.runModal() == .OK {
                        guard !MinecraftDirectoryManager.shared.directories.contains(where: { $0.rootURL == panel.url! }) else {
                            hint("该目录已存在！", .critical)
                            return
                        }
                        let directory = MinecraftDirectory(rootURL: panel.url!, config: .init(name: "自定义目录"))
                        MinecraftDirectoryManager.shared.directories.append(directory)
                        MinecraftDirectoryManager.shared.current = directory
                        hint("添加成功", .finish)
                    }
                }
            ButtonListItem(imageName: "ImportModpackIcon", text: "导入整合包")
                .onTapGesture {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    
                    if panel.runModal() == .OK {
                        importModpack(panel.url!)
                    }
                }
            Spacer()
        }
    }
    
    private func importModpack(_ url: URL) {
        if case .failure(let error) = ModrinthModpackImporter.checkModpack(url) {
            switch error {
            case .zipFormatError:
                PopupManager.shared.show(.init(.error, "无法导入整合包", "该整合包不是一个有效的压缩包！", [.ok]))
            case .unsupported:
                PopupManager.shared.show(.init(.error, "无法导入整合包", "很抱歉，PCL.Mac 暂时只支持导入 Modrinth 整合包……\n你可以使用其它启动器导入，然后把实例文件夹拖入本页面的右侧。", [.ok]))
            }
            return
        }
        
        do {
            let importer = try ModrinthModpackImporter(minecraftDirectory: MinecraftDirectoryManager.shared.current, modpackURL: url)
            let index = try importer.loadIndex()
            let tasks = try importer.createInstallTasks()
            dataManager.inprogressInstallTasks = tasks
            tasks.startAll { result in
                switch result {
                case .success(_):
                    hint("整合包 \(index.name) 导入成功！", .finish)
                case .failure(let failure):
                    PopupManager.shared.show(.init(.error, "导入整合包失败", "\(failure.localizedDescription)\n若要寻求帮助，请进入设置 > 其它 > 打开日志，将选中的文件发给别人，而不是发送此页面的照片或截图。", [.ok]))
                }
            }
        } catch {
            err("创建导入任务失败: \(error.localizedDescription)")
            PopupManager.shared.show(.init(.error, "无法创建导入任务", "\(error.localizedDescription)\n若要寻求帮助，请进入设置 > 其它 > 打开日志，将选中的文件发给别人，而不是发送本页面的照片或截图。", [.ok]))
        }
    }
    
    /// Minecraft 目录列表项
    private struct MinecraftDirectoryListItem: View {
        @ObservedObject private var settings: AppSettings = .shared
        @State private var isHovered: Bool = false
        private let directory: MinecraftDirectory
        
        init(directory: MinecraftDirectory) {
            self.directory = directory
        }
        
        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(directory.config.name)
                        .font(.custom("PCL English", size: 14))
                        .foregroundStyle(.primary)
                    Text(directory.rootURL.path)
                        .font(.custom("PCL English", size: 12))
                        .foregroundStyle(Color(hex: 0x8C8C8C))
                        .lineLimit(1)
                }
                Spacer()
                if isHovered {
                    Image("SettingsIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16)
                        .bold()
                        .foregroundStyle(AppSettings.shared.theme.getTextStyle())
                        .contentShape(Rectangle())
                        .onTapGesture {
                            DataManager.shared.router.removeLast()
                            DataManager.shared.router.append(.directoryConfig(directory: directory))
                        }
                    Image(systemName: "xmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10)
                        .bold()
                        .foregroundStyle(AppSettings.shared.theme.getTextStyle())
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 移除 Minecraft 目录
                            MinecraftDirectoryManager.shared.remove(directory)
                            hint("移除成功", .finish)
                        }
                        .padding(4)
                }
            }
            .animation(.easeInOut, value: isHovered)
            .onHover { isHovered in
                self.isHovered = isHovered
            }
        }
    }
    
    /// 按钮列表项（如导入整合包）
    private struct ButtonListItem: View {
        let imageName: String
        let text: String
        
        var body: some View {
            MyListItem {
                HStack {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22)
                        .foregroundStyle(Color("TextColor"))
                        .padding(.leading)
                        .padding(.top, 6)
                        .padding(.bottom, 6)
                    Text(text)
                        .font(.custom("PCL English", size: 14))
                        .foregroundStyle(Color("TextColor"))
                    Spacer()
                }
            }
            
        }
    }
}
