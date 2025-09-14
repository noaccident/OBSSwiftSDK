import Foundation

typealias AsyncThrowingRequestHandler = () async throws -> (Data, URLResponse)

/// Internal client for handling network requests, including retry logic.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
internal final class OBSAPIClient {
    private let session: URLSession
    private let maxRetryCount: Int
    // TODO 为什么这里要加logger
    private let logger: OBSLogger

    init(session: URLSession, maxRetryCount: Int, logger: OBSLogger) {
        self.session = session
        self.maxRetryCount = maxRetryCount
        self.logger = logger
    }

    func performUpload(request: URLRequest, from data: Data) async throws -> (Data, HTTPURLResponse) {
        let handler: AsyncThrowingRequestHandler = {
            try await self.session.upload(for: request, from: data)
        }
        return try await performRequest(with: handler)
    }

    func performUpload(request: URLRequest, fromFile fileURL: URL) async throws -> (Data, HTTPURLResponse) {
        let handler: AsyncThrowingRequestHandler = {
            try await self.session.upload(for: request, fromFile: fileURL)
        }
        return try await performRequest(with: handler)
    }

    private func performRequest(with requestHandler: @escaping AsyncThrowingRequestHandler) async throws -> (Data, HTTPURLResponse) {

        var lastError: Error = OBSError.unknown("Request failed after all retry attempts.")

        for attempt in 0...maxRetryCount {

            logger.debug("Attempt \(attempt + 1) of  \(maxRetryCount + 1)...")

            do {
                let (data, response) = try await requestHandler()

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OBSError.unknown(String("Received non-HTTP response"))
                }

                if (200..<300).contains(httpResponse.statusCode) {
                    logger.debug("Request successful with status code \(httpResponse.statusCode).")
                    return (data, httpResponse)
                }

                let obsErrorResponse = OBSErrorXMLParser.parse(from: data)
                let currentHttpError = OBSError.httpError(
                    statusCode: httpResponse.statusCode,
                    response:obsErrorResponse
                )

                if (500..<600).contains(httpResponse.statusCode) {
                    logger.error("Received server error (status code: \(httpResponse.statusCode)). Retrying if possible...")
                    lastError = currentHttpError
                } else {
                    // TODO 日志记录
                    throw currentHttpError
                }
            } catch let error where error is OBSError {
                throw error
            } catch {
                logger.error("Network error on attempt \(attempt + 1): \(error.localizedDescription)")
                lastError = OBSError.networkError(underlyingError: error)
            }
            if attempt < maxRetryCount {
                let delaySeconds = pow(2.0, Double(attempt)) // 1, 2, 4, 8... seconds
                logger.info("Waiting for \(delaySeconds) seconds before retrying...")
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }
        throw lastError
    }
    
    // TODO
    private func isRetryable(error: URLError) -> Bool {
        switch error.code {
        case.timedOut,.cannotFindHost,.cannotConnectToHost,.networkConnectionLost,.notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}
