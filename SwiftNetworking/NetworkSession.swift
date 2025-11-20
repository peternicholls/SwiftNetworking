//
//  NetworkSession.swift
//  SwiftNetworking
//
//  Created by Ilya Puchka on 16.08.15.
//  Copyright © 2015 Ilya Puchka. All rights reserved.
//

import Foundation

public protocol NetworkSession: AnyObject {
    
    func scheduleRequest<ResultType>(_ request: APIRequestFor<ResultType>, after: [APIRequestTask], completionHandler: ((APIResponseOf<ResultType>) -> Void)?) -> APIRequestTask
    func cancelTasksDependentOnTask(_ task: APIRequestTask, error: Error?)
    
    var credentialsStorage: APICredentialsStorage {get}
}

public class NetworkSessionImp: NSObject, NetworkSession, URLSessionDataDelegate {
    
    private typealias TaskCompletionHandler = (URLRequest!, Data!, URLResponse!, Error!) -> Void
    private typealias TaskIdentifier = APIRequestTask.TaskIdentifier
    
    private(set) public var session: URLSession!
    
    private var completionHandlers = [TaskIdentifier: TaskCompletionHandler]()
    private var recievedData = [TaskIdentifier: Data]()
    private let resultsQueue: DispatchQueue
    
    private var tasks = [APIRequestTask]()
    
    var accessToken: AccessToken? {
        get {
            return credentialsStorage.accessToken
        }
        set {
            credentialsStorage.accessToken = newValue
        }
    }
    
    private static let scheduler = TasksScheduler<APIRequestTask>(maxTasks: 0)
    let requestSigning: APIRequestSigning
    let requestProcessing: APIRequestProcessing
    let responseProcessing: APIResponseProcessing
    private(set) public var credentialsStorage: APICredentialsStorage
    
    private let privateQueue: DispatchQueue = DispatchQueue(label: "NetworkSessionQueue")

    public init(
        configuration: URLSessionConfiguration = NetworkSessionImp.foregroundSessionConfiguration(),
        resultsQueue: DispatchQueue = DispatchQueue.main,
        requestProcessing: APIRequestProcessing = DefaultAPIRequestProcessing(),
        requestSigning: APIRequestSigning = DefaultAPIRequestSigning(),
        responseProcessing: APIResponseProcessing = DefaultAPIResponseProcessing(),
        credentialsStorage: APICredentialsStorage = APICredentialsStorageInMemory())
    {
        self.resultsQueue = resultsQueue
        self.requestSigning = requestSigning
        self.requestProcessing = requestProcessing
        self.responseProcessing = responseProcessing
        self.credentialsStorage = credentialsStorage
        super.init()
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    public static func foregroundSessionConfiguration(additinalHeaders: [HTTPHeader] = []) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = [:]
        for header in additinalHeaders {
            configuration.httpAdditionalHeaders![header.key] = header.requestHeaderValue
        }
        return configuration
    }
    
    public func scheduleRequest<ResultType>(_ request: APIRequestFor<ResultType>, after: [APIRequestTask] = [], completionHandler: ((APIResponseOf<ResultType>) -> Void)?) -> APIRequestTask {
        var task: APIRequestTask!
        privateQueue.sync {
            task = APIRequestTask(request: request, session: self.session, requestBuilder: self.buildRequest)
            task.onCancel = self.taskCancelled
            self.tasks.append(task)
            self.completionHandlers[task.taskIdentifier] = self.completeRequest(request, withHandler: completionHandler)
            NetworkSessionImp.scheduler.enqueue(task, after: after)
        }
        return task
    }
    
    private func buildRequest(_ request: APIRequestType) throws -> URLRequest {
        var httpRequest: URLRequest
        httpRequest = try self.requestProcessing.processRequest(request)
        if request.endpoint.signed {
            return try self.requestSigning.signRequest(&httpRequest, storage: self.credentialsStorage)
        }
        return httpRequest
    }
    
    private func completeRequest<ResultType>(_ request: APIRequestFor<ResultType>, withHandler completionHandler: ((APIResponseOf<ResultType>) -> Void)?) -> TaskCompletionHandler {
        return { response in
            let apiResponse = self.responseProcessing.processResponse(APIResponseOf<ResultType>(response), request: request)
            
            if let token = apiResponse.result as? AccessToken {
                self.accessToken = self.accessToken?.refreshTokenWithToken(token) ?? token
            }
            
            self.resultsQueue.async {
                completionHandler?(apiResponse)
            }
        }
    }
    
    private func finishTask(_ sessionTask: URLSessionTask?, _ transportTask: APIRequestTask) {
        self.completionHandlers[transportTask.taskIdentifier] = nil
        if let sessionTask = sessionTask {
            self.recievedData[sessionTask.taskIdentifier] = nil
        }

        if let index = self.tasks.firstIndex(of: transportTask) {
            self.tasks.remove(at: index)
        }
        NetworkSessionImp.scheduler.nextTask(transportTask)
    }
    
    private func taskCancelled(_ task: APIRequestTask, error: Error?) {
        privateQueue.async {
            let comletionHandler = self.completionHandlers[task.taskIdentifier]
            self.completionHandlers[task.taskIdentifier] = nil
            DispatchQueue.main.async { () -> Void in
                comletionHandler?(task.originalRequest, nil, nil, error)
            }
            self.finishTask(nil, task)
        }
    }
    
    public func cancelTasksDependentOnTask(_ task: APIRequestTask, error: Error?) {
        NetworkSessionImp.scheduler.cancelTasksDependentOnTask(task.taskIdentifier, error: error)
    }
}

//MARK: URLSession delegate
extension NetworkSessionImp {
    
    private func transportTaskCancelled(_ transportTask: APIRequestTask, error: NSError?) -> Bool {
        if let error = error, let onCancel = transportTask.onCancel, error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            onCancel(transportTask, error)
            return true;
        }
        return false;
    }
    
    private func completeTask(_ task: URLSessionTask, transportTask: APIRequestTask, error: NSError?) {
        if let completionHandler = self.completionHandlers[transportTask.taskIdentifier] {
            let data = self.recievedData[task.taskIdentifier]
            DispatchQueue.main.async { () -> Void in
                completionHandler(task.originalRequest, data, task.response, error)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        privateQueue.async {
            var taskData = self.recievedData[dataTask.taskIdentifier] ?? Data()
            taskData.append(data)
            self.recievedData[dataTask.taskIdentifier] = taskData
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        privateQueue.async {
            if let transportTask = self.tasks.filter({ $0.isTaskForSessionTask(task) }).first {
                if !self.transportTaskCancelled(transportTask, error: error as NSError?) {
                    self.completeTask(task, transportTask: transportTask, error: error as NSError?)
                }
                self.finishTask(task, transportTask)
            }
        }
    }
}
