//
//  AnnouncementManager.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/10/16.
//

import Foundation
import SwiftyJSON

public class AnnouncementManager: ObservableObject {
    public static let shared: AnnouncementManager = .init(apiRoot: URL(string: "https://gitee.com/yizhimcqiu/PCL.Mac.Announcements/raw/main")!)
    @Published public var lastAnnouncement: Announcement?
    private let apiRoot: URL
    private var eTag: String?
    
    @discardableResult
    public func fetchAnnouncement() async -> Announcement? {
        do {
            if self.eTag != nil, let eTag = await Requests.request(url: apiRoot.appending(path: "manifest.json"), method: "HEAD").headers["ETag"] {
                if self.eTag == eTag { return lastAnnouncement }
            }
            let response: Response = await Requests.get(apiRoot.appending(path: "manifest.json"))
            let manifest: JSON = try response.getJSONOrThrow()
            self.eTag = response.headers["ETag"]
            
            let announcementURL: URL = apiRoot.appending(path: manifest["latest"].stringValue)
            let xmlString = try String(data: await Requests.get(announcementURL).getDataOrThrow(), encoding: .utf8).unwrap()
            await MainActor.run {
                self.lastAnnouncement = .parse(from: xmlString)
            }
            return self.lastAnnouncement
        } catch {
            return nil
        }
    }
    
    private init(apiRoot: URL) {
        self.apiRoot = apiRoot
    }
}
