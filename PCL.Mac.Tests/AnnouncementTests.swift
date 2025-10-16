//
//  AnnouncementTests.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/10/16.
//

import Foundation
import PCL_Mac
import Testing

struct AnnouncementTests {
    @Test func testParse() async throws {
        let xml = String(data: try await Requests.get("https://gitee.com/yizhimcqiu/PCL.Mac.Announcements/raw/main/announcements/0.pma").getDataOrThrow(), encoding: .utf8)!
        guard let announcement = Announcement.parse(from: xml) else {
            assertionFailure("Failed to parse announcement")
            return
        }
        print("\(announcement.isImportant ? "重要公告" : "公告") | \(announcement.title)")
        print("作者:\t\(announcement.author)")
        print("发布时间:\t\(DateFormatters.shared.displayDateFormatter.string(from: announcement.time))")
        for content in announcement.content {
            switch content {
            case .text(let text):
                print(text.content)
            case .link(let link):
                print(link.display)
            case .tip(let tip):
                print("提示: \(tip.text)")
            }
        }
    }
}
