import Foundation

/// Pre-defined Access Control Lists (ACLs) for objects.
public enum ObjectACL: String {
    /// Owner gets FULL_CONTROL. No one else has access rights (default).
    case `private` = "private"
    /// Owner gets FULL_CONTROL. The AllUsers group gets READ access.
    case publicRead = "public-read"
    /// Owner gets FULL_CONTROL. The AllUsers group gets READ and WRITE access.
    case publicReadWrite = "public-read-write"
    /// Owner gets FULL_CONTROL. The AuthenticatedUsers group gets READ access.
    case authenticatedRead = "authenticated-read"
    /// Owner gets FULL_CONTROL. The bucket owner gets READ access.
    case bucketOwnerRead = "bucket-owner-read"
    /// Owner gets FULL_CONTROL. The bucket owner gets FULL_CONTROL.
    case bucketOwnerFullControl = "bucket-owner-full-control"
}

/// Available storage classes for objects in OBS.
public enum StorageClass: String {
    /// Default storage class. Suitable for frequently accessed data.
    case standard = "STANDARD"
    /// Suitable for infrequently accessed data that requires rapid retrieval. Corresponds to OBS Infrequent Access storage class.
    case warm = "WARM"
    /// Suitable for long-term archival data that is rarely accessed. Corresponds to OBS Archive storage class.
    case cold = "COLD"
}

/// Server-side encryption options for an object.
public enum ServerSideEncryption {
    /// SSE-KMS: Encryption using a key managed by Huawei Cloud Key Management Service (KMS).
    /// - Parameter keyId: The ID of the KMS key to use. If nil, the default KMS key is used.
    case sseKms(keyId: String? = nil)
    
    /// SSE-C: Encryption using a customer-provided key. The key is sent with the request.
    /// - Parameter customerKey: The raw data of the AES-256 encryption key.
    case sseC(customerKey: Data)
    
    internal func apply(to request: inout URLRequest) {
        switch self {
        case.sseKms(let keyId):
            request.setValue("kms", forHTTPHeaderField: "x-obs-server-side-encryption")
            if let key = keyId {
                request.setValue(key, forHTTPHeaderField: "x-obs-server-side-encryption-kms-key-id")
            }
        case.sseC(let customerKey):
            let keyBase64 = customerKey.base64EncodedString()
            let keyMd5Base64 = Utilities.md5Base64(for: customerKey)
            request.setValue("AES256", forHTTPHeaderField: "x-obs-server-side-encryption-customer-algorithm")
            request.setValue(keyBase64, forHTTPHeaderField: "x-obs-server-side-encryption-customer-key")
            request.setValue(keyMd5Base64, forHTTPHeaderField: "x-obs-server-side-encryption-customer-key-md5")
        }
    }
}