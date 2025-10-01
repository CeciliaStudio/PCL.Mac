//
//  UpdateTest.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/9/29.
//

import Foundation
import Testing
import PCL_Mac

struct UpdateTest {
    @Test func updateLauncher() async throws {
        print(Bundle.main.bundlePath)
        let list = try await UpdateChecker.fetchVersions()
        try await UpdateChecker.update(to: list.getLatestVersion())
    }
}
