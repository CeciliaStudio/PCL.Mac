//
//  LaunchPrecheck.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/20.
//

import Foundation
import AppKit

public enum JavaCheckError: Error {
    case javaNotFound
    case noUsableJava(minVersion: Int)
    case javaUnusable(minVersion: Int)
    case javaVersionTooHigh(recommended: Int)
    case javaNotSupport
    case invalidMemoryConfiguration
    case rosetta
}

public enum AccountCheckError: Error {
    case missingAccount
    case noMicrosoftAccount
}

public class LaunchPrecheck {
    public static func checkJava(_ instance: MinecraftInstance, _ options: LaunchOptions) -> Result<Void, JavaCheckError> {
        log("[launchPrecheck] 正在进行 Java 检查")
        if DataManager.shared.javaVirtualMachines
            .filter({ $0.executableURL.path != "/usr/bin/java" })
            .count == 0 {
            err("[launchPrecheck] 用户未安装 Java")
            return .failure(.javaNotFound)
        }
        let minVersion: Int = MinecraftInstance.getMinJavaVersion(instance.version)
        
        if instance.config.maxMemory == 0 {
            return .failure(.invalidMemoryConfiguration)
        }
        
        // 在用户未设置 Java 或 Java 路径不合法时自动查找并设置
        if instance.config.javaURL == nil
            || !FileManager.default.fileExists(atPath: instance.config.javaURL.path) {
            guard let url = MinecraftInstance.findSuitableJava(instance.version)?.executableURL else {
                warn("[launchPrecheck] 无可用 Java。")
                return .failure(.noUsableJava(minVersion: minVersion))
            }
            instance.config.javaURL = url
        }
        let java: JavaVirtualMachine = .of(instance.config.javaURL)
        if java.version < minVersion {
            err("[launchPrecheck] Java 不可用。当前 Java 版本：\(java.version)，最低 Java 版本：\(minVersion)")
            return .failure(.javaUnusable(minVersion: minVersion))
        }
        
        if Architecture.system == .x64 && java.architecture == .arm64 {
            err("[launchPrecheck] Java 架构不兼容")
            return .failure(.javaNotSupport)
        } else if Architecture.system == .arm64 && java.architecture == .x64 {
            warn("[launchPrecheck] 正在使用 x64 Java")
            return .failure(.rosetta)
        }
        
        if (instance.clientBrand == .forge || instance.clientBrand == .neoforge) && java.version > minVersion {
            warn("[launchPrecheck] Java 版本过高")
            return .failure(.javaVersionTooHigh(recommended: minVersion))
        }
        
        return .success(())
    }
    
    public static func checkAccount(_ instance: MinecraftInstance, _ options: LaunchOptions) -> Result<Void, AccountCheckError> {
        guard let account = AccountManager.shared.getAccount() else {
            err("无法启动 Minecraft: 未设置账号")
            return .failure(.missingAccount)
        }
        
        options.account = account
        
        if !AppSettings.shared.hasMicrosoftAccount {
            debug("[launchPrecheck] 未登录过正版账号")
            return .failure(.noMicrosoftAccount)
        }
        
        return .success(())
    }
}
