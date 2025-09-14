import Foundation

public protocol UploadRequest {
    var date: Date? { get }
    var bucketName: String { get }
    var objectKey: String { get }
    var contentType: String? { get }
    var acl: ObjectACL? { get }
    var storageClass: StorageClass? { get }
    var contentMD5: String? { get }
    var contentLength: Int64? { get }
    var metadata: [String: String]? { get }
    var serverSideEncryption: ServerSideEncryption? { get }
}

/// Parameters for uploading an object from an in-memory Data buffer.
public final class UploadObjectRequest: UploadRequest {
    public let date: Date?
    public let bucketName: String
    public let objectKey: String
    public let data: Data
    public let contentType: String?
    public let acl: ObjectACL?
    public let storageClass: StorageClass?
    public let contentMD5: String?
    public let contentLength: Int64?
    public let metadata: [String: String]?
    public let serverSideEncryption: ServerSideEncryption?

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
    public let fileURL: URL
    public let contentType: String?
    public let acl: ObjectACL?
    public let storageClass: StorageClass?
    public let contentMD5: String?
    public let contentLength: Int64?
    public let metadata: [String: String]?
    public let serverSideEncryption: ServerSideEncryption?

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
