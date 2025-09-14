import Foundation
import CryptoKit

internal enum Utilities {
  static func md5Base64(for data: Data) -> String {
      let md5Data = Insecure.MD5.hash(data: data)
      return Data(md5Data).base64EncodedString()
  }

  static func md5Base64(for fileURL: URL) throws -> String {
    do {
      let fileData = try Data(contentsOf: fileURL)
      return md5Base64(for: fileData)
    } catch {
      throw OBSError.fileAccessError(path: fileURL.path, underlyingError: error)
    }
  }

  static let rfc1123DateFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
      formatter.timeZone = TimeZone(abbreviation: "GMT")
      formatter.locale = Locale(identifier: "en_US_POSIX")
      return formatter
  }()
}