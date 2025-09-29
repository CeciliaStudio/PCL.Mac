//
//  DateFormatters.swift
//  PCL.Mac
//
//  Created by 温迪 on 2025/9/29.
//

import Foundation

public class DateFormatters {
    public static let shared: DateFormatters = .init()
    
    public let iso8601Formatter: ISO8601DateFormatter = .init()
    
    /// 用于在界面上显示时间的 DateFormatter，格式为 yyyy/MM/dd HH:mm
    public let displayDateFormatter: DateFormatter = .init()
    
    private init() {
        self.iso8601Formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        
        self.displayDateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
        self.displayDateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    }
}
