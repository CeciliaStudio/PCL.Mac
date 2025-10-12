//
//  TitleBarView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/17.
//

import SwiftUI

struct DraggableArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableHelperView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class DraggableHelperView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        self.window?.defaultButtonCell?.performClick(self)
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return self
    }
}

struct GenericTitleBarView<Content: View>: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack {
            ZStack {
                DraggableArea()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                HStack(alignment: .center) {
                    content()
                    Spacer()
                    if AppSettings.shared.windowControlButtonStyle == .pcl {
                        WindowControlButton.Miniaturize
                        WindowControlButton.Close
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 48)
        .background(
            AppSettings.shared.theme.getStyle()
        )
    }
}

struct TitleBarView: View {
    @ObservedObject private var dataManager: DataManager = DataManager.shared
    
    var body: some View {
        GenericTitleBarView {
            Group {
                if AppSettings.shared.windowControlButtonStyle == .pcl {
                    Image("TitleLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 19)
                        .bold()
                    MyTag(label: "Mac", backgroundColor: .white)
                        .foregroundStyle(AppSettings.shared.theme.getTextStyle())
                }
                Spacer()
                MenuItemButton(route: .launch)
                MenuItemButton(route: .download)
                MenuItemButton(route: .settings)
                MenuItemButton(route: .others)
            }
        }
    }
}

struct SubviewTitleBarView: View {
    @ObservedObject private var dataManager: DataManager = DataManager.shared

    var body: some View {
        GenericTitleBarView {
            WindowControlButton.Back
                .padding(.leading, AppSettings.shared.windowControlButtonStyle == .macOS ? 40 : 0)
            Text(dataManager.router.getLast().title)
                .font(.custom("PCL English", size: 16))
                .foregroundStyle(.white)
        }
    }
}

struct MenuItemButton: View {
    @ObservedObject private var dataManager: DataManager = DataManager.shared
    @State private var isHovered = false
    
    private let route: AppRoute
    private let label: String
    private let imageName: String
    
    init(route: AppRoute) {
        self.route = route
        self.label = switch route {
        case .launch: "启动"
        case .download: "下载"
        case .settings: "设置"
        case .others: "更多"
        default: ""
        }
        self.imageName = switch route {
        case .launch: "LaunchIcon"
        case .download: "DownloadIcon"
        case .settings: "SettingsIcon"
        case .others: "OthersIcon"
        default: ""
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .foregroundStyle(dataManager.router.getRoot() == route ? .white : (isHovered ? Color(hex: 0xFFFFFF, alpha: 0.17) : .clear))
            
            HStack {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                Text(label)
            }
            .foregroundStyle(dataManager.router.getRoot() == route ?
                             AnyShapeStyle(AppSettings.shared.theme.getTextStyle()) : AnyShapeStyle(.white))
        }
        .frame(width: 75, height: 27)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.2), value: dataManager.router.getRoot() == route)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if dataManager.router.getRoot() != route {
                        dataManager.router.setRoot(route)
                    }
                }
        )
        .onHover { isHovered in
            self.isHovered = isHovered
        }
    }
}

#Preview {
    TitleBarView()
}
