//
//  AnnouncementExtension.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/10/16.
//

import SwiftUI

extension Announcement {
    @ViewBuilder
    func makeContentView() -> some View {
        ForEach(content) { (content: Announcement.Content) in
            Group {
                switch content {
                case .text(let text):
                    SwiftUI.Text(text.content)
                        .font(.custom("PCL English", size: text.size))
                        .foregroundStyle(Color("TextColor"))
                case .link(let link):
                    SwiftUI.Text(link.display)
                        .font(.custom("PCL English", size: 14))
                        .foregroundStyle(.blue)
                        .onTapGesture {
                            NSWorkspace.shared.open(link.url)
                        }
                case .tip(let tip):
                    MyTip(text: tip.text, color: tip.color)
                }
            }
        }
    }
}
