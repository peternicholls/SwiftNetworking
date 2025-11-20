//
//  AccessToken.swift
//  SwiftNetworking
//
//  Created by Ilya Puchka on 22.08.15.
//  Copyright © 2015 Ilya Puchka. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AccessToken: JSONDecodable, JSONEncodable, APIResponseDecodable, CustomStringConvertible, Equatable, Sendable {
    public let type: String
    public let token: String
    public let refresh: String!
    public let expires: Date
    
    public init(type: String, token: String, refresh: String?, expires: Date) {
        self.type = type
        self.token = token
        self.refresh = refresh
        self.expires = expires
    }
    
    var requestHeaderValue: String {
        get {
            return "\(type) \(token)"
        }
    }
    
    func isNearToExpire() -> Bool {
        return expires.timeIntervalSinceNow < 60
    }
    
    func refreshTokenWithToken(_ refreshedToken: AccessToken) -> AccessToken {
        return AccessToken(type: refreshedToken.type, token: refreshedToken.token, refresh: self.refresh, expires: refreshedToken.expires)
    }
    
}

public func ==(lhs: AccessToken, rhs: AccessToken) -> Bool {
    return lhs.type == rhs.type && lhs.token == rhs.token && lhs.refresh == rhs.refresh && lhs.expires == rhs.expires
}

//MARK: - CustomStringConvertible
extension AccessToken {
    public var description: String {
        return "\(type) \(token) \(expires)"
    }
}

//MARK: - JSONDecodable
extension AccessToken {
    
    struct Keys {
        static let token    = "access_token"
        static let refresh  = "refresh_token"
        static let type     = "token_type"
        static let expires  = "expires_in"
    }
    public init?(jsonDictionary: JSONDictionary?) {
        guard
            let json = JSONObject(jsonDictionary),
            let token = json[Keys.token] as? String,
            let type = json[Keys.type] as? String,
            let expires = json[Keys.expires] as? Double
            else {
                return nil
        }
        let refresh = json[Keys.refresh] as? String
        self.init(type: type, token: token, refresh: refresh, expires: Date(timeIntervalSinceNow: expires))
    }
}

//MARK: - JSONEncodable
extension AccessToken {
    
    public var jsonDictionary: JSONDictionary {
        var dict: JSONDictionary = [
            Keys.type: type,
            Keys.token: token,
            Keys.expires: expires.timeIntervalSince1970
        ]
        if let refresh = refresh {
            dict[Keys.refresh] = refresh
        }
        return dict
    }
}

//MARK: - APIResponseDecodable
extension AccessToken {
    
    public init?(apiResponseData: Data) throws {
        guard let result: AccessToken = try apiResponseData.decodeToJSON() else {
            return nil
        }
        self = result
    }
}
