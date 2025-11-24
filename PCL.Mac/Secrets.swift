//
//  Secrets.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/13.
//

import Foundation

public let CLIENT_ID: String = "{{CLIENT_ID}}"
public let THEME_KEY: String = "{{THEME_KEY}}"
public let API_ROOT: String = "{{API_ROOT}}"

public class Secrets {
    public static func getClientID() -> String {
        if !CLIENT_ID.starts(with: "{{") {
            return CLIENT_ID
        }
        
        return ProcessInfo.processInfo.environment["CLIENT_ID"] ?? "" // 本地调试使用
    }
    
    public static func getAPIRoot() -> URL {
        return URL(string: API_ROOT) ?? URL(string: ProcessInfo.processInfo.environment["PCL_MAC_API_ROOT"] ?? "") ?? URL(string: "https://ceciliastudio.netlify.app/pcl_mac")!
    }
}
