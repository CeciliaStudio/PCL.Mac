//
//  ContentView.swift
//  PCL-Mac
//
//  Created by YiZhiMCQiu on 2025/5/17.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var dataManager: DataManager = .shared
    
    var body: some View {
        ZStack {
            createViewFromRouter()
            if let task = dataManager.inprogressInstallTask {
                if case .installing = dataManager.router.getLast() {
                    EmptyView()
                } else {
                    HStack() {
                        Spacer()
                        VStack() {
                            Spacer()
                            RoundedButton {
                                Image("DownloadItem")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20)
                            } onClick: {
                                dataManager.router.append(.installing(task: task))
                            }
                            .padding()
                        }
                    }
                }
            }
            if let currentPopup = dataManager.currentPopup {
                Group {
                    Rectangle()
                        .fill(Color(hex: 0x000000, alpha: 0.7))
                        .opacity(dataManager.showPopup ? 1 : 0)
                    currentPopup
                        .padding()
                        .opacity(dataManager.showPopup ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.3), value: dataManager.showPopup)
            }
        }
        .onAppear {
            if !AppStartTracker.shared.finished { // 避免多次 onAppear
                AppStartTracker.shared.finished = true
                let cost = Int(Double(Date().timeIntervalSince1970 - AppStartTracker.shared.launchTime) * 1000.0)
                log("主界面加载完成, App 启动总耗时 \(cost)ms")
            }
        }
    }
    
    private func createViewFromRouter() -> some View {
        VStack(spacing: 0) {
            if dataManager.router.getLast().isRoot {
                TitleBarComponent()
            } else {
                SubviewTitleBarComponent()
            }
            HStack {
                ZStack {
                    Rectangle()
                        .fill(Color("BackgroundColor"))
                        .shadow(radius: 2)
                    dataManager.leftTabContent
                }
                .frame(width: dataManager.leftTabWidth)
                .zIndex(1)
                .animation(.easeInOut(duration: 0.15), value: dataManager.leftTabWidth)
                
                AnyView(dataManager.router.getLastView())
                    .foregroundStyle(Color("TextColor"))
                    .frame(minWidth: 815 - dataManager.leftTabWidth, minHeight: 418)
                    .zIndex(0)
                    .overlay {
                        if SharedConstants.shared.isDevelopment {
                            VStack {
                                HStack {
                                    Text(dataManager.router.getDebugText())
                                        .font(.custom("PCL English", size: 14))
                                        .foregroundStyle(Color("TextColor"))
                                    Spacer()
                                }
                                Spacer()
                            }
                        }
                    }
            }
            .background(
                LocalStorage.shared.theme.getBackgroundView()
            )
        }
        .ignoresSafeArea(.container, edges: .top)
    }
    
    static func setPopup(_ popup: PopupOverlay?) {
        DataManager.shared.currentPopup = popup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            DataManager.shared.showPopup = true
        }
    }
}

#Preview {
    ContentView()
}
