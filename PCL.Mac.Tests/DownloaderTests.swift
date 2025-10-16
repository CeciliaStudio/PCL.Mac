//
//  DownloaderTests.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/24.
//

import Foundation
import PCL_Mac
import Testing
import SwiftyJSON

struct DownloaderTests {
    @Test func testSingleFileDownload() async throws {
        AccountManager.shared.accounts.append(.offline(.init("MinecraftVenti", UUID(uuidString: "038d4a77-200d-48c7-8217-20de0a4d313a"))))
//        try await SingleFileDownloader.download(url: "https://bmclapi2.bangbang93.com/version/1.21/client".url, destination: URL(fileURLWithUserPath: "~/test.file"), replaceMethod: .replace) { progress in
//            print(progress)
//        }
    }
    
    @Test func testMultiFileDownload() async throws {
        let versions = ["1.21", "1.19", "1.14.2"]
        
        let downloader = MultiFileDownloader(
            items: versions.map {
                DownloadItem("https://bmclapi2.bangbang93.com/version/\($0)/client".url, URL(fileURLWithPath: "/tmp/\($0).jar"))
            },
            concurrentLimit: 4,
            replaceMethod: .replace
        ) { progress, finished in
            print(String(format: "%.2f%% %d", progress, finished))
        }
        
        try await downloader.start()
    }
    
    @Test func testReusableMultiFileDownload() async throws {
        let data = try FileHandle(forReadingFrom: URL(fileURLWithUserPath: "~/minecraft/assets/indexes/27.json")).readToEnd()!
        let assetIndex = AssetIndex(try JSON(data: data))
        let urls = assetIndex.objects.map { $0.appendTo(URL(string: "https://resources.download.minecraft.net")!) }
        let destinations = assetIndex.objects.map { $0.appendTo(URL(filePath: "/tmp")) }
        try await ReusableMultiFileDownloader(task: nil, urls: urls, destinations: destinations, sha1: assetIndex.objects.map { $0.hash }, maxConnections: 64).start()
    }
}
