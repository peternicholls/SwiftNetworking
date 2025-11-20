//
//  APIResponse.swift
//  SwiftNetworking
//
//  Created by Ilya Puchka on 16.08.15.
//  Copyright © 2015 Ilya Puchka. All rights reserved.
//

import Foundation

public protocol APIResponse {
    
    var httpResponse: HTTPURLResponse? {get}
    var data: Data? {get}
    var error: Error? {get}
    var originalRequest: URLRequest? {get}
    var contentType: HTTPContentType? {get}
    
}

public struct APIResponseOf<ResultType: APIResponseDecodable>: APIResponse {
    
    public let httpResponse: HTTPURLResponse?
    public let data: Data?
    public let originalRequest: URLRequest?
    internal(set) public var error: Error?
    internal(set) public var result: ResultType?
    
    init(request: URLRequest?, data: Data?, httpResponse: URLResponse?, error: Error?) {
        self.originalRequest = request
        self.httpResponse = httpResponse as? HTTPURLResponse
        self.data = data
        self.error = error
        self.result = nil
    }
    
    init(_ r: (request: URLRequest!, data: Data!, httpResponse: URLResponse!, error: Error!)) {
        self.init(request: r.request, data: r.data, httpResponse: r.httpResponse, error: r.error)
    }
    
    public var contentType: HTTPContentType? {
        get {
            return httpResponse?.mimeType.flatMap {HTTPContentType(rawValue: $0)}
        }
    }
    
    public func map<T>(_ f: (ResultType) -> T) -> APIResponseOf<T> {
        return flatMap(f)
    }
    
    public func mapError<E: Error>(_ f: (Error) -> E) -> APIResponseOf {
        return flatMapError(f)
    }
    
    public func flatMap<T>(_ f: (ResultType) -> T?) -> APIResponseOf<T> {
        var response = APIResponseOf<T>(request: originalRequest, data: data, httpResponse: httpResponse, error: error)
        response.result = result.flatMap(f)
        return response
    }
    
    public func flatMapError<E: Error>(_ f: (Error) -> E?) -> APIResponseOf {
        var response = APIResponseOf(request: originalRequest, data: data, httpResponse: httpResponse, error: error.flatMap(f) ?? error)
        response.result = result
        return response
    }

}

public struct None: APIResponseDecodable {
    public init?(apiResponseData: Data) throws {
        return nil
    }
}
