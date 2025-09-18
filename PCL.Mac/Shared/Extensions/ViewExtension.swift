//
//  ViewExtension.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/19.
//

import SwiftUI

struct OnChangeModifier<V: Equatable>: ViewModifier {
    let value: V
    let initial: Bool
    let action: (_ oldValue: V, _ newValue: V) -> Void
    
    @State private var oldValue: V?
    @State private var hasAppeared = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if initial && !hasAppeared {
                    hasAppeared = true
                    action(value, value)
                    oldValue = value
                } else if oldValue == nil {
                    oldValue = value
                }
            }
            .onChange(of: value) { newValue in
                let prev = oldValue ?? newValue
                action(prev, newValue)
                oldValue = newValue
            }
    }
}

extension View {
    func onChange<V: Equatable>(
        of value: V,
        initial: Bool = false,
        _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View {
        self.modifier(OnChangeModifier(value: value, initial: initial, action: action))
    }
}
