//
//  JSON.swift
//  SwiftNetworking
//
//  Created by Ilya Puchka on 16.08.15.
//  Copyright © 2015 Ilya Puchka. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public typealias JSONDictionary = [String: Any]

public protocol JSONDecodable {
    init?(jsonDictionary: JSONDictionary?)
}

public protocol JSONConvertible: JSONDecodable, JSONEncodable {}

public protocol JSONArrayConvertible: JSONConvertible {
    //having nil is a workround for bug with extensions rdar://23314307
    //when it's fixed there should be extension of JSONArrayOf where T: JSONArrayConvertible
    //but it actually can make sence if array of objects is root objecti in json
    static var itemsKey: String? { get }
}

public protocol JSONEncodable {
    var jsonDictionary: JSONDictionary { get }
}

public protocol JSONContainer {
    associatedtype Element
    
    var value: Element {get set}
    
    init(_ value: Element)
    init?(_ value: Element?)
}

extension JSONContainer {
    public init?(_ value: Element?) {
        guard let value = value else { return nil }
        self.init(value)
    }
}

public struct JSONObject: JSONContainer {
    public var value: JSONDictionary
    
    public init(_ value: JSONDictionary) {
        self.value = value
    }
}

public struct JSONArray: JSONContainer {
    public var value: [JSONDictionary]
    
    public init(_ value: [JSONDictionary]) {
        self.value = value
    }
}

public struct JSONArrayOf<T: JSONArrayConvertible>: JSONContainer {
    public var value: [T]
    
    public init(_ value: [T]) {
        self.value = value
    }
}

extension Dictionary {
    mutating func append(element: (Key, Value)) -> [Key:Value] {
        self[element.0] = element.1
        return self
    }
}

func +<K: Hashable,V>(lhs: inout [K: V], rhs: (K, V)) -> [K: V] {
    return lhs.append(element: rhs)
}

//MARK: - Subscript
extension JSONObject: ExpressibleByDictionaryLiteral {
    
    public init(dictionaryLiteral elements: (String, Any)...) {
        var dict: [String: Any] = [:]
        for (key, value) in elements {
            dict[key] = value
        }
        self.init(dict)
    }
    
    public subscript(keyPaths: String...) -> Any? {
        return keyPath(keyPaths.joined(separator: "."))
    }
    
    public func keyPath<T: JSONDecodable>(_ keyPath: String) -> [T]? {
        if let jsonDict: [JSONDictionary] = self.keyPath(keyPath) {
            return jsonDict.compactMap { T(jsonDictionary: $0) }
        }
        return nil
    }

    public func keyPath<T: JSONDecodable>(_ keyPath: String) -> T? {
        if let jsonDict: JSONDictionary = self.keyPath(keyPath) {
            return T(jsonDictionary: jsonDict)
        }
        return nil
    }

    public func keyPath<T>(_ keyPath: String) -> T? {
        guard var paths = partitionKeyPath(keyPath) else { return nil }
        return (paths.count == 1 ? value[keyPath] : resolve(&paths)) as? T
    }
    
    private func partitionKeyPath(_ keyPath: String) -> [String]? {
        var paths = keyPath.components(separatedBy: ".")
        var key: String!
        var partitionedPaths = [String]()
        repeat {
            key = paths.removeFirst()
            if key.hasPrefix("@") && paths.count > 0 {
                key = "\(key).\(paths.removeFirst())"
            }
            partitionedPaths += [key]
        } while paths.count > 0
        return partitionedPaths
    }
    
    private func resolve(_ keyPaths: inout [String]) -> Any? {
        var result = value[keyPaths.removeFirst()]
        while keyPaths.count > 1 && result != nil {
            let key = keyPaths.removeFirst()
            result = resolve(key, value: result!)
        }
        if let result = result {
            return resolve(keyPaths.last!, value: result)
        }
        return nil
    }
    
    private func resolve(_ key: String, value: Any) -> Any? {
        if key.hasPrefix("@"), let array = value as? Array<Any>  {
            return resolve(key, array: array)
        }
        else if let dict = value as? JSONDictionary {
            return dict[key]
        }
        return nil
    }
    
    private func resolve(_ key: String, array: Array<Any>) -> Any? {
        let startIndex = key.index(key.startIndex, offsetBy: 1)
        let substring = String(key[startIndex...])
        return CollectionOperation(substring).collect(array)
    }
    
    enum CollectionOperation {
        case Index(Int)
        case First
        case Last
        case KeyPath(String)
        
        init(_ rawValue: String) {
            switch rawValue {
            case _ where Int(rawValue) != nil:
                self = .Index(Int(rawValue)!)
            case "first":
                self = .First
            case "last":
                self = .Last
            default:
                self = .KeyPath(rawValue)
            }
        }
        
        func collect(_ array: Array<Any>) -> Any? {
            switch self {
            case .Index(let index):
                return array[index]
            case .First:
                return array.first
            case .Last:
                return array.last
            case .KeyPath(let keyPath):
                #if canImport(ObjectiveC)
                return (array as NSArray).value(forKeyPath: "@\(keyPath)")
                #else
                // Fallback for platforms without NSArray.value(forKeyPath:)
                return array.compactMap { ($0 as? [String: Any])?[keyPath] }
                #endif
            }
        }
    }
    
}

//MARK: - NSData

extension Data {

    public func decodeToJSON() throws -> JSONDictionary? {
        return try JSONSerialization.jsonObject(with: self, options: JSONSerialization.ReadingOptions()) as? JSONDictionary
    }

    public func decodeToJSON() throws -> Any? {
        return try JSONSerialization.jsonObject(with: self, options: [.allowFragments])
    }

    public func decodeToJSON() throws -> [JSONDictionary]? {
        return try JSONSerialization.jsonObject(with: self, options: JSONSerialization.ReadingOptions()) as? [JSONDictionary]
    }

    public func decodeToJSON<J: JSONDecodable>() throws -> J? {
        return try J(jsonDictionary: self.decodeToJSON())
    }

    public func decodeToJSON<J: JSONDecodable>() throws -> [J]? {
        let array: [JSONDictionary]? = try self.decodeToJSON()
        return array?.compactMap { J(jsonDictionary: $0) }
    }
    
}

extension JSONEncodable {
    public func encodeJSON() throws -> Data {
        return try serializeJSON(self.jsonDictionary)
    }
}

public func encodeJSONDictionary(_ jsonDictionary: JSONDictionary) throws -> Data {
    return try serializeJSON(jsonDictionary)
}

public func encodeJSONArray(_ jsonArray: [JSONDictionary]) throws -> Data {
    return try serializeJSON(jsonArray)
}

public func encodeJSONObjectsArray(_ objects: [JSONEncodable]) throws -> Data {
    return try serializeJSON(objects.map { $0.jsonDictionary })
}

private func serializeJSON(_ obj: Any) throws -> Data {
    return try JSONSerialization.data(withJSONObject: obj, options: JSONSerialization.WritingOptions())
}

extension Optional {
    public var String: Swift.String? {
        return self as? Swift.String
    }
    
    public var Double: Swift.Double? {
        return self as? Swift.Double
    }
    
    public var Int: Swift.Int? {
        return self as? Swift.Int
    }
    
    public var Bool: Swift.Bool? {
        return self as? Swift.Bool
    }
    
    public var Array: [JSONDictionary]? {
        return self as? [JSONDictionary]
    }
    
    public var Object: JSONDictionary? {
        return self as? JSONDictionary
    }
}

