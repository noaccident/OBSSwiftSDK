import Foundation
@testable import OBSSwiftSDK

/// 存放测试中使用的所有静态数据和常量。
enum MockData {
    
    // MARK: - Credentials
    
    static let permanentCredentials = OBSCredentialsProvider.permanent(
        accessKey: "TEST_AK",
        secretKey: "TEST_SK"
    )
    
    static let temporaryCredentials = OBSCredentialsProvider.temporary(
        accessKey: "TEMP_AK",
        secretKey: "TEMP_SK",
        securityToken: "THIS_IS_A_VERY_LONG_AND_SECURE_TEST_SECURITY_TOKEN"
    )
    
    // MARK: - Basic Request Info
    
    static let endpoint = "obs.test-region.myhuaweicloud.com"
    static let bucket = "test-bucket"
    static let objectKey = "test/object.txt"
    static let fileContent = "Hello, OBS Swift SDK!"
    static let fileData = fileContent.data(using: .utf8)!
    
    // MARK: - Mock Responses
    
    static func successResponse(for url: URL, eTag: String = "abc-123", versionId: String = "xyz-789") -> HTTPURLResponse {
        return HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "ETag": eTag,
                "x-obs-version-id": versionId,
                "x-obs-storage-class": "STANDARD"
            ]
        )!
    }
    
    static func errorResponse(for url: URL, statusCode: Int) -> HTTPURLResponse {
        return HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
    }
    
    static let forbiddenErrorXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <Error>
        <Code>AccessDenied</Code>
        <Message>Access Denied</Message>
    </Error>
    """.data(using: .utf8)
}