//
//  Requests.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/11.
//

import Foundation
import SwiftyJSON

public protocol URLConvertible {
    var url: URL { get }
}

extension URL: URLConvertible {
    public var url: URL { self }
}

extension String: URLConvertible {
    public var url: URL { URL(string: self)! }
}

public enum EncodeMethod {
    case json
    case urlEncoded
}

public struct Response {
    public let statusCode: Int?
    public let headers: [String: String]
    public let data: Data?
    public var json: JSON? { try? _json.get() }
    public let error: Error?
    private let _json: Result<JSON, Error>
    
    private init(statusCode: Int?, headers: [String : String], data: Data?, error: Error?) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
        self.error = error
        self._json = Result { try JSON(data: data.unwrap()) }
    }
    
    public static func success(response: HTTPURLResponse, data: Data) -> Response {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, entry in
            if let key = entry.key as? String, let value = entry.value as? String {
                result[key] = value
            }
        }
        return Response(statusCode: response.statusCode, headers: headers, data: data, error: nil)
    }
    
    public static func failure(error: Error) -> Response {
        Response(statusCode: nil, headers: [:], data: nil, error: error)
    }
    
    public func getDataOrThrow() throws -> Data {
        guard let data = self.data else {
            throw self.error ?? NSError(domain: "data 为空", code: -1)
        }
        
        return data
    }
    
    public func getJSONOrThrow() throws -> JSON {
        return try _json.get()
    }
}

public class Requests {
    public static func request(
        url: URL,
        method: String = "GET",
        headers: [String: String]? = nil,
        body: [String: Any]? = nil,
        encodeMethod: EncodeMethod = .json
    ) async -> Response {
        do {
            // 创建 URLRequest
            var request = URLRequest(url: url)
            request.httpMethod = method
            
            // 设置请求头
            headers?.forEach { key, value in
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            // 设置请求体
            if let body = body {
                switch encodeMethod {
                case .json:
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                case .urlEncoded:
                    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                    if method == "GET" {
                        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                        components.queryItems = body.map { URLQueryItem(name: $0.key, value: String(describing: $0.value)) }
                        request.url = components.url
                    } else {
                        let query = body.map { key, value in
                            "\(key)=\(String(describing: value))"
                        }.joined(separator: "&")
                        request.httpBody = query.data(using: .utf8)
                    }
                }
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw MyLocalizedError(reason: "响应格式不正确。")
            }
            return .success(response: response, data: data)
        } catch let error as URLError where error.code == .cancelled {
            return .failure(error: error)
        } catch {
            err("在发送请求时发生错误: \(error)")
            return .failure(error: error)
        }
    }

    public static func get(
        _ url: URLConvertible,
        headers: [String: String]? = nil,
        body: [String: Any]? = nil,
        encodeMethod: EncodeMethod = .urlEncoded
    ) async -> Response {
        return await request(url: url.url, method: "GET", headers: headers, body: body, encodeMethod: encodeMethod)
    }

    public static func post(
        _ url: URLConvertible,
        headers: [String: String]? = nil,
        body: [String: Any]? = nil,
        encodeMethod: EncodeMethod = .json
    ) async -> Response {
        return await request(url: url.url, method: "POST", headers: headers, body: body, encodeMethod: encodeMethod)
    }
}
