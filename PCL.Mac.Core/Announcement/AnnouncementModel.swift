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
    
    public enum Content {
        case text(Text)
        case link(Link)
        case tip(Tip)
    }
    
    public struct Text {
        public let content: String
    }
    
    public struct Link {
        public let url: URL
        public let display: String
    }
    
    public struct Tip {
        public let text: String
        public let color: TipColor
        public enum TipColor: String {
            case blue, red, yellow
        }
    }
}
