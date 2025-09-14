import Foundation

/// Configuration settings for the `OBSClient`.
public final class OBSConfiguration {
    /// The service endpoint (e.g., "obs.cn-north-4.myhuaweicloud.com").
    let endpoint: String
    /// The credentials provider to use for authenticating requests.
    let credentialsProvider: OBSCredentialsProvider
    /// The maximum number of times to retry a failed request due to a transient error.
    let maxRetryCount: Int
    /// The minimum logging level for the SDK's internal logger.
    let logLevel: OBSLogger.Level
    /// A boolean indicating whether to use SSL (HTTPS) for requests.
    let useSSL: Bool

    /// Initializes a new configuration object.
    /// - Parameters:
    ///   - endpoint: The service endpoint.
    ///   - credentialsProvider: The initial credentials provider for authentication.
    ///   - useSSL: Specifies whether to use HTTPS (`true`) or HTTP (`false`). Defaults to `true`.
    ///   - maxRetryCount: The maximum number of retry attempts for failed requests. Defaults to 3.
    ///   - logLevel: The minimum level of messages to be logged by the SDK.
    public init(
        endpoint: String,
        credentialsProvider: OBSCredentialsProvider,
        useSSL: Bool = true,
        maxRetryCount: Int = 3,
        logLevel: OBSLogger.Level
    ) {
        self.endpoint = endpoint
        self.credentialsProvider = credentialsProvider
        self.useSSL = useSSL
        self.maxRetryCount = maxRetryCount
        self.logLevel = logLevel
    }
}