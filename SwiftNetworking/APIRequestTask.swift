//
//  APIRequestTask.swift
//  SwiftNetworking
//
//  Created by Ilya Puchka on 16.08.15.
//  Copyright © 2015 Ilya Puchka. All rights reserved.
//

import Foundation

final public class APIRequestTask: Task, Resumable, Cancellable, Equatable {
    
    public typealias TaskIdentifier = Int
    
    var onCancel: ((APIRequestTask, Error?) -> ())?
    private var completionHandlers: [(APIResponseDecodable) -> Void] = []
    
    public func addCompletionHandler(_ handler: @escaping (APIResponseDecodable) -> Void) {
        completionHandlers.append(handler)
    }
    
    let session: URLSession
    let requestBuilder: () throws -> URLRequest
    
    private static var requestTasksCounter = 0
    
    init(request: APIRequestType, session: URLSession, requestBuilder: @escaping (APIRequestType) throws -> URLRequest) {
        APIRequestTask.requestTasksCounter += 1
        self.taskIdentifier = APIRequestTask.requestTasksCounter
        self.session = session
        self.requestBuilder = { () throws -> URLRequest in
            return try requestBuilder(request)
        }
    }
    
    private(set) public var taskIdentifier: TaskIdentifier
    
    private var sessionTask: URLSessionTask!
    
    var originalRequest: URLRequest? {
        get {
            return sessionTask?.originalRequest
        }
    }
    
    func isTaskForSessionTask(_ task: URLSessionTask) -> Bool {
        if let sessionTask = sessionTask {
            return sessionTask === task
        }
        return false
    }
}

//MARK: - Resumable
extension APIRequestTask {
    func resume() {
        do {
            let httpRequest = try requestBuilder()
            sessionTask = self.session.dataTask(with: httpRequest)
            sessionTask.resume()
        }
        catch {
            cancel(error)
        }
    }
}

//MARK: - Cancellable
extension APIRequestTask {
    func cancel(_ error: Error?) {
        if let sessionTask = sessionTask {
            sessionTask.cancel()
        }
        else {
            onCancel?(self, error)
            onCancel = nil
        }
    }
}

public func ==(left: APIRequestTask, right: APIRequestTask) -> Bool {
    return left.taskIdentifier == right.taskIdentifier
}