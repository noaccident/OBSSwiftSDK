import Foundation

public final class OBSLogger {
    public enum Level: Int, Comparable {
        case none, error, info, debug
        
        public static func < (lhs: Level, rhs: Level) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    private let level: Level

    init(level: Level) {
        self.level = level
    }

    private func log(_ message: @autoclosure () -> String, level: Level, file: String = #file, function: String = #function, line: UInt = #line) {
        guard level <= self.level && level != .none else { return }
        let fileName = (file as NSString).lastPathComponent
        print("[\(level)][\(fileName):\(line)] \(function) - \(message())")
    }
    
    func debug(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        log(message(), level:.debug, file: file, function: function, line: line)
    }
    func info(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        log(message(), level:.info, file: file, function: function, line: line)
    }
    func error(_ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: UInt = #line) {
        log(message(), level:.error, file: file, function: function, line: line)
    }
}
