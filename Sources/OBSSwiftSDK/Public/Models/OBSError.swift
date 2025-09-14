import Foundation

/// Represents errors that can occur during OBS operations.
public enum OBSError: Error, LocalizedError {
    /// The provided configuration was invalid (e.g., bad endpoint URL).
    case invalidConfiguration(String)
    
    /// Failed to generate the request signature.
    case signatureGenerationFailed(String)
    
    /// The constructed URL for the request was invalid.
    case invalidURL(String)

    case fileAccessError(path: String, underlyingError: Error)
    
    /// An underlying network error occurred (e.g., no internet connection).
    case networkError(underlyingError: Error)
    
    /// The server responded with a non-successful HTTP status code.
    case httpError(statusCode: Int, response: OBSErrorResponse?)
    
    /// The server's response could not be decoded.
    case responseDecodingFailed(String)

    /// An unexpected internal error occurred.
    case internalError(String)

    // 如何定义错误
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case.invalidConfiguration(let reason):
            return "Invalid Configuration: \(reason)"
        case.signatureGenerationFailed(let reason):
            return "Signature Generation Failed: \(reason)"
        case.invalidURL(let url):
            return "Invalid URL: \(url)"
        case.fileAccessError(let path, let underlyingError):
            return "Failed to access file at path '\(path)': \(underlyingError.localizedDescription)"
        case.networkError(let underlyingError):
            return "Network Error: \(underlyingError.localizedDescription)"
        case.httpError(let statusCode, let response):
            if let response = response {
                return "HTTP Error \(statusCode): \(response.code) - \(response.message) (RequestID: \(response.requestId))"
            }
            return "HTTP Error: Received status code \(statusCode)"
        case.responseDecodingFailed(let reason):
            return "Response Decoding Failed: \(reason)"
        case.internalError(let message):
            return "Internal SDK Error: \(message)"
        case .unknown(let reason):
            return "An unknown error occurred: \(reason)"
        }
    }
    
    // public static func == (lhs: OBSError, rhs: OBSError) -> Bool {
    //     switch (lhs, rhs) {
    //     case (.invalidConfiguration(let a),.invalidConfiguration(let b)): return a == b
    //     case (.signatureGenerationFailed(let a),.signatureGenerationFailed(let b)): return a == b
    //     case (.invalidURL(let a),.invalidURL(let b)): return a == b
    //     case (.networkError(let a),.networkError(let b)): return a == b
    //     case (.httpError(let sc1, let r1),.httpError(let sc2, let r2)): return sc1 == sc2 && r1 == r2
    //     case (.responseDecodingFailed(let a),.responseDecodingFailed(let b)): return a == b
    //     case (.internalError(let a),.internalError(let b)): return a == b
    //     default: return false
    //     }
    // }
}

/// Represents the structured error response from the OBS service (parsed from XML).
public struct OBSErrorResponse: Equatable, Sendable {
    public let code: String
    public let message: String
    public let requestId: String
    public let hostId: String

    public func toString() -> String {
        return "Error \(code): \(message) (RequestID: \(requestId), HostID: \(hostId))"
    }
}