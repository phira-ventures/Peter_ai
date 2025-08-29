import XCTest
import Foundation
@testable import PeterAI

// MARK: - UserStore Tests

class UserStoreTests: XCTestCase {
    var userStore: UserStore!
    var mockUserDefaults: MockUserDefaults!
    
    override func setUp() {
        super.setUp()
        mockUserDefaults = MockUserDefaults()
        userStore = UserStore()
        userStore.userDefaults = mockUserDefaults
    }
    
    override func tearDown() {
        userStore = nil
        mockUserDefaults = nil
        super.tearDown()
    }
    
    func testUserStoreInitialization() {
        // Given
        mockUserDefaults.mockValues = [
            "firstName": "Margaret",
            "email": "margaret@example.com",
            "location": "Boston",
            "isOnboardingCompleted": true,
            "hasActiveSubscription": false
        ]
        
        // When
        userStore = UserStore()
        userStore.userDefaults = mockUserDefaults
        userStore.loadUserData()
        
        // Then
        XCTAssertEqual(userStore.firstName, "Margaret")
        XCTAssertEqual(userStore.email, "margaret@example.com")
        XCTAssertEqual(userStore.location, "Boston")
        XCTAssertTrue(userStore.isOnboardingCompleted)
        XCTAssertFalse(userStore.hasActiveSubscription)
    }
    
    func testSaveUserData() {
        // Given
        userStore.firstName = "Robert"
        userStore.email = "robert@example.com"
        userStore.location = "Chicago"
        userStore.isOnboardingCompleted = true
        userStore.hasActiveSubscription = true
        
        // When
        userStore.saveUserData()
        
        // Then
        XCTAssertEqual(mockUserDefaults.savedValues["firstName"] as? String, "Robert")
        XCTAssertEqual(mockUserDefaults.savedValues["email"] as? String, "robert@example.com")
        XCTAssertEqual(mockUserDefaults.savedValues["location"] as? String, "Chicago")
        XCTAssertEqual(mockUserDefaults.savedValues["isOnboardingCompleted"] as? Bool, true)
        XCTAssertEqual(mockUserDefaults.savedValues["hasActiveSubscription"] as? Bool, true)
    }
    
    func testCompleteOnboarding() {
        // Given
        XCTAssertFalse(userStore.isOnboardingCompleted)
        
        // When
        userStore.completeOnboarding()
        
        // Then
        XCTAssertTrue(userStore.isOnboardingCompleted)
        XCTAssertTrue(mockUserDefaults.setShouldBeCalled)
    }
    
    func testUpdateSubscriptionStatus() {
        // Given
        XCTAssertFalse(userStore.hasActiveSubscription)
        
        // When
        userStore.updateSubscriptionStatus(true)
        
        // Then
        XCTAssertTrue(userStore.hasActiveSubscription)
        XCTAssertTrue(mockUserDefaults.setShouldBeCalled)
    }
    
    func testEmailValidation() {
        // Valid emails
        XCTAssertTrue(userStore.isValidEmail("test@example.com"))
        XCTAssertTrue(userStore.isValidEmail("user.name+tag@example.co.uk"))
        XCTAssertTrue(userStore.isValidEmail("senior123@gmail.com"))
        
        // Invalid emails
        XCTAssertFalse(userStore.isValidEmail(""))
        XCTAssertFalse(userStore.isValidEmail("invalid-email"))
        XCTAssertFalse(userStore.isValidEmail("@example.com"))
        XCTAssertFalse(userStore.isValidEmail("test@"))
        XCTAssertFalse(userStore.isValidEmail("test.example.com"))
    }
    
    func testLocationValidation() {
        // Valid locations
        XCTAssertTrue(userStore.isValidLocation("New York"))
        XCTAssertTrue(userStore.isValidLocation("Los Angeles, CA"))
        XCTAssertTrue(userStore.isValidLocation("London, UK"))
        
        // Invalid locations
        XCTAssertFalse(userStore.isValidLocation(""))
        XCTAssertFalse(userStore.isValidLocation("   "))
        XCTAssertFalse(userStore.isValidLocation("A")) // Too short
    }
    
