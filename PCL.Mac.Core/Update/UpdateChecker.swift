//
//  UpdateChecker.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/9/29.
//

import Foundation
import SwiftyJSON
import Cocoa

public class UpdateChecker {
    public static func fetchVersions() async throws -> LauncherVersionList {
        let json: JSON = try await Requests.get(
            "https://gitee.com/yizhimcqiu/PCL.Mac.Releases/raw/main/versions.json"
        ).getJSONOrThrow()
        
        return LauncherVersionList(json: json)
    }
    
    public static func isLauncherUpToDate(list: LauncherVersionList) -> Bool {
        guard let version = list.getVersion(name: SharedConstants.shared.version) else {
            return true
        }
        if AppSettings.shared.launcherVersionId == -1 {
            AppSettings.shared.launcherVersionId = version.id
        }
        if SharedConstants.shared.isDevelopment {
            return true
        }
        return list.getLatestVersion().id <= AppSettings.shared.launcherVersionId
    }
    
    public static func update(to version: LauncherVersion) async throws {
        // 创建临时目录
        let temp = TemperatureDirectory(name: "LauncherUpdate")
        defer { temp.free() }
        
        // 下载 App 归档
        let url = URL(string: "https://gitee.com/yizhimcqiu/PCL.Mac.Releases/raw/main")!
            .appending(path: version.sha1.prefix(2)).appending(path: version.sha1)
        let archiveURL = temp.getURL(path: "archive.zip")
        try await SingleFileDownloader.download(url: url, destination: archiveURL)
        try FileManager.default.unzipItem(at: archiveURL, to: temp.getURL(path: "launcher"))
        let newAppURL = temp.getURL(path: "launcher/PCL.Mac.app")
        
        // 替换 App
        try FileManager.default.removeItem(at: Bundle.main.bundleURL)
        try FileManager.default.moveItem(at: newAppURL, to: Bundle.main.bundleURL)
        temp.free()
        
        // 重启
        let process = Process()
        process.executableURL = Bundle.main.bundleURL
            .appending(path: "Contents").appending(path: "MacOS").appending(path: "PCL.Mac")
        try process.run()
        await NSApp.terminate(nil)
    }
    
    private init() {}
}

public struct LauncherVersion {
    public let id: Int
    public let tag: String
    public let name: String
    public let sha1: String
    public let time: Date
    
    public init(id: Int, tag: String, name: String, sha1: String, time: Date) {
        self.id = id
        self.tag = tag
        self.name = name
        self.sha1 = sha1
        self.time = time
    }
    
    public init(json: JSON) {
        self.init(
            id: json["id"].intValue,
            tag: json["tag"].stringValue,
            name: json["name"].stringValue,
            sha1: json["sha1"].stringValue,
            time: DateFormatters.shared.iso8601Formatter.date(from: json["time"].stringValue)!
        )
    }
}

public struct LauncherVersionList {
    public let latest: String
    public let versions: [String: LauncherVersion]
    
    public init(json: JSON) {
        self.latest = json["latest"].stringValue
        self.versions = Dictionary(uniqueKeysWithValues: json["versions"].arrayValue.map {
            let version = LauncherVersion(json: $0)
            return (version.tag, version)
        })
    }
    
    public func getVersion(tag: String) -> LauncherVersion? {
        return versions[tag]
    }
    
    public func getVersion(name: String) -> LauncherVersion? {
        return versions.values.first { $0.name == name }
    }
    
    public func getLatestVersion() -> LauncherVersion! {
        return versions[latest]
    }
}
