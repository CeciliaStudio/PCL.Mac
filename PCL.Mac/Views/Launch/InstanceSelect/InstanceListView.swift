//
//  InstanceListView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/9/11.
//

import SwiftUI

struct InstanceListView: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @ObservedObject private var directory: MinecraftDirectory
    @MainActor @State private var hasFinishedLoading: Bool = false
    @MainActor @State private var error: Error? = nil
    
    init(directory: MinecraftDirectory) {
        self.directory = directory
    }
    
    var body: some View {
        Group {
            if hasFinishedLoading {
                if directory.instances.isEmpty {
                    Text("未安装任何实例")
                        .font(.custom("PCL English", size: 14))
                        .foregroundStyle(Color("TextColor"))
                } else if let error {
                    Text("加载实例列表失败\n\(error.localizedDescription)")
                        .font(.custom("PCL English", size: 14))
                        .foregroundStyle(Color("TextColor"))
                } else {
                    ScrollView {
                        if directory.instances.contains(where: { $0.brand != .vanilla }) {
                            createInstanceCard(index: 0, title: "可安装 Mod") { $0.brand != .vanilla }
                                .padding()
                        }
                        createInstanceCard(index: 1, title: "常规实例") { $0.brand == .vanilla }
                            .padding()
                            .padding(.bottom, 25)
                    }
                    .scrollIndicators(.never)
                }
            } else {
                Text("加载实例列表中")
                    .font(.custom("PCL English", size: 14))
                    .foregroundStyle(Color("TextColor"))
            }
        }
        .onAppear {
            MinecraftDirectoryManager.shared.current = directory
            if directory.instances.isEmpty {
                Task {
                    do {
                        try await directory.loadInstances()
                    } catch {
                        self.error = error
                    }
                    self.hasFinishedLoading = true
                }
            } else {
                hasFinishedLoading = true
            }
        }
    }
    
    private func createInstanceCard(index: Int, title: String, _ predicate: @escaping (InstanceInfo) -> Bool) -> some View {
        MyCard(index: index, title: title) {
            LazyVStack(spacing: 0) {
                ForEach(directory.instances.filter(predicate), id: \.self) { instanceInfo in
                    InstanceListItem(instanceInfo)
                }
            }
        }
    }
    
    private struct InstanceListItem: View {
        @State private var isHovered: Bool = false
        private let info: InstanceInfo
        
        init(_ info: InstanceInfo) {
            self.info = info
        }
        
        var body: some View {
            MyListItem {
                HStack {
                    Image(info.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35)
                        .padding(.leading, 5)
                    VStack(alignment: .leading) {
                        Text(info.name)
                            .font(.custom("PCL English", size: 14))
                            .foregroundStyle(Color("TextColor"))
                            .padding(.top, 5)
                        Text(info.version.displayName)
                            .font(.custom("PCL English", size: 14))
                            .foregroundStyle(Color(hex: 0x7F8790))
                            .padding(.bottom, 5)
                    }
                    Spacer()
                }
            }
            .onTapGesture {
                MinecraftDirectoryManager.shared.setDefaultInstance(info.name)
                DataManager.shared.router.setRoot(.launch)
            }
            .onHover { isHovered in
                self.isHovered = isHovered
            }
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
    }
}
