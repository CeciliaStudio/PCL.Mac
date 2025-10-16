//
//  AnnouncementModel.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/10/16.
//

import Foundation

public struct Announcement {
    public let title: String
    public let isImportant: Bool
    public let author: String
    public let time: Date
    public let content: [Content]
    
    public enum Content: Identifiable {
        public var id: UUID {
            switch self {
            case .text(let text): text.id
            case .link(let link): link.id
            case .tip(let tip): tip.id
            }
        }
        
        case text(Text)
        case link(Link)
        case tip(Tip)
    }
    
    public struct Text: Identifiable {
        public let id: UUID = UUID()
        public let content: String
        public let size: CGFloat
    }
    
    public struct Link: Identifiable {
        public let id: UUID = UUID()
        public let url: URL
        public let display: String
    }
    
    public struct Tip: Identifiable {
        public let id: UUID = UUID()
        public let text: String
        public let color: TipColor
    }
}
