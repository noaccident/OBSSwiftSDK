import Foundation

/// The main client for interacting with Huawei Cloud OBS.
///
/// This class provides methods to upload objects from memory or local files.
/// As an `actor`, all of its methods are thread-safe and can be called concurrently
/// without requiring external synchronization.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public actor OBSClient {
    private let configuration: OBSConfiguration
    private var apiClient: OBSAPIClientProtocol
    private var signer: OBSRequestSigner
    private let logger: OBSLogger

    /// Initializes a new OBS client with the specified configuration.
    /// - Parameters:
    ///   - configuration: The configuration object containing the endpoint, credentials, and other settings.
    ///   - apiClient: An optional custom API client for testing purposes. If `nil`, a default client will be created.
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
    ///
    /// This is useful when using temporary credentials (STS) that expire, allowing the client
    /// to continue making authenticated requests with a new set of credentials.
    /// - Parameter newCredentialsProvider: The new credentials provider, typically containing a new security token.
    public func refreshCredentials(with newCredentialsProvider: OBSCredentialsProvider) {
        self.signer = OBSRequestSigner(credentialsProvider: newCredentialsProvider)
        logger.info("Credentials refreshed successfully.")
    }
    
    /// Uploads an object to OBS from an in-memory `Data` buffer.
    ///
    /// - Parameter request: An `UploadObjectRequest` containing the bucket name, object key, data, and other optional parameters.
    /// - Throws: An `OBSError` if the request fails. This can be due to network issues (`.networkError`),
    ///   server-side errors (`.httpError`), invalid configuration (`.invalidURL`), or other issues.
    /// - Returns: An `UploadResponse` containing details about the successful upload, such as the ETag and version ID.
    public func uploadObject(request: UploadObjectRequest) async throws -> UploadResponse {
        var urlRequest = try buildBaseRequest(for: request)
        
        let signedRequest = try signer.sign(request: &urlRequest, for: request)

        if let contentLength = request.contentLength {
            urlRequest.setValue("\(contentLength)", forHTTPHeaderField: "Content-Length")
        } else {
            // If Content-Length is not provided, derive it from the Data buffer's count.
            urlRequest.setValue("\(request.data.count)", forHTTPHeaderField: "Content-Length")
        }

        let (responseData, httpResponse) = try await apiClient.perform(
            request: signedRequest,
            body:.data(request.data)
        )

        return try processUploadResponse(responseData: responseData, httpResponse: httpResponse)
    }

    /// Uploads an object to OBS from a local file.
    ///
    /// This method efficiently streams the file from disk, avoiding loading the entire file into memory.
    /// It also verifies the existence and readability of the file before starting the upload.
    ///
    /// - Parameter request: An `UploadFileRequest` containing the bucket name, object key, local file URL, and other optional parameters.
    /// - Throws: An `OBSError`. Specifically, it can throw `.fileAccessError` if the file at `fileURL`
    ///   cannot be read or its size cannot be determined. It can also throw other errors like `.networkError` or `.httpError`.
    /// - Returns: An `UploadResponse` containing details about the successful upload.
    public func uploadFile(request: UploadFileRequest) async throws -> UploadResponse {
        var urlRequest = try buildBaseRequest(for: request)
        
        let fileSize: NSNumber
        
        do {
            // Attempt to get file attributes. This step also validates the file's existence and read permissions.
            let attributes = try FileManager.default.attributesOfItem(atPath: request.fileURL.path)
            
            if let providedLength = request.contentLength {
                fileSize = NSNumber(value: providedLength)
            } else if let size = attributes[.size] as? NSNumber {
                fileSize = size
            } else {
                throw OBSError.fileAccessError(
                    path: request.fileURL.path,
                    underlyingError: NSError(domain: "OBSSDKError", code: -1, userInfo: nil)
                )
            }
        } catch {
            // Catch all errors from FileManager (e.g., file not found, no permissions).
            // Wrap the underlying system error into our public, unified OBSError type.
            throw OBSError.fileAccessError(path: request.fileURL.path, underlyingError: error)
        }

        let signedRequest = try signer.sign(request: &urlRequest, for: request)

        // Set the Content-Length header.
        urlRequest.setValue(fileSize.stringValue, forHTTPHeaderField: "Content-Length")

        let (responseData, httpResponse) = try await apiClient.perform(
            request: signedRequest,
            body:.file(request.fileURL)
        )

        return try processUploadResponse(responseData: responseData, httpResponse: httpResponse)
    }
    
    /// Builds a base `URLRequest` with common headers from a generic `UploadRequest`.
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

        let encodedKey = key.addingPercentEncoding(withAllowedCharacters:.urlPathAllowed) ?? key
        let urlString = "\(scheme)://\(bucket).\(configuration.endpoint)/\(encodedKey)"
        
        guard let url = URL(string: urlString) else {
            throw OBSError.invalidURL(urlString)
        }
        return url
    }

    private func processUploadResponse(responseData: Data, httpResponse: HTTPURLResponse) throws -> UploadResponse {
        // Determine if the request was successful based on the HTTP status code.
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OBSError.httpError(statusCode: httpResponse.statusCode, response: OBSErrorXMLParser.parse(from: responseData))
        }
        
        // If successful, extract information from the response headers to construct the UploadResponse.
        return UploadResponse(from: httpResponse)
    }
}