//
//  Logger.swift
//  Mixboard
//
//  Created by Raghavasimhan Sankaranarayanan on 12/7/22.
//

import Foundation

// Adapted from: https://youtu.be/Ao6jkaV_9Kc
class Logger {
    static private var buffer = LinkedList(capacity: 1000)
    static var logLevel: Level = .trace
    static private let df = DateFormatter()
    
    enum Level: Int {
        case trace = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
        case critical = 5
        
        fileprivate var prefix: String {
            switch self {
            case .trace: return "TRACE"
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            case .critical: return "CRITICAL"
            }
        }
    }
    
    struct Context: CustomStringConvertible {
        let file: String
        let function: String
        let line: Int
        let date: Date
        var description: String {
            df.dateFormat = "y-MM-dd H:mm:ss.SSSS"
            let logDate = df.string(from: date)
            
            return "\(logDate) | \((file as NSString).lastPathComponent.split(separator: ".")[0]):\(line):\(function)"
        }
    }
    
    struct Log: CustomStringConvertible {
        let level: Level
        let context: Context
        var message: Any?
        
        var description: String {
            return "[\(level.prefix)] | \(context) | \(message ?? "")"
        }
    }
    
    private static func handle(level: Level, str: Any?, context: Context) {
        let msg = Log(level: level, context: context, message: str)
        buffer.append(data: msg)
#if DEBUG
        print(msg)
#endif
    }
    
    static func clearBuffer() {
        buffer.clear()
    }
    
    static func getLogs(shouldClear: Bool = true) -> [String] {
        let temp = buffer.getDataAsStringList()
        if shouldClear { clearBuffer() }
        return temp
    }
    
    static func trace(_ msg: Any?, file: String = #fileID, fn: String = #function, line: Int = #line, date: Date = .now) {
        if logLevel.rawValue <= Level.trace.rawValue {
            handle(level: .trace, str: msg, context: Context(file: file, function: fn, line: line, date: date))
        }
    }
    
    static func debug(_ msg: Any?, file: String = #fileID, fn: String = #function, line: Int = #line, date: Date = .now) {
        if logLevel.rawValue <= Level.debug.rawValue {
            handle(level: .debug, str: msg, context: Context(file: file, function: fn, line: line, date: date))
        }
    }
    
    static func info(_ msg: Any?, file: String = #fileID, fn: String = #function, line: Int = #line, date: Date = .now) {
        if logLevel.rawValue <= Level.info.rawValue {
            handle(level: .info, str: msg, context: Context(file: file, function: fn, line: line, date: date))
        }
    }
    
    static func warn(_ msg: Any?, file: String = #fileID, fn: String = #function, line: Int = #line, date: Date = .now) {
        if logLevel.rawValue <= Level.warning.rawValue {
            handle(level: .warning, str: msg, context: Context(file: file, function: fn, line: line, date: date))
        }
    }
    
    static func error(_ msg: Any?, file: String = #fileID, fn: String = #function, line: Int = #line, date: Date = .now) {
        if logLevel.rawValue <= Level.error.rawValue {
            handle(level: .error, str: msg, context: Context(file: file, function: fn, line: line, date: date))
        }
    }
    
    static func critical(_ msg: Any?, file: String = #fileID, fn: String = #function, line: Int = #line, date: Date = .now) {
        if logLevel.rawValue <= Level.critical.rawValue {
            handle(level: .critical, str: msg, context: Context(file: file, function: fn, line: line, date: date))
        }
    }
}
