import Foundation
import os.log
import UIKit

class MonitoringService: ObservableObject {
    static let shared = MonitoringService()
    
    @Published var isMonitoring = false
    @Published var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    
    private let logger = Logger(subsystem: "com.phira.peterai", category: "Monitoring")
    private var crashReportingEnabled = true
    private var analyticsEnabled = true
    private let secureStorage = SecureStorage.shared
    
    // Performance tracking
    private var sessionStartTime = Date()
    private var memoryWarningCount = 0
    private var crashCount = 0
    private var errorCount = 0
    
    // Elderly user specific metrics
    private var voiceInteractionCount = 0
    private var accessibilityFeatureUsage: [String: Int] = [:]
    private var elderlySpecificErrors: [ElderlyUserError] = []
    
    private init() {
        setupMonitoring()
    }
    
    // MARK: - Setup and Configuration
    
    private func setupMonitoring() {
        // Setup memory warning notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Setup app lifecycle monitoring
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // Setup crash detection
        setupCrashDetection()
        
        sessionStartTime = Date()
        isMonitoring = true
        
        logger.info("PeterAI Monitoring Service initialized for elderly user protection")
    }
    
    private func setupCrashDetection() {
        // Setup NSException handler
        NSSetUncaughtExceptionHandler { exception in
            MonitoringService.shared.handleCrash(exception: exception, signal: nil)
        }
        
        // Setup signal handlers for various crash types
        signal(SIGABRT) { signal in
            MonitoringService.shared.handleCrash(exception: nil, signal: signal)
        }
        
        signal(SIGILL) { signal in
            MonitoringService.shared.handleCrash(exception: nil, signal: signal)
        }
        
        signal(SIGSEGV) { signal in
            MonitoringService.shared.handleCrash(exception: nil, signal: signal)
        }
        
        signal(SIGFPE) { signal in
            MonitoringService.shared.handleCrash(exception: nil, signal: signal)
        }
        
        signal(SIGBUS) { signal in
            MonitoringService.shared.handleCrash(exception: nil, signal: signal)
        }
    }
    
    // MARK: - Crash Handling
    
    private func handleCrash(exception: NSException?, signal: Int32?) {
        let crashReport = createCrashReport(exception: exception, signal: signal)
        storeCrashReport(crashReport)
        
        // Log for elderly user protection
        logger.critical("CRITICAL: PeterAI crashed - protecting elderly user data")
        
        // Send emergency notification if possible
        sendEmergencyCrashNotification(crashReport)
    }
    
    private func createCrashReport(exception: NSException?, signal: Int32?) -> CrashReport {
        let timestamp = Date()
        let deviceInfo = getDeviceInfo()
        let appState = getAppState()
        
        var crashType = "Unknown"
        var crashMessage = "Unknown crash occurred"
        
        if let exception = exception {
            crashType = "Exception: \(exception.name.rawValue)"
            crashMessage = exception.reason ?? "No reason provided"
        } else if let signal = signal {
            crashType = "Signal: \(signal)"
            crashMessage = getSignalDescription(signal)
        }
        
        return CrashReport(
            timestamp: timestamp,
            crashType: crashType,
            crashMessage: crashMessage,
            deviceInfo: deviceInfo,
            appState: appState,
            stackTrace: Thread.callStackSymbols,
            userType: "elderly", // Important for support prioritization
            sessionDuration: Date().timeIntervalSince(sessionStartTime)
        )
    }
    
