//
//  CoreExtensions.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import Sodium
import OneTimePassword
import PromiseKit
import Kronos
import DataCompression

// MARK: - Primitive extensions

infix operator %%: MultiplicationPrecedence

extension Int {
    static func %% (m: Int, n: Int) -> Int {
        return (m % n + n) % n
    }
}

extension String {

    var hash: String? {
        return try? Crypto.shared.hash(self)
    }

    var sha256: String {
        return Crypto.shared.sha256(from: self)
    }

    var sha256Data: Data {
        return Crypto.shared.sha256(from: self.data)
    }

    var fromBase64: Data? {
        return try? Crypto.shared.convertFromBase64(from: self)
    }

    var data: Data {
        return self.data(using: .utf8)!
    }

    var capitalizedFirstLetter: String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizedFirstLetter
    }

    func components(withLength length: Int) -> [String] {
        return stride(from: 0, to: self.count, by: length).map {
            let start = self.index(self.startIndex, offsetBy: $0)
            let end = self.index(start, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            return String(self[start..<end])
        }
    }

    func pad(toSize: Int) -> String {
        var padded = self
        for _ in 0..<(toSize - self.count) {
            padded = "0" + padded
        }
        return padded
    }

    var lines: [String] {
        var result: [String] = []
        enumerateLines { line, _ in result.append(line) }
        return result
    }
}

extension Substring {
    func pad(toSize: Int) -> String {
        var padded = String(self)
        for _ in 0..<(toSize - self.count) {
            padded = "0" + padded
        }
        return padded
    }
}

// Extension for URL that return parameters as dict
extension URL {
    public var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true), let queryItems = components.queryItems else {
            return nil
        }

        var parameters = [String: String]()
        for item in queryItems {
            parameters[item.name] = item.value
        }

        return parameters
    }
}

extension Data {

    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }

    var bitstring: String {
        return self.reduce("", { $0 + String($1, radix: 2).pad(toSize: 8) })
    }

    var hash: Data? {
        return try? Crypto.shared.hash(self)
    }

    var sha256: Data {
        return Crypto.shared.sha256(from: self)
    }

    var base64: String {
        var result = base64EncodedString()
        result = result.replacingOccurrences(of: "+", with: "-")
        result = result.replacingOccurrences(of: "/", with: "_")
        result = result.replacingOccurrences(of: "=", with: "")
        return result
    }

    var bytes: Bytes { return Bytes(self) }

    func compress() -> Data? {
        return self.zip()
    }

    func decompress() -> Data? {
        return self.unzip()
    }

}

extension Collection {

    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Array where Element == UInt8 {
    public var data: Data {
        return Data(self)
    }
}

typealias Timestamp = Int

extension Date {

    init(millisSince1970: Timestamp) {
        self.init(timeIntervalSince1970: TimeInterval(millisSince1970 / 1000))
    }

    /**
     The current timestamp in milliseconds (unsynced).
     */
    var millisSince1970: Timestamp {
        return Timestamp(timeIntervalSince1970 * 1000)
    }

    /**
     The current timestamp in milliseconds, synced with NTP-server.
     */
    static var now: Timestamp {
        return (Clock.now ?? Date()).millisSince1970
    }

    func timeAgoSinceNow(useNumericDates: Bool = false) -> String {
        let calendar = Calendar.current
        let unitFlags: Set<Calendar.Component> = [.minute, .hour, .day, .weekOfYear, .month, .year, .second]
        let now = Date()
        let components = calendar.dateComponents(unitFlags, from: self, to: now)
        let formatter = DateComponentUnitFormatter()
        return formatter.string(forDateComponents: components, useNumericDates: useNumericDates)
    }
}

extension TimeInterval {
    static let oneDay: TimeInterval = 3600 * 24
}
