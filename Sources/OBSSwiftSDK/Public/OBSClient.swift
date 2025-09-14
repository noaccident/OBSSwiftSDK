import Foundation

/// The main client for interacting with Huawei Cloud OBS.
/// This class is thread-safe.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public actor OBSClient {
    private let configuration: OBSConfiguration
    private var apiClient: OBSAPIClientProtocol
    private var signer: OBSRequestSigner
    private let logger: OBSLogger

    /// Initializes a new OBS client with the specified configuration.
    /// - Parameter configuration: The configuration object containing endpoint, credentials, and other settings.
    public init(
        configuration: OBSConfiguration,
        apiClient: OBSAPIClientProtocol? = nil
    ) {
        let logger = OBSLogger(level: configuration.logLevel)
        self.configuration = configuration
        self.logger = logger
        self.apiClient = apiClient ?? OBSAPIClient(
            session: URLSession(configuration:.default),
            maxRetryCount: configuration.maxRetryCount,
            logger: logger
        )
        self.signer = OBSRequestSigner(
            credentialsProvider: configuration.credentialsProvider
        )
    }
    
    /// Refreshes the client with new temporary credentials.
    public func refreshCredentials(with newCredentialsProvider: OBSCredentialsProvider) {
        self.signer = OBSRequestSigner(credentialsProvider: newCredentialsProvider)
        logger.info("Credentials refreshed successfully.")
    }
    
    /// Uploads an object to OBS from an in-memory Data buffer.
    public func uploadObject(request: UploadObjectRequest) async throws -> UploadResponse {
        var urlRequest = try buildBaseRequest(for: request)
        
        let signedRequest = try signer.sign(request: &urlRequest, for: request)

        if let contentLength = request.contentLength {
            urlRequest.setValue("\(contentLength)", forHTTPHeaderField: "Content-Length")
        } else {
            // 如果没有提供 Content-Length，尝试从 Data 获取长度
            urlRequest.setValue("\(request.data.count)", forHTTPHeaderField: "Content-Length")
        }

        let (responseData, httpResponse) = try await apiClient.perform(
            request: signedRequest,
            body: .data(request.data)
        )

        return try processUploadResponse(responseData: responseData, httpResponse: httpResponse)
    }

    /// Uploads an object to OBS from a local file path.
    public func uploadFile(request: UploadFileRequest) async throws -> UploadResponse {
        var urlRequest = try buildBaseRequest(for: request)
        
        let fileSize: NSNumber
        
        do {
            // 尝试获取文件属性。这一步同时验证了文件的存在性和读取权限。
            let attributes = try FileManager.default.attributesOfItem(atPath: request.fileURL.path)
            
            if let providedLength = request.contentLength {
                fileSize = NSNumber(value: providedLength)
            } else if let size = attributes[.size] as? NSNumber {
                fileSize = size
            } else {
                throw OBSError.fileAccessError(
                    path: request.fileURL.path,
                    underlyingError: NSError(domain: "OBSSDKError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not determine file size from attributes."])
                )
            }
        } catch {
            // 捕获所有来自 FileManager 的错误 (如：文件不存在、无权限等)。
            // 将底层的系统错误，包装成我们对外的、统一的 OBSError 类型。
            throw OBSError.fileAccessError(path: request.fileURL.path, underlyingError: error)
    }

        let signedRequest = try signer.sign(request: &urlRequest, for: request)

        // 设置 Content-Length 头部。
        urlRequest.setValue(fileSize.stringValue, forHTTPHeaderField: "Content-Length")

        let (responseData, httpResponse) = try await apiClient.perform(
            request: signedRequest,
            body: .file(request.fileURL)
        )

        return try processUploadResponse(responseData: responseData, httpResponse: httpResponse)
    }
    
    /// Builds a base URLRequest with common headers from a generic UploadRequest.
    private func buildBaseRequest(for request: any UploadRequest) throws -> URLRequest {
        let url = try buildURL(bucket: request.bucketName, key: request.objectKey)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        
        // Add optional headers from the request model
        urlRequest.setValue(request.contentType ?? "application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        if let acl = request.acl {
            urlRequest.setValue(acl.rawValue, forHTTPHeaderField: "x-obs-acl")
        }
        
        if let storageClass = request.storageClass {
            urlRequest.setValue(storageClass.rawValue, forHTTPHeaderField: "x-obs-storage-class")
        }
        
        if let md5 = request.contentMD5 {
            urlRequest.setValue(md5, forHTTPHeaderField: "Content-MD5")
        }
        
        if let metadata = request.metadata {
            for (key, value) in metadata {
                urlRequest.setValue(value, forHTTPHeaderField: "x-obs-meta-\(key)")
            }
        }
        
        if let encryption = request.serverSideEncryption {
            encryption.apply(to: &urlRequest)
        }
        
        return urlRequest
    }
    
    private func buildURL(bucket: String, key: String) throws -> URL {
        let scheme = configuration.useSSL ? "https" : "http"
        
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key
        let urlString = "\(scheme)://\(bucket).\(configuration.endpoint)/\(encodedKey)"
        
        guard let url = URL(string: urlString) else {
            throw OBSError.invalidURL(urlString)
        }
        return url
    }

    private func processUploadResponse(responseData: Data, httpResponse: HTTPURLResponse) throws -> UploadResponse {
        // 根据 HTTP 状态码判断请求是否成功
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OBSError.httpError(statusCode: httpResponse.statusCode, response: OBSErrorXMLParser.parse(from: responseData))
        }
        
        // 如果成功，从响应头中提取信息并构造 UploadResponse
        return UploadResponse(from: httpResponse)
    }
}