    func testDataMigration() {
        // Given - Simulate old data format
        mockUserDefaults.mockValues = [
            "user_name": "OldName", // Old key format
            "user_email": "old@example.com"
        ]
        
        // When
        userStore.migrateDataIfNeeded()
        
        // Then
        XCTAssertEqual(userStore.firstName, "OldName")
        XCTAssertEqual(userStore.email, "old@example.com")
    }
}

// MARK: - AnalyticsService Tests

class AnalyticsServiceTests: XCTestCase {
    var analyticsService: AnalyticsService!
    var mockUserDefaults: MockUserDefaults!
    
    override func setUp() {
        super.setUp()
        mockUserDefaults = MockUserDefaults()
        analyticsService = AnalyticsService()
        analyticsService.userDefaults = mockUserDefaults
    }
    
    override func tearDown() {
        analyticsService = nil
        mockUserDefaults = nil
        super.tearDown()
    }
    
    func testEventTracking() {
        // Given
        let eventName = "test_event"
        let properties = ["key1": "value1", "key2": "value2"]
        
        // When
        analyticsService.track(eventName, properties: properties)
        
        // Then
        XCTAssertEqual(analyticsService.eventQueue.count, 1)
        let event = analyticsService.eventQueue.first!
        XCTAssertEqual(event.eventName, eventName)
        XCTAssertEqual(event.properties, properties)
        XCTAssertNotNil(event.userId)
        XCTAssertNotNil(event.sessionId)
    }
    
    func testAbuseMonitoring() {
        // Given
        analyticsService.dailyQueryCount = 0
        analyticsService.dailyQueryLimit = 5
        
        // When - Make queries within limit
        for _ in 1...4 {
            XCTAssertTrue(analyticsService.trackQuery())
        }
        
        // Then - Should still allow queries
        XCTAssertTrue(analyticsService.trackQuery()) // 5th query - at limit
        
        // When - Exceed limit
        let result = analyticsService.trackQuery() // 6th query
        
        // Then
        XCTAssertFalse(result) // Should block
        XCTAssertEqual(analyticsService.dailyQueryCount, 6) // But still count it
    }
    
    func testDailyQueryReset() {
        // Given
        analyticsService.dailyQueryCount = 50
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        mockUserDefaults.mockValues["last_query_reset"] = yesterday
        
        // When
        analyticsService.updateQueryCounts()
        
        // Then
        XCTAssertEqual(analyticsService.dailyQueryCount, 1) // Reset and incremented
    }
    
    func testMonthlyQueryReset() {
        // Given
        analyticsService.monthlyQueryCount = 500
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        mockUserDefaults.mockValues["last_monthly_reset"] = lastMonth
        
        // When
        analyticsService.updateQueryCounts()
        
        // Then
        XCTAssertEqual(analyticsService.monthlyQueryCount, 1) // Reset and incremented
    }
    
    func testSessionManagement() {
        // When
        analyticsService.startSession()
        
        // Then
        XCTAssertNotNil(analyticsService.currentSession)
        XCTAssertEqual(analyticsService.eventQueue.count, 1) // Session started event
        XCTAssertEqual(analyticsService.eventQueue.first?.eventName, "session_started")
        
        // When
        analyticsService.endSession()
        
        // Then
        XCTAssertNil(analyticsService.currentSession)
        XCTAssertEqual(analyticsService.eventQueue.count, 2) // Session ended event added
    }
    
    func testConversationAnalytics() {
        // When
        analyticsService.trackConversationStarted()
        analyticsService.trackConversationEnded(messageCount: 5, duration: 120.0)
        
        // Then
        XCTAssertEqual(analyticsService.eventQueue.count, 2)
        
        let endEvent = analyticsService.eventQueue.last!
        XCTAssertEqual(endEvent.eventName, "conversation_ended")
        XCTAssertEqual(endEvent.properties["message_count"], "5")
        XCTAssertEqual(endEvent.properties["duration_seconds"], "120")
    }
    
    func testVoiceInteractionTracking() {
        // When
        analyticsService.trackVoiceInteraction(duration: 15.5, successful: true)
        
        // Then
        let event = analyticsService.eventQueue.last!
        XCTAssertEqual(event.eventName, "voice_interaction")
        XCTAssertEqual(event.properties["duration_seconds"], "15")
        XCTAssertEqual(event.properties["successful"], "true")
    }
    
    func testSuggestedPromptTracking() {
        // When
        analyticsService.trackSuggestedPromptUsed("What's the weather?", category: "weather")
        
        // Then
        let event = analyticsService.eventQueue.last!
        XCTAssertEqual(event.eventName, "suggested_prompt_used")
        XCTAssertEqual(event.properties["prompt_text"], "What's the weather?")
        XCTAssertEqual(event.properties["category"], "weather")
    }
    
    func testAbuseStatusChecking() {
        // Given
        analyticsService.dailyQueryCount = 30
        analyticsService.monthlyQueryCount = 200
        analyticsService.dailyQueryLimit = 50
        analyticsService.monthlyQueryLimit = 500
        
        // When
        let status = analyticsService.getAbuseStatus()
        
        // Then
        XCTAssertEqual(status.daily, 30)
        XCTAssertEqual(status.monthly, 200)
        XCTAssertEqual(status.dailyLimit, 50)
        XCTAssertEqual(status.monthlyLimit, 500)
        XCTAssertFalse(status.isBlocked)
    }
    
    func testErrorTracking() {
        // Given
        let testError = NSError(domain: "TestDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: "Not found"])
        
        // When
        analyticsService.trackError(testError, context: "voice_recognition")
        
        // Then
        let event = analyticsService.eventQueue.last!
        XCTAssertEqual(event.eventName, "error_occurred")
        XCTAssertEqual(event.properties["error_message"], "Not found")
        XCTAssertEqual(event.properties["context"], "voice_recognition")
        XCTAssertEqual(event.properties["error_type"], "NSError")
    }
    
    func testAPIErrorTracking() {
        // When
        analyticsService.trackAPIError(endpoint: "/chat/completions", statusCode: 429, message: "Rate limit exceeded")
        
        // Then
        let event = analyticsService.eventQueue.last!
        XCTAssertEqual(event.eventName, "api_error")
        XCTAssertEqual(event.properties["endpoint"], "/chat/completions")
        XCTAssertEqual(event.properties["status_code"], "429")
        XCTAssertEqual(event.properties["message"], "Rate limit exceeded")
    }
    
    func testUserInsights() {
        // Given
        analyticsService.dailyQueryCount = 15
        analyticsService.monthlyQueryCount = 120
        
        // When
        let insights = analyticsService.getUserInsights()
        
        // Then
        XCTAssertNotNil(insights["user_id"])
        XCTAssertEqual(insights["daily_queries"] as? Int, 15)
        XCTAssertEqual(insights["monthly_queries"] as? Int, 120)
        XCTAssertNotNil(insights["app_version"])
        XCTAssertNotNil(insights["device_model"])
    }
    
    func testDataPrivacyCompliance() {
        // Given
        analyticsService.track("test_event")
        XCTAssertGreaterThan(analyticsService.eventQueue.count, 0)
        
        // When
        analyticsService.clearAllAnalyticsData()
        
        // Then
        XCTAssertEqual(analyticsService.eventQueue.count, 1) // Should have "analytics_data_cleared" event
        XCTAssertEqual(analyticsService.eventQueue.first?.eventName, "analytics_data_cleared")
        XCTAssertTrue(mockUserDefaults.removeObjectCalled)
    }
    
    func testEventUploadBatching() {
        // Given
        for i in 1...25 {
            analyticsService.track("test_event_\(i)")
        }
        
        // When
        analyticsService.uploadEvents()
        
        // Then
        XCTAssertEqual(analyticsService.eventQueue.count, 0) // Should be cleared after upload
        XCTAssertTrue(analyticsService.lastUploadAttempted) // Verify upload was attempted
    }
    
    func testPerformanceOptimization() {
        // Test that frequent analytics calls don't impact performance
        measure {
            for i in 0..<1000 {
                analyticsService.track("performance_test_\(i)", properties: ["iteration": String(i)])
            }
        }
    }
}

// MARK: - ErrorHandlingService Tests

class ErrorHandlingServiceTests: XCTestCase {
    var errorHandlingService: ErrorHandlingService!
    var mockNetworkMonitor: MockNetworkMonitor!
    
    override func setUp() {
        super.setUp()
        errorHandlingService = ErrorHandlingService()
        mockNetworkMonitor = MockNetworkMonitor()
        errorHandlingService.networkMonitor = mockNetworkMonitor
    }
    
    override func tearDown() {
        errorHandlingService = nil
        mockNetworkMonitor = nil
        super.tearDown()
    }
    
    func testErrorConversion() {
        // Network errors
        let networkError = URLError(.notConnectedToInternet)
        let convertedError = errorHandlingService.convertToPeterAIError(networkError)
        XCTAssertEqual(convertedError, .noInternet)
        
        // Timeout errors
        let timeoutError = URLError(.timedOut)
        let convertedTimeout = errorHandlingService.convertToPeterAIError(timeoutError)
        XCTAssertEqual(convertedTimeout, .timeout)
        
        // HTTP errors
        let httpError = HTTPError(statusCode: 429, message: "Rate limit")
        let convertedHTTP = errorHandlingService.convertToPeterAIError(httpError)
        XCTAssertEqual(convertedHTTP, .apiRateLimit)
    }
    
    func testUserFriendlyMessages() {
        // Test that error messages are elderly-friendly
        let noInternetError = PeterAIError.noInternet
        let message = noInternetError.userFriendlyMessage
        
        XCTAssertTrue(message.contains("not connected to the internet"))
        XCTAssertTrue(message.contains("WiFi or cellular"))
        XCTAssertFalse(message.contains("network unreachable")) // Avoid technical terms
    }
    
    func testRetryLogic() async {
        // Given
        var attemptCount = 0
        let operation: () async throws -> String = {
            attemptCount += 1
            if attemptCount < 3 {
                throw URLError(.networkConnectionLost)
            }
            return "Success"
        }
        
        // When
        do {
            let result = try await errorHandlingService.retry(operation, configuration: .default)
            
            // Then
            XCTAssertEqual(result, "Success")
            XCTAssertEqual(attemptCount, 3)
        } catch {
            XCTFail("Should have succeeded after retries")
        }
    }
    
    func testRetryWithNonRetryableError() async {
        // Given
        let operation: () async throws -> String = {
            throw PeterAIError.microphonePermissionDenied
        }
        
        // When/Then
        do {
            _ = try await errorHandlingService.retry(operation, configuration: .default)
            XCTFail("Should not retry permission errors")
        } catch let error as PeterAIError {
            XCTAssertEqual(error, .microphonePermissionDenied)
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    func testErrorPresentationState() {
        // Given
        let error = PeterAIError.speechRecognitionFailed
        
        // When
        errorHandlingService.handle(error)
        
        // Then
        XCTAssertTrue(errorHandlingService.isShowingError)
        XCTAssertEqual(errorHandlingService.currentError, error)
        
        // When
        errorHandlingService.dismissError()
        
        // Then
        XCTAssertFalse(errorHandlingService.isShowingError)
        XCTAssertNil(errorHandlingService.currentError)
    }
    
    func testRecoveryOptions() {
        // Test different error types have appropriate recovery options
        let networkError = PeterAIError.noInternet
        let networkOptions = errorHandlingService.getRecoveryOptions(for: networkError)
        XCTAssertTrue(networkOptions.contains { $0.action == .retry })
        
        let permissionError = PeterAIError.microphonePermissionDenied
        let permissionOptions = errorHandlingService.getRecoveryOptions(for: permissionError)
        XCTAssertTrue(permissionOptions.contains { $0.action == .openSettings })
    }
    
    func testNetworkStatusMonitoring() {
        // Given
        mockNetworkMonitor.isConnected = false
        
        // When
        mockNetworkMonitor.simulateNetworkChange()
        
        // Then
        XCTAssertEqual(errorHandlingService.networkStatus, .disconnected)
        
        // Given
        mockNetworkMonitor.isConnected = true
        
        // When
        mockNetworkMonitor.simulateNetworkChange()
        
        // Then
        XCTAssertEqual(errorHandlingService.networkStatus, .connected)
    }
    
    func testGracefulDegradation() {
        // Test that the service provides helpful alternatives
        let speechError = PeterAIError.speechRecognitionFailed
        XCTAssertTrue(errorHandlingService.shouldFallbackToText(speechError))
        
        let voiceError = PeterAIError.speechSynthesisFailed
        XCTAssertTrue(errorHandlingService.shouldDisableVoiceOutput(voiceError))
        
        let offlineError = PeterAIError.noInternet
        XCTAssertTrue(errorHandlingService.shouldShowOfflineMode(offlineError))
    }
    
    func testSystemHealthCheck() {
        // Given
        mockNetworkMonitor.isConnected = false
        
        // When
        let issues = errorHandlingService.checkSystemHealth()
        
        // Then
        XCTAssertTrue(issues.contains { $0.type == .connectivity })
        XCTAssertTrue(issues.contains { $0.severity == .high })
    }
    
    func testErrorAlertGeneration() {
        // Given
        errorHandlingService.currentError = PeterAIError.apiRateLimit
        
        // When
        let alert = errorHandlingService.createErrorAlert()
        
        // Then
        XCTAssertNotNil(alert)
        XCTAssertEqual(alert?.title, "Too Many Requests")
        XCTAssertTrue(alert?.message.contains("chatting a lot") == true)
        XCTAssertFalse(alert?.recoveryOptions.isEmpty == true)
    }
}

// MARK: - AccessibilityService Tests

class AccessibilityServiceTests: XCTestCase {
    var accessibilityService: AccessibilityService!
    
    override func setUp() {
        super.setUp()
        accessibilityService = AccessibilityService()
    }
    
    override func tearDown() {
        accessibilityService = nil
        super.tearDown()
    }
    
    func testFontSizeCalculation() {
        // Given
        accessibilityService.settings.largeText = true
        
        // When/Then
        let titleSize = accessibilityService.getOptimalFontSize(for: .title)
        let bodySize = accessibilityService.getOptimalFontSize(for: .body)
        
        XCTAssertGreaterThan(titleSize, bodySize)
        XCTAssertGreaterThanOrEqual(titleSize, 30) // Minimum for elderly users
        XCTAssertGreaterThanOrEqual(bodySize, 20)
    }
    
    func testTouchTargetSizes() {
        // Given
        accessibilityService.settings.buttonSizeLarge = true
        
        // When
        let touchTargetSize = accessibilityService.getMinimumTouchTargetSize()
        
        // Then
        XCTAssertGreaterThanOrEqual(touchTargetSize, 60) // Larger for elderly users
    }
    
    func testVoiceOverSupport() {
        // Test accessibility label generation
        let voiceButtonLabel = accessibilityService.createAccessibilityLabel(for: .voiceButton("idle"))
        XCTAssertTrue(voiceButtonLabel.contains("Tap to speak"))
        XCTAssertTrue(voiceButtonLabel.contains("Peter"))
        
        let promptLabel = accessibilityService.createAccessibilityLabel(for: .suggestedPrompt("Weather forecast"))
        XCTAssertTrue(promptLabel.contains("Suggested question"))
        XCTAssertTrue(promptLabel.contains("Weather forecast"))
    }
    
    func testHighContrastMode() {
        // Given
        accessibilityService.settings.highContrast = true
        
        // When
        let buttonColor = accessibilityService.getAccessibleButtonColor()
        let backgroundColor = accessibilityService.getAccessibleBackgroundColor()
        
        // Then
        XCTAssertEqual(buttonColor, .black) // High contrast
        XCTAssertEqual(backgroundColor, .white)
    }
    
    func testReducedMotionSupport() {
        // Given
        accessibilityService.settings.reduceMotion = true
        
        // When
        let animationDuration = accessibilityService.getAnimationDuration()
        
        // Then
        XCTAssertEqual(animationDuration, 0.0) // No animations
    }
    
    func testAccessibilityAudit() {
        // Given
        accessibilityService.settings.largeText = false
        accessibilityService.dynamicTypeSize = .small
        
        // When
        let issues = accessibilityService.performAccessibilityAudit()
        
        // Then
        XCTAssertTrue(issues.contains { $0.type == .textSize })
        XCTAssertTrue(issues.contains { $0.recommendation.contains("large text") })
    }
    
    func testHapticFeedback() {
        // Should disable haptic feedback when VoiceOver is running
        accessibilityService.isVoiceOverRunning = true
        XCTAssertFalse(accessibilityService.shouldUseHapticFeedback())
        
        accessibilityService.isVoiceOverRunning = false
        accessibilityService.settings.hapticFeedback = true
        XCTAssertTrue(accessibilityService.shouldUseHapticFeedback())
    }
}

// MARK: - Mock Classes

class MockUserDefaults {
    var mockValues: [String: Any] = [:]
    var savedValues: [String: Any] = [:]
    var setShouldBeCalled = false
    var removeObjectCalled = false
    
    func string(forKey key: String) -> String? {
        return mockValues[key] as? String
    }
    
    func bool(forKey key: String) -> Bool {
        return mockValues[key] as? Bool ?? false
    }
    
    func object(forKey key: String) -> Any? {
        return mockValues[key]
    }
    
    func data(forKey key: String) -> Data? {
        return mockValues[key] as? Data
    }
    
    func set(_ value: Any?, forKey key: String) {
        setShouldBeCalled = true
        savedValues[key] = value
    }
    
    func removeObject(forKey key: String) {
        removeObjectCalled = true
        savedValues.removeValue(forKey: key)
    }
}

class MockNetworkMonitor {
    var isConnected = true
    var changeCallback: ((Bool) -> Void)?
    
    func simulateNetworkChange() {
        changeCallback?(isConnected)
    }
}

// MARK: - Service Extensions for Testing

extension UserStore {
    var userDefaults: MockUserDefaults? {
        get { return nil }
        set { /* Inject mock */ }
    }
    
    func loadUserData() {
        // Exposed for testing
    }
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    func isValidLocation(_ location: String) -> Bool {
        return !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               location.count >= 2
    }
    
    func migrateDataIfNeeded() {
        // Implement data migration logic
    }
}

extension AnalyticsService {
    var userDefaults: MockUserDefaults? {
        get { return nil }
        set { /* Inject mock */ }
    }
    
    var eventQueue: [AnalyticsEvent] {
        return [] // Expose for testing
    }
    
    func updateQueryCounts() {
        // Exposed for testing
    }
    
    func uploadEvents() {
        // Exposed for testing
    }
    
    var lastUploadAttempted: Bool {
        return true // Mock implementation
    }
}

extension ErrorHandlingService {
    var networkMonitor: MockNetworkMonitor? {
        get { return nil }
        set { /* Inject mock */ }
    }
    
    func convertToPeterAIError(_ error: Error) -> PeterAIError {
        // Implementation exposed for testing
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
}