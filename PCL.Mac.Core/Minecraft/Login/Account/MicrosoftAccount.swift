//
//  MicrosoftAccount.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/6/29.
//

import Foundation
import SwiftyJSON

public class PlayerProfile: Codable {
    public let uuid: UUID
    public let name: String
    public let properties: [String: String]
    
    public init(json: JSON) {
        self.uuid = UUID(uuidString: json["id"].stringValue.replacingOccurrences(
            of: "(\\w{8})(\\w{4})(\\w{4})(\\w{4})(\\w{12})",
            with: "$1-$2-$3-$4-$5",
            options: .regularExpression
        ))!
        self.name = json["name"].stringValue
        self.properties = json["properties"].arrayValue.reduce(into: [String: String]()) { result, property in
            result[property["name"].stringValue] = property["value"].stringValue
        }
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        name = try container.decode(String.self, forKey: .name)
        properties = try container.decodeIfPresent([String: String].self, forKey: .properties) ?? [:]
    }
}

public class MicrosoftAccount: Account {
    public let id: UUID
    public var refreshToken: String
    public var profile: PlayerProfile
    public var isTokenRefreshing: Bool = false
    
    public var name: String { profile.name }
    public var uuid: UUID { profile.uuid }
    
    public func refreshAccessToken() async {
        if isTokenRefreshing { return }
        isTokenRefreshing = true
        if AccessTokenStorage.shared.getTokenInfo(for: id) != nil {
            debug("无需刷新 Access Token")
            return
        }
        
        if let authToken = try? await MsLogin.refreshAccessToken(self.refreshToken) {
            if (try? await MsLogin.getMinecraftAccessToken(id: id, authToken.accessToken)) != nil {
                self.refreshToken = authToken.refreshToken
                debug("成功刷新 Access Token")
                return
            }
        }
        err("无法刷新 Access Token")
    }
    
    enum CodingKeys: CodingKey {
        case id
        case refreshToken
        case profile
    }
    
    public init(refreshToken: String, profile: PlayerProfile) {
        self.id = .init()
        self.refreshToken = refreshToken
        self.profile = profile
    }
    
    public static func create(_ authToken: AuthToken) async -> MicrosoftAccount? {
        guard let accessToken = authToken.minecraftAccessToken else {
            return nil
        }
        
        if let json = await Requests.get(
            URL(string: "https://api.minecraftservices.com/minecraft/profile")!,
            headers: [
                "Authorization": "Bearer \(accessToken)"
            ]
        ).json {
            return .init(refreshToken: authToken.refreshToken, profile: .init(json: json))
        }
        return nil
    }
    
    public func putAccessToken(options: LaunchOptions) async {
        await self.refreshAccessToken()
        options.accessToken = AccessTokenStorage.shared.getTokenInfo(for: id)?.accessToken ?? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}
