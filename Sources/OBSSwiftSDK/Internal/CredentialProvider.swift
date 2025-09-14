import Foundation

/// A thread-safe class responsible for managing and providing OBS credentials.
///
/// This class ensures that access and updates to the credentials are synchronized,
/// preventing race conditions in a multi-threaded environment. It uses a serial
/// `DispatchQueue` to serialize all read and write operations on the underlying
/// credentials property. This is particularly important when credentials can be
/// refreshed dynamically (e.g., temporary STS tokens).
final class CredentialsProvider {
    private var credentials: OBSCredentialsProvider
    private let queue = DispatchQueue(label: "com.obsswiftsdk.credentialsProvider.queue")

    init(initialCredentials: OBSCredentialsProvider) {
        self.credentials = initialCredentials
    }

    /// Safely retrieves the current credentials.
    ///
    /// This operation is performed synchronously on a serial queue to ensure thread safety.
    /// - Returns: The current `OBSCredentialsProvider` instance.
    func get() -> OBSCredentialsProvider {
        queue.sync {
            credentials
        }
    }

    /// Safely updates the credentials.
    ///
    /// This operation is performed synchronously on a serial queue to prevent concurrent modifications.
    /// - Parameter credentials: The new `OBSCredentialsProvider` instance to set.
    func update(credentials: OBSCredentialsProvider) {
        queue.sync {
            self.credentials = credentials
        }
    }
}