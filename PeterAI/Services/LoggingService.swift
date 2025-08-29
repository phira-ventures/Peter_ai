import Foundation
import os.log

class LoggingService: ObservableObject {
    static let shared = LoggingService()
    
    // Specialized loggers for different aspects
    private let mainLogger = Logger(subsystem: "com.phira.peterai", category: "Main")
    private let voiceLogger = Logger(subsystem: "com.phira.peterai", category: "Voice")
    private let accessibilityLogger = Logger(subsystem: "com.phira.peterai", category: "Accessibility")
    private let subscriptionLogger = Logger(subsystem: "com.phira.peterai", category: "Subscription")
    private let supportLogger = Logger(subsystem: "com.phira.peterai", category: "CustomerSupport")
    
    // File logging for customer support
    private let fileLogger = FileLogger()
    private let secureStorage = SecureStorage.shared
    
    // Log levels for different contexts
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"  
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        case support = "SUPPORT" // Special level for customer support logs
    }
    
    // Categories for organizing logs
    enum LogCategory: String, CaseIterable {
        case userInteraction = "USER_INTERACTION"
        case voiceProcessing = "VOICE_PROCESSING"
        case accessibility = "ACCESSIBILITY"
        case subscription = "SUBSCRIPTION"
        case error = "ERROR"
        case performance = "PERFORMANCE"
        case security = "SECURITY"
        case customerSupport = "CUSTOMER_SUPPORT"
        case elderlyUserIssue = "ELDERLY_USER_ISSUE"
    }
    
    private init() {
        setupLogging()
    }
    
    // MARK: - Setup
    
    private func setupLogging() {
        // Initialize file logging
        fileLogger.initialize()
        
        // Log service startup
        log(.info, category: .userInteraction, message: "PeterAI Logging Service initialized", context: [:])
    }
    
    // MARK: - Main Logging Interface
    
    func log(_ level: LogLevel, category: LogCategory, message: String, context: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        
        let timestamp = Date()
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let fullMessage = "[\(fileName):\(line)] \(function) - \(message)"
        
        // Log to appropriate system logger
        logToSystemLogger(level, category: category, message: fullMessage, context: context)
        
        // Always log to file for customer support
        logToFile(level, category: category, message: fullMessage, context: context, timestamp: timestamp)
        
        // Special handling for customer support and elderly user issues
        if category == .customerSupport || category == .elderlyUserIssue || level == .support {
            logToCustomerSupportSystem(level, category: category, message: fullMessage, context: context, timestamp: timestamp)
        }
        
        // Critical errors need immediate attention
        if level == .critical {
            handleCriticalError(message: fullMessage, context: context, category: category)
        }
    }
    
    // MARK: - System Logger Integration
    
    private func logToSystemLogger(_ level: LogLevel, category: LogCategory, message: String, context: [String: Any]) {
        let logger = getSystemLogger(for: category)
        let contextString = formatContext(context)
        let fullMessage = contextString.isEmpty ? message : "\(message) | Context: \(contextString)"
        
        switch level {
        case .debug:
            logger.debug("\(fullMessage)")
        case .info:
            logger.info("\(fullMessage)")
        case .warning:
            logger.warning("\(fullMessage)")
        case .error, .critical, .support:
            logger.error("\(fullMessage)")
        }
    }
    
    private func getSystemLogger(for category: LogCategory) -> Logger {
        switch category {
        case .voiceProcessing:
            return voiceLogger
        case .accessibility:
            return accessibilityLogger
        case .subscription:
            return subscriptionLogger
        case .customerSupport, .elderlyUserIssue:
            return supportLogger
        default:
            return mainLogger
        }
    }
    
    // MARK: - File Logging for Customer Support
    
    private func logToFile(_ level: LogLevel, category: LogCategory, message: String, context: [String: Any], timestamp: Date) {
        let logEntry = LogEntry(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message,
            context: context
        )
        
        fileLogger.writeLog(logEntry)
    }
    
    // MARK: - Customer Support Specific Logging
    
    private func logToCustomerSupportSystem(_ level: LogLevel, category: LogCategory, message: String, context: [String: Any], timestamp: Date) {
        let supportEntry = CustomerSupportLogEntry(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message,
            context: context,
            userType: "elderly",
            sessionId: getCurrentSessionId(),
            deviceInfo: getCurrentDeviceInfo()
        )
        
        // Store securely for customer support access
        storeCustomerSupportLog(supportEntry)
        
        // If it's a critical elderly user issue, create a support ticket
        if level == .critical && category == .elderlyUserIssue {
            createSupportTicket(supportEntry)
        }
    }
    
    // MARK: - Elderly User Specific Logging
    
    func logElderlyUserInteraction(_ interaction: String, success: Bool, duration: TimeInterval? = nil, context: [String: Any] = [:]) {
        var logContext = context
        logContext["success"] = success
        if let duration = duration {
            logContext["duration_seconds"] = duration
        }
        logContext["user_type"] = "elderly"
        
        let level: LogLevel = success ? .info : .warning
        log(level, category: .elderlyUserIssue, message: "Elderly user interaction: \(interaction)", context: logContext)
    }
    
    func logAccessibilityFeatureUsage(_ feature: String, effectiveForUser: Bool, context: [String: Any] = [:]) {
        var logContext = context
        logContext["effective"] = effectiveForUser
        logContext["feature"] = feature
        
        log(.info, category: .accessibility, message: "Accessibility feature used: \(feature)", context: logContext)
    }
    
    func logVoiceInteractionIssue(_ issue: String, severity: String, context: [String: Any] = [:]) {
        var logContext = context
        logContext["severity"] = severity
        logContext["user_type"] = "elderly"
        
        let level: LogLevel = severity == "critical" ? .critical : (severity == "high" ? .error : .warning)
        log(level, category: .voiceProcessing, message: "Voice interaction issue: \(issue)", context: logContext)
    }
    
    func logElderlyUserConfusion(_ scenario: String, context: [String: Any] = [:]) {
        var logContext = context
        logContext["user_type"] = "elderly"
        logContext["requires_support_attention"] = true
        
        log(.support, category: .elderlyUserIssue, message: "Elderly user confusion detected: \(scenario)", context: logContext)
    }
    
    func logSubscriptionIssueForElderly(_ issue: String, context: [String: Any] = [:]) {
        var logContext = context
        logContext["user_type"] = "elderly"
        logContext["priority"] = "high" // Elderly subscription issues get high priority
        
        log(.error, category: .subscription, message: "Elderly user subscription issue: \(issue)", context: logContext)
    }
    
    // MARK: - Performance Logging
    
    func logPerformanceIssue(_ operation: String, duration: TimeInterval, expectedDuration: TimeInterval, context: [String: Any] = [:]) {
        var logContext = context
        logContext["operation"] = operation
        logContext["actual_duration"] = duration
        logContext["expected_duration"] = expectedDuration
        logContext["slowdown_factor"] = duration / expectedDuration
        
        let level: LogLevel = duration > (expectedDuration * 3) ? .error : .warning
        log(level, category: .performance, message: "Slow operation detected: \(operation)", context: logContext)
    }
    
    // MARK: - Security Logging
    
    func logSecurityEvent(_ event: String, severity: String, context: [String: Any] = [:]) {
        var logContext = context
        logContext["security_event"] = true
        logContext["severity"] = severity
        
        let level: LogLevel = severity == "critical" ? .critical : .error
        log(level, category: .security, message: "Security event: \(event)", context: logContext)
    }
    
    // MARK: - Customer Support Ticket Creation
    
    private func createSupportTicket(_ logEntry: CustomerSupportLogEntry) {
        let ticket = SupportTicket(
            ticketId: UUID().uuidString,
            timestamp: logEntry.timestamp,
            severity: logEntry.level == .critical ? .critical : .high,
            category: .elderlyUserIssue,
            title: "Critical elderly user issue detected",
            description: logEntry.message,
            context: logEntry.context,
            deviceInfo: logEntry.deviceInfo,
            sessionId: logEntry.sessionId
        )
        
        storeSupportTicket(ticket)
        
        // In production, this would also:
        // - Send to support team via email/Slack
        // - Create ticket in support system (Zendesk, etc.)
        // - Trigger emergency response if needed
        
        supportLogger.critical("SUPPORT TICKET CREATED: \(ticket.ticketId) - \(ticket.title)")
    }
    
    // MARK: - Log Retrieval for Customer Support
    
    func getCustomerSupportLogs(since: Date, category: LogCategory? = nil) -> [CustomerSupportLogEntry] {
        return fileLogger.getCustomerSupportLogs(since: since, category: category)
    }
    
    func exportLogsForSupport(sessionId: String? = nil) -> Data? {
        let logs = sessionId != nil ? 
            fileLogger.getLogsForSession(sessionId!) :
            fileLogger.getRecentLogs(hours: 24)
        
        return try? JSONEncoder().encode(logs)
    }
    
    func generateSupportReport() -> SupportReport {
        let recentLogs = fileLogger.getRecentLogs(hours: 24)
        let errors = recentLogs.filter { $0.level == .error || $0.level == .critical }
        let elderlyIssues = recentLogs.filter { $0.category == .elderlyUserIssue }
        let performanceIssues = recentLogs.filter { $0.category == .performance }
        
        return SupportReport(
            timestamp: Date(),
            sessionId: getCurrentSessionId(),
            totalLogs: recentLogs.count,
            errorCount: errors.count,
            elderlyUserIssues: elderlyIssues.count,
            performanceIssues: performanceIssues.count,
            topIssues: getTopIssues(from: recentLogs),
            deviceInfo: getCurrentDeviceInfo(),
            appVersion: getAppVersion()
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatContext(_ context: [String: Any]) -> String {
        guard !context.isEmpty else { return "" }
        
        let contextPairs = context.map { key, value in
            "\(key)=\(value)"
        }
        return contextPairs.joined(separator: ", ")
    }
    
    private func handleCriticalError(message: String, context: [String: Any], category: LogCategory) {
        // Critical errors need immediate attention
        supportLogger.critical("CRITICAL ERROR: \(message)")
        
        // Store for immediate review
        let criticalError = CriticalError(
            timestamp: Date(),
            message: message,
            context: context,
            category: category,
            sessionId: getCurrentSessionId(),
            deviceInfo: getCurrentDeviceInfo()
        )
        
        storeCriticalError(criticalError)
        
        // Notify monitoring service
        MonitoringService.shared.trackElderlyUserInteraction(
            .errorEncountered(
                ElderlyUserError(
                    type: .performanceIssue,
                    severity: .critical,
                    description: message,
                    context: formatContext(context),
                    timestamp: Date(),
                    affectedFeature: category.rawValue
                )
            )
        )
    }
    
    private func getCurrentSessionId() -> String {
        // Get or generate session ID
        if let sessionId = UserDefaults.standard.string(forKey: "current_session_id") {
            return sessionId
        } else {
            let newSessionId = UUID().uuidString
            UserDefaults.standard.set(newSessionId, forKey: "current_session_id")
            return newSessionId
        }
    }
    
    private func getCurrentDeviceInfo() -> [String: Any] {
        let device = UIDevice.current
        return [
            "model": device.model,
            "system_version": device.systemVersion,
            "system_name": device.systemName,
            "app_version": getAppVersion()
        ]
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getTopIssues(from logs: [LogEntry]) -> [String] {
        let errorLogs = logs.filter { $0.level == .error || $0.level == .critical }
        var issueCounts: [String: Int] = [:]
        
        for log in errorLogs {
            let key = log.message.components(separatedBy: ":").first ?? log.message
            issueCounts[key, default: 0] += 1
        }
        
        return issueCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { "\($0.key) (×\($0.value))" }
    }
    
    // MARK: - Storage Methods
    
    private func storeCustomerSupportLog(_ entry: CustomerSupportLogEntry) {
        if let data = try? JSONEncoder().encode(entry) {
            let key = "support_log_\(Int(entry.timestamp.timeIntervalSince1970))"
            _ = secureStorage.store(key: key, value: data.base64EncodedString())
        }
    }
    
    private func storeSupportTicket(_ ticket: SupportTicket) {
        if let data = try? JSONEncoder().encode(ticket) {
            let key = "support_ticket_\(ticket.ticketId)"
            _ = secureStorage.store(key: key, value: data.base64EncodedString())
        }
    }
    
    private func storeCriticalError(_ error: CriticalError) {
        if let data = try? JSONEncoder().encode(error) {
            let key = "critical_error_\(Int(error.timestamp.timeIntervalSince1970))"
            _ = secureStorage.store(key: key, value: data.base64EncodedString())
        }
    }
}

// MARK: - File Logger Class

private class FileLogger {
    private let logDirectory: URL
    private let maxLogFileSize: Int = 1024 * 1024 * 5 // 5MB
    private let maxLogFiles: Int = 10
    private var currentLogFile: URL?
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logDirectory = documentsPath.appendingPathComponent("Logs")
    }
    
    func initialize() {
        createLogDirectory()
        createNewLogFileIfNeeded()
    }
    
    private func createLogDirectory() {
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }
    
    private func createNewLogFileIfNeeded() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "peterai_\(dateFormatter.string(from: Date())).log"
        currentLogFile = logDirectory.appendingPathComponent(filename)
        
        // Clean up old log files
        cleanupOldLogFiles()
    }
    
    func writeLog(_ entry: LogEntry) {
        guard let logFile = currentLogFile else { return }
        
        let logLine = formatLogEntry(entry)
        
        if let data = (logLine + "\n").data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
            
            // Check if we need a new log file
            checkLogFileSize()
        }
    }
    
    private func formatLogEntry(_ entry: LogEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = formatter.string(from: entry.timestamp)
        
        let contextString = entry.context.isEmpty ? "" : " | Context: \(formatContext(entry.context))"
        return "[\(timestamp)] [\(entry.level.rawValue)] [\(entry.category.rawValue)] \(entry.message)\(contextString)"
    }
    
    private func formatContext(_ context: [String: Any]) -> String {
        let contextPairs = context.map { key, value in "\(key)=\(value)" }
        return contextPairs.joined(separator: ", ")
    }
    
    private func checkLogFileSize() {
        guard let logFile = currentLogFile,
              let attributes = try? FileManager.default.attributesOfItem(atPath: logFile.path),
              let fileSize = attributes[.size] as? Int else { return }
        
        if fileSize > maxLogFileSize {
            createNewLogFileIfNeeded()
        }
    }
    
    private func cleanupOldLogFiles() {
        do {
            let logFiles = try FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
            let sortedFiles = logFiles.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
            
            if sortedFiles.count > maxLogFiles {
                for file in sortedFiles[maxLogFiles...] {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            // Silently handle cleanup errors
        }
    }
    
    func getCustomerSupportLogs(since: Date, category: LoggingService.LogCategory?) -> [CustomerSupportLogEntry] {
        // Implementation would parse log files and return relevant entries
        return []
    }
    
    func getLogsForSession(_ sessionId: String) -> [LogEntry] {
        // Implementation would parse log files for specific session
        return []
    }
    
    func getRecentLogs(hours: Int) -> [LogEntry] {
        // Implementation would parse recent log files
        return []
    }
}

// MARK: - Data Models

struct LogEntry: Codable {
    let timestamp: Date
    let level: LoggingService.LogLevel
    let category: LoggingService.LogCategory
    let message: String
    let context: [String: String] // Simplified for Codable
}

struct CustomerSupportLogEntry: Codable {
    let timestamp: Date
    let level: LoggingService.LogLevel
    let category: LoggingService.LogCategory
    let message: String
    let context: [String: String]
    let userType: String
    let sessionId: String
    let deviceInfo: [String: String]
}

struct SupportTicket: Codable {
    let ticketId: String
    let timestamp: Date
    let severity: Severity
    let category: Category
    let title: String
    let description: String
    let context: [String: String]
    let deviceInfo: [String: String]
    let sessionId: String
    
    enum Severity: String, Codable {
        case low, medium, high, critical
    }
    
    enum Category: String, Codable {
        case elderlyUserIssue, voiceProcessing, accessibility, subscription, performance, security
    }
}

struct CriticalError: Codable {
    let timestamp: Date
    let message: String
    let context: [String: String]
    let category: LoggingService.LogCategory
    let sessionId: String
    let deviceInfo: [String: String]
}

struct SupportReport: Codable {
    let timestamp: Date
    let sessionId: String
    let totalLogs: Int
    let errorCount: Int
    let elderlyUserIssues: Int
    let performanceIssues: Int
    let topIssues: [String]
    let deviceInfo: [String: String]
    let appVersion: String
}