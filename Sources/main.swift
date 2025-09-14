
import Foundation
import OBSSwiftSDK // 1. 导入我们的 SDK

print("🚀 OBS Swift SDK 应用示例开始运行...")

// MARK: - 1. 配置 (Configuration)

// !!! 安全警告 !!!
// 绝不要在生产代码中硬编码您的 AK/SK。
// 最佳实践是从环境变量或安全的密钥管理服务中读取。
guard let ak = ProcessInfo.processInfo.environment["OBS_AK"],
    let sk = ProcessInfo.processInfo.environment["OBS_SK"],
    let endpoint = ProcessInfo.processInfo.environment["OBS_ENDPOINT"],
    let bucket = ProcessInfo.processInfo.environment["OBS_BUCKET"] else {
    print("❌ 错误: 请先设置环境变量 OBS_AK, OBS_SK, OBS_ENDPOINT, OBS_BUCKET")
    fatalError("缺少必要的环境变量。")
}

// 创建一个使用永久凭证的配置
let permanentCredentials = OBSCredentialsProvider.permanent(accessKey: ak, secretKey: sk)

let config = OBSConfiguration(
    endpoint: endpoint,
    credentialsProvider: permanentCredentials,
    useSSL: true, // 默认使用 HTTPS，更安全
    logLevel: .debug  // 在开发时开启详细日志，方便调试
)

// 初始化 OBS 客户端
let client = OBSClient(configuration: config)

// MARK: - 2. 核心用法演示

do {
    // --- 示例 1: 上传内存中的数据 ---
    let objectKey1 = "from-memory/demo-\(UUID().uuidString).txt"
    let objectData = "Hello, Swift OBS SDK! This data is from memory.".data(using: .utf8)!
    
    print("\n- 示例 1: 正在上传内存数据到 \(objectKey1)...")
    let uploadObjectRequest = UploadObjectRequest(
        bucketName: bucket,
        objectKey: objectKey1,
        data: objectData,
        contentType: "text/plain",
        acl: .private,
        metadata: ["source": "swift-sdk-demo"]
    )
    // **修正点 1: 缺少 try**
    let response1 = try await client.uploadObject(request: uploadObjectRequest)
    print("✅ 成功！ETag: \(response1.eTag ?? "N/A")")

    // --- 示例 2: 上传一个本地文件 ---
    // 为了让示例可独立运行，我们先动态创建一个临时文件
    let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("my-local-file.txt")
    // **修正点 2: 缺少 try**
    try "This is content from a local file.".write(to: tempFileURL, atomically: true, encoding: .utf8)
    
    let objectKey2 = "from-file/demo-\(UUID().uuidString).txt"
    print("\n- 示例 2: 正在上传本地文件 \(tempFileURL.path) 到 \(objectKey2)...")
    
    // (根据我们最终的设计，UploadFileRequest.init 不会抛出错误，所以这里不需要 try)
    let uploadFileRequest = UploadFileRequest(
        bucketName: bucket,
        objectKey: objectKey2,
        fileURL: tempFileURL
    )
    // **修正点 3: 缺少 try**
    let response2 = try await client.uploadFile(request: uploadFileRequest)
    print("✅ 成功！ETag: \(response2.eTag ?? "N/A")")
    
    // 清理临时文件
    // **修正点 4: 缺少 try**
    try FileManager.default.removeItem(at: tempFileURL)

    // --- 示例 3: 使用临时凭证并刷新 ---
    print("\n- 示例 3: 演示临时凭证和刷新机制...")
    // 假设您从 STS 服务获取了临时凭证
    let tempAK = ProcessInfo.processInfo.environment["OBS_TEMP_AK"] ?? "TEMP_AK_PLACEHOLDER"
    let tempSK = ProcessInfo.processInfo.environment["OBS_TEMP_SK"] ?? "TEMP_SK_PLACEHOLDER"
    let tempToken = ProcessInfo.processInfo.environment["OBS_TEMP_TOKEN"] ?? "TEMP_TOKEN_PLACEHOLDER"
    
    let initialTempCredentials = OBSCredentialsProvider.temporary(
        accessKey: tempAK,
        secretKey: tempSK,
        securityToken: tempToken
    )
    
    // 使用新凭证刷新客户端
    await client.refreshCredentials(with: initialTempCredentials)
    print("   凭证已刷新为初始临时凭证。")
    
    let objectKey3 = "from-temp-auth/demo.log"
    // **修正点 5: 缺少 try**
    let response3 = try await client.uploadObject(
        request: UploadObjectRequest(bucketName: bucket, objectKey: objectKey3, data: Data("Log entry 1".utf8))
    )
    print("   使用初始临时凭证上传成功！ETag: \(response3.eTag ?? "N/A")")
    
    // 模拟一段时间后，Token 过期，您获取了新的临时凭证
    let refreshedTempCredentials = OBSCredentialsProvider.temporary(
        accessKey: "NEW_"+tempAK,
        secretKey: "NEW_"+tempSK,
        securityToken: "NEW_"+tempToken
    )
    
    // 再次刷新客户端
    await client.refreshCredentials(with: refreshedTempCredentials)
    print("   凭证已刷新为新的临时凭证。")
    
    // **修正点 6: 缺少 try**
    let response4 = try await client.uploadObject(
        request: UploadObjectRequest(bucketName: bucket, objectKey: objectKey3, data: Data("Log entry 2".utf8))
    )
    print("   使用新的临时凭证上传成功！ETag: \(response4.eTag ?? "N/A")")

} catch let error as OBSError {
    // MARK: - 3. 错误处理
    // 捕获我们定义的 OBSError，可以进行精细化处理
    print("\n❌ 操作失败！捕获到 OBS 错误:")
    switch error {
    case .fileAccessError(let path, let underlyingError):
        print("   错误类型: 文件访问错误")
        print("   文件路径: \(path)")
        print("   底层原因: \(underlyingError.localizedDescription)")
    case .httpError(let statusCode, let response):
        print("   错误类型: HTTP 错误")
        print("   状态码: \(statusCode)")
        print("   响应内容: \(response?.toString() ?? "N/A")")
    default:
        print("   错误详情: \(error.localizedDescription)")
    }
} catch {
    // 捕获其他未知错误
    print("\n❌ 操作失败！捕获到未知错误: \(error.localizedDescription)")
}

print("\n🎉 示例运行结束。")
