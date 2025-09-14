import Foundation

/// A thread-safe class responsible for managing and providing OBS credentials.
final class credentialsProvider {
    private var _credentials: OBSCredentialsProvider
    private let queue = DispatchQueue(label: "com.obsswiftsdk.credentialsProvider.queue")

    init(initialCredentials: OBSCredentialsProvider) {
        self._credentials = initialCredentials
    }

    /// Safely retrieves the current credentials.
    func get() -> OBSCredentialsProvider {
        queue.sync {
            _credentials
        }
    }

    /// Safely updates the credentials.
    func update(credentials: OBSCredentialsProvider) {
        queue.sync {
            self._credentials = credentials
        }
    }
}
