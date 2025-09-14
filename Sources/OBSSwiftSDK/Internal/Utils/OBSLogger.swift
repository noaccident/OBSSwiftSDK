public struct OBSLogger: Sendable {
    
    /// Defines the severity level of a log message.
    public enum Level: Int, Comparable, Sendable {
        /// Detailed information for debugging purposes.
        case debug = 0
        /// Informational messages that highlight the progress of the application.
        case info = 1
        /// Potentially harmful situations.
        case warning = 2
        /// Errors that might still allow the application to continue running.
        case error = 3
        
        case none = 4
        
        public static func < (lhs: OBSLogger.Level, rhs: OBSLogger.Level) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// The minimum level of messages to be logged. Messages with a lower severity will be ignored.
    let level: Level

    /// Initializes a new logger with a specified logging threshold.
    /// - Parameter level: The minimum level of messages to log.
    public init(level: Level = .none) {
        self.level = level
    }

    /// Logs a message at the debug level.
    /// - Parameter message: The message to log.
    public func debug(_ message: String) {
        log(level: .debug, message: message)
    }

    /// Logs a message at the info level.
    /// - Parameter message: The message to log.
    public func info(_ message: String) {
        log(level: .info, message: message)
    }
    
    /// Logs a message at the warning level.
    /// - Parameter message: The message to log.
    public func warning(_ message: String) {
        log(level: .warning, message: message)
    }
    
    /// Logs a message at the error level.
    /// - Parameter message: The message to log.
    public func error(_ message: String) {
        log(level: .error, message: message)
    }

    private func log(level messageLevel: Level, message: String) {
        // Only log messages that are at or above the configured threshold.
        if messageLevel >= self.level {
            // Using uppercased() for a cleaner log prefix.
            print("[OBS-\(String(describing: messageLevel).uppercased())] \(message)")
        }
    }
}
