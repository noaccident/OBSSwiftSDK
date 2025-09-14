import Foundation
import CryptoKit

/// Internal component responsible for calculating OBS V1 request signatures.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
internal final class OBSRequestSigner {
    private let credentialsProvider: OBSCredentialsProvider


    private let subResources: Set<String> = [
        "acl", "append", "attname", "backtosource", "billing", "cors", "customdomain",
        "delete", "deletebucket", "encryption", "inventory", "length", "lifecycle",
        "location", "logging", "metadata", "modify", "notification", "partNumber",
        "policy", "position", "quota", "rename", "replication", "response-cache-control",
        "response-content-disposition", "response-content-encoding", "response-content-language",
        "response-content-type", "response-expires", "restore", "storageinfo", "storagepolicy",
        "tagging", "truncate", "uploads", "uploadId", "versionId", "versioning", "versions",
        "website", "x-image-process", "x-image-save-bucket", "x-image-save-object"
    ]

    init(credentialsProvider: OBSCredentialsProvider) {
        self.credentialsProvider = credentialsProvider
    }

    func sign(request: inout URLRequest, for uploadDetails: UploadRequest) throws -> URLRequest {
        let (accessKey, secretKey, securityToken) = credentialsProvider.getCredentials()

        // 1. Add required headers

        addHeaders(to: &request, for: uploadDetails, securityToken: securityToken)

        // 2. Build StringToSign
        let stringToSign = try buildStringToSign(for: request, uploadDetails: uploadDetails)
        
        // 3. Calculate Signature
        let signature = hmacSha1Base64(key: secretKey, data: stringToSign)

        // 4. Build and add Authorization header
        let authorizationHeader = "OBS \(accessKey):\(signature)"
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")

        return request
    }

    private func addHeaders(to request: inout URLRequest, for uploadDetails: UploadRequest, securityToken: String?) {
        // Add Date header
        if let existingDate = uploadDetails.date {
            request.setValue(Utilities.rfc1123DateFormatter.string(from: existingDate), forHTTPHeaderField: "Date")
        } else {
            request.setValue(Utilities.rfc1123DateFormatter.string(from: Date()), forHTTPHeaderField: "Date")
        }

        // Add Host header
        if let host = request.url?.host {
            request.setValue(host, forHTTPHeaderField: "Host")
        }

        // Add Content-Type header if provided
        if let contentType = uploadDetails.contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

         // Add Content-MD5 header if provided
        if let contentMD5 = uploadDetails.contentMD5 {
            request.setValue(contentMD5, forHTTPHeaderField: "Content-MD5")
        }
        
        // Add security token if present
        if let token = securityToken {
            request.setValue(token, forHTTPHeaderField: "x-obs-security-token")
        }
        
        // Add any additional headers from uploadDetails

        if let acl = uploadDetails.acl {
            request.setValue(acl.rawValue, forHTTPHeaderField: "x-obs-acl")
        }

        if let storageClass = uploadDetails.storageClass {
            request.setValue(storageClass.rawValue, forHTTPHeaderField: "x-obs-storage-class")
        }

        if let metadata = uploadDetails.metadata {
            for (key, value) in metadata {
                request.setValue(value, forHTTPHeaderField: "x-obs-meta-\(key)")
            }
        }

        if let encryption = uploadDetails.serverSideEncryption {
            encryption.apply(to: &request)
        }       
    }

    private func buildStringToSign(for request: URLRequest, uploadDetails: UploadRequest) throws -> String {
        let httpVerb = request.httpMethod ?? ""
        let contentMD5 = request.value(forHTTPHeaderField: "Content-MD5") ?? ""
        let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
        let date = request.value(forHTTPHeaderField: "Date") ?? ""

        let canonicalizedHeaders = buildCanonicalizedHeaders(from: request)
        let canonicalizedResource = try buildCanonicalizedResource(
            for: uploadDetails.bucketName,
            objectKey: uploadDetails.objectKey,
            from: request.url
        )

        let stringToSign = """
        \(httpVerb)
        \(contentMD5)
        \(contentType)
        \(date)
        \(canonicalizedHeaders)\(canonicalizedResource)
        """

        return stringToSign
    }

    private func buildCanonicalizedHeaders(from request: URLRequest) -> String {
        guard let allHeaders = request.allHTTPHeaderFields else { return "" }

        let obsHeaders = allHeaders
            .filter { $0.key.lowercased().hasPrefix("x-obs-") }
            .map { (key: $0.key.lowercased(), value: $0.value.trimmingCharacters(in:.whitespacesAndNewlines)) }
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "\n")
        
        if obsHeaders.isEmpty {
            return ""
        }

        return obsHeaders + "\n"
    }

    private func buildCanonicalizedResource(for bucketName: String, objectKey: String, from url: URL?) throws -> String {

        guard let url = url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw OBSError.invalidURL("Cannot parse URL components for signing.")
        }
        
        var resourcePath = "/\(bucketName)/\(objectKey)"
        
        if let queryItems = components.queryItems {
            let signedQueryItems = queryItems
                .filter { subResources.contains($0.name) }
                .sorted { $0.name < $1.name }
            if !signedQueryItems.isEmpty {
                let queryString = signedQueryItems.map { item in
                    if let value = item.value {
                        return "\(item.name)=\(value)"
                    }
                    return item.name
                }.joined(separator: "&")
                resourcePath += "?\(queryString)"
            }
        }
        
        return resourcePath
    }

    private func hmacSha1Base64(key: String, data: String) -> String {
        guard let keyData = key.data(using:.utf8), let dataToSign = data.data(using:.utf8) else {
            return ""
        }
        let symmetricKey = SymmetricKey(data: keyData)
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: dataToSign, using: symmetricKey)
        return Data(signature).base64EncodedString()
    }
}

fileprivate extension OBSCredentialsProvider {
    func getCredentials() -> (accessKey: String, secretKey: String, securityToken: String?) {
        switch self {
        case .permanent(let accessKey, let secretKey):
            return (accessKey, secretKey, nil)
        case .temporary(let accessKey, let secretKey, let securityToken):
            return (accessKey, secretKey, securityToken)
        }
    }
}
