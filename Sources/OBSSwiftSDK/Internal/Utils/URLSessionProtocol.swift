import Foundation

/// A protocol that mirrors the necessary `URLSession` methods, allowing for mocking during tests.
public protocol URLSessionProtocol {
    func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse)
    
    func upload(for request: URLRequest, fromFile fileURL: URL, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse)

    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
}

// Conform the real URLSession to our protocol.
extension URLSession: URLSessionProtocol {
    public func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse) {
        try await self.data(for: request, delegate: delegate)
    }

    public func upload(for request: URLRequest, fromFile fileURL: URL, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse) {
        try await self.upload(for: request, fromFile: fileURL, delegate: delegate)
    }

    public func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        self.dataTask(with: request, completionHandler: completionHandler)
    }
}