import Foundation

/// Represents the body of an HTTP request for an OBS operation.
public enum OBSRequestBody: Sendable {
    /// Represents an empty request body.
    /// Suitable for HTTP methods like GET, DELETE, or HEAD that typically do not include a body.
    case empty
    
    /// The request body is sourced from an in-memory `Data` buffer.
    /// - Parameter Data: The binary data to be uploaded.
    case data(Data)
    
    /// The request body is sourced from a local file.
    /// `URLSession` will efficiently stream the file content, avoiding loading the entire file into memory.
    /// - Parameter URL: The URL pointing to the local file.
    case file(URL)
}

/// Defines the contract for the underlying network client.
///
/// This protocol is key to enabling dependency injection and testability. By making `OBSClient`
/// depend on this abstract interface rather than the concrete `OBSAPIClient` class, we can easily
/// substitute a mock implementation in unit tests to verify `OBSClient`'s behavior without
/// making actual network requests.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public protocol OBSAPIClientProtocol: Sendable {
    func perform(request: URLRequest, body: OBSRequestBody?) async throws -> (Data, HTTPURLResponse)
}

/// Defines a protocol for `URLSession` to allow for mocking in tests.
internal protocol URLSessionProtocol: Sendable {
    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse)
    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse)
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// Make URLSession conform to the protocol by default, so production code needs no changes.
extension URLSession: URLSessionProtocol {}

/// The default implementation of `OBSAPIClientProtocol` that uses `URLSession` for networking.
///
/// This actor handles the entire lifecycle of a network request, including retries with
/// exponential backoff for transient server-side or network errors.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
internal actor OBSAPIClient: OBSAPIClientProtocol {
    // Dependencies are now protocol types, not concrete classes.
    private let session: URLSessionProtocol
    private let maxRetryCount: Int
    private let logger: OBSLogger

    init(session: URLSessionProtocol, maxRetryCount: Int, logger: OBSLogger) {
        self.session = session
        self.maxRetryCount = maxRetryCount
        self.logger = logger
    }

    /// Performs a network request with a given request body, handling retries.
    func perform(request: URLRequest, body: OBSRequestBody?) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error = OBSError.unknown("Request failed after all retry attempts.")

        for attempt in 0...maxRetryCount {
            logger.debug("Initiating request attempt \(attempt + 1) of \(maxRetryCount + 1)...")

            do {
                // Call the appropriate session method based on the request body type.
                let (data, response) = try await performDataTask(for: request, with: body)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OBSError.unknown("Received a non-HTTP response, which is unexpected.")
                }

                // Success (2xx status codes)
                if (200..<300).contains(httpResponse.statusCode) {
                    logger.debug("Request succeeded with status code: \(httpResponse.statusCode).")
                    return (data, httpResponse)
                }

                let obsErrorResponse = OBSErrorXMLParser.parse(from: data)
                let currentHttpError = OBSError.httpError(
                    statusCode: httpResponse.statusCode,
                    response: obsErrorResponse
                )

                // Server errors (5xx) are potentially transient and can be retried.
                if (500..<600).contains(httpResponse.statusCode) {
                    logger.error("Received server error (status code: \(httpResponse.statusCode)). Retrying if possible...")
                    lastError = currentHttpError
                } else {
                    // Client errors (4xx) or other non-2xx/5xx errors should not be retried.
                    logger.error("Received client error (status code: \(httpResponse.statusCode)). The request will not be retried.")
                    throw currentHttpError
                }

            } catch let error as OBSError {
                // If it's already our custom OBSError, re-throw it directly.
                throw error
            } catch let urlError as URLError where isRetryable(error: urlError) {
                // A retryable network error occurred.
                logger.error("Network error on attempt \(attempt + 1): \(urlError.localizedDescription)")
                lastError = OBSError.networkError(underlyingError: urlError)
            } catch {
                // A non-retryable or unexpected error occurred.
                logger.error("An unrecoverable error occurred: \(error.localizedDescription)")
                throw OBSError.networkError(underlyingError: error)
            }

            // If this wasn't the last attempt, wait with exponential backoff.
            if attempt < maxRetryCount {
                let delaySeconds = pow(2.0, Double(attempt)) // Delays: 1, 2, 4, 8... seconds
                logger.info("Waiting for \(delaySeconds)s before retrying...")
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }
        
        // After all retries are exhausted, throw the last recorded error.
        throw lastError
    }
    
    /// Dispatches the task to the appropriate `URLSession` method based on the request body.
    private func performDataTask(for request: URLRequest, with body: OBSRequestBody?) async throws -> (Data, URLResponse) {
        switch body {
        case.data(let data):
            return try await session.upload(for: request, from: data)
        case.file(let fileURL):
            return try await session.upload(for: request, fromFile: fileURL)
        case.empty,.none:
            return try await session.data(for: request)
        }
    }

    /// Checks if a `URLError` indicates a transient, retryable network condition.
    private func isRetryable(error: URLError) -> Bool {
        switch error.code {
        case.timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .networkConnectionLost,
            .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}