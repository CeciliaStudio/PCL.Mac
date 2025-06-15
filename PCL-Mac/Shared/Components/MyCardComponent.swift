//
//  ListComponent.swift
//  PCL-Mac
//
//  Created by YiZhiMCQiu on 2025/5/18.
//

import SwiftUI

struct MyCardComponent<Content: View>: View {
    @ObservedObject private var dataManager: DataManager = .shared
    
    let title: String
    private let content: Content
    @State private var isHovered: Bool = false
    @State private var isUnfolded: Bool = false // 带动画
    @State private var showContent: Bool = false // 无动画
    @State private var internalContentHeight: CGFloat = .zero
    @State private var contentHeight: CGFloat = .zero
    @State private var lastClick: Date = Date()

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Text(title)
                        .font(.custom("PCL English", size: 14))
                    Spacer()
                    Image("FoldController")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .offset(x: -8, y: 4)
                        .rotationEffect(.degrees(isUnfolded ? 180 : 0), anchor: .center)
                }
                .foregroundStyle(isHovered ? AnyShapeStyle(LocalStorage.shared.theme.getTextStyle()) : AnyShapeStyle(.black))
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if Date().timeIntervalSince(lastClick) < 0.2 {
                            return
                        }
                        lastClick = Date()
                        if !showContent {
                            showContent = true
                            withAnimation(.linear(duration: 0.2)) {
                                isUnfolded = true
                                contentHeight = internalContentHeight
                            }
                        } else {
                            contentHeight = min(2000, contentHeight)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0)) {
                                isUnfolded = false
                                contentHeight = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                showContent = false
                            }
                        }
                    }
            }
            .frame(height: 9)

            ZStack(alignment: .top) {
                content
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: ContentHeightKey.self, value: proxy.size.height)
                        }
                    )
                    .opacity(showContent ? 1 : 0)
            }
            .frame(height: contentHeight, alignment: .top)
            .clipped()
            .padding(.top, showContent ? 10 : 0)
            .animation(.easeInOut(duration: 0.3), value: isUnfolded)
            .animation(.easeInOut(duration: 0.3), value: contentHeight)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white)
                .shadow(color: isHovered ? Color(hex: 0x0B5BCB) : .gray, radius: 2, x: 0.5, y: 0.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hover in
            isHovered = hover
        }
        .onPreferenceChange(ContentHeightKey.self) { h in
            if h > 0 { internalContentHeight = h }
        }
    }
}

fileprivate struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
struct StaticMyCardComponent<Content: View>: View {
    @ObservedObject private var dataManager: DataManager = DataManager.shared
    
    let title: String
    let content: () -> Content
    @State private var isHovered: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Text(title)
                    .font(.custom("PCL English", size: 14))
                    .foregroundStyle(isHovered ? AnyShapeStyle(LocalStorage.shared.theme.getTextStyle()) : AnyShapeStyle(.black))
                Spacer()
            }
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white)
                .shadow(color: isHovered ? Color(hex: 0x0B5BCB) : .gray, radius: isHovered ? 2 : 2, x: 0.5, y: 0.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hover in
            isHovered = hover
        }
    }
}

struct TitlelessMyCardComponent<Content: View>: View {
    let content: () -> Content
    @State private var isHovered: Bool = false
    
    var body: some View {
        VStack {
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white)
                .shadow(color: isHovered ? Color(hex: 0x0B5BCB) : .gray, radius: isHovered ? 2 : 2, x: 0.5, y: 0.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hover in
            isHovered = hover
        }
    }
}

#Preview {
    SettingsView()
        .padding()
        .background(Color(hex: 0xC7D9F0))
}
