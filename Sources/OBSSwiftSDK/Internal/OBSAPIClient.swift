import Foundation


public enum OBSRequestBody: Sendable{
    
    /// 表示一个空的请求体。
    ///
    /// 适用于像 GET、DELETE 或 HEAD 这样通常不包含请求体的 HTTP 方法。
    case empty
    
    /// 请求体来自一个内存中的 `Data` 缓冲区。
    ///
    /// - Parameter Data: 要上传的二进制数据。
    case data(Data)
    
    /// 请求体来自一个本地文件。
    ///
    /// `URLSession` 会高效地以流式方式上传文件内容，避免将整个文件读入内存。
    /// - Parameter URL: 指向本地文件的 URL。
    case file(URL)
}
/// 定义了底层网络客户端必须遵循的契约（contract）。
///
/// 这个协议是实现依赖注入和可测试性的关键。通过让 `OBSClient` 依赖于这个抽象接口，
/// 而不是具体的 `OBSAPIClient` 类，我们可以在单元测试中轻松地替换一个模拟（mock）的实现，
/// 从而在不发出真实网路请求的情况下测试 `OBSClient` 的行为。
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public protocol OBSAPIClientProtocol: Sendable {
    func perform(request: URLRequest, body: OBSRequestBody?) async throws -> (Data, HTTPURLResponse)
}

/// 为 URLSession 定义一个协议，以便在测试中可以模拟(mock)它。
internal protocol URLSessionProtocol: Sendable {
    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse)
    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse)
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// 让 URLSession 默认遵循这个协议，这样生产代码无需任何改动。
extension URLSession: URLSessionProtocol {}

// MARK: - 2. 重构后的 OBSAPIClient

/// 遵循我们之前定义的协议，使其可被注入到 OBSClient 中。
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
internal actor OBSAPIClient: OBSAPIClientProtocol {
    // 依赖项现在是协议类型，而不是具体类
    private let session: URLSessionProtocol
    private let maxRetryCount: Int
    private let logger: OBSLogger

    init(session: URLSessionProtocol, maxRetryCount: Int, logger: OBSLogger) {
        self.session = session
        self.maxRetryCount = maxRetryCount
        self.logger = logger
    }

    /// 统一的 perform 方法，处理所有类型的请求。
    func perform(request: URLRequest, body: OBSRequestBody?) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error = OBSError.unknown("请求在所有重试后失败。")

        for attempt in 0...maxRetryCount {
            logger.debug("请求尝试第 \(attempt + 1) 次 (共 \(maxRetryCount + 1) 次)...")

            do {
                // 根据请求体类型调用不同的 session 方法
                let (data, response) = try await performDataTask(for: request, with: body)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw OBSError.unknown("收到了非 HTTP 响应")
                }

                // 成功 (2xx 状态码)
                if (200..<300).contains(httpResponse.statusCode) {
                    logger.debug("请求成功，状态码: \(httpResponse.statusCode)。")
                    return (data, httpResponse)
                }

                let obsErrorResponse = OBSErrorXMLParser.parse(from: data)
                let currentHttpError = OBSError.httpError(
                    statusCode: httpResponse.statusCode,
                    response: obsErrorResponse
                )

                // 服务器错误 (5xx)，可以重试
                if (500..<600).contains(httpResponse.statusCode) {
                    logger.error("收到服务器错误 (状态码: \(httpResponse.statusCode))。如果可能，将进行重试...")
                    lastError = currentHttpError
                } else {
                    // 客户端错误 (4xx) 或其他非 2xx/5xx 错误，不应重试
                    logger.error("收到客户端错误 (状态码: \(httpResponse.statusCode))，请求将不会重试。")
                    throw currentHttpError
                }

            } catch let error as OBSError {
                // 如果已经是我们自定义的 OBSError，直接抛出
                throw error
            } catch let urlError as URLError where isRetryable(error: urlError) {
                // 可重试的网络错误
                logger.error("网络错误 (尝试 \(attempt + 1)): \(urlError.localizedDescription)")
                lastError = OBSError.networkError(underlyingError: urlError)
            } catch {
                // 不可重试的其他错误
                logger.error("发生不可重试的错误: \(error.localizedDescription)")
                throw OBSError.networkError(underlyingError: error)
            }

            // 如果还未到最大重试次数，则进行指数退避延迟
            if attempt < maxRetryCount {
                let delaySeconds = pow(2.0, Double(attempt)) // 延迟 1, 2, 4, 8... 秒
                logger.info("等待 \(delaySeconds) 秒后重试...")
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }
        
        // 所有重试次数用尽后，抛出最后一次记录的错误
        throw lastError
    }
    
    /// 根据请求体分发任务
    private func performDataTask(for request: URLRequest, with body: OBSRequestBody?) async throws -> (Data, URLResponse) {
        switch body {
        case .data(let data):
            return try await session.upload(for: request, from: data)
        case .file(let fileURL):
            return try await session.upload(for: request, fromFile: fileURL)
        case .empty, .none:
            return try await session.data(for: request)
        }
    }

    /// 检查一个 URLError 是否是可重试的网络相关错误。
    private func isRetryable(error: URLError) -> Bool {
        switch error.code {
        case .timedOut,
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
