import Foundation
import CryptoKit

/// An internal component responsible for calculating OBS V1 request signatures.
///
/// This class implements the OBS V1 Canonical Request Signing Process. It constructs a
/// "StringToSign" by combining the HTTP verb, content headers, canonicalized OBS headers,
/// and a canonicalized resource path. This string is then signed with the secret key
/// using HMAC-SHA1, and the resulting signature is added to the request's
/// `Authorization` header.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
internal final class OBSRequestSigner {
    private let credentialsProvider: OBSCredentialsProvider

    /// A set of OBS sub-resources that must be included in the canonicalized resource
    /// string for signature calculation. For the authoritative list, refer to the official
    /// OBS API documentation.
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

    /// Signs the given URLRequest according to the OBS V1 signature specification.
    /// - Parameters:
    ///   - request: The `URLRequest` to be signed. This is an `inout` parameter and will be modified.
    ///   - uploadDetails: An `UploadRequest` object containing details needed for signing.
    /// - Returns: The signed `URLRequest`.
    /// - Throws: An `OBSError` if the URL is invalid or cannot be parsed.
    func sign(request: inout URLRequest, for uploadDetails: UploadRequest) throws -> URLRequest {
        let (accessKey, secretKey, securityToken) = credentialsProvider.getCredentials()

        // 1. Add required and optional headers to the request.
        addHeaders(to: &request, for: uploadDetails, securityToken: securityToken)

        // 2. Build the canonical string that will be signed.
        let stringToSign = try buildStringToSign(for: request, uploadDetails: uploadDetails)
        
        // 3. Calculate the HMAC-SHA1 signature and Base64-encode it.
        let signature = hmacSha1Base64(key: secretKey, data: stringToSign)

        // 4. Construct and add the final Authorization header.
        let authorizationHeader = "OBS \(accessKey):\(signature)"
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")

        return request
    }

    private func addHeaders(to request: inout URLRequest, for uploadDetails: UploadRequest, securityToken: String?) {
        // Add Date header.
        let date = uploadDetails.date ?? Date()
        request.setValue(Utilities.rfc1123DateFormatter.string(from: date), forHTTPHeaderField: "Date")

        // Add Host header.
        if let host = request.url?.host {
            request.setValue(host, forHTTPHeaderField: "Host")
        }

        // Add Content-Type header if provided.
        if let contentType = uploadDetails.contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

         // Add Content-MD5 header if provided.
        if let contentMD5 = uploadDetails.contentMD5 {
            request.setValue(contentMD5, forHTTPHeaderField: "Content-MD5")
        }
        
        // Add security token if present (for temporary credentials).
        if let token = securityToken {
            request.setValue(token, forHTTPHeaderField: "x-obs-security-token")
        }
        
        // Add any additional OBS-specific headers from uploadDetails.
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

    /// Constructs the string to be signed according to OBS V1 specification.
    /// The format is:
    ///
    /// HTTP-Verb + "\n" +
    /// Content-MD5 + "\n" +
    /// Content-Type + "\n" +
    /// Date + "\n" +
    /// CanonicalizedHeaders +
    /// CanonicalizedResource
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

    /// Creates the CanonicalizedHeaders string.
    /// This involves selecting headers starting with "x-obs-", converting keys to lowercase,
    /// trimming values, sorting them alphabetically by key, and joining them with newlines.
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

    /// Creates the CanonicalizedResource string.
    /// This consists of the bucket and object path, followed by a '?' and any
    /// recognized sub-resources from the query string, sorted alphabetically by name.
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

    /// Computes the HMAC-SHA1 signature for the given data and returns it as a Base64 encoded string.
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
        case.permanent(let accessKey, let secretKey):
            return (accessKey, secretKey, nil)
        case.temporary(let accessKey, let secretKey, let securityToken):
            return (accessKey, secretKey, securityToken)
        }
    }
}