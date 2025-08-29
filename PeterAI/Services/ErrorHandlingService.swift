import Foundation
import Network

enum PeterAIError: Error, LocalizedError {
    case noInternet
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case apiKeyMissing
    case apiRateLimit
    case apiServerError(Int)
    case speechRecognitionFailed
    case speechSynthesisFailed
    case subscriptionExpired
    case abuseLimit
    case locationPermissionDenied
    case invalidInput
    case timeout
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .noInternet:
            return "No Internet Connection"
        case .microphonePermissionDenied:
            return "Microphone Access Needed"
        case .speechRecognitionPermissionDenied:
            return "Speech Recognition Access Needed"
        case .apiKeyMissing:
            return "Service Not Available"
        case .apiRateLimit:
            return "Too Many Requests"
        case .apiServerError:
            return "Service Temporarily Unavailable"
        case .speechRecognitionFailed:
            return "Couldn't Understand Speech"
        case .speechSynthesisFailed:
            return "Voice Playback Error"
        case .subscriptionExpired:
            return "Subscription Expired"
        case .abuseLimit:
            return "Daily Limit Reached"
        case .locationPermissionDenied:
            return "Location Access Needed"
        case .invalidInput:
            return "Invalid Request"
        case .timeout:
            return "Request Timed Out"
        case .unknown:
            return "Something Went Wrong"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .noInternet:
            return "It looks like you're not connected to the internet. Please check your WiFi or cellular connection and try again."
        case .microphonePermissionDenied:
            return "Peter needs access to your microphone to hear you. Please go to Settings → Peter AI → Microphone and turn it on."
        case .speechRecognitionPermissionDenied:
            return "Peter needs permission to understand your speech. Please go to Settings → Peter AI → Speech Recognition and turn it on."
        case .apiKeyMissing:
            return "Peter's brain isn't connected right now. Please try again later or contact support if this continues."
        case .apiRateLimit:
            return "You've been chatting a lot today! Please wait a moment and try again."
        case .apiServerError(let code):
            return "Peter's having trouble thinking right now (Error \(code)). Please try again in a few minutes."
        case .speechRecognitionFailed:
            return "I didn't quite catch that. Could you please speak a bit clearer and try again?"
        case .speechSynthesisFailed:
            return "I'm having trouble speaking right now. You can still see my response on the screen."
        case .subscriptionExpired:
            return "Your Peter AI subscription has expired. Please renew to continue chatting."
        case .abuseLimit:
            return "You've reached your daily chat limit. Your limit will reset tomorrow morning."
        case .locationPermissionDenied:
            return "Peter needs your location to provide local weather. Please enable location access in Settings."
        case .invalidInput:
            return "I didn't understand that request. Could you try asking in a different way?"
        case .timeout:
            return "That took longer than expected. Please check your connection and try again."
        case .unknown(let error):
            return "Something unexpected happened: \(error.localizedDescription). Please try again."
        }
    }
    
    var actionSuggestion: String? {
        switch self {
        case .noInternet:
            return "Check your WiFi or cellular connection"
        case .microphonePermissionDenied, .speechRecognitionPermissionDenied:
            return "Go to Settings to enable permissions"
        case .apiKeyMissing, .apiServerError:
            return "Contact support if this continues"
        case .apiRateLimit:
            return "Wait a moment and try again"
        case .speechRecognitionFailed:
            return "Speak more clearly or try typing"
        case .speechSynthesisFailed:
            return "Check your volume settings"
        case .subscriptionExpired:
            return "Renew your subscription"
        case .abuseLimit:
            return "Try again tomorrow"
        case .locationPermissionDenied:
            return "Enable location in Settings"
        case .invalidInput:
            return "Try asking in a different way"
        case .timeout:
            return "Check your connection and retry"
        case .unknown:
            return "Try restarting the app"
        }
    }
    
    var shouldShowRetryButton: Bool {
        switch self {
        case .noInternet, .apiServerError, .speechRecognitionFailed, .timeout, .unknown:
            return true
        case .microphonePermissionDenied, .speechRecognitionPermissionDenied, .locationPermissionDenied:
            return false
        case .apiKeyMissing, .subscriptionExpired, .abuseLimit:
            return false
        case .apiRateLimit:
            return true
        case .speechSynthesisFailed, .invalidInput:
            return true
        }
    }
    
    var shouldShowSettingsButton: Bool {
        switch self {
        case .microphonePermissionDenied, .speechRecognitionPermissionDenied, .locationPermissionDenied:
            return true
        default:
            return false
        }
    }
}

struct RetryConfiguration {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let backoffMultiplier: Double
    let maxDelay: TimeInterval
    
    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        initialDelay: 1.0,
        backoffMultiplier: 2.0,
        maxDelay: 30.0
    )
    
    static let speech = RetryConfiguration(
        maxAttempts: 2,
        initialDelay: 0.5,
        backoffMultiplier: 1.5,
        maxDelay: 3.0
    )
    
    static let api = RetryConfiguration(
        maxAttempts: 3,
        initialDelay: 2.0,
        backoffMultiplier: 2.0,
        maxDelay: 60.0
    )
}

class ErrorHandlingService: ObservableObject {
    @Published var currentError: PeterAIError?
    @Published var isShowingError = false
    @Published var networkStatus: NetworkStatus = .unknown
    @Published var isRecovering = false
    @Published var recoveryProgress: Double = 0.0
    @Published var lastSuccessfulOperation: Date = Date()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var retryTasks: [String: Task<Void, Never>] = [:]
    private var errorHistory: [ErrorEvent] = []
    private var recoveryStrategies: [String: RecoveryStrategy] = [:]
    private let maxErrorHistory = 50
    
    // Circuit breaker pattern for elderly users - prevent overwhelming them with errors
    private var circuitBreakerState: CircuitBreakerState = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let failureThreshold = 3
    private let recoveryTimeout: TimeInterval = 300 // 5 minutes
    
    enum NetworkStatus {
        case connected
        case disconnected
        case unknown
    }
    
    enum CircuitBreakerState {
        case closed    // Normal operation
        case open      // Failing fast, not attempting operations
        case halfOpen  // Testing if service is recovered
    }
    
    init() {
        startNetworkMonitoring()
        setupRecoveryStrategies()
        scheduleHealthChecks()
    }
    
    deinit {
        monitor.cancel()
        retryTasks.values.forEach { $0.cancel() }
    }
    
    private func setupRecoveryStrategies() {
        // Network recovery
        recoveryStrategies["network"] = RecoveryStrategy(
            name: "Network Recovery",
            priority: 1,
            action: { [weak self] in
                await self?.attemptNetworkRecovery() ?? false
            },
            requiresUserConsent: false,
            estimatedTime: 10.0
        )
        
        // Permission recovery
        recoveryStrategies["permissions"] = RecoveryStrategy(
            name: "Permission Recovery",
            priority: 2,
            action: { [weak self] in
                await self?.attemptPermissionRecovery() ?? false
            },
            requiresUserConsent: true,
            estimatedTime: 30.0
        )
        
        // Service recovery
        recoveryStrategies["service"] = RecoveryStrategy(
            name: "Service Recovery",
            priority: 3,
            action: { [weak self] in
                await self?.attemptServiceRecovery() ?? false
            },
            requiresUserConsent: false,
            estimatedTime: 15.0
        )
    }
    
    private func scheduleHealthChecks() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performProactiveHealthCheck()
            }
        }
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.networkStatus = path.status == .satisfied ? .connected : .disconnected
            }
        }
        monitor.start(queue: queue)
    }
    
    // MARK: - Error Presentation
    
    func handle(_ error: Error, context: String = "") {
        let peterError = convertToPeterAIError(error)
        
        // Record error event
        recordErrorEvent(peterError, context: context)
        
        // Update circuit breaker
        updateCircuitBreaker(for: peterError)
        
        // Check if we should show this error to elderly user (avoid overwhelming)
        if shouldShowErrorToUser(peterError) {
            DispatchQueue.main.async {
                self.currentError = peterError
                self.isShowingError = true
            }
        }
        
        // Log error for analytics
        print("🚨 Error in \(context): \(peterError.errorDescription ?? "Unknown")")
        if let suggestion = peterError.actionSuggestion {
            print("💡 Suggestion: \(suggestion)")
        }
        
        // Attempt automatic recovery for certain errors
        Task {
            await attemptAutomaticRecovery(for: peterError, context: context)
        }
    }
    
    private func recordErrorEvent(_ error: PeterAIError, context: String) {
        let event = ErrorEvent(
            timestamp: Date(),
            error: error,
            context: context,
            recovered: false,
            recoveryTime: nil
        )
        
        errorHistory.append(event)
        
        // Keep history manageable
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeFirst()
        }
    }
    
    private func updateCircuitBreaker(for error: PeterAIError) {
        switch circuitBreakerState {
        case .closed:
            if isCircuitBreakerError(error) {
                failureCount += 1
                lastFailureTime = Date()
                
                if failureCount >= failureThreshold {
                    circuitBreakerState = .open
                    print("🔴 Circuit breaker OPEN - protecting elderly user from repeated failures")
                    
                    // Schedule recovery attempt
                    scheduleCircuitBreakerRecovery()
                }
            } else {
                // Reset on success or non-critical error
                failureCount = 0
                lastSuccessfulOperation = Date()
            }
            
        case .open:
            // Don't process operations, wait for recovery
            break
            
        case .halfOpen:
            if isCircuitBreakerError(error) {
                circuitBreakerState = .open
                failureCount += 1
                scheduleCircuitBreakerRecovery()
            } else {
                circuitBreakerState = .closed
                failureCount = 0
                print("🟢 Circuit breaker CLOSED - service recovered")
            }
        }
    }
    
    private func isCircuitBreakerError(_ error: PeterAIError) -> Bool {
        switch error {
        case .apiServerError, .timeout, .noInternet:
            return true
        default:
            return false
        }
    }
    
    private func shouldShowErrorToUser(_ error: PeterAIError) -> Bool {
        // Don't overwhelm elderly users with repeated errors
        if circuitBreakerState == .open {
            return false
        }
        
        // Check if we've shown similar errors recently
        let recentSimilarErrors = errorHistory
            .filter { $0.timestamp.timeIntervalSinceNow > -60 } // Last minute
            .filter { $0.error.errorDescription == error.errorDescription }
        
        return recentSimilarErrors.count <= 2
    }
    
    private func scheduleCircuitBreakerRecovery() {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(recoveryTimeout * 1_000_000_000))
            
            DispatchQueue.main.async {
                self.circuitBreakerState = .halfOpen
                print("🟡 Circuit breaker HALF-OPEN - testing recovery")
            }
        }
    }
    
    func dismissError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.isShowingError = false
        }
    }
    
    private func convertToPeterAIError(_ error: Error) -> PeterAIError {
        if let peterError = error as? PeterAIError {
            return peterError
        }
        
        // Network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .noInternet
            case .timedOut:
                return .timeout
            default:
                return .unknown(error)
            }
        }
        
        // HTTP errors
        if let httpError = error as? HTTPError {
            switch httpError.statusCode {
            case 429:
                return .apiRateLimit
            case 401, 403:
                return .apiKeyMissing
            case 500...599:
                return .apiServerError(httpError.statusCode)
            default:
                return .unknown(error)
            }
        }
        
        return .unknown(error)
    }
    
    // MARK: - Retry Logic
    
    func retry<T>(
        _ operation: @escaping () async throws -> T,
        configuration: RetryConfiguration = .default,
        operationId: String = UUID().uuidString
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = configuration.initialDelay
        
        for attempt in 1...configuration.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry certain errors
                let peterError = convertToPeterAIError(error)
                if !shouldRetry(peterError) {
                    throw peterError
                }
                
                // Don't wait after the last attempt
                if attempt < configuration.maxAttempts {
                    print("🔄 Retry attempt \(attempt) failed, waiting \(currentDelay)s before retry...")
                    
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    
                    currentDelay = min(
                        currentDelay * configuration.backoffMultiplier,
                        configuration.maxDelay
                    )
                }
            }
        }
        
        throw lastError ?? PeterAIError.unknown(NSError(domain: "RetryFailed", code: -1))
    }
    
    private func shouldRetry(_ error: PeterAIError) -> Bool {
        switch error {
        case .noInternet, .timeout, .apiServerError, .apiRateLimit:
            return true
        case .microphonePermissionDenied, .speechRecognitionPermissionDenied, .locationPermissionDenied:
            return false
        case .apiKeyMissing, .subscriptionExpired, .abuseLimit:
            return false
        case .speechRecognitionFailed, .speechSynthesisFailed:
            return true
        case .invalidInput:
            return false
        case .unknown:
            return true
        }
    }
    
    // MARK: - Graceful Degradation
    
    func shouldFallbackToText(_ error: PeterAIError) -> Bool {
        switch error {
        case .speechRecognitionFailed, .microphonePermissionDenied, .speechRecognitionPermissionDenied:
            return true
        default:
            return false
        }
    }
    
    func shouldDisableVoiceOutput(_ error: PeterAIError) -> Bool {
        switch error {
        case .speechSynthesisFailed:
            return true
        default:
            return false
        }
    }
    
    func shouldShowOfflineMode(_ error: PeterAIError) -> Bool {
        switch error {
        case .noInternet:
            return true
        default:
            return false
        }
    }
    
    // MARK: - User Guidance
    
    func getHelpfulMessage(for error: PeterAIError) -> String {
        var message = error.userFriendlyMessage
        
        // Add contextual help based on network status
        if error == .noInternet && networkStatus == .connected {
            message += "\n\nYour device shows internet connection, but Peter can't reach the server. This might be temporary."
        }
        
        return message
    }
    
    func getRecoveryOptions(for error: PeterAIError) -> [RecoveryOption] {
        var options: [RecoveryOption] = []
        
        if error.shouldShowRetryButton {
            options.append(RecoveryOption(
                title: "Try Again",
                icon: "arrow.clockwise",
                action: .retry
            ))
        }
        
        if error.shouldShowSettingsButton {
            options.append(RecoveryOption(
                title: "Open Settings",
                icon: "gear",
                action: .openSettings
            ))
        }
        
        // Always show help option
        options.append(RecoveryOption(
            title: "Get Help",
            icon: "questionmark.circle",
            action: .showHelp
        ))
        
        return options
    }
    
    // MARK: - Proactive Error Prevention
    
    func checkSystemHealth() -> [HealthIssue] {
        var issues: [HealthIssue] = []
        
        // Network check
        if networkStatus == .disconnected {
            issues.append(HealthIssue(
                type: .connectivity,
                severity: .high,
                message: "No internet connection detected",
                suggestion: "Check your WiFi or cellular connection"
            ))
        }
        
        // Permission checks would go here
        // Battery level checks
        // Storage checks
        // etc.
        
        return issues
    }
    
    // MARK: - Automatic Recovery Methods
    
    private func attemptAutomaticRecovery(for error: PeterAIError, context: String) async {
        guard circuitBreakerState != .open else { return }
        
        DispatchQueue.main.async {
            self.isRecovering = true
            self.recoveryProgress = 0.0
        }
        
        let startTime = Date()
        var recovered = false
        
        switch error {
        case .noInternet:
            recovered = await attemptNetworkRecovery()
        case .apiServerError, .timeout:
            recovered = await attemptServiceRecovery()
        case .microphonePermissionDenied, .speechRecognitionPermissionDenied:
            // Don't auto-recover permissions - requires user action
            break
        default:
            break
        }
        
        let recoveryTime = Date().timeIntervalSince(startTime)
        
        if recovered {
            print("✅ Automatic recovery successful for \(error) in \(recoveryTime)s")
            lastSuccessfulOperation = Date()
            failureCount = max(0, failureCount - 1)
            
            // Update error history
            if let lastIndex = errorHistory.lastIndex(where: { $0.context == context && $0.error.errorDescription == error.errorDescription }) {
                errorHistory[lastIndex] = ErrorEvent(
                    timestamp: errorHistory[lastIndex].timestamp,
                    error: error,
                    context: context,
                    recovered: true,
                    recoveryTime: recoveryTime
                )
            }
        }
        
        DispatchQueue.main.async {
            self.isRecovering = false
            self.recoveryProgress = recovered ? 1.0 : 0.0
        }
    }
    
    private func attemptNetworkRecovery() async -> Bool {
        print("🔄 Attempting network recovery...")
        
        // Wait for network to come back
        for attempt in 1...5 {
            await updateProgress(Double(attempt) / 5.0)
            
            if networkStatus == .connected {
                // Test with a simple request
                do {
                    let url = URL(string: "https://www.google.com")!
                    let (_, response) = try await URLSession.shared.data(from: url)
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                        return true
                    }
                } catch {
                    print("Network test failed: \(error)")
                }
            }
            
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        return false
    }
    
    private func attemptPermissionRecovery() async -> Bool {
        print("🔄 Checking permission status...")
        
        await updateProgress(0.5)
        
        // Check current permissions
        // This would trigger permission request dialogs if needed
        // For now, just check current status
        
        await updateProgress(1.0)
        
        // Permissions require user interaction, so we can't automatically recover
        return false
    }
    
    private func attemptServiceRecovery() async -> Bool {
        print("🔄 Attempting service recovery...")
        
        // Test API connectivity with exponential backoff
        let delays: [UInt64] = [1, 2, 4, 8, 16] // seconds in nanoseconds * 1B
        
        for (index, delay) in delays.enumerated() {
            await updateProgress(Double(index + 1) / Double(delays.count))
            
            do {
                // Test with a simple health check endpoint
                let url = URL(string: "https://api.openai.com/v1/models")!
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 10
                
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode < 500 {
                    return true
                }
            } catch {
                print("Service test failed: \(error)")
            }
            
            if index < delays.count - 1 {
                try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            }
        }
        
        return false
    }
    
    private func performProactiveHealthCheck() async {
        // Only check if system has been stable
        let timeSinceLastError = errorHistory.last?.timestamp.timeIntervalSinceNow ?? -3600
        guard timeSinceLastError < -300 else { return } // 5 minutes since last error
        
        let issues = checkSystemHealth()
        
        for issue in issues where issue.severity == .high || issue.severity == .critical {
            print("⚠️ Health check found issue: \(issue.message)")
            
            // Attempt preemptive recovery
            switch issue.type {
            case .connectivity:
                _ = await attemptNetworkRecovery()
            default:
                break
            }
        }
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            self.recoveryProgress = progress
        }
    }
    
    // MARK: - Recovery Status
    
    func canAttemptOperation() -> Bool {
        return circuitBreakerState != .open
    }
    
    func getRecoveryStatus() -> String {
        switch circuitBreakerState {
        case .closed:
            if isRecovering {
                return "Trying to fix the problem..."
            } else {
                return "Everything is working normally"
            }
        case .open:
            return "Taking a break to prevent more problems"
        case .halfOpen:
            return "Testing if the problem is fixed"
        }
    }
    
    func getErrorStatistics() -> (totalErrors: Int, recentErrors: Int, recoveryRate: Double) {
        let totalErrors = errorHistory.count
        let recentErrors = errorHistory.filter { $0.timestamp.timeIntervalSinceNow > -3600 }.count // Last hour
        let recoveredErrors = errorHistory.filter { $0.recovered }.count
        let recoveryRate = totalErrors > 0 ? Double(recoveredErrors) / Double(totalErrors) : 0.0
        
        return (totalErrors, recentErrors, recoveryRate)
    }
}

// MARK: - Supporting Types

struct HTTPError: Error {
    let statusCode: Int
    let message: String
}

struct RecoveryOption {
    let title: String
    let icon: String
    let action: RecoveryAction
    
    enum RecoveryAction {
        case retry
        case openSettings
        case showHelp
        case contact
        case dismiss
    }
}

struct HealthIssue {
    let type: IssueType
    let severity: Severity
    let message: String
    let suggestion: String
    
    enum IssueType {
        case connectivity
        case permissions
        case storage
        case battery
        case performance
    }
    
    enum Severity {
        case low
        case medium
        case high
        case critical
    }
}

// MARK: - Error Presentation Views Helper

extension ErrorHandlingService {
    func createErrorAlert() -> ErrorAlert? {
        guard let error = currentError else { return nil }
        
        return ErrorAlert(
            title: error.errorDescription ?? "Error",
            message: getHelpfulMessage(for: error),
            recoveryOptions: getRecoveryOptions(for: error)
        )
    }
}

struct ErrorAlert {
    let title: String
    let message: String
    let recoveryOptions: [RecoveryOption]
}

struct ErrorEvent {
    let timestamp: Date
    let error: PeterAIError
    let context: String
    let recovered: Bool
    let recoveryTime: TimeInterval?
}

struct RecoveryStrategy {
    let name: String
    let priority: Int
    let action: () async -> Bool
    let requiresUserConsent: Bool
    let estimatedTime: TimeInterval
}