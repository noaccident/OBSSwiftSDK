import XCTest
import CryptoKit
@testable import OBSSwiftSDK

final class OBSRequestSignerTests: XCTestCase {

    /// 测试使用永久 AK/SK 时的签名是否正确。
    func testSign_withPermanentCredentials_generatesCorrectSignature() throws {
        // 1. 准备
        // 伪造一个固定的日期，以确保签名结果是可预测的
        let fixedDateString = "Sun, 14 Sep 2025 01:25:30 GMT"
        let mockDate = Utilities.rfc1123DateFormatter.date(from: fixedDateString)!
        let signer = OBSRequestSigner(credentialsProvider: MockData.permanentCredentials)
        var request = URLRequest(url: URL(string: "https://\(MockData.bucket).\(MockData.endpoint)/\(MockData.objectKey)")!)
        let uploadDetails = UploadObjectRequest(
            bucketName: MockData.bucket,
            objectKey: MockData.objectKey,
            data: MockData.fileData,
            contentType: "text/plain",
            metadata: ["user-id": "123"],
            date: mockDate
        )
        request.httpMethod = "PUT"
        
        // 2. 执行
        // 手动添加固定的日期和MD5，以匹配我们手动计算的 "黄金样本"
        request.setValue(fixedDateString, forHTTPHeaderField: "Date")
        request.setValue(Utilities.md5Base64(for: MockData.fileData), forHTTPHeaderField: "Content-MD5")
        
        let signedRequest = try signer.sign(request: &request, for: uploadDetails)

        // 3. 验证
        // 根据 OBS 文档，手动构建正确的 "StringToSign"
        let canonicalizedHeaders = "x-obs-meta-user-id:123\n"
        let canonicalizedResource = "/\(MockData.bucket)/\(MockData.objectKey)"
        let stringToSign = """
        PUT
        \(Utilities.md5Base64(for: MockData.fileData))
        text/plain
        \(fixedDateString)
        \(canonicalizedHeaders)\(canonicalizedResource)
        """
        
        // 手动计算期望的签名
        let key = SymmetricKey(data: MockData.permanentCredentials.secretKey.data(using: .utf8)!)
        let signatureData = HMAC<Insecure.SHA1>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: key)
        let expectedSignature = Data(signatureData).base64EncodedString()

        let expectedAuthHeader = "OBS \(MockData.permanentCredentials.accessKey):\(expectedSignature)"

        XCTAssertEqual(signedRequest.value(forHTTPHeaderField: "Authorization"), expectedAuthHeader)
    }
    
    /// 测试使用临时凭证（带 Security Token）时的签名是否正确。
    func testSign_withTemporaryCredentials_includesTokenAndSignsCorrectly() throws {
        // 1. 准备
        let fixedDateString = "Sun, 14 Sep 2025 01:25:30 GMT"
        let mockDate = Utilities.rfc1123DateFormatter.date(from: fixedDateString)!
        
        let signer = OBSRequestSigner(credentialsProvider: MockData.temporaryCredentials)
        var request = URLRequest(url: URL(string: "https://\(MockData.bucket).\(MockData.endpoint)/\(MockData.objectKey)")!)
        let uploadDetails = UploadObjectRequest(
            bucketName: MockData.bucket,
            objectKey: MockData.objectKey,
            data: MockData.fileData,
            date: mockDate
        )
        
        // 2. 执行
        request.setValue(fixedDateString, forHTTPHeaderField: "Date")
        let signedRequest = try signer.sign(request: &request, for: uploadDetails)
        
        // 3. 验证
        // 验证 security-token 头部是否已添加
        XCTAssertEqual(signedRequest.value(forHTTPHeaderField: "x-obs-security-token"), MockData.temporaryCredentials.securityToken)
        
        // 手动构建 StringToSign，这次必须包含 x-obs-security-token
        let canonicalizedHeaders = "x-obs-security-token:\(MockData.temporaryCredentials.securityToken ?? "")\n"
        let canonicalizedResource = "/\(MockData.bucket)/\(MockData.objectKey)"
        let stringToSign = """
        GET
        
        
        \(fixedDateString)
        \(canonicalizedHeaders)\(canonicalizedResource)
        """
        
        let key = SymmetricKey(data: MockData.temporaryCredentials.secretKey.data(using: .utf8)!)
        let signatureData = HMAC<Insecure.SHA1>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: key)
        let expectedSignature = Data(signatureData).base64EncodedString()
        
        let expectedAuthHeader = "OBS \(MockData.temporaryCredentials.accessKey):\(expectedSignature)"
        
        XCTAssertEqual(signedRequest.value(forHTTPHeaderField: "Authorization"), expectedAuthHeader)
    }
    
    /// 测试包含子资源的 URL 是否能生成正确的 CanonicalizedResource
    func testSign_withSubResource_generatesCorrectCanonicalizedResource() throws {
         // 1. 准备 (Arrange)
        let signer = OBSRequestSigner(credentialsProvider: MockData.permanentCredentials)
        
        // 构造一个复杂的 URL：
        // - 包含两个需要签名的子资源: versionId, acl
        // - 它们的顺序是乱的 (versionId 在前)
        // - 包含一个不需要签名的参数: other=foo
        let complexUrlString = "https://\(MockData.bucket).\(MockData.endpoint)/\(MockData.objectKey)?versionId=abc-123&other=foo&acl"
        var request = URLRequest(url: URL(string: complexUrlString)!)
        
        let fixedDateString = "Tue, 27 May 2025 12:00:00 GMT"
        let mockDate = Utilities.rfc1123DateFormatter.date(from: fixedDateString)!
        
        let uploadDetails = UploadObjectRequest(
            bucketName: MockData.bucket,
            objectKey: MockData.objectKey,
            data: Data(),
            date: mockDate
        )
        
        // 伪造一个固定的日期，以确保签名结果是可预测的
        request.setValue(fixedDateString, forHTTPHeaderField: "Date")

        // 2. 执行 (Act)
        let signedRequest = try signer.sign(request: &request, for: uploadDetails)

        // 3. 验证 (Assert)
        
        // 3.1. 手动构建正确的 CanonicalizedResource
        //      - `other=foo` 应该被忽略
        //      - `acl` 和 `versionId` 应该按字母序排序
        let correctCanonicalizedResource = "/\(MockData.bucket)/\(MockData.objectKey)?acl&versionId=abc-123"
        
        // 3.2. 手动构建正确的 StringToSign
        let stringToSign = """
        GET
        
        
        \(fixedDateString)
        \(correctCanonicalizedResource)
        """
        
        // 3.3. 手动计算期望的 "黄金标准" 签名
        let key = SymmetricKey(data: MockData.permanentCredentials.secretKey.data(using: .utf8)!)
        let signatureData = HMAC<Insecure.SHA1>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: key)
        let expectedSignature = Data(signatureData).base64EncodedString()
        
        // 3.4. 构造期望的 Authorization 头部
        let expectedAuthHeader = "OBS \(MockData.permanentCredentials.accessKey):\(expectedSignature)"
        
        // 3.5. 断言：如果 sign() 方法生成的头部与我们手动计算的完全一致，
        //       就证明了它内部的 buildCanonicalizedResource 方法工作是完全正确的。
        XCTAssertEqual(signedRequest.value(forHTTPHeaderField: "Authorization"), expectedAuthHeader)
    }
}
