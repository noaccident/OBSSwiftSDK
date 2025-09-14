import Foundation

/// A protocol defining the common properties for all upload-related requests.
public protocol UploadRequest {
    /// The date of the request. If not provided, the current date will be used for signing.
    var date: Date? { get }
    /// The name of the target bucket.
    var bucketName: String { get }
    /// The key (i.e., the name) of the object in the bucket.
    var objectKey: String { get }
    /// The MIME type of the object. Defaults to "application/octet-stream" if not specified.
    var contentType: String? { get }
    /// The access control list (ACL) to apply to the object.
    var acl: ObjectACL? { get }
    /// The storage class for the object.
    var storageClass: StorageClass? { get }
    /// The base64-encoded 128-bit MD5 digest of the object content.
    var contentMD5: String? { get }
    /// The size of the object content in bytes. If not provided, it will be inferred from the data or file.
    var contentLength: Int64? { get }
    /// A dictionary of user-defined metadata to store with the object.
    var metadata: [String: String]? { get }
    /// The server-side encryption settings for the object.
    var serverSideEncryption: ServerSideEncryption? { get }
}

/// Parameters for uploading an object from an in-memory `Data` buffer.
public final class UploadObjectRequest: UploadRequest {
    public let date: Date?
    public let bucketName: String
    public let objectKey: String
    /// The raw data of the object to upload.
    public let data: Data
    public let contentType: String?
    public let acl: ObjectACL?
    public let storageClass: StorageClass?
    public let contentMD5: String?
    public let contentLength: Int64?
    public let metadata: [String: String]?
    public let serverSideEncryption: ServerSideEncryption?

    /// Initializes a new request to upload data from memory.
    /// - Parameters:
    ///   - bucketName: The name of the target bucket.
    ///   - objectKey: The key (name) of the object.
    ///   - data: The object's content as a `Data` buffer.
    ///   - contentType: The MIME type of the object.
    ///   - acl: The access control list (ACL) for the object.
    ///   - storageClass: The storage class for the object.
    ///   - contentMD5: The base64-encoded MD5 hash of the data.
    ///   - contentLength: The size of the data in bytes.
    ///   - metadata: User-defined metadata.
    ///   - serverSideEncryption: Server-side encryption settings.
    ///   - date: The timestamp for the request signature.
    public init(
        bucketName: String,
        objectKey: String,
        data: Data,
        contentType: String? = nil,
        acl: ObjectACL? = nil,
        storageClass: StorageClass? = nil,
        contentMD5: String? = nil,
        contentLength: Int64? = nil,
        metadata: [String: String]? = nil,
        serverSideEncryption: ServerSideEncryption? = nil,
        date: Date? = nil
    ) {
        self.date = date
        self.bucketName = bucketName
        self.objectKey = objectKey
        self.data = data
        self.contentType = contentType
        self.acl = acl
        self.storageClass = storageClass
        self.contentMD5 = contentMD5
        self.contentLength = contentLength
        self.metadata = metadata
        self.serverSideEncryption = serverSideEncryption
    }
}

/// Parameters for uploading an object from a local file.
public final class UploadFileRequest: UploadRequest {
    public var date: Date?
    public let bucketName: String
    public let objectKey: String
    /// The URL of the local file to upload.
    public let fileURL: URL
    public let contentType: String?
    public let acl: ObjectACL?
    public let storageClass: StorageClass?
    public let contentMD5: String?
    public let contentLength: Int64?
    public let metadata: [String: String]?
    public let serverSideEncryption: ServerSideEncryption?

    /// Initializes a new request to upload data from a local file.
    /// - Parameters:
    ///   - bucketName: The name of the target bucket.
    ///   - objectKey: The key (name) of the object.
    ///   - fileURL: The URL pointing to the local file.
    ///   - contentType: The MIME type of the object.
    ///   - acl: The access control list (ACL) for the object.
    ///   - storageClass: The storage class for the object.
    ///   - contentMD5: The base64-encoded MD5 hash of the file content.
    ///   - contentLength: The size of the file in bytes.
    ///   - metadata: User-defined metadata.
    ///   - serverSideEncryption: Server-side encryption settings.
    public init(
        bucketName: String,
        objectKey: String,
        fileURL: URL,
        contentType: String? = nil,
        acl: ObjectACL? = nil,
        storageClass: StorageClass? = nil,
        contentMD5: String? = nil,
        contentLength: Int64? = nil,
        metadata: [String: String]? = nil,
        serverSideEncryption: ServerSideEncryption? = nil
    ) {
        self.bucketName = bucketName
        self.objectKey = objectKey
        self.fileURL = fileURL
        self.contentType = contentType
        self.acl = acl
        self.storageClass = storageClass
        self.contentMD5 = contentMD5
        self.contentLength = contentLength
        self.metadata = metadata
        self.serverSideEncryption = serverSideEncryption
    }
}