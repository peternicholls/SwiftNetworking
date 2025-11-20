//
//  APIRequestProcessing.swift
//  SwiftNetworking
//
//  Created by Ilya Puchka on 16.08.15.
//  Copyright © 2015 Ilya Puchka. All rights reserved.
//

import Foundation

public protocol APIRequestProcessing {
    func processRequest(_ request: APIRequestType) throws -> URLRequest
}

public func percentEncodedQueryString(_ query: APIRequestQuery) -> String? {
    let components = URLComponents()
    components.queryItems = URLQueryItem.queryItems(query)
    return components.percentEncodedQuery
}

extension URLQueryItem {
    static func queryItems(_ query: APIRequestQuery) -> [URLQueryItem]? {
        if query.count > 0 {
            return query.map { URLQueryItem(name: $0, value: $1) }
        }
        return nil
    }
}

/**
Process APIRequest and returns URLRequest.
*/
public class DefaultAPIRequestProcessing: APIRequestProcessing {

    public var defaultHeaders: [HTTPHeader]
    
    public init(defaultHeaders: [HTTPHeader] = []) {
        self.defaultHeaders = defaultHeaders
    }
    
    public func processRequest(_ request: APIRequestType) throws -> URLRequest {
        var components = URLComponents(string: request.endpoint.path)!
        components.queryItems = URLQueryItem.queryItems(request.query)
        guard let url = components.url(relativeTo: request.baseURL) else {
            throw NSError(code: .BadRequest)
        }
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = request.endpoint.method.rawValue
        httpRequest.httpBody = request.body
        for header in defaultHeaders + request.headers {
            header.setRequestHeader(&httpRequest)
        }
        return httpRequest
    }

}