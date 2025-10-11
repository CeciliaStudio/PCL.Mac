//
//  DirectoryConfigView.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/10/5.
//

import SwiftUI

struct DirectoryConfigView: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @ObservedObject private var directory: MinecraftDirectory
    
    init(directory: MinecraftDirectory) {
        self.directory = directory
    }
    
    var body: some View {
        ScrollView {
            StaticMyCard(title: "配置") {
                VStack {
                    OptionStack("目录名称") { MyTextField(text: Binding<String>(
                        get: { directory.config.name },
                        set: { directory.config.name = $0 ; directory.objectWillChange.send() }
                    )) }
                    
                    OptionStack("启用符号链接") { Toggle("", isOn: Binding<Bool>(
                        get: { directory.config.enableSymbolicLink },
                        set: { directory.config.enableSymbolicLink = $0 ; directory.objectWillChange.send() }
                    )) }
                }
                .padding()
            }
            .padding()
        }
        .scrollIndicators(.never)
        .onAppear {
            dataManager.leftTab(0) { EmptyView() }
        }
        .onChange(of: directory.config.enableSymbolicLink) { newValue in
            do {
                if newValue {
                    try directory.enableSymbolicLink()
                } else {
                    try directory.disableSymbolicLink()
                }
            } catch {
                err("无法\(newValue ? "开启" : "关闭")符号链接: \(error.localizedDescription)")
                hint("无法\(newValue ? "开启" : "关闭")符号链接: \(error.localizedDescription)", .critical)
            }
        }
    }
}
