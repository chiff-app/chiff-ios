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
    /// Mathematic modulo, always resulting in a positive integer.
    static func %% (m: Int, n: Int) -> Int {
        return (m % n + n) % n
    }
}

extension String {

    /// The blake2b hash of this string.
    var hash: String? {
        return try? Crypto.shared.hash(self)
    }

    /// The SHA256 hash of this string.
    var sha256: String {
        return Crypto.shared.sha256(from: self)
    }

    /// The SHA256 hash data of this string.
    var sha256Data: Data {
        return Crypto.shared.sha256(from: self.data)
    }

    /// Decode this string from base64 to data. Returns nil on any error.
    var fromBase64: Data? {
        return try? Crypto.shared.convertFromBase64(from: self)
    }

    /// Convert to data using utf8.
    var data: Data {
        return self.data(using: .utf8)!
    }

    /// Return a new string with the first letter of this string capitalized.
    var capitalizedFirstLetter: String {
        return prefix(1).capitalized + dropFirst()
    }

    /// Capitalize the first letter of this string in-place.
    mutating func capitalizeFirstLetter() {
        self = self.capitalizedFirstLetter
    }

    /// Split this string into equal components of the provided length into an array.
    func components(withLength length: Int) -> [String] {
        return stride(from: 0, to: self.count, by: length).map {
            let start = self.index(self.startIndex, offsetBy: $0)
            let end = self.index(start, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            return String(self[start..<end])
        }
    }

    /// Zero-pad this string up to the provided length.
    func pad(toSize: Int) -> String {
        var padded = self
        for _ in 0..<(toSize - self.count) {
            padded = "0" + padded
        }
        return padded
    }

    /// Split this string by newlines.
    var lines: [String] {
        var result: [String] = []
        enumerateLines { line, _ in result.append(line) }
        return result
    }
}

extension Substring {

    /// Zero-pad this substring up to the provided length
    func pad(toSize: Int) -> String {
        var padded = String(self)
        for _ in 0..<(toSize - self.count) {
            padded = "0" + padded
        }
        return padded
    }
}

extension URL {

    /// Return the query parameters as a dict.
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

    /// A hex-encoded string of this data.
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }

    /// A bit string of this data.
    var bitstring: String {
        return self.reduce("", { $0 + String($1, radix: 2).pad(toSize: 8) })
    }

    /// The blake2b hash of this data.
    var hash: Data? {
        return try? Crypto.shared.hash(self)
    }

    /// The SHA256 hash of this data.
    var sha256: Data {
        return Crypto.shared.sha256(from: self)
    }

    /// A base64-encoded string of this data.
    var base64: String {
        var result = base64EncodedString()
        result = result.replacingOccurrences(of: "+", with: "-")
        result = result.replacingOccurrences(of: "/", with: "_")
        result = result.replacingOccurrences(of: "=", with: "")
        return result
    }

    /// A bytes object for libsodium compatibility.
    var bytes: Bytes { return Bytes(self) }

    /// Compress this data with the zip algorithm.
    func compress() -> Data? {
        return self.zip()
    }

    /// Decompress this data with the zip algorithm.
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

    /// Convert UInt8-array to Data
    public var data: Data {
        return Data(self)
    }

}

/// Typealias for Int to make clear it concerns a epoch timestamp.
typealias Timestamp = Int

extension Date {

    init(millisSince1970: Timestamp) {
        self.init(timeIntervalSince1970: TimeInterval(millisSince1970 / 1000))
    }

    /// The current timestamp in milliseconds (unsynced).
    var millisSince1970: Timestamp {
        return Timestamp(timeIntervalSince1970 * 1000)
    }

    /// The current timestamp in milliseconds, synced with NTP-server.
    static var now: Timestamp {
        return (Clock.now ?? Date()).millisSince1970
    }

    /// A human-friendly formatted string of how much time has passed since this date.
    /// - Parameter useNumericDates: Whether to use numeric dates.
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

    /// The number of seconds in a day.
    static let oneDay: TimeInterval = 3600 * 24

}
