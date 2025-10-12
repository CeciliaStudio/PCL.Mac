//
//  MinecraftVersionListView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/6/20.
//

import SwiftUI

fileprivate struct VersionView: View, Identifiable {
    private let name: String
    private let description: String
    private let icon: String
    private let version: VersionManifest.GameVersion
    
    let id: UUID = UUID()
    
    init(version: VersionManifest.GameVersion, isLatest: Bool = false) {
        self.name = version.id
        
        var description = DateFormatters.shared.displayDateFormatter.string(from: version.releaseTime)
        if isLatest {
            description = "最新\(version.type == .release ? "正式" : "预览")版，发布于 " + description
        } else if version.type == .aprilFool {
            description = VersionManifest.getAprilFoolDescription(version.id)
        }
        self.description = description
        self.version = version
        self.icon = version.parse().getIconName()
    }
    
    var body: some View {
        MyListItem {
            HStack {
                Image(self.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 35)
                    .padding(.leading, 5)
                VStack(alignment: .leading) {
                    Text(self.name)
                        .font(.custom("PCL English", size: 14))
                        .foregroundStyle(Color("TextColor"))
                        .padding(.top, 5)
                    Text(self.description)
                        .font(.custom("PCL English", size: 14))
                        .foregroundStyle(Color(hex: 0x7F8790))
                        .padding(.bottom, 5)
                }
                Spacer()
            }
        }
        .onTapGesture {
            DataManager.shared.router.append(.minecraftInstall(version: version.parse()))
        }
    }
}

struct MinecraftVersionListView: View {
    @ObservedObject private var dataManager: DataManager = .shared
    
    var body: some View {
        ScrollView {
            VStack {
                StaticMyCard(index: 0, title: "最新版本") {
                    VStack {
                        VersionView(version: dataManager.versionManifest.getLatestRelease(), isLatest: true)
                        VersionView(version: dataManager.versionManifest.getLatestSnapshot(), isLatest: true)
                    }
                    .padding(.top, 12)
                }
                .padding()
                
                categoryCard(index: 1, label: "正式版")  { $0.type == .release }
                categoryCard(index: 2, label: "预览版") { $0.type == .snapshot || $0.type == .pending }
                categoryCard(index: 3, label: "远古版") { $0.type == .beta || $0.type == .alpha }
                categoryCard(index: 4, label: "愚人节版") { $0.type == .aprilFool }
                Spacer()
            }
            .padding(.bottom, 20)
        }
        .zIndex(0)
        .transition(.move(edge: .leading).combined(with: .opacity))
        .scrollIndicators(.never)
    }
    
    @ViewBuilder
    private func categoryCard(index: Int, label: String, filter: (VersionManifest.GameVersion) -> Bool) -> some View {
        let versions = dataManager.versionManifest!.versions.filter(filter)
        MyCard(index: index, title: "\(label) (\(versions.count))") {
            LazyVStack(spacing: 0) {
                ForEach(versions, id: \.id) { version in
                    VersionView(version: version)
                }
            }
            .padding(.top, 12)
        }
        .cardId(label)
        .padding()
    }
}
