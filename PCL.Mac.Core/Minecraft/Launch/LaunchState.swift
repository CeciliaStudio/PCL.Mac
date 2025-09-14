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
    public var logURL: URL!
    
    public func setStage(_ stage: LaunchStage) async {
        await MainActor.run {
            self.stage = stage
        }
    }
}

public enum LaunchStage {
    case preCheck, login, resourcesCheck, buildArgs, waitForWindow, finish
}
