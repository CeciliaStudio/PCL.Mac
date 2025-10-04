//
//  MultiplayerView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/18.
//

import SwiftUI

struct MultiplayerView: View {
    @ObservedObject private var dataManager: DataManager = .shared
    
    var body: some View {
        VStack {
            Text("Multiplayer view")
        }
        .onAppear {
            dataManager.leftTab(0) { EmptyView() }
        }
    }
}

#Preview {
    ZStack {
        RoundedRectangle(cornerRadius: 30)
            .stroke(lineWidth: 3)
        Rectangle()
            .frame(height: 2)
            .offset(y: 140)
        Text("PCL.Mac")
            .offset(y: 170)
            .font(.custom("PCL English", size: 20))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .foregroundStyle(Color(hex: 0x2F2F2F))
        Rectangle()
            .frame(height: 1)
            .offset(y: 200)
        Text("Cecilia Studio")
            .offset(y: 225)
            .font(.system(size: 20))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
    }
    .foregroundStyle(
        LinearGradient(
            colors: [
                .init(hex: 0x71ECCD),
                .init(hex: 0x42907D)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    .padding(45)
    .frame(width: 800, height: 600)
    .background(.white)
}
