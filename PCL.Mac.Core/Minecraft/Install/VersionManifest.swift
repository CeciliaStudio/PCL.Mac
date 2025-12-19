//
//  VersionManifest.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/20.
//

import Foundation
import SwiftyJSON

public class VersionManifest {
    public private(set) static var latest: VersionManifest = .init()
    private static let aprilFoolVersions: [String] = ["15w14a", "1.rv-pre1", "3d shareware v1.34", "20w14infinite", "22w13oneblockatatime", "23w13a_or_b", "24w14potato", "25w14craftmine"]
    private static let cacheURL: URL = AppURLs.cacheURL.appending(path: "version_manifest.json")
    
    public let latestVersions: LatestVersions
    public let versionMap: [String: Version]
    
    private init() {
        self.latestVersions = .init()
        self.versionMap = [:]
    }
    
    public init(_ json: JSON, base: VersionManifest? = nil) {
        if let base {
            self.latestVersions = base.latestVersions
        } else {
            self.latestVersions = LatestVersions(json["latest"])
        }
        self.versionMap = Dictionary(uniqueKeysWithValues: json["versions"].arrayValue.map { versionJSON in
            let version: Version = Version(versionJSON)
            return (version.id, version)
        }).merging(base?.versionMap ?? [:], uniquingKeysWith: { v1, v2 in v1 })
    }
    
    public struct LatestVersions {
        public let release: String
        public let snapshot: String?
        
        fileprivate init() {
            self.release = ""
            self.snapshot = nil
        }
        
        public init(_ json: JSON) {
            self.release = json["release"].stringValue
            self.snapshot = json["snapshot"].stringValue == release ? nil : json["snapshot"].stringValue
        }
    }
    
    public class Version {
        public let id: String
        public let type: VersionType
        public let url: URL
        public let releaseTime: Date
        
        public init(_ json: JSON) {
            self.id = json["id"].stringValue
                .replacingOccurrences(of: " Pre-Release ", with: "-pre")
                .replacingOccurrences(of: "point", with: ".")
            let type = VersionType(rawValue: json["type"].stringValue)!
            self.type = VersionManifest.isAprilFoolVersion(id: id, type: type) ? .aprilFool : type
            self.url = Util.replaceRoot(
                url: json["url"].stringValue,
                root: "https://zkitefly.github.io/unlisted-versions-of-minecraft",
                target: "https://alist.8mi.tech/d/mirror/unlisted-versions-of-minecraft/Auto"
            ).url
            self.releaseTime = DateFormatters.shared.iso8601Formatter.date(from: json["releaseTime"].stringValue)!
        }
    }
    
    /// 拉取版本清单并保存至本地缓存文件。
    public static func fetchVersionManifest() async throws {
        let response = await Requests.get(DownloadSourceManager.shared.getVersionManifestURL())
        FileManager.default.createFile(atPath: cacheURL.path, contents: try response.getDataOrThrow())
        let base = VersionManifest(try response.getJSONOrThrow())
        // 与 UVMC 清单合并
        let full = VersionManifest(try await Requests.get("https://alist.8mi.tech/d/mirror/unlisted-versions-of-minecraft/Auto/version_manifest.json").getJSONOrThrow(), base: base)
        latest = full
    }
    
    /// 尝试从本地缓存中加载版本清单。
    public static func loadFromCache() throws {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        let data = try FileHandle(forReadingFrom: cacheURL).readToEnd().unwrap()
        let json = try JSON(data: data)
        latest = VersionManifest(json)
    }
    
    public static func isAprilFoolVersion(id: String, type: VersionType) -> Bool {
        if aprilFoolVersions.contains(id.lowercased()) { return true }
        return type == .snapshot // 是快照
        && id.wholeMatch(of: /[0-9]{2}w[0-9]{2}.{1}/) == nil // 且不是标准快照格式 (如 23w33a)
        && id.rangeOfCharacter(from: .letters) != nil // 至少有一个字母 (筛掉 1.x 与 1.x.x)
        && !id.contains("-pre") && !id.contains("-rc") // 不是 Pre Release 或 Release Candidate
        && !id.contains("snapshot") // 不是新版本号格式的快照（如 26.1-snapshot-1）
    }
    
    public static func getAprilFoolDescription(_ name: String) -> String {
        let name = name.lowercased()
        var tag = ""
        if name.hasPrefix("2.0") || name.hasPrefix("2point0") {
            if name.hasSuffix("red") {
                tag = "（红色版本）"
            } else if name.hasSuffix("blue") {
                tag = "（蓝色版本）"
            } else if name.hasSuffix("purple") {
                tag = "（紫色版本）"
            }
            return "2013 | 这个秘密计划了两年的更新将游戏推向了一个新高度！" + tag
        } else if name == "15w14a" {
            return "2015 | 作为一款全年龄向的游戏，我们需要和平，需要爱与拥抱。"
        } else if name == "1.rv-pre1" {
            return "2016 | 是时候将现代科技带入 Minecraft 了！"
        } else if name == "3d shareware v1.34" {
            return "2019 | 我们从地下室的废墟里找到了这个开发于 1994 年的杰作！"
        } else if name.hasPrefix("20w14inf") || name == "20w14∞" {
            return "2020 | 我们加入了 20 亿个新的维度，让无限的想象变成了现实！"
        } else if name == "22w13oneblockatatime" {
            return "2022 | 一次一个方块更新！迎接全新的挖掘、合成与骑乘玩法吧！"
        } else if name == "23w13a_or_b" {
            return "2023 | 研究表明：玩家喜欢作出选择——越多越好！"
        } else if name == "24w14potato" {
            return "2024 | 毒马铃薯一直都被大家忽视和低估，于是我们超级加强了它！"
        } else if name == "25w14craftmine" {
            return "2025 | 你可以合成任何东西——包括合成你的世界！"
        } else {
            return ""
        }
    }
    
    public static func getLatestRelease() -> Version {
        return latest.versionMap[latest.latestVersions.release]!
    }
    
    public static func getLatestSnapshot() -> Version? {
        return latest.latestVersions.snapshot.map { latest.versionMap[$0]! }
    }
}
