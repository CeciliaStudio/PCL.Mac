//
//  StopGameButtonOverlay.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/9/18.
//

import SwiftUI

struct StopGameButtonOverlay: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @ObservedObject private var state: LaunchState
    @State private var isAppeared: Bool = false
    
    init(state: LaunchState) {
        self.state = state
    }
    
    var body: some View {
        RoundedButton {
            Image("StopGameIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 20)
                .foregroundStyle(.white)
        } onClick: {
            state.process.terminate()
            dataManager.launchState = nil
        }
        .scaleEffect(isAppeared ? 1 : 0)
        .onChange(of: state.process) { _ in
            if state.process != nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isAppeared = true
                }
            }
        }
    }
}
