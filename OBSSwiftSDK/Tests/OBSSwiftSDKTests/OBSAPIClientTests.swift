import XCTest
@testable import OBSSwiftSDK

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class OBSAPIClientTests: XCTestCase {

    var mockSession: URLSession!
    
    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        mockSession = nil
        super.tearDown()
    }

    /// 测试在遇到服务器错误 (503) 时，客户端是否会按预期重试。
    func testPerformRequest_onServerError_retriesUpToMaxCount() async throws {
        let maxRetries = 2
        var attemptCount = 0
        let url = URL(string: "https://test.com")!
        
        // 设置模拟响应：前两次返回 503 错误，第三次返回 200 成功
        MockURLProtocol.requestHandler = { _ in
            attemptCount += 1
            if attemptCount <= maxRetries {
                return (MockData.errorResponse(for: url, statusCode: 503), "Service Unavailable".data(using: .utf8))
            } else {
                return (MockData.successResponse(for: url), "OK".data(using: .utf8))
            }
        }
        
        let apiClient = OBSAPIClient(session: mockSession, maxRetryCount: maxRetries, logger: OBSLogger(level: .none))
        
        // 执行请求
        _ = try await apiClient.perform(request: URLRequest(url: url), body: .data(Data()))

        // 验证：总共的尝试次数应该是 1次初始 + 2次重试 = 3次
        XCTAssertEqual(attemptCount, maxRetries + 1)
    }

    /// 测试在遇到客户端错误 (403) 时，客户端是否会立即失败，不进行重试。
    func testPerformRequest_onClientError_failsImmediatelyWithoutRetry() async {
        var attemptCount = 0
        let url = URL(string: "https://test.com")!
        
        // 设置模拟响应：总是返回 403 错误
        MockURLProtocol.requestHandler = { _ in
            attemptCount += 1
            return (MockData.errorResponse(for: url, statusCode: 403), MockData.forbiddenErrorXML)
        }
        
        let apiClient = OBSAPIClient(session: mockSession, maxRetryCount: 3, logger: OBSLogger(level: .none))

        do {
            _ = try await apiClient.perform(request: URLRequest(url: url), body: .data(Data()))
            XCTFail("Request should have failed but it succeeded.")
        } catch {
            // 成功捕获到错误
        }
        
        // 验证：应该只尝试了一次
        XCTAssertEqual(attemptCount, 1)
    }
}
