//
//  StoredProperty.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/10/1.
//

import Foundation

@propertyWrapper
public struct StoredProperty<T: Codable> {
    private let storage: PropertyStorage
    private let key: String
    
    public var wrappedValue: T {
        get {
            storage.get(key: key, type: T.self).forceUnwrap("无法反序列化 \(key)")
        }
        set {
            storage.set(key: key, value: newValue)
        }
    }
    
    public init(wrappedValue: T, _ storage: PropertyStorage, _ key: String) {
        self.storage = storage
        self.key = key
        if !storage.contains(key: key) {
            storage.set(key: key, value: wrappedValue)
        }
    }
}
