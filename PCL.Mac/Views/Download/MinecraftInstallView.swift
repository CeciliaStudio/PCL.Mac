//
//  MinecraftInstallView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/8.
//

import SwiftUI
import SwiftyJSON

struct MinecraftInstallView: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @State private var name: String
    @State private var tasks: InstallTasks = .empty()
    @State private var errorMessage: String = ""
    @State private var loader: LoaderVersion? = nil
    
    let version: MinecraftVersion
    
    init(_ version: MinecraftVersion) {
        self.version = version
        self.name = version.displayName
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                TitlelessMyCard {
                    HStack(alignment: .center) {
                        Image(loader != nil ? "\(loader!.loader.rawValue.capitalized)Icon" : version.getIconName())
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35)
                        VStack {
                            MyTextField(text: $name)
                                .foregroundStyle(Color("TextColor"))
                                .onChange(of: name) { _ in
                                    checkName()
                                }
                                .onAppear(perform: checkName)
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundStyle(Color(hex: 0xFF4C4C))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: errorMessage)
                    }
                }
                .padding()
                
                VStack {
                    LoaderCard(index: 1, loader: .fabric, selectedLoader: $loader, name: $name, version: version)
                        .padding()
                        .padding(.top, 20)
                    
                    LoaderCard(index: 2, loader: .forge, selectedLoader: $loader, name: $name, version: version)
                        .padding()
                    
                    LoaderCard(index: 3, loader: .neoforge, selectedLoader: $loader, name: $name, version: version)
                        .padding()
                }
                .onChange(of: loader) { old, new in
                    // 移除 Mod 加载器
                    if let old, new == nil {
                        if name == version.displayName + "-" + old.loader.getName() {
                            name = version.displayName
                        }
                        checkName()
                    }
                    // 添加 Mod 加载器
                    else if let new, old == nil {
                        if name == version.displayName { name.append("-\(new.loader.getName())") }
                    }
                }
                
                Spacer()
            }
            .scrollIndicators(.never)
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RoundedButton {
                        HStack {
                            Image("DownloadIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20)
                            Text("开始下载")
                                .font(.custom("PCL English", size: 16))
                        }
                    } onClick: {
                        startInstall()
                    }
                    .foregroundStyle(.white)
                    .padding()
                    Spacer()
                }
            }
        }
        .onAppear {
            dataManager.leftTab(0) { EmptyView() }
        }
    }
    
    private func startInstall() {
        // 若实例名无效则直接返回
        guard errorMessage.isEmpty else {
            hint(errorMessage, .critical)
            return
        }
        
        if DataManager.shared.inprogressInstallTasks != nil { return }
        let directory: MinecraftDirectory = MinecraftDirectoryManager.shared.current
        let instanceURL = directory.versionsURL.appending(path: name)
        
        // 如果选择了加载器，添加加载器安装任务
        if let loader {
            let task: InstallTask? =
            switch loader.loader {
            case .fabric: FabricInstallTask(directory: directory, instanceURL: instanceURL, loaderVersion: loader.version)
            case .forge, .neoforge: ForgeInstallTask(directory: directory, instanceURL: instanceURL, loaderVersion: loader.version, isNeoforge: loader.loader == .neoforge)
            default: nil
            }
            tasks.addTask(key: loader.loader.rawValue, task: task!)
        }
        
        // 设置 MinecraftInstallTask 的实例名
        let minecraftInstallTask = MinecraftInstallTask(instanceURL: instanceURL, version: version, minecraftDirectory: directory)
        tasks.addTask(key: "minecraft", task: minecraftInstallTask)
        
        // 切换到安装任务页面
        DataManager.shared.inprogressInstallTasks = self.tasks
        DataManager.shared.router.append(.installing(tasks: tasks))
        // 开始安装
        tasks.startAll { result in
            switch result {
            case .success(_):
                hint("\(name) 安装完成！", .finish)
                onInstallFinish(directory: directory, instanceURL: instanceURL, name: name)
                MinecraftDirectoryManager.shared.setDefaultInstance(name)
            case .failure(let failure):
                PopupManager.shared.show(.init(.error, "Minecraft 安装失败", "\(failure.localizedDescription)\n若要寻求帮助，请进入设置 > 其它 > 打开日志，将选中的文件发给别人，而不是发送此页面的照片或截图。", [.ok]))
            }
        }
    }
    
    private func onInstallFinish(directory: MinecraftDirectory, instanceURL: URL, name: String) {
        do {
            // 修改清单中的 id
            let manifestURL = instanceURL.appending(path: "\(instanceURL.lastPathComponent).json")
            guard FileManager.default.fileExists(atPath: manifestURL.path),
                  let data = try FileHandle(forReadingFrom: manifestURL).readToEnd(),
                  var dict = try JSON(data: data).dictionaryObject else {
                return
            }
            dict["id"] = instanceURL.lastPathComponent
            try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .withoutEscapingSlashes]).write(to: manifestURL)
            
            // 初始化实例
            let instance = MinecraftInstance.create(directory: directory, runningDirectory: instanceURL)
            instance?.config.minecraftVersion = version.displayName
            instance?.saveConfig()
        } catch {
            err("无法修改 id: \(error.localizedDescription)")
        }
    }
    
    private func checkName() {
        if name == version.displayName && loader != nil {
            errorMessage = "带 Mod 加载器的实例名不能与版本号一致！"
        } else if name.isEmpty {
            errorMessage = "实例名不能为空！"
        } else if FileManager.default.fileExists(atPath: MinecraftDirectoryManager.shared.current.versionsURL.appending(path: name).path) {
            errorMessage = "已有同名实例！"
        } else {
            errorMessage = ""
        }
    }
}

private struct LoaderVersion: Identifiable, Equatable {
    let id: UUID = .init()
    let loader: ClientBrand
    let version: String
    let stable: Bool
    var displayName: String
    
    init(loader: ClientBrand, version: String, stable: Bool) {
        self.init(loader: loader, version: version, stable: stable, displayName: version)
    }
    
    init(loader: ClientBrand, version: String, stable: Bool, displayName: String) {
        self.loader = loader
        self.version = version
        self.stable = stable
        self.displayName = displayName
    }
    
    static func == (lhs: LoaderVersion, rhs: LoaderVersion) -> Bool {
        lhs.version == rhs.version && lhs.loader == rhs.loader
    }
}

fileprivate struct LoaderCard: View {
    @State private var isAppeared: Bool = false
    @State private var showFoldController: Bool = false
    @State private var showCancelButton: Bool = false
    @State private var versions: [LoaderVersion]? = nil
    @State private var isUnfolded: Bool = false
    @State private var text: String = "加载中……"
    @Binding private var selectedLoader: LoaderVersion?
    @Binding private var name: String
    
    private let index: Int
    private let loader: ClientBrand
    private let version: MinecraftVersion
    
    init(
        index: Int,
        loader: ClientBrand,
        selectedLoader: Binding<LoaderVersion?>,
        name: Binding<String>,
        version: MinecraftVersion
    ) {
        self.index = index
        self.loader = loader
        self.version = version
        self._selectedLoader = selectedLoader
        self._name = name.wrappedValue == version.displayName ? name : .constant(name.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            if showFoldController, let versions = versions {
                MyCard(index: index, title: loader.getName(), unfoldBinding: $isUnfolded) {
                    LazyVStack(spacing: 0) {
                        ForEach(versions) { version in
                            ListItem(iconName: "\(loader.rawValue.capitalized)Icon", title: version.displayName, description: version.stable ? "稳定版" : "测试版", isSelected: selectedLoader == version)
                                .animation(.easeInOut(duration: 0.2), value: selectedLoader?.id)
                                .onTapGesture {
                                    selectedLoader = version
                                    isUnfolded = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        showFoldController = false
                                        showCancelButton = true
                                    }
                                }
                        }
                    }
                }
            } else {
                TitlelessMyCard(index: index) {
                    HStack {
                        MaskedTextRectangle(text: loader.getName())
                        Spacer()
                        if showCancelButton {
                            Image(systemName: "xmark")
                                .resizable()
                                .scaledToFit()
                                .bold()
                                .frame(width: 16)
                                .foregroundStyle(Color("TextColor"))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    showCancelButton = false
                                    showFoldController = true
                                    selectedLoader = nil
                                }
                        }
                    }
                    .frame(height: 9)
                }
            }
            
            if !isUnfolded {
                HStack {
                    overlayContent
                    .font(.custom("PCL English", size: 14))
                    .foregroundStyle(Color(hex: 0x8C8C8C))
                    .offset(x: 150, y: isAppeared ? 14 : -11)
                    .opacity(isAppeared ? 1 : 0)
                    
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .task {
            await loadVersions()
        }
        .onChange(of: versions) { _ in
            guard let versions else {
                text = "加载中……"
                return
            }
            
            if versions.isEmpty {
                text = "无可用版本"
            } else {
                text = "可以添加"
                DispatchQueue.main.async {
                    showFoldController = true
                }
            }
        }
        .onChange(of: selectedLoader) { _ in
            if let selectedLoader, selectedLoader.loader != loader {
                text = "与 \(selectedLoader.loader.getName()) 不兼容"
                showFoldController = false
                isUnfolded = false
            } else if selectedLoader == nil {
                text = "可以添加"
                showFoldController = true
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.04) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    isAppeared = true
                }
            }
        }
    }
    
    private var overlayContent: some View {
        HStack {
            if let selected = selectedLoader, selected.loader == loader {
                Image("\(loader.rawValue.capitalized)Icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16)
                Text(selected.displayName)
            } else {
                Text(text)
            }
        }
    }
    
    private func loadVersions() async {
        var versions: [LoaderVersion] = []
        switch loader {
        case .fabric:
            if let json = await Requests.get("https://meta.fabricmc.net/v2/versions/loader/\(version.displayName)").json {
                versions = json.arrayValue.map { LoaderVersion(loader: .fabric, version: $0["loader"]["version"].stringValue, stable: $0["loader"]["stable"].boolValue) }
            }
        case .forge:
            if let json = await Requests.get("https://bmclapi2.bangbang93.com/forge/minecraft/\(version.displayName)").json {
                versions = json.arrayValue.map { LoaderVersion(loader: .forge, version: $0["version"].stringValue, stable: true) }
            }
        case .neoforge:
            if let json = await Requests.get("https://bmclapi2.bangbang93.com/neoforge/list/\(version.displayName)").json {
                versions = json.arrayValue.map { LoaderVersion(loader: .neoforge, version: $0["version"].stringValue, stable: true) }
            }
        default:
            break
        }
        
        for i in 0..<versions.count {
            if versions[i].version.starts(with: "1.20.1") {
                versions[i] = LoaderVersion(
                    loader: versions[i].loader,
                    version: versions[i].version,
                    stable: versions[i].stable,
                    displayName: String(versions[i].version.dropFirst(7))
                )
            }
        }
        
        versions.sort { version1, version2 in
            return version1.displayName.compare(version2.displayName, options: .numeric) == .orderedDescending
        }
        self.versions = versions
    }
    
    private struct ListItem: View {
        let iconName: String
        let title: String
        let description: String
        let isSelected: Bool
        
        init(iconName: String, title: String, description: String, isSelected: Bool) {
            self.iconName = iconName
            self.title = title
            self.description = description
            self.isSelected = isSelected
        }
        
        var body: some View {
            MyListItem(isSelected: isSelected) {
                HStack {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35)
                        .padding(.leading, 5)
                    VStack(alignment: .leading) {
                        Text(title)
                            .foregroundStyle(Color("TextColor"))
                        Text(description)
                            .foregroundStyle(Color(hex: 0x8C8C8C))
                    }
                    .font(.custom("PCL English", size: 14))
                    Spacer()
                }
                .padding(4)
            }
        }
    }
}
