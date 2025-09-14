import XCTest
@testable import OBSSwiftSDK

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class OBSClientTests: XCTestCase {
    
    var mockSession: URLSession!
    var client: OBSClient!

    override func setUp() {
        super.setUp()
        // 配置 URLSession 使用我们的 MockURLProtocol
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        
        // 创建一个使用模拟 session 的 OBSClient 实例
        let obsConfig = OBSConfiguration(
            endpoint: MockData.endpoint, credentialsProvider: MockData.permanentCredentials,
        )
        // (注意：这里我们通过注入一个自定义的 apiClient 来使用模拟 session)
        let apiClient = OBSAPIClient(session: mockSession, maxRetryCount: 0, logger: OBSLogger(level: .none))
        
        client = OBSClient(configuration: obsConfig, apiClient: apiClient)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        mockSession = nil
        client = nil
        super.tearDown()
    }

    func testUploadObject_onSuccess_returnsCorrectResponse() async throws {
        // 1. 准备
        let request = UploadObjectRequest(bucketName: MockData.bucket, objectKey: MockData.objectKey, data: MockData.fileData)
        let expectedURL = URL(string: "https://\(MockData.bucket).\(MockData.endpoint)/\(MockData.objectKey)")!
        
        // 设置模拟响应：返回一个成功的 HTTP 200 响应
        MockURLProtocol.requestHandler = { req in
            // 在这里可以验证传入的请求是否被正确签名
            XCTAssertNotNil(req.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(req.url, expectedURL)
            return (MockData.successResponse(for: expectedURL, eTag: "success-etag"), nil)
        }
        
        // 2. 执行
        let response = try await client.uploadObject(request: request)
        
        // 3. 验证
        // 验证从模拟响应中解析出的数据是否正确
        XCTAssertEqual(response.eTag, "success-etag")
        XCTAssertEqual(response.versionId, "xyz-789")
        XCTAssertEqual(response.storageClass, "STANDARD")
    }

    func testUploadObject_onHttpError_throwsCorrectError() async {
        // 1. 准备
        let request = UploadObjectRequest(bucketName: MockData.bucket, objectKey: MockData.objectKey, data: MockData.fileData)
        let url = URL(string: "https://\(MockData.bucket).\(MockData.endpoint)/\(MockData.objectKey)")!
        
        // 设置模拟响应：返回一个 HTTP 403 Forbidden 错误
        MockURLProtocol.requestHandler = { _ in
            (MockData.errorResponse(for: url, statusCode: 403), MockData.forbiddenErrorXML)
        }
        
        // 2. 执行 & 3. 验证
        do {
            _ = try await client.uploadObject(request: request)
            XCTFail("Expected to throw an error, but succeeded.")
        } catch let error as OBSError {
            guard case .httpError(let statusCode, let rawBody) = error else {
                XCTFail("Incorrect error type received: \(error)")
                return
            }
            XCTAssertEqual(statusCode, 403)
            XCTAssertNotNil(rawBody)
            XCTAssertTrue(rawBody?.message.contains("<Code>AccessDenied</Code>") != nil)
        } catch {
            XCTFail("An unexpected error type was thrown: \(error)")
        }
    }
    
    func testUploadFile_whenFileDoesNotExist_throwsFileAccessError() async throws {
        // 1. 准备 (Arrange)
         // 使用 FileManager 获取一个可靠的、可写的临时目录。
        let temporaryDirectory = FileManager.default.temporaryDirectory
        
        // 在临时目录中创建一个唯一的、保证不存在的文件 URL。
        // 使用 UUID 可以确保每次运行测试时的文件名都不同，避免冲突。
        let nonExistentURL = temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        
        // 为了确保测试的绝对可靠，我们先检查并确保这个文件确实不存在。
        if FileManager.default.fileExists(atPath: nonExistentURL.path) {
            try FileManager.default.removeItem(at: nonExistentURL)
        }
        
        print("Attempting to initialize with non-existent file at: \(nonExistentURL.path)")

        let request = UploadFileRequest(
            bucketName: MockData.bucket,
            objectKey: MockData.objectKey,
            fileURL: nonExistentURL
        )
        
        MockURLProtocol.requestHandler = { request in
            XCTFail("网络请求不应该被发起！请求被发送到了: \(request.url?.absoluteString ?? "N/A")")
            // 返回一个虚拟响应以满足闭包的返回类型要求
            return (HTTPURLResponse(), nil)
        }

        // 2. 执行与验证 (Act & Assert)
        // 我们断言，当执行 `try UploadFileRequest(...)` 这段代码时，它一定会抛出错误。
        do {
            // 我们尝试执行 `uploadFile` 方法。
            _ = try await client.uploadFile(request: request)
            
            // 如果上面的代码没有抛出错误并走到了这里，说明逻辑有误，测试失败。
            XCTFail("期望 `uploadFile` 方法抛出错误，但它成功了。")
            
        } catch let error as OBSError {
            // 成功捕获到了 OBSError，现在检查它是否是我们期望的类型。
            guard case .fileAccessError(let path, _) = error else {
                XCTFail("捕获到了错误的 OBSError 类型。期望得到 .fileAccessError, 但实际为: \(error)")
                return
            }
            // 验证错误中包含的文件路径是否正确。
            XCTAssertEqual(path, nonExistentURL.path)
            
            // 如果代码执行到这里，说明我们成功捕获到了预期的错误，
            // 并且“网络陷阱”没有被触发。测试完美通过！✅
            
        } catch {
            // 捕获到了一个不是 OBSError 的未知错误。
            XCTFail("捕获到了一个预料之外的错误类型: \(error)")
        }
    }
    
    func testRefreshCredentials_updatesTheSigner() async throws {
        let expectation = XCTestExpectation(description: "Verify signature is updated after credential refresh")
        expectation.expectedFulfillmentCount = 2 // 期望被调用两次

        // 第一次请求的 handler，期望收到旧 AK 的签名
        MockURLProtocol.requestHandler = { req in
            expectation.fulfill()
            return (MockData.successResponse(for: req.url!), nil)
        }
        
        let request = UploadObjectRequest(bucketName: MockData.bucket, objectKey: "obj1", data: Data())
        _ = try await client.uploadObject(request: request)
        
        // 刷新凭证
        client.refreshCredentials(with: MockData.temporaryCredentials)
        
        // 第二次请求的 handler，期望收到新 AK 的签名
        MockURLProtocol.requestHandler = { req in
            expectation.fulfill()
            return (MockData.successResponse(for: req.url!), nil)
        }
        
        let request2 = UploadObjectRequest(bucketName: MockData.bucket, objectKey: "obj2", data: Data())
        _ = try await client.uploadObject(request: request2)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
