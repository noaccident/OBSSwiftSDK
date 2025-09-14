import Foundation

/// Represents the credentials used for authenticating with OBS.
public enum OBSCredentialsProvider: Sendable {
    /// Permanent Access Key ID and Secret Access Key.
    case permanent(accessKey: String, secretKey: String)
    
    /// Temporary credentials including an Access Key ID, Secret Access Key, and a Security Token.
    /// Typically obtained from a Security Token Service (STS).
    case temporary(accessKey: String, secretKey: String, securityToken: String)
    
    /// The Access Key ID.
    var accessKey: String {
        switch self {
        case.permanent(let accessKey, _),.temporary(let accessKey, _, _):
            return accessKey
        }
    }
    
    /// The Secret Access Key.
    var secretKey: String {
        switch self {
        case.permanent(_, let secretKey),.temporary(_, let secretKey, _):
            return secretKey
        }
    }
    
    /// The security token, which is only present for temporary credentials.
    var securityToken: String? {
        switch self {
        case.permanent:
            return nil
        case.temporary(_, _, let securityToken):
            return securityToken
        }
    }
}