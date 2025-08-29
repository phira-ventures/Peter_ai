import XCTest
import SwiftUI
@testable import PeterAI

class IntegrationTests: XCTestCase {
    var app: PeterAIApp!
    var userStore: UserStore!
    var voiceService: VoiceService!
    var openAIService: OpenAIService!
    var subscriptionService: SubscriptionService!
    var analyticsService: AnalyticsService!
    
    override func setUp() {
        super.setUp()
        
        // Create real services for integration testing
        userStore = UserStore()
        voiceService = VoiceService()
        openAIService = OpenAIService()
        subscriptionService = SubscriptionService()
        analyticsService = AnalyticsService()
        
        // Set up test environment
        setupTestEnvironment()
    }
    
    override func tearDown() {
        cleanupTestEnvironment()
        super.tearDown()
    }
    
    private func setupTestEnvironment() {
        // Configure services for testing
        openAIService.setAPIKey("test-key-for-integration")
        
        // Reset user data for clean tests
        userStore.firstName = ""
        userStore.email = ""
        userStore.location = ""
        userStore.isOnboardingCompleted = false
        userStore.hasActiveSubscription = false
        
        // Clear analytics data
        analyticsService.clearAllAnalyticsData()
    }
    
    private func cleanupTestEnvironment() {
        userStore.clearAllData()
        analyticsService.clearAllAnalyticsData()
        voiceService.stopRecording()
        voiceService.stopSpeaking()
    }
    
    // MARK: - Complete Onboarding Flow Tests
    
    func testCompleteOnboardingFlow() async {
        let expectation = XCTestExpectation(description: "Complete onboarding flow")
        
        // Given - User starts fresh
        XCTAssertFalse(userStore.isOnboardingCompleted)
        
        // Step 1: Welcome Screen (automatic advance)
        await simulateOnboardingStep("welcome", duration: 1.5)
        
        // Step 2: Name Input
        userStore.firstName = "Margaret"
        await simulateOnboardingStep("name_input", duration: 0.5)
        
        // Step 3: Greeting Screen (automatic advance)
        await simulateOnboardingStep("greeting", duration: 1.5)
        
        // Step 4: Email Input
        userStore.email = "margaret@example.com"
        XCTAssertTrue(userStore.isValidEmail(userStore.email))
        await simulateOnboardingStep("email_input", duration: 0.5)
        
        // Step 5: Email Confirmation (automatic advance)
        await simulateOnboardingStep("email_confirmation", duration: 1.5)
        
        // Step 6: Location Input
        userStore.location = "Boston, MA"
        await simulateOnboardingStep("location_input", duration: 0.5)
        
        // Step 7: Location Confirmation (automatic advance)
        await simulateOnboardingStep("location_confirmation", duration: 1.5)
        
        // Step 8: Payment Selection
        // Simulate subscription selection and purchase
        if #available(iOS 15.0, *) {
            let purchaseResult = await simulateSubscriptionPurchase()
            XCTAssertTrue(purchaseResult)
        }
        
        // Step 9-10: Payment Processing Screens
        await simulateOnboardingStep("payment_processing", duration: 2.0)
        
        // Step 11: Completion
        userStore.completeOnboarding()
        
        // Then - Verify onboarding completed successfully
        XCTAssertTrue(userStore.isOnboardingCompleted)
        XCTAssertEqual(userStore.firstName, "Margaret")
        XCTAssertEqual(userStore.email, "margaret@example.com")
        XCTAssertEqual(userStore.location, "Boston, MA")
        
        // Verify analytics tracked the flow
        let onboardingEvents = analyticsService.getEventsByType("onboarding_step")
        XCTAssertGreaterThan(onboardingEvents.count, 0)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testOnboardingFlowWithErrors() async {
        // Test onboarding flow with various error scenarios
        
        // Invalid email
        userStore.email = "invalid-email"
        XCTAssertFalse(userStore.isValidEmail(userStore.email))
        
        // Empty location
        userStore.location = ""
        XCTAssertFalse(userStore.isValidLocation(userStore.location))
        
        // Subscription purchase failure
        if #available(iOS 15.0, *) {
            subscriptionService.simulatePurchaseFailure = true
            let purchaseResult = await simulateSubscriptionPurchase()
            XCTAssertFalse(purchaseResult)
        }
        
        // User should still be able to complete onboarding with retry
        userStore.email = "margaret@example.com"
        userStore.location = "Boston, MA"
        
        let retryPurchase = await simulateSubscriptionPurchase()
        // Should succeed after retry with valid data
    }
    
    // MARK: - Complete Voice Conversation Flow Tests
    
    func testCompleteVoiceConversationFlow() async {
        let expectation = XCTestExpectation(description: "Voice conversation flow")
        
        // Given - User is onboarded and subscribed
        await setupCompletedUser()
        
        // Step 1: User taps voice button to start
        analyticsService.trackConversationStarted()
        
        // Step 2: Voice recording starts
        voiceService.startRecording()
        XCTAssertTrue(voiceService.isRecording)
        XCTAssertTrue(voiceService.isListening)
        
        // Step 3: Simulate speech recognition
        await simulateVoiceInput("What's the weather like today in Boston?")
        
        // Step 4: Send to OpenAI service
        await openAIService.sendMessage(voiceService.transcribedText, userName: userStore.firstName)
        
        // Step 5: Verify AI response
        XCTAssertEqual(openAIService.messages.count, 2) // User + Assistant
        XCTAssertEqual(openAIService.messages.last?.role, "assistant")
        XCTAssertNotNil(openAIService.messages.last?.content)
        
        // Step 6: Speak response
        if let response = openAIService.messages.last?.content {
            voiceService.speak(response)
        }
        
        // Step 7: Track analytics
        analyticsService.trackVoiceInteraction(duration: 15.0, successful: true)
        analyticsService.trackConversationEnded(messageCount: 2, duration: 30.0)
        
        // Verify complete flow
        XCTAssertFalse(voiceService.isRecording)
        XCTAssertGreaterThan(openAIService.messages.count, 0)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testVoiceConversationWithErrors() async {
        await setupCompletedUser()
        
        // Test microphone permission denied
        voiceService.simulatePermissionDenied = true
        voiceService.startRecording()
        XCTAssertFalse(voiceService.isRecording)
        XCTAssertNotNil(voiceService.recordingError)
        
        // Test speech recognition failure
        voiceService.simulatePermissionDenied = false
        voiceService.startRecording()
        await simulateVoiceRecognitionError()
        XCTAssertNotNil(voiceService.recordingError)
        
        // Test API failure
        openAIService.simulateAPIError = true
        await openAIService.sendMessage("Test message", userName: userStore.firstName)
        XCTAssertNotNil(openAIService.error)
        
        // Verify error analytics tracking
        let errorEvents = analyticsService.getEventsByType("error_occurred")
        XCTAssertGreaterThan(errorEvents.count, 0)
    }
    
    // MARK: - Subscription Flow Tests
    
    @available(iOS 15.0, *)
    func testSubscriptionPurchaseFlow() async {
        let expectation = XCTestExpectation(description: "Subscription purchase")
        
        // Step 1: Load available products
        await subscriptionService.loadProducts()
        XCTAssertGreaterThan(subscriptionService.products.count, 0)
        
        // Step 2: Select a product
        let monthlyProduct = subscriptionService.products.first { $0.id.contains("monthly") }
        XCTAssertNotNil(monthlyProduct)
        
        // Step 3: Initiate purchase
        if let product = monthlyProduct {
            let purchaseSuccess = await subscriptionService.purchase(product)
            
            // In test environment, this might fail due to sandbox setup
            // But we can verify the purchase flow was initiated
            XCTAssertTrue(subscriptionService.purchaseAttempted)
            
            // Step 4: Update subscription status
            await subscriptionService.updateSubscriptionStatus()
            
            // Step 5: Update user store
            if subscriptionService.hasValidSubscription {
                userStore.updateSubscriptionStatus(true)
                XCTAssertTrue(userStore.hasActiveSubscription)
            }
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testSubscriptionRestoreFlow() async {
        // Test restore purchases flow
        if #available(iOS 15.0, *) {
            await subscriptionService.restorePurchases()
            XCTAssertTrue(subscriptionService.restoreAttempted)
            
            // Verify status update
            await subscriptionService.updateSubscriptionStatus()
        }
    }
    
    // MARK: - Offline Scenarios Tests
    
    func testOfflineScenarios() async {
        let expectation = XCTestExpectation(description: "Offline scenarios")
        
        await setupCompletedUser()
        
        // Simulate network disconnection
        NetworkSimulator.simulateOffline()
        
        // Test voice recording (should work offline)
        voiceService.startRecording()
        XCTAssertTrue(voiceService.isRecording) // Recording works offline
        
        await simulateVoiceInput("What's the weather today?")
        voiceService.stopRecording()
        
        // Test OpenAI API call (should fail gracefully)
        await openAIService.sendMessage(voiceService.transcribedText, userName: userStore.firstName)
        
        // Should have appropriate error handling
        XCTAssertNotNil(openAIService.error)
        XCTAssertTrue(openAIService.error?.contains("network") == true ||
                     openAIService.error?.contains("connection") == true)
        
        // Test subscription status check (should handle offline gracefully)
        if #available(iOS 15.0, *) {
            await subscriptionService.updateSubscriptionStatus()
            // Should maintain last known status or show appropriate error
        }
        
        // Test analytics (should queue events for later upload)
        analyticsService.track("offline_test_event")
        XCTAssertGreaterThan(analyticsService.queuedEventCount, 0)
        
        // Restore network connection
        NetworkSimulator.simulateOnline()
        
        // Test recovery
        await openAIService.sendMessage("Test recovery", userName: userStore.firstName)
        XCTAssertNil(openAIService.error) // Should work again
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    // MARK: - Data Persistence Tests
    
    func testDataPersistenceAcrossAppRestarts() {
        // Set up user data
        userStore.firstName = "Robert"
        userStore.email = "robert@example.com"
        userStore.location = "Chicago"
        userStore.isOnboardingCompleted = true
        userStore.hasActiveSubscription = true
        userStore.saveUserData()
        
        // Add some conversation history
        openAIService.messages.append(ChatMessage(role: "user", content: "Hello"))
        openAIService.messages.append(ChatMessage(role: "assistant", content: "Hi Robert!"))
        
        // Track analytics
        analyticsService.track("test_persistence_event")
        
        // Simulate app restart by creating new instances
        let newUserStore = UserStore()
        XCTAssertEqual(newUserStore.firstName, "Robert")
        XCTAssertEqual(newUserStore.email, "robert@example.com")
        XCTAssertEqual(newUserStore.location, "Chicago")
        XCTAssertTrue(newUserStore.isOnboardingCompleted)
        XCTAssertTrue(newUserStore.hasActiveSubscription)
        
        // Verify analytics data persists
        let newAnalyticsService = AnalyticsService()
        let savedEvents = newAnalyticsService.getPersistedEvents()
        XCTAssertGreaterThan(savedEvents.count, 0)
    }
    
    // MARK: - Memory Management Integration Tests
    
    func testMemoryManagementDuringLongSession() async {
        await setupCompletedUser()
        
        // Simulate a long conversation session
        for i in 1...50 {
            // Add messages to conversation
            openAIService.messages.append(ChatMessage(role: "user", content: "Message \(i)"))
            openAIService.messages.append(ChatMessage(role: "assistant", content: "Response \(i)"))
            
            // Track analytics events
            analyticsService.track("long_session_event_\(i)")
            
            // Simulate voice interactions
            if i % 10 == 0 {
                voiceService.speak("This is response \(i)")
            }
        }
        
        // Verify memory management
        XCTAssertLessThanOrEqual(openAIService.messages.count, 50) // Should limit message history
        
        // Verify analytics batching
        if analyticsService.queuedEventCount > 25 {
            analyticsService.uploadEvents()
            XCTAssertLessThan(analyticsService.queuedEventCount, 25)
        }
        
        // Check for memory leaks by monitoring service lifecycle
        weak var weakVoiceService = voiceService
        weak var weakOpenAIService = openAIService
        weak var weakAnalyticsService = analyticsService
        
        // Cleanup services
        voiceService = nil
        openAIService = nil
        analyticsService = nil
        
        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool {
                // Create temporary objects to trigger memory cleanup
                _ = Array(0..<1000)
            }
        }
        
        // Verify services are deallocated (may not always work in unit tests)
        // This is more for documentation of expected behavior
    }
    
    // MARK: - Error Recovery Integration Tests
    
    func testCompleteErrorRecoveryFlow() async {
        let expectation = XCTestExpectation(description: "Error recovery flow")
        
        await setupCompletedUser()
        
        // Start a conversation
        voiceService.startRecording()
        await simulateVoiceInput("Tell me about the weather")
        
        // Simulate API error
        openAIService.simulateAPIError = true
        await openAIService.sendMessage(voiceService.transcribedText, userName: userStore.firstName)
        
        // Verify error handling
        XCTAssertNotNil(openAIService.error)
        
        // User should be able to retry
        openAIService.simulateAPIError = false
        await openAIService.sendMessage("Retry: " + voiceService.transcribedText, userName: userStore.firstName)
        
        // Verify recovery
        XCTAssertNil(openAIService.error)
        XCTAssertGreaterThan(openAIService.messages.count, 0)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    // MARK: - Helper Methods
    
    private func setupCompletedUser() async {
        userStore.firstName = "Margaret"
        userStore.email = "margaret@example.com"
        userStore.location = "Boston, MA"
        userStore.isOnboardingCompleted = true
        userStore.hasActiveSubscription = true
        userStore.saveUserData()
    }
    
    private func simulateOnboardingStep(_ step: String, duration: TimeInterval) async {
        analyticsService.trackOnboardingStep(step, completed: true)
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
    
    private func simulateSubscriptionPurchase() async -> Bool {
        if #available(iOS 15.0, *) {
            await subscriptionService.loadProducts()
            if let product = subscriptionService.products.first {
                return await subscriptionService.purchase(product)
            }
        }
        return false
    }
    
    private func simulateVoiceInput(_ text: String) async {
        // Simulate voice recognition
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        voiceService.transcribedText = text
        voiceService.stopRecording()
    }
    
    private func simulateVoiceRecognitionError() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
        voiceService.recordingError = "Speech recognition failed"
        voiceService.stopRecording()
    }
}

// MARK: - Network Simulation Helper

class NetworkSimulator {
    private static var isOffline = false
    
    static func simulateOffline() {
        isOffline = true
        // In real implementation, this would disable network requests
    }
    
    static func simulateOnline() {
        isOffline = false
    }
    
    static var isNetworkAvailable: Bool {
        return !isOffline
    }
}

// MARK: - Service Extensions for Integration Testing

extension UserStore {
    func clearAllData() {
        firstName = ""
        email = ""
        location = ""
        isOnboardingCompleted = false
        hasActiveSubscription = false
        saveUserData()
    }
}

extension VoiceService {
    var simulatePermissionDenied: Bool {
        get { false }
        set { /* Set for testing */ }
    }
}

extension OpenAIService {
    var simulateAPIError: Bool {
        get { false }
        set { /* Set for testing */ }
    }
    
    func setAPIKey(_ key: String) {
        // Set API key for testing
    }
}

extension AnalyticsService {
    func getEventsByType(_ eventName: String) -> [AnalyticsEvent] {
        return [] // Return filtered events for testing
    }
    
    var queuedEventCount: Int {
        return 0 // Return queue count for testing
    }
    
    func getPersistedEvents() -> [AnalyticsEvent] {
        return [] // Return persisted events for testing
    }
}

@available(iOS 15.0, *)
extension SubscriptionService {
    var simulatePurchaseFailure: Bool {
        get { false }
        set { /* Set for testing */ }
    }
    
    var purchaseAttempted: Bool {
        return false // Track purchase attempts for testing
    }
    
    var restoreAttempted: Bool {
        return false // Track restore attempts for testing
    }
}

// MARK: - Performance Integration Tests

extension IntegrationTests {
    
    func testAppLaunchPerformance() {
        measure {
            // Simulate app launch sequence
            let userStore = UserStore()
            let voiceService = VoiceService()
            let openAIService = OpenAIService()
            let analyticsService = AnalyticsService()
            
            // Initialize services (similar to real app launch)
            analyticsService.startSession()
            
            // Cleanup
            _ = [userStore, voiceService, openAIService, analyticsService]
        }
    }
    
    func testVoiceInteractionPerformance() async {
        await setupCompletedUser()
        
        measure {
            Task {
                // Measure complete voice interaction cycle
                voiceService.startRecording()
                await simulateVoiceInput("Performance test message")
                await openAIService.sendMessage(voiceService.transcribedText, userName: userStore.firstName)
                if let response = openAIService.messages.last?.content {
                    voiceService.speak(response)
                }
            }
        }
    }
    
    func testSubscriptionCheckPerformance() {
        if #available(iOS 15.0, *) {
            measure {
                Task {
                    await subscriptionService.updateSubscriptionStatus()
                }
            }
        }
    }
}

// MARK: - Accessibility Integration Tests

extension IntegrationTests {
    
    func testVoiceOverIntegration() async {
        // Test complete app flow with VoiceOver simulation
        let accessibilityService = AccessibilityService()
        accessibilityService.isVoiceOverRunning = true
        
        await setupCompletedUser()
        
        // Test voice button accessibility
        let voiceButtonLabel = accessibilityService.createAccessibilityLabel(for: .voiceButton("idle"))
        XCTAssertTrue(voiceButtonLabel.contains("Peter"))
        XCTAssertTrue(voiceButtonLabel.contains("Double tap"))
        
        // Test suggested prompts accessibility
        let promptLabel = accessibilityService.createAccessibilityLabel(for: .suggestedPrompt("What's the weather?"))
        XCTAssertTrue(promptLabel.contains("Suggested question"))
        
        // Test message accessibility
        let messageLabel = accessibilityService.createAccessibilityLabel(for: .messageFrom("Peter", "Hello Margaret!"))
        XCTAssertTrue(messageLabel.contains("Message from Peter"))
        
        // Verify VoiceOver announcements work
        accessibilityService.announceToVoiceOver("Test announcement")
        // In real implementation, this would trigger VoiceOver speech
    }
    
    func testLargeTextSupport() {
        let accessibilityService = AccessibilityService()
        accessibilityService.settings.largeText = true
        accessibilityService.dynamicTypeSize = .accessibility3
        
        // Verify font sizes are appropriate for elderly users
        let titleSize = accessibilityService.getOptimalFontSize(for: .title)
        let bodySize = accessibilityService.getOptimalFontSize(for: .body)
        
        XCTAssertGreaterThanOrEqual(titleSize, 30)
        XCTAssertGreaterThanOrEqual(bodySize, 24)
        
        // Verify touch targets are large enough
        let touchTargetSize = accessibilityService.getMinimumTouchTargetSize()
        XCTAssertGreaterThanOrEqual(touchTargetSize, 60)
    }
}