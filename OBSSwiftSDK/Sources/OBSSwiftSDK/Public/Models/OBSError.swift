import Foundation

/// Represents errors that can occur during OBS operations.
public enum OBSError: Error, LocalizedError, Equatable {
    /// The provided configuration was invalid (e.g., bad endpoint URL).
    case invalidConfiguration(String)
    
    /// Failed to generate the request signature.
    case signatureGenerationFailed(String)
    
    /// The constructed URL for the request was invalid.
    case invalidURL(String)

    /// An error occurred while accessing a local file (e.g., file not found, permission denied).
    case fileAccessError(path: String, underlyingError: Error)
    
    /// An underlying network error occurred (e.g., no internet connection, DNS failure).
    case networkError(underlyingError: Error)
    
    /// The server responded with a non-successful HTTP status code (i.e., not in the 200-299 range).
    case httpError(statusCode: Int, response: OBSErrorResponse?)
    
    /// The server's response could not be decoded.
    case responseDecodingFailed(String)

    /// An unexpected internal error occurred within the SDK.
    case internalError(String)

    /// An unknown or unexpected error occurred.
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
        case.unknown(let reason):
            return "An unknown error occurred: \(reason)"
        }
    }
    
    public static func == (lhs: OBSError, rhs: OBSError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidConfiguration(let a),.invalidConfiguration(let b)):
            return a == b
        case (.signatureGenerationFailed(let a),.signatureGenerationFailed(let b)):
            return a == b
        case (.invalidURL(let a),.invalidURL(let b)):
            return a == b
        case (.fileAccessError(let path1, let error1),.fileAccessError(let path2, let error2)):
            return path1 == path2 && error1.localizedDescription == error2.localizedDescription
        case (.networkError(let a),.networkError(let b)):
            return a.localizedDescription == b.localizedDescription
        case (.httpError(let sc1, let r1),.httpError(let sc2, let r2)):
            return sc1 == sc2 && r1 == r2
        case (.responseDecodingFailed(let a),.responseDecodingFailed(let b)):
            return a == b
        case (.internalError(let a),.internalError(let b)):
            return a == b
        case (.unknown(let a),.unknown(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Represents the structured error response from the OBS service (parsed from XML).
public struct OBSErrorResponse: Equatable, Sendable {
    /// The OBS-specific error code (e.g., "NoSuchBucket").
    public let code: String
    /// A human-readable message providing more details about the error.
    public let message: String
    /// A unique identifier for the request, useful for support inquiries.
    public let requestId: String
    /// The ID of the host that processed the request.
    public let hostId: String

    public func toString() -> String {
        return "Error \(code): \(message) (RequestID: \(requestId), HostID: \(hostId))"
    }
}