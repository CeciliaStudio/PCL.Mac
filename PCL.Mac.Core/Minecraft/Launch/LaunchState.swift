//
//  LaunchState.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/9/14.
//

import Foundation

/// 启动状态，用于保存启动中的状态信息
/// 与 `LaunchOptions` 不同，`LaunchState` 仅用于界面展示当前启动阶段等状态
public class LaunchState: ObservableObject {
    @Published public var stage: LaunchStage = .preCheck
    @Published public var progress: Double = 0
    public let options: LaunchOptions
    public var logURL: URL!
    public var process: Process!
    
    public init(options: LaunchOptions) {
        self.options = options
    }
    
    public func setStage(_ stage: LaunchStage) async {
        await MainActor.run {
            self.stage = stage
            self.progress = stage.progress
        }
    }
}

public enum LaunchStage: String {
    case preCheck = "预检查"
    case login = "登录"
    case resourcesCheck = "检查资源完整性"
    case buildArgs = "构建启动命令"
    case waitForWindow = "等待游戏窗口出现"
    case finish = "完成"
    
    public var progress: Double {
        switch self {
        case .preCheck:
            0.1
        case .login:
            0.4
        case .resourcesCheck:
            0.6
        case .buildArgs:
            0.7
        case .waitForWindow, .finish:
            1.0
        }
    }
}