    private func getSignalDescription(_ signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "Process aborted"
        case SIGILL: return "Illegal instruction"
        case SIGSEGV: return "Segmentation violation"
        case SIGFPE: return "Floating point exception"
        case SIGBUS: return "Bus error"
        default: return "Unknown signal: \(signal)"
        }
    }
    
    // MARK: - Performance Monitoring
    
    func trackPerformanceMetric(_ metric: PerformanceMetric) {
        performanceMetrics.addMetric(metric)
        
        // Log performance issues that might affect elderly users
        if metric.duration > 2.0 { // Anything over 2s is too slow for elderly users
            logger.warning("SLOW OPERATION: \(metric.operation) took \(metric.duration)s - may frustrate elderly users")
            
            // Store slow operation for analysis
            let slowOperation = SlowOperation(
                operation: metric.operation,
                duration: metric.duration,
                timestamp: Date(),
                context: metric.context
            )
            storeSlowOperation(slowOperation)
        }
    }
    
    func startPerformanceTracking(_ operation: String, context: [String: Any] = [:]) -> String {
        let trackingId = UUID().uuidString
        let metric = PerformanceMetric(
            operation: operation,
            startTime: Date(),
            duration: 0,
            context: context,
            trackingId: trackingId
        )
        
        performanceMetrics.activeMetrics[trackingId] = metric
        return trackingId
    }
    
    func endPerformanceTracking(_ trackingId: String) {
        guard let metric = performanceMetrics.activeMetrics[trackingId] else { return }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(metric.startTime)
        
        let completedMetric = PerformanceMetric(
            operation: metric.operation,
            startTime: metric.startTime,
            duration: duration,
            context: metric.context,
            trackingId: trackingId
        )
        
        trackPerformanceMetric(completedMetric)
        performanceMetrics.activeMetrics.removeValue(forKey: trackingId)
    }
    
    // MARK: - Elderly User Specific Monitoring
    
    func trackElderlyUserInteraction(_ interaction: ElderlyUserInteraction) {
        logger.info("Elderly user interaction: \(interaction.type)")
        
        switch interaction.type {
        case .voiceCommand:
            voiceInteractionCount += 1
            
        case .accessibilityFeatureUsed(let feature):
            accessibilityFeatureUsage[feature, default: 0] += 1
            
        case .errorEncountered(let error):
            elderlySpecificErrors.append(error)
            errorCount += 1
            
            // Special handling for errors that are particularly problematic for elderly users
            if error.severity == .critical {
                logger.critical("CRITICAL elderly user error: \(error.description)")
                sendElderlyUserAlert(error)
            }
            
        case .slowResponse(let duration):
            if duration > 3.0 { // 3s+ is very frustrating for elderly users
                logger.error("VERY SLOW response (\(duration)s) - elderly user likely frustrated")
            }
            
        case .confused(let context):
            logger.warning("Elderly user appears confused: \(context)")
            // This could trigger simplified interface mode
        }
    }
    
    private func sendElderlyUserAlert(_ error: ElderlyUserError) {
        // In a real app, this would send to customer support/monitoring service
        logger.critical("ELDERLY USER ALERT: \(error.description) - Context: \(error.context)")
        
        // Store for immediate support team review
        storeElderlyUserAlert(error)
    }
    
    // MARK: - Device and App State Information
    
    private func getDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        let screen = UIScreen.main
        let processInfo = ProcessInfo.processInfo
        
        return DeviceInfo(
            model: device.model,
            systemVersion: device.systemVersion,
            systemName: device.systemName,
            screenScale: screen.scale,
            screenBounds: screen.bounds,
            totalMemory: processInfo.physicalMemory,
            availableMemory: getAvailableMemory(),
            batteryLevel: device.batteryLevel,
            batteryState: device.batteryState.rawValue,
            isLowPowerModeEnabled: processInfo.isLowPowerModeEnabled
        )
    }
    
    private func getAppState() -> AppState {
        return AppState(
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            memoryWarningCount: memoryWarningCount,
            errorCount: errorCount,
            voiceInteractionCount: voiceInteractionCount
        )
    }
    
    private func getAvailableMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    // MARK: - Data Storage
    
    private func storeCrashReport(_ report: CrashReport) {
        do {
            let data = try JSONEncoder().encode(report)
            let filename = "crash_report_\(Int(report.timestamp.timeIntervalSince1970)).json"
            
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let crashReportURL = documentsPath.appendingPathComponent("CrashReports").appendingPathComponent(filename)
                
                // Create directory if needed
                try FileManager.default.createDirectory(at: crashReportURL.deletingLastPathComponent(), 
                                                       withIntermediateDirectories: true)
                
                try data.write(to: crashReportURL)
                logger.info("Crash report stored: \(filename)")
            }
        } catch {
            logger.error("Failed to store crash report: \(error.localizedDescription)")
        }
    }
    
    private func storeSlowOperation(_ operation: SlowOperation) {
        // Store in secure storage for analysis
        let key = "slow_operation_\(Int(operation.timestamp.timeIntervalSince1970))"
        let data = "\(operation.operation):\(operation.duration):\(operation.context)"
        _ = secureStorage.store(key: key, value: data)
    }
    
    private func storeElderlyUserAlert(_ error: ElderlyUserError) {
        do {
            let data = try JSONEncoder().encode(error)
            let key = "elderly_alert_\(Int(Date().timeIntervalSince1970))"
            _ = secureStorage.store(key: key, value: data.base64EncodedString())
        } catch {
            logger.error("Failed to store elderly user alert: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleMemoryWarning() {
        memoryWarningCount += 1
        logger.warning("Memory warning received - count: \(memoryWarningCount)")
        
        // If too many memory warnings, this might affect elderly user experience
        if memoryWarningCount > 3 {
            logger.error("EXCESSIVE memory warnings - elderly users may experience app crashes")
            
            let error = ElderlyUserError(
                type: .performanceIssue,
                severity: .high,
                description: "Excessive memory warnings detected",
                context: "Memory warnings: \(memoryWarningCount)",
                timestamp: Date(),
                affectedFeature: "overall_app_stability"
            )
            
            trackElderlyUserInteraction(.errorEncountered(error))
        }
    }
    
    @objc private func appDidEnterBackground() {
        logger.info("App entered background - session duration: \(Date().timeIntervalSince(sessionStartTime))s")
        generateSessionReport()
    }
    
    @objc private func appWillEnterForeground() {
        logger.info("App returning to foreground")
        sessionStartTime = Date() // Reset session timer
    }
    
    // MARK: - Reporting
    
    func generateSessionReport() -> SessionReport {
        let deviceInfo = getDeviceInfo()
        let appState = getAppState()
        
        let report = SessionReport(
            sessionId: UUID().uuidString,
            startTime: sessionStartTime,
            endTime: Date(),
            deviceInfo: deviceInfo,
            appState: appState,
            performanceMetrics: performanceMetrics,
            elderlySpecificMetrics: ElderlySpecificMetrics(
                voiceInteractionCount: voiceInteractionCount,
                accessibilityFeatureUsage: accessibilityFeatureUsage,
                errorCount: elderlySpecificErrors.count,
                criticalErrorCount: elderlySpecificErrors.filter { $0.severity == .critical }.count
            )
        )
        
        storeSessionReport(report)
        return report
    }
    
    private func storeSessionReport(_ report: SessionReport) {
        do {
            let data = try JSONEncoder().encode(report)
            let filename = "session_\(report.sessionId).json"
            
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let sessionReportURL = documentsPath.appendingPathComponent("SessionReports").appendingPathComponent(filename)
                
                try FileManager.default.createDirectory(at: sessionReportURL.deletingLastPathComponent(), 
                                                       withIntermediateDirectories: true)
                try data.write(to: sessionReportURL)
            }
        } catch {
            logger.error("Failed to store session report: \(error.localizedDescription)")
        }
    }
    
    private func sendEmergencyCrashNotification(_ report: CrashReport) {
        // This would integrate with crash reporting service
        logger.critical("EMERGENCY: Sending crash notification for elderly user protection")
        
        // In production, this would send to:
        // - Crashlytics/Firebase Crashlytics
        // - Sentry
        // - Custom monitoring service
        // - Support team alert system
    }
    
    // MARK: - Public Interface
    
    func getHealthStatus() -> AppHealthStatus {
        let isHealthy = memoryWarningCount < 3 && 
                       errorCount < 10 && 
                       crashCount == 0 &&
                       performanceMetrics.averageOperationTime < 1.0
        
        return AppHealthStatus(
            isHealthy: isHealthy,
            memoryWarnings: memoryWarningCount,
            errorCount: errorCount,
            crashCount: crashCount,
            averagePerformance: performanceMetrics.averageOperationTime,
            elderlyUserFriendliness: calculateElderlyUserFriendliness()
        )
    }
    
    private func calculateElderlyUserFriendliness() -> Double {
        // Calculate a score based on elderly user specific metrics
        var score = 1.0
        
        // Penalize for critical errors
        let criticalErrors = elderlySpecificErrors.filter { $0.severity == .critical }.count
        score -= Double(criticalErrors) * 0.2
        
        // Penalize for slow operations
        if performanceMetrics.averageOperationTime > 2.0 {
            score -= 0.3
        }
        
        // Penalize for excessive memory warnings
        if memoryWarningCount > 2 {
            score -= 0.2
        }
        
        return max(0.0, min(1.0, score))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Data Models

struct CrashReport: Codable {
    let timestamp: Date
    let crashType: String
    let crashMessage: String
    let deviceInfo: DeviceInfo
    let appState: AppState
    let stackTrace: [String]
    let userType: String
    let sessionDuration: TimeInterval
}

struct DeviceInfo: Codable {
    let model: String
    let systemVersion: String
    let systemName: String
    let screenScale: CGFloat
    let screenBounds: CGRect
    let totalMemory: UInt64
    let availableMemory: UInt64
    let batteryLevel: Float
    let batteryState: Int
    let isLowPowerModeEnabled: Bool
}

struct AppState: Codable {
    let version: String
    let buildNumber: String
    let sessionDuration: TimeInterval
    let memoryWarningCount: Int
    let errorCount: Int
    let voiceInteractionCount: Int
}

struct PerformanceMetric {
    let operation: String
    let startTime: Date
    let duration: TimeInterval
    let context: [String: Any]
    let trackingId: String
}

class PerformanceMetrics: ObservableObject {
    @Published var metrics: [PerformanceMetric] = []
    var activeMetrics: [String: PerformanceMetric] = [:]
    
    var averageOperationTime: Double {
        guard !metrics.isEmpty else { return 0 }
        return metrics.map { $0.duration }.reduce(0, +) / Double(metrics.count)
    }
    
    func addMetric(_ metric: PerformanceMetric) {
        metrics.append(metric)
        
        // Keep only last 100 metrics to prevent memory growth
        if metrics.count > 100 {
            metrics.removeFirst()
        }
    }
}

struct SlowOperation {
    let operation: String
    let duration: TimeInterval
    let timestamp: Date
    let context: [String: Any]
}

enum ElderlyUserInteraction {
    case voiceCommand
    case accessibilityFeatureUsed(String)
    case errorEncountered(ElderlyUserError)
    case slowResponse(TimeInterval)
    case confused(String)
}

struct ElderlyUserError: Codable {
    let type: ErrorType
    let severity: ErrorSeverity
    let description: String
    let context: String
    let timestamp: Date
    let affectedFeature: String
    
    enum ErrorType: String, Codable {
        case voiceRecognition
        case speechSynthesis
        case navigationConfusion
        case performanceIssue
        case accessibilityIssue
        case subscriptionIssue
    }
    
    enum ErrorSeverity: String, Codable {
        case low, medium, high, critical
    }
}

struct SessionReport: Codable {
    let sessionId: String
    let startTime: Date
    let endTime: Date
    let deviceInfo: DeviceInfo
    let appState: AppState
    let performanceMetrics: PerformanceMetrics
    let elderlySpecificMetrics: ElderlySpecificMetrics
}

// Make PerformanceMetrics Codable for session reports
extension PerformanceMetrics: Codable {
    enum CodingKeys: String, CodingKey {
        case averageTime, totalOperations
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(averageOperationTime, forKey: .averageTime)
        try container.encode(metrics.count, forKey: .totalOperations)
    }
    
    convenience init(from decoder: Decoder) throws {
        self.init()
        // Don't need to decode individual metrics, just summary
    }
}

struct ElderlySpecificMetrics: Codable {
    let voiceInteractionCount: Int
    let accessibilityFeatureUsage: [String: Int]
    let errorCount: Int
    let criticalErrorCount: Int
}

struct AppHealthStatus {
    let isHealthy: Bool
    let memoryWarnings: Int
    let errorCount: Int
    let crashCount: Int
    let averagePerformance: Double
    let elderlyUserFriendliness: Double
}