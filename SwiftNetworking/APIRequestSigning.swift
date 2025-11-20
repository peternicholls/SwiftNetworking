//
//  APIRequestSigning.swift
//  SwiftNetworking
//
//  Created by Ilya Puchka on 16.08.15.
//  Copyright © 2015 Ilya Puchka. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol APICredentialsStorage {
    var accessToken: AccessToken? {get set}
}

final public class APICredentialsStorageInMemory: APICredentialsStorage {
    public var accessToken: AccessToken?
    
    public init(){}
}

public protocol APIRequestSigning {
    func signRequest(_ request: inout URLRequest, storage: APICredentialsStorage) throws -> URLRequest
}

/**
Signs request with access token.
*/
public class DefaultAPIRequestSigning: APIRequestSigning {

    public func signRequest(_ request: inout URLRequest, storage: APICredentialsStorage) throws -> URLRequest {
        guard let accessToken = storage.accessToken else {
            throw NSError(code: .Unauthorized)
        }
        HTTPHeader.Authorization(accessToken).setRequestHeader(&request)
        return request
    }

    public init(){}

}