import Foundation

/// Configuration settings for the OBSClient.
public final class OBSConfiguration {
    /// The service endpoint (e.g., "https://obs.cn-north-4.myhuaweicloud.com").
    let endpoint: String
    /// The initial credentialsProvider to use for authentication.
    let credentialsProvider: OBSCredentialsProvider
    /// The maximum number of times to retry a failed request due to a transient error.
    let maxRetryCount: Int
    /// The minimum logging level for the SDK's internal logger.
    let logLevel: OBSLogger.Level
    let useSSL: Bool

    public init(
        endpoint: String,
        credentialsProvider: OBSCredentialsProvider,
        useSSL: Bool = true,
        maxRetryCount: Int = 3,
        logLevel: OBSLogger.Level = .none
    ) {
        self.endpoint = endpoint
        self.credentialsProvider = credentialsProvider
        self.useSSL = useSSL
        self.maxRetryCount = maxRetryCount
        self.logLevel = logLevel
    }
}