//
//  Constants.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/20.
//

import Foundation

public struct SharedConstants {
    public static let shared = SharedConstants()
    
    public let applicationContentsURL: URL
    public let applicationResourcesURL: URL
    public let logURL: URL
    public let applicationSupportURL: URL = .applicationSupportDirectory.appending(path: "PCL.Mac")
    public let configURL: URL
    public let temperatureURL: URL
    public let authlibInjectorURL: URL
    
    public let isDevelopment: Bool
    public let version: String
    public let branch: String
    
    private init() {
        self.applicationContentsURL = Bundle.main.bundleURL.appending(path: "Contents")
        self.applicationResourcesURL = self.applicationContentsURL.appending(path: "Resources")
        self.logURL = applicationSupportURL.appending(path: "Logs").appending(path: "app.log")
        self.configURL = applicationSupportURL.appending(path: "Config")
        self.temperatureURL = applicationSupportURL.appending(path: "Temp")
        self.authlibInjectorURL = applicationSupportURL.appending(path: "authlib-injector.jar")
        
        self.isDevelopment = Self.getInfoValueOrDefault(key: "IS_DEVELOPMENT", default: "true") == "true" ? true : false
        
        self.version = Self.getInfoValueOrDefault(key: "APP_VERSION", default: "本地构建")
        self.branch = Self.getInfoValueOrDefault(key: "BRANCH", default: "本地构建")
    }
    
    private static func getInfoValueOrDefault(key: String, default: String) -> String {
        let value: String = Bundle.main.object(forInfoDictionaryKey: key) as! String
        return value.isEmpty ? `default` : value
    }
}
