//
//  APIRequestTask.swift
//  SwiftNetworking
//
//  Created by Ilya Puchka on 16.08.15.
//  Copyright © 2015 Ilya Puchka. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final public class APIRequestTask: Task, Resumable, Cancellable, Equatable, @unchecked Sendable {
    
    public typealias TaskIdentifier = Int
    
    var onCancel: ((APIRequestTask, Error?) -> ())?
    private var completionHandlers: [(APIResponseDecodable) -> Void] = []
    
    public func addCompletionHandler(_ handler: @escaping (APIResponseDecodable) -> Void) {
        completionHandlers.append(handler)
    }
    
    let session: URLSession
    let requestBuilder: () throws -> URLRequest
    
    private static let counterLock = NSLock()
    nonisolated(unsafe) private static var _requestTasksCounter = 0
    private static func nextTaskIdentifier() -> Int {
        counterLock.lock()
        defer { counterLock.unlock() }
        _requestTasksCounter += 1
        return _requestTasksCounter
    }
    
    init(request: APIRequestType, session: URLSession, requestBuilder: @escaping (APIRequestType) throws -> URLRequest) {
        self.taskIdentifier = APIRequestTask.nextTaskIdentifier()
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