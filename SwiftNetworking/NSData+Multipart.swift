//
//  NSData+Multipart.swift
//  SwiftNetworking
//
//  Created by Ilya Puchka on 11.09.15.
//  Copyright © 2015 Ilya Puchka. All rights reserved.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct MultipartBodyItem: APIRequestDataEncodable, Equatable {
    let data: Data
    let contentType: MIMEType
    let headers: [HTTPHeader]
    
    public init(data: Data, contentType: MIMEType, headers: [HTTPHeader]) {
        self.data = data
        self.contentType = contentType
        self.headers = headers
    }
    
    public init?(multipartData: Data) {
        let (data, contentType, headers) = MultipartBodyItem.parseMultipartData(multipartData)
        guard let _ = contentType, let _ = data else {
            return nil
        }
        self.headers = headers
        self.contentType = contentType!
        self.data = data!
    }
    
    static private func parseMultipartData(_ multipartData: Data) -> (Data?, MIMEType?, [HTTPHeader]) {
        var headers = [HTTPHeader]()
        var contentType: MIMEType?
        var data: Data?
        let dataLines = MultipartBodyItem.multipartDataLines(multipartData)
        for dataLine in dataLines {
            let line = String(data: dataLine, encoding: .utf8)!
            if let _contentType = MultipartBodyItem.contentTypeFromLine(line) {
                contentType = _contentType
            }
            else if let contentLength = MultipartBodyItem.contentLengthFromLine(line) {
                data = MultipartBodyItem.contentDataFromData(multipartData, contentLength: contentLength)
            }
            else if let header = MultipartBodyItem.headersFromLine(line) {
                headers.append(header)
            }
        }
        return (data, contentType, headers)
    }
    
    static private func multipartDataLines(_ data: Data) -> [Data] {
        var dataLines = data.lines()
        dataLines.removeLast()
        return dataLines
    }
    
    private static let ContentTypePrefix = "Content-Type: "
    private static let ContentLengthPrefix = "Content-Length: "
    
    private static func contentTypeFromLine(_ line: String) -> String? {
        guard line.hasPrefix(MultipartBodyItem.ContentTypePrefix) else {
            return nil
        }
        return String(line[MultipartBodyItem.ContentTypePrefix.endIndex...])
    }
    
    private static func contentLengthFromLine(_ line: String) -> Int? {
        guard line.hasPrefix(MultipartBodyItem.ContentLengthPrefix) else {
            return nil
        }
        let scanner = Scanner(string: String(line[MultipartBodyItem.ContentLengthPrefix.endIndex...]))
        var contentLength: Int = 0
        _ = scanner.scanInt(&contentLength)
        return contentLength
    }
    
    private static func headersFromLine(_ line: String) -> HTTPHeader? {
        guard let colonRange = line.range(of: ": ") else {
            return nil
        }
        let key = String(line[..<colonRange.lowerBound])
        let value = String(line[colonRange.upperBound...])
        return HTTPHeader.Custom(key, value)
    }

    private static func contentDataFromData(_ data: Data, contentLength: Int) -> Data {
        let carriageReturn = "\r\n".data(using: .utf8)!
        let range = (data.count - carriageReturn.count - contentLength)..<data.count - carriageReturn.count
        return data.subdata(in: range)
    }
}

//MARK: - APIRequestDataEncodable

extension MultipartBodyItem {
    public func encodeForAPIRequestData() throws -> Data {
        return Data()
    }
}

//MARK: - Equatable

public func ==(lhs: MultipartBodyItem, rhs: MultipartBodyItem) -> Bool {
    return lhs.data == rhs.data && lhs.contentType == rhs.contentType && lhs.headers == rhs.headers
}


public func NSSubstractRange(fromRange: NSRange, _ substractRange: NSRange) -> NSRange {
    return NSMakeRange(NSMaxRange(substractRange), NSMaxRange(fromRange) - NSMaxRange(substractRange));
}

public func NSRangeInterval(fromRange: NSRange, toRange: NSRange) -> NSRange {
    if (NSIntersectionRange(fromRange, toRange).length > 0) {
        return NSMakeRange(0, 0);
    }
    if (NSMaxRange(fromRange) < NSMaxRange(toRange)) {
        return NSMakeRange(NSMaxRange(fromRange), toRange.location - NSMaxRange(fromRange));
    }
    else {
        return NSMakeRange(NSMaxRange(toRange), fromRange.location - NSMaxRange(toRange));
    }
}

extension Data {
    
    public mutating func appendString(_ string: String) {
        append(string.data(using: .utf8) ?? Data())
    }
    
    public mutating func appendNewLine() {
        appendString("\r\n")
    }

    public mutating func appendStringLine(_ string: String) {
        appendString(string)
        appendNewLine()
    }
    
    public mutating func appendMultipartBodyItem(_ item: MultipartBodyItem, boundary: String) {
        appendStringLine("--\(boundary)")
        appendStringLine("Content-Type: \(item.contentType)")
        appendStringLine("Content-Length: \(item.data.count)")
        for header in item.headers {
            appendStringLine("\(header.key): \(header.requestHeaderValue)")
        }
        appendNewLine()
        append(item.data)
        appendNewLine()
    }
}

extension Data {
    
    public init(multipartDataWithItems items: [MultipartBodyItem], boundary: String) {
        var multipartData = Data()
        for item in items {
            multipartData.appendMultipartBodyItem(item, boundary: boundary)
        }
        multipartData.appendStringLine("--\(boundary)--")
        self = multipartData
    }
    
    public func multipartDataItemsSeparatedWithBoundary(_ boundary: String) -> [MultipartBodyItem] {
        let boundaryData = "--\(boundary)".data(using: .utf8)!
        let trailingData = "--\r\n".data(using: .utf8)!
        let items = componentsSeparatedByData(boundaryData).compactMap { (data: Data) -> MultipartBodyItem? in
            if data != trailingData {
                return MultipartBodyItem(multipartData: data)
            }
            return nil
        }
        return items
    }
    
    public func componentsSeparatedByData(_ boundary: Data) -> [Data] {
        var components = [Data]()
        enumerateBytesByBoundary(boundary) { (dataPart, _, _) -> Void in
            components.append(dataPart)
        }
        return components
    }
    
    public func lines() -> [Data] {
        return componentsSeparatedByData("\r\n".data(using: .utf8)!)
    }
    
    private func enumerateBytesByBoundary(_ boundary: Data, iteration: (Data, NSRange, inout Bool) -> Void) {
        var boundaryRange = NSMakeRange(0, 0)
        var stop = false
        repeat {
            if let subRange = subRange(boundary, boundaryRange: boundaryRange) {
                if subRange.length > 0 {
                    iteration(self.subdata(in: subRange.location..<NSMaxRange(subRange)), subRange, &stop)
                }
                boundaryRange = NSMakeRange(NSMaxRange(subRange), boundary.count)
            }
            else {
                break;
            }
        } while (!stop && NSMaxRange(boundaryRange) < count)
    }
    
    private func subRange(_ boundary: Data, boundaryRange: NSRange) -> NSRange? {
        let searchRange = NSSubstractRange(fromRange: NSMakeRange(0, count), boundaryRange)
        let nextBoundaryRange = (self as NSData).range(of: boundary, options: NSData.SearchOptions(), in: searchRange)
        var subRange: NSRange?
        if nextBoundaryRange.location != NSNotFound {
            subRange = NSRangeInterval(fromRange: boundaryRange, toRange: nextBoundaryRange)
        }
        else if (NSMaxRange(boundaryRange) < count) {
            subRange = searchRange
        }
        return subRange
    }
}
