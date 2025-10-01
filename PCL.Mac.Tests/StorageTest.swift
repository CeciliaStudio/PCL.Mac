//
//  StorageTest.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/10/1.
//

import Testing
import PCL_Mac
import Foundation

struct StorageTest {
    @Test func testWrite() throws {
        let storage = PropertyStorage(fileURL: URL(fileURLWithUserPath: "~/test.json"))
        storage.set(key: "downloadSourceOption", value: DownloadSourceOption.both)
        storage.set(key: "test", value: [123: "foo"])
        try storage.save()
        let storage2 = PropertyStorage(fileURL: URL(fileURLWithUserPath: "~/test.json"))
        try storage2.load()
        assert(storage2.get(key: "downloadSourceOption", type: DownloadSourceOption.self) == .both)
        assert(storage2.get(key: "test", type: [Int: String].self) == [123: "foo"])
        assert(storage2.get(key: "test", type: Int.self) == nil)
        assert(storage2.get(key: "test1", type: Int.self) == nil)
    }
}
