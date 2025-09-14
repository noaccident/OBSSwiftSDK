import Foundation
import CryptoKit

/// A namespace for static utility functions used across the SDK.
internal enum Utilities {

    /// Computes the MD5 hash of the given `Data` object and returns its Base64 encoded string representation.
    /// - Parameter data: The `Data` object to hash.
    /// - Returns: A Base64 encoded string of the MD5 hash.
    static func md5Base64(for data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)
        return Data(digest).base64EncodedString()
    }

    /// Computes the MD5 hash of a file's contents at the specified URL and returns its Base64 encoded string.
    /// - Parameter fileURL: The URL of the file to hash.
    /// - Returns: A Base64 encoded string of the file's MD5 hash.
    /// - Throws: `OBSError.fileAccessError` if the file cannot be accessed or read.
    static func md5Base64(for fileURL: URL) throws -> String {
        do {
            let fileData = try Data(contentsOf: fileURL)
            return md5Base64(for: fileData)
        } catch {
            throw OBSError.fileAccessError(path: fileURL.path, underlyingError: error)
        }
    }

    /// A shared, lazily-initialized `DateFormatter` configured for RFC 1123 date string formatting.
    ///
    /// Creating `DateFormatter` instances is computationally expensive. This static property ensures
    /// that a single instance is created and reused throughout the application, improving performance.
    ///
    /// The formatter is configured with specific settings for consistency:
    /// - `timeZone`: Set to GMT to produce a timezone-agnostic timestamp, as required by many web protocols.
    /// - `locale`: Set to "en_US_POSIX" to ensure that the date format is not affected by the user's
    ///   local settings (e.g., language, calendar), guaranteeing a stable, machine-readable format.
    static let rfc1123DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}