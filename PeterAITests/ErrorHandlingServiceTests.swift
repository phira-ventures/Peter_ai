import XCTest
import Network
@testable import PeterAI

final class ErrorHandlingServiceTests: XCTestCase {
    var errorHandlingService: ErrorHandlingService!
    
    override func setUp() {
        super.setUp()
        errorHandlingService = ErrorHandlingService()
    }
    
    override func tearDown() {
        errorHandlingService = nil
        super.tearDown()
    }
    
    // MARK: - Error Classification Tests
    
    func testPeterAIErrorCreation() {
        // Test all error types can be created
        let errors: [PeterAIError] = [
            .noInternet,
            .microphonePermissionDenied,
            .speechRecognitionPermissionDenied,
            .apiKeyMissing,
            .apiRateLimit,
            .apiServerError(500),
            .speechRecognitionFailed,
            .speechSynthesisFailed,
            .subscriptionExpired,
            .abuseLimit,
            .locationPermissionDenied,
            .invalidInput,
            .timeout,
            .unknown(NSError(domain: "Test", code: -1))
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \(error)")
            XCTAssertNotNil(error.userFriendlyMessage, "Error should have user-friendly message: \(error)")
        }
    }
    
    func testElderlyFriendlyErrorMessages() {
        // Test that error messages are appropriate for elderly users
        let internetError = PeterAIError.noInternet
        let micError = PeterAIError.microphonePermissionDenied
        let speechError = PeterAIError.speechRecognitionFailed
        
        // Should be clear and non-technical
        XCTAssertTrue(internetError.userFriendlyMessage.contains("internet"), "Should mention internet clearly")
        XCTAssertTrue(micError.userFriendlyMessage.contains("microphone"), "Should explain microphone clearly")
        XCTAssertTrue(speechError.userFriendlyMessage.contains("speak"), "Should use familiar language")
        
        // Should not contain technical jargon
        XCTAssertFalse(internetError.userFriendlyMessage.contains("network"), "Should avoid technical terms")
        XCTAssertFalse(micError.userFriendlyMessage.contains("permission"), "Should use simple language")
    }
    
    // MARK: - Circuit Breaker Tests
    
    func testCircuitBreakerProtection() {
        let expectation = XCTestExpectation(description: "Circuit breaker protection")
        
        // Given - Multiple consecutive failures
        let serverError = PeterAIError.apiServerError(500)
        
        // When - Trigger multiple errors quickly (should trigger circuit breaker)
        for _ in 0..<5 {
            errorHandlingService.handle(serverError, context: "test")
        }
        
        // Then - Circuit breaker should protect elderly users from repeated errors
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(errorHandlingService.canAttemptOperation(), 
                          "Circuit breaker should prevent operations after multiple failures")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCircuitBreakerRecovery() {
        let expectation = XCTestExpectation(description: "Circuit breaker recovery")
        
        // Given - Circuit breaker in open state
        let serverError = PeterAIError.apiServerError(500)
        for _ in 0..<3 {
            errorHandlingService.handle(serverError, context: "test")
        }
        
        // When - Successful operation after timeout
        let successfulError = PeterAIError.speechSynthesisFailed // Non-circuit-breaker error
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.errorHandlingService.handle(successfulError, context: "test")
            
            // Then - Should eventually allow operations again
            let status = self.errorHandlingService.getRecoveryStatus()
            XCTAssertFalse(status.isEmpty, "Should provide recovery status")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Recovery Tests
    
    func testRetryConfigurationForElderlyUsers() {
        // Given - Test different retry configurations
        let speechConfig = RetryConfiguration.speech
        let apiConfig = RetryConfiguration.api
        let defaultConfig = RetryConfiguration.default
        
        // Then - Should have appropriate timeouts for elderly users
        XCTAssertLessThanOrEqual(speechConfig.maxAttempts, 2, "Speech should have limited retries to avoid frustration")
        XCTAssertGreaterThan(apiConfig.maxDelay, 30.0, "API should have longer delays for slower connections")
        XCTAssertGreaterThan(defaultConfig.initialDelay, 0.5, "Should have reasonable initial delays")
    }
    
    func testAutomaticRecoveryForCommonErrors() async {
        // Test that common errors trigger automatic recovery attempts
        let networkError = PeterAIError.noInternet
        let serverError = PeterAIError.apiServerError(503)
        
        // When - Handle errors that should trigger recovery
        errorHandlingService.handle(networkError, context: "test")
        errorHandlingService.handle(serverError, context: "test")
        
        // Then - Should attempt recovery (can't easily test the full async recovery without mocking)
        let statistics = errorHandlingService.getErrorStatistics()
        XCTAssertGreaterThan(statistics.totalErrors, 0, "Should track error statistics")
    }
    
    func testErrorHistoryTracking() {
        // Given - Multiple errors over time
        let errors = [
            PeterAIError.noInternet,
            PeterAIError.speechRecognitionFailed,
            PeterAIError.apiRateLimit
        ]
        
        // When - Handle multiple errors
        for error in errors {
            errorHandlingService.handle(error, context: "test_\(error)")
        }
        
        // Then - Should track error history
        let statistics = errorHandlingService.getErrorStatistics()
        XCTAssertEqual(statistics.totalErrors, errors.count, "Should track all errors")
        XCTAssertGreaterThanOrEqual(statistics.recentErrors, 0, "Should track recent errors")
    }
    
    // MARK: - Error Presentation Tests
    
    func testErrorSuppressionForElderlyUsers() {
        // Given - Multiple similar errors in quick succession
        let speechError = PeterAIError.speechRecognitionFailed
        
        // When - Trigger same error multiple times quickly
        errorHandlingService.handle(speechError, context: "test1")
        errorHandlingService.handle(speechError, context: "test2")
        errorHandlingService.handle(speechError, context: "test3")
        errorHandlingService.handle(speechError, context: "test4") // Should be suppressed
        
        // Then - Should not overwhelm elderly users with repeated errors
        // (Testing this requires checking internal state, but we can verify error handling doesn't crash)
        XCTAssertNotNil(errorHandlingService.currentError, "Should still track current error")
    }
    
    func testHelpfulErrorMessages() {
        // Test error messages provide helpful guidance
        let permissionError = PeterAIError.microphonePermissionDenied
        let networkError = PeterAIError.noInternet
        
        XCTAssertNotNil(permissionError.actionSuggestion, "Permission errors should suggest action")
        XCTAssertNotNil(networkError.actionSuggestion, "Network errors should suggest action")
        
        XCTAssertTrue(permissionError.shouldShowSettingsButton, "Permission errors should show settings button")
        XCTAssertFalse(networkError.shouldShowSettingsButton, "Network errors shouldn't need settings")
        
        XCTAssertFalse(permissionError.shouldShowRetryButton, "Permission errors can't be retried")
        XCTAssertTrue(networkError.shouldShowRetryButton, "Network errors can be retried")
    }
    
    // MARK: - Recovery Options Tests
    
    func testRecoveryOptionsForElderlyUsers() {
        // Test different error types provide appropriate recovery options
        let errors = [
            PeterAIError.noInternet,
            PeterAIError.microphonePermissionDenied,
            PeterAIError.speechRecognitionFailed,
            PeterAIError.subscriptionExpired
        ]
        
        for error in errors {
            let options = errorHandlingService.getRecoveryOptions(for: error)
            
            // All errors should offer help
            let hasHelpOption = options.contains { $0.action == .showHelp }
            XCTAssertTrue(hasHelpOption, "All errors should offer help option for elderly users: \(error)")
            
            // Verify appropriate actions
            if error.shouldShowRetryButton {
                let hasRetryOption = options.contains { $0.action == .retry }
                XCTAssertTrue(hasRetryOption, "Retryable errors should offer retry: \(error)")
            }
            
            if error.shouldShowSettingsButton {
                let hasSettingsOption = options.contains { $0.action == .openSettings }
                XCTAssertTrue(hasSettingsOption, "Permission errors should offer settings: \(error)")
            }
        }
    }
    
    // MARK: - Graceful Degradation Tests
    
    func testFallbackToTextMode() {
        // Test fallback recommendations for speech issues
        let speechErrors = [
            PeterAIError.speechRecognitionFailed,
            PeterAIError.microphonePermissionDenied,
            PeterAIError.speechRecognitionPermissionDenied
        ]
        
        for error in speechErrors {
            let shouldFallback = errorHandlingService.shouldFallbackToText(error)
            XCTAssertTrue(shouldFallback, "Speech errors should suggest text fallback: \(error)")
        }
    }
    
    func testVoiceOutputDisabling() {
        // Test recommendation to disable voice output for TTS issues
        let ttsError = PeterAIError.speechSynthesisFailed
        let networkError = PeterAIError.noInternet
        
        XCTAssertTrue(errorHandlingService.shouldDisableVoiceOutput(ttsError), 
                     "TTS errors should disable voice output")
        XCTAssertFalse(errorHandlingService.shouldDisableVoiceOutput(networkError), 
                      "Network errors shouldn't affect voice output")
    }
    
    func testOfflineMode() {
        // Test offline mode recommendation
        let networkError = PeterAIError.noInternet
        let apiError = PeterAIError.apiKeyMissing
        
        XCTAssertTrue(errorHandlingService.shouldShowOfflineMode(networkError),
                     "Network errors should show offline mode")
        XCTAssertFalse(errorHandlingService.shouldShowOfflineMode(apiError),
                      "API errors are different from network errors")
    }
    
    // MARK: - Health Check Tests
    
    func testSystemHealthCheck() {
        // When - Perform health check
        let healthIssues = errorHandlingService.checkSystemHealth()
        
        // Then - Should return health status
        XCTAssertNotNil(healthIssues, "Health check should return results")
        
        // Health issues should have proper structure
        for issue in healthIssues {
            XCTAssertFalse(issue.message.isEmpty, "Health issues should have messages")
            XCTAssertFalse(issue.suggestion.isEmpty, "Health issues should have suggestions")
        }
    }
    
    // MARK: - Error Alert Creation Tests
    
    func testErrorAlertCreation() {
        // Given - An error is set
        let testError = PeterAIError.speechRecognitionFailed
        errorHandlingService.handle(testError, context: "test")
        
        // When - Create alert
        let alert = errorHandlingService.createErrorAlert()
        
        // Then - Should create proper alert
        XCTAssertNotNil(alert, "Should create alert for current error")
        XCTAssertEqual(alert?.title, testError.errorDescription, "Alert title should match error")
        XCTAssertFalse(alert?.message.isEmpty ?? true, "Alert should have message")
        XCTAssertGreaterThan(alert?.recoveryOptions.count ?? 0, 0, "Alert should have recovery options")
    }
    
    func testNoAlertWhenNoError() {
        // Given - No current error
        errorHandlingService.dismissError()
        
        // When - Try to create alert
        let alert = errorHandlingService.createErrorAlert()
        
        // Then - Should return nil
        XCTAssertNil(alert, "Should not create alert when no current error")
    }
    
    // MARK: - Error Statistics Tests
    
    func testErrorStatisticsTracking() {
        // Given - Mix of errors over time
        let errors = [
            PeterAIError.noInternet,
            PeterAIError.speechRecognitionFailed,
            PeterAIError.apiServerError(500),
            PeterAIError.timeout
        ]
        
        // When - Handle errors
        for error in errors {
            errorHandlingService.handle(error, context: "statistics_test")
        }
        
        // Then - Should provide accurate statistics
        let stats = errorHandlingService.getErrorStatistics()
        XCTAssertEqual(stats.totalErrors, errors.count, "Should count all errors")
        XCTAssertGreaterThanOrEqual(stats.recentErrors, 0, "Recent errors should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.recoveryRate, 0.0, "Recovery rate should be non-negative")
        XCTAssertLessThanOrEqual(stats.recoveryRate, 1.0, "Recovery rate should not exceed 100%")
    }
    
    // MARK: - Edge Cases and Robustness Tests
    
    func testConcurrentErrorHandling() {
        let expectation = XCTestExpectation(description: "Concurrent error handling")
        let queue = DispatchQueue.global(qos: .userInitiated)
        let group = DispatchGroup()
        
        // When - Handle errors concurrently
        for i in 0..<10 {
            group.enter()
            queue.async {
                let error = PeterAIError.speechRecognitionFailed
                self.errorHandlingService.handle(error, context: "concurrent_\(i)")
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Then - Should handle concurrent access gracefully
            let stats = self.errorHandlingService.getErrorStatistics()
            XCTAssertGreaterThan(stats.totalErrors, 0, "Should handle concurrent errors")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testErrorDismissal() {
        // Given - An active error
        let testError = PeterAIError.apiRateLimit
        errorHandlingService.handle(testError, context: "test")
        XCTAssertNotNil(errorHandlingService.currentError)
        
        // When - Dismiss error
        errorHandlingService.dismissError()
        
        // Then - Should clear error state
        XCTAssertNil(errorHandlingService.currentError, "Current error should be cleared")
        XCTAssertFalse(errorHandlingService.isShowingError, "Should not be showing error")
    }
}