//
//  API.swift
//  SwiftNetworking
//
//  Created by Ilya Puchka on 16.08.15.
//  Copyright © 2015 Ilya Puchka. All rights reserved.
//

import Foundation

public protocol APIClientAccessTokenRefresh: AnyObject {
    func apiClient(client: APIClient, requestToRefreshToken token: AccessToken) -> APIRequestFor<AccessToken>
}

public class APIClient {
    
    public let baseURL: URL
    private let session: NetworkSession
    private(set) var credentialsStorage: APICredentialsStorage
    
    public weak var accessTokenRefresh: APIClientAccessTokenRefresh?
    
    public init(baseURL: URL, session: NetworkSession = NetworkSessionImp()) {
        self.baseURL = baseURL
        self.session = session
        self.credentialsStorage = session.credentialsStorage
    }

    public func request<ResultType>(request: APIRequestFor<ResultType>, completion: @escaping (APIResponseOf<ResultType>) -> Void) -> APIRequestTask {
        let accessTokenRequest = refreshTokenIfNeeded(accessToken)
        return session.scheduleRequest(request, after: accessTokenRequest != nil ? [accessTokenRequest!] : [], completionHandler: completion)
    }
    
    func refreshTokenIfNeeded(_ token: AccessToken?, completion: ((AccessToken?, Error?) -> Void)? = nil) -> APIRequestTask?  {
        if shouldRenewToken(token) && accessTokenRefresh != nil {
            let refreshTokenRequest = accessTokenRefresh!.apiClient(client: self, requestToRefreshToken: token!)
            return session.scheduleRequest(refreshTokenRequest, after: [], completionHandler: { (response: APIResponseOf<AccessToken>) in
                if let error = response.error {
                    self.session.cancelTasksDependentOnTask(self.accessTokenRequest!, error: error)
                }
                self.accessTokenRequest = nil
                completion?(self.accessToken, response.error)
            })
        }
        return nil
    }
    
    private var accessTokenRequest: APIRequestTask? = nil

    func shouldRenewToken(_ token: AccessToken?) -> Bool {
        return token != nil && token!.isNearToExpire() && accessTokenRequest == nil
    }

    var accessToken: AccessToken? {
        get {
            return credentialsStorage.accessToken
        }
        set {
            credentialsStorage.accessToken = newValue
        }
    }

}
