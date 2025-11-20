//
//  TasksScheduler.swift
//  SwiftNetworking
//
//  Created by Ilya Puchka on 16.08.15.
//  Copyright © 2015 Ilya Puchka. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol Task {
    associatedtype TaskIdentifier: Hashable
    var taskIdentifier: TaskIdentifier {get}
}

protocol Resumable {
    func resume()
}

protocol Cancellable {
    func cancel(_ error: Error?)
}

typealias ResumableTask = Task & Resumable

final class TasksScheduler<T: ResumableTask & Equatable>: @unchecked Sendable {
    
    typealias TaskIdentifier = T.TaskIdentifier
    
    let maxTasks: Int
    
    init(maxTasks: Int) {
        self.maxTasks = maxTasks
    }
    
    var taskDependencies = [TaskIdentifier: [TaskIdentifier]]()
    var enqueuedTasks = [T]()
    var ongoingTasks = [T]()
    
    private let privateQueue: DispatchQueue = DispatchQueue(label: "TasksSchedulerQueue")
    
    func enqueue(_ task: T, after: [T] = []) {
        privateQueue.async { [task, after] in
            self.taskDependencies[task.taskIdentifier] = self.taskDependencies[task.taskIdentifier] ?? [] + after.map {$0.taskIdentifier}
            self.enqueuedTasks.append(task)
            self.nextTask()
        }
    }
    
    func canResumeTask(_ task: T!) -> Bool {
        if task == nil {
            return false
        }
        
        let dependencies = self.taskDependencies[task.taskIdentifier]!
        let enquedTasksIds = enqueuedTasks.map {$0.taskIdentifier}
        let ongoingTasksIds = ongoingTasks.map {$0.taskIdentifier}
        
        for dependency in dependencies {
            if enquedTasksIds.firstIndex(of: dependency) != nil || ongoingTasksIds.firstIndex(of: dependency) != nil {
                return false
            }
        }
        return true
    }
    
    func canResumeMoreTasks() -> Bool {
        return (self.ongoingTasks.count <= self.maxTasks || self.maxTasks == 0)
    }
    
    func nextTask(_ finished: T? = nil) {
        privateQueue.async { [finished] in
            if let finished = finished, let finishedTaskIndex = self.ongoingTasks.firstIndex(of: finished) {
                self.ongoingTasks.remove(at: finishedTaskIndex)
            }
            var nextTask: T! = nil
            var taskIndex: Int = 0
            while self.canResumeMoreTasks() && taskIndex < self.enqueuedTasks.count {
                nextTask = self.enqueuedTasks[taskIndex]
                if self.canResumeTask(nextTask) {
                    self.enqueuedTasks.remove(at: taskIndex)
                    self.ongoingTasks.append(nextTask)
                    nextTask.resume()
                }
                else {
                    taskIndex += 1
                }
            }
        }
    }
    
    func cancel(tasks: [T], error: Error?) {
        for task in tasks {
            if let task = task as? Cancellable {
                task.cancel(error)
            }
        }
    }
    
    func cancelAll(_ error: Error?) {
        privateQueue.async { () -> Void in
            let ongoing = self.ongoingTasks
            self.ongoingTasks.removeAll()
            self.cancel(tasks: ongoing, error: error)
            
            let enqueued = self.enqueuedTasks
            self.enqueuedTasks.removeAll()
            self.cancel(tasks: enqueued, error: error)
        }
    }
    
    func cancelTasksDependentOnTask(_ taskIdentifier: T.TaskIdentifier, error: Error?) {
        privateQueue.async { [taskIdentifier] in
            var tasksToCancel = [T]()
            let ongoing = self.ongoingTasks
            for (taskIndex, task) in ongoing.enumerated() {
                if let dependencies = self.taskDependencies[task.taskIdentifier],
                    let _ = dependencies.firstIndex(of: taskIdentifier) {
                        self.ongoingTasks.remove(at: taskIndex)
                        tasksToCancel.append(task)
                }
            }
            let enqueued = self.enqueuedTasks
            for (taskIndex, task) in enqueued.enumerated() {
                if let dependencies = self.taskDependencies[task.taskIdentifier],
                    let _ = dependencies.firstIndex(of: taskIdentifier) {
                        self.enqueuedTasks.remove(at: taskIndex)
                        tasksToCancel.append(task)
                }
            }
            self.cancel(tasks: tasksToCancel, error: error)
        }
    }
    
}