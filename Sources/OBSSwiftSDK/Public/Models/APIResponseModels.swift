import Foundation

/// The successful response from an upload operation.
public struct UploadResponse: Sendable {
    /// The ETag of the object, used for integrity checks.
    public let eTag: String?
    /// The version ID of the object, if the bucket has versioning enabled.
    public let versionId: String?
    /// The storage class of the uploaded object.
    public let storageClass: String?
    /// The server-side encryption algorithm used, if any.
    public let serverSideEncryption: String?
    public let statusCode: Int
    
    internal init(from response: HTTPURLResponse) {
        self.eTag = response.value(forHTTPHeaderField: "ETag")?.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        self.versionId = response.value(forHTTPHeaderField: "x-obs-version-id")
        self.storageClass = response.value(forHTTPHeaderField: "x-obs-storage-class")
        self.serverSideEncryption = response.value(forHTTPHeaderField: "x-obs-server-side-encryption")
        self.statusCode = response.statusCode
    }
}
