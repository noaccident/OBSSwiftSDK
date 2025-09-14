import Foundation

/// Pre-defined Access Control Lists (ACLs) for objects.
public enum ObjectACL: String {
    case `private` = "private"
    case publicRead = "public-read"
    case publicReadWrite = "public-read-write"
    case authenticatedRead = "authenticated-read"
    case bucketOwnerRead = "bucket-owner-read"
    case bucketOwnerFullControl = "bucket-owner-full-control"
}

/// Available storage classes for objects.
public enum StorageClass: String {
    case standard = "STANDARD"
    case warm = "WARM" // Infrequent Access
    case cold = "COLD" // Archive
}

/// Server-side encryption options.
public enum ServerSideEncryption {
    /// SSE-KMS: Encryption using a key managed by Huawei Cloud KMS.
    case sseKms(keyId: String? = nil)
    
    /// SSE-C: Encryption using a customer-provided key.
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