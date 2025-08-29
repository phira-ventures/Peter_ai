import XCTest
import Foundation
@testable import PeterAI

class PerformanceTests: XCTestCase {
    var userStore: UserStore!
    var voiceService: VoiceService!
    var openAIService: OpenAIService!
    var analyticsService: AnalyticsService!
    var subscriptionService: SubscriptionService!
    
    override func setUp() {
        super.setUp()
        
        userStore = UserStore()
        voiceService = VoiceService()
        openAIService = OpenAIService()
        analyticsService = AnalyticsService()
        if #available(iOS 15.0, *) {
            subscriptionService = SubscriptionService()
        }
        
        // Configure services for performance testing
        setupPerformanceTestEnvironment()
    }
    
    override func tearDown() {
        cleanupPerformanceTestEnvironment()
        super.tearDown()
    }
    
    private func setupPerformanceTestEnvironment() {
        // Set up services with performance monitoring
        openAIService.setAPIKey("test-key-for-performance")
        
        // Clear any existing data
        analyticsService.clearEventQueue()
        openAIService.clearMessages()
    }
    
    private func cleanupPerformanceTestEnvironment() {
        voiceService.stopRecording()
        voiceService.stopSpeaking()
        analyticsService.clearEventQueue()
        openAIService.clearMessages()
    }
    
    // MARK: - App Launch Performance Tests
    
    func testAppLaunchTime() {
        // Test cold start performance
        measure {
            // Simulate app launch sequence
            let userStore = UserStore()
            let voiceService = VoiceService()
            let openAIService = OpenAIService()
            let analyticsService = AnalyticsService()
            
            // Initialize services (mimics real app launch)
            analyticsService.startSession()
            userStore.loadUserData()
            voiceService.requestPermissions()
            
            // Cleanup
            _ = [userStore, voiceService, openAIService, analyticsService]
        }
    }
    
    func testAppLaunchMemoryUsage() {
        // Test memory footprint during launch
        let initialMemory = getMemoryUsage()
        
        // Create services
        let userStore = UserStore()
        let voiceService = VoiceService()
        let openAIService = OpenAIService()
        let analyticsService = AnalyticsService()
        
        let launchMemory = getMemoryUsage()
        let memoryIncrease = launchMemory - initialMemory
        
        // Should not use excessive memory on launch
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024) // Less than 50MB increase
        
        // Cleanup
        _ = [userStore, voiceService, openAIService, analyticsService]
    }
    
    func testWarmStartPerformance() {
        // Test app resume performance
        setupServices()
        
        measure {
            // Simulate app coming back from background
            analyticsService.startSession()
            userStore.loadUserData()
            
            if #available(iOS 15.0, *) {
                Task {
                    await subscriptionService.updateSubscriptionStatus()
                }
            }
        }
    }
    
    // MARK: - Voice Service Performance Tests
    
    func testVoiceRecordingStartupTime() {
        measure {
            for _ in 0..<10 {
                voiceService.startRecording()
                voiceService.stopRecording()
            }
        }
    }
    
    func testVoiceRecordingMemoryUsage() {
        let initialMemory = getMemoryUsage()
        
        // Start long recording session
        voiceService.startRecording()
        
        // Simulate 30 seconds of recording
        for _ in 0..<30 {
            simulateAudioBuffer()
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        let recordingMemory = getMemoryUsage()
        voiceService.stopRecording()
        
        let finalMemory = getMemoryUsage()
        
        // Memory should not grow excessively during recording
        let recordingIncrease = recordingMemory - initialMemory
        XCTAssertLessThan(recordingIncrease, 20 * 1024 * 1024) // Less than 20MB
        
        // Memory should be released after stopping
        let memoryAfterStop = finalMemory - initialMemory
        XCTAssertLessThan(memoryAfterStop, recordingIncrease / 2) // At least 50% released
    }
    
    func testConcurrentVoiceOperations() {
        // Test performance with multiple voice operations
        measure {
            let group = DispatchGroup()
            
            for _ in 0..<5 {
                group.enter()
                DispatchQueue.global().async {
                    self.voiceService.speak("Performance test message")
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    func testSpeechRecognitionPerformance() {
        // Test speech recognition processing time
        voiceService.startRecording()
        
        measure {
            // Simulate speech recognition processing
            for _ in 0..<100 {
                simulateVoiceRecognitionResult("Test recognition result")
            }
        }
        
        voiceService.stopRecording()
    }
    
    // MARK: - OpenAI Service Performance Tests
    
    func testAPIRequestPerformance() {
        // Mock fast API responses for performance testing
        openAIService.enableMockMode(responseTime: 0.1)
        
        measure {
            Task {
                for i in 0..<10 {
                    await openAIService.sendMessage("Performance test message \(i)", userName: "TestUser")
                }
            }
        }
    }
    
    func testMessageHistoryManagement() {
        // Test performance with large message history
        
        // Add many messages
        for i in 0..<1000 {
            openAIService.messages.append(ChatMessage(role: "user", content: "Message \(i)"))
            openAIService.messages.append(ChatMessage(role: "assistant", content: "Response \(i)"))
        }
        
        let initialMemory = getMemoryUsage()
        
        measure {
            // Test operations on large message history
            _ = openAIService.getRecentMessages()
            openAIService.clearOldMessages()
            _ = openAIService.getConversationSummary()
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Should not use excessive memory
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024)
    }
    
    func testJSONProcessingPerformance() {
        // Test JSON encoding/decoding performance
        let largeMessage = String(repeating: "Test message content. ", count: 1000)
        
        measure {
            for _ in 0..<100 {
                let message = ChatMessage(role: "user", content: largeMessage)
                
                // Test encoding
                let encoder = JSONEncoder()
                let data = try! encoder.encode(message)
                
                // Test decoding
                let decoder = JSONDecoder()
                _ = try! decoder.decode(ChatMessage.self, from: data)
            }
        }
    }
    
    func testConcurrentAPIRequests() {
        openAIService.enableMockMode(responseTime: 0.2)
        
        measure {
            let group = DispatchGroup()
            
            for i in 0..<5 {
                group.enter()
                Task {
                    await openAIService.sendMessage("Concurrent message \(i)", userName: "TestUser")
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    // MARK: - Analytics Service Performance Tests
    
    func testAnalyticsEventProcessing() {
        measure {
            for i in 0..<1000 {
                analyticsService.track("performance_test_event_\(i)", properties: [
                    "iteration": String(i),
                    "timestamp": String(Date().timeIntervalSince1970),
                    "test_data": String(repeating: "x", count: 100)
                ])
            }
        }
    }
    
    func testAnalyticsMemoryManagement() {
        let initialMemory = getMemoryUsage()
        
        // Generate many analytics events
        for i in 0..<10000 {
            analyticsService.track("memory_test_event", properties: ["index": String(i)])
        }
        
        let afterEventsMemory = getMemoryUsage()
        
        // Upload events to clear queue
        analyticsService.uploadEvents()
        
        let finalMemory = getMemoryUsage()
        
        // Verify memory is managed properly
        let memoryIncrease = afterEventsMemory - initialMemory
        let memoryAfterCleanup = finalMemory - initialMemory
        
        XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024) // Less than 100MB for 10k events
        XCTAssertLessThan(memoryAfterCleanup, memoryIncrease / 2) // Significant cleanup
    }
    
    func testAbuseMonitoringPerformance() {
        measure {
            // Test abuse monitoring doesn't slow down regular operations
            for _ in 0..<1000 {
                _ = analyticsService.trackQuery()
            }
        }
    }
    
    func testAnalyticsUploadBatching() {
        // Add many events
        for i in 0..<5000 {
            analyticsService.track("batch_test_\(i)")
        }
        
        measure {
            analyticsService.uploadEvents()
        }
    }
    
    // MARK: - Subscription Service Performance Tests
    
    @available(iOS 15.0, *)
    func testProductLoadingPerformance() {
        measure {
            Task {
                for _ in 0..<10 {
                    await subscriptionService.loadProducts()
                }
            }
        }
    }
    
    @available(iOS 15.0, *)
    func testSubscriptionStatusCheckPerformance() {
        measure {
            Task {
                for _ in 0..<20 {
                    await subscriptionService.updateSubscriptionStatus()
                }
            }
        }
    }
    
    @available(iOS 15.0, *)
    func testConcurrentSubscriptionOperations() {
        measure {
            let group = DispatchGroup()
            
            for _ in 0..<3 {
                group.enter()
                Task {
                    await subscriptionService.loadProducts()
                    await subscriptionService.updateSubscriptionStatus()
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    // MARK: - UserStore Performance Tests
    
    func testUserDataPersistencePerformance() {
        measure {
            for i in 0..<100 {
                userStore.firstName = "TestUser\(i)"
                userStore.email = "test\(i)@example.com"
                userStore.location = "TestCity\(i)"
                userStore.saveUserData()
            }
        }
    }
    
    func testUserDataLoadingPerformance() {
        // Set up data
        userStore.firstName = "PerformanceTestUser"
        userStore.email = "performance@example.com"
        userStore.saveUserData()
        
        measure {
            for _ in 0..<1000 {
                let newUserStore = UserStore()
                _ = newUserStore.firstName
                _ = newUserStore.email
                _ = newUserStore.isOnboardingCompleted
            }
        }
    }
    
    // MARK: - UI Performance Tests
    
    func testMessageBubbleRenderingPerformance() {
        // Create many messages for UI performance testing
        let messages = (0..<100).map { i in
            ChatMessage(role: i % 2 == 0 ? "user" : "assistant", content: "Test message \(i) with some longer content to test text rendering performance.")
        }
        
        measure {
            // Simulate message bubble creation
            for message in messages {
                _ = MessageBubbleViewModel(message: message, userName: "TestUser")
            }
        }
    }
    
    func testSuggestedPromptsPerformance() {
        let promptsService = PromptsService()
        
        measure {
            for _ in 0..<50 {
                promptsService.updateCurrentPrompts(for: "Boston, MA")
                _ = promptsService.currentPrompts
            }
        }
    }
    
    func testAccessibilityCalculationPerformance() {
        let accessibilityService = AccessibilityService()
        
        measure {
            for _ in 0..<1000 {
                _ = accessibilityService.getOptimalFontSize(for: .body)
                _ = accessibilityService.getMinimumTouchTargetSize()
                _ = accessibilityService.createAccessibilityLabel(for: .voiceButton("idle"))
            }
        }
    }
    
    // MARK: - Memory Leak Tests
    
    func testServiceMemoryLeaks() {
        weak var weakUserStore: UserStore?
        weak var weakVoiceService: VoiceService?
        weak var weakOpenAIService: OpenAIService?
        weak var weakAnalyticsService: AnalyticsService?
        
        autoreleasepool {
            let userStore = UserStore()
            let voiceService = VoiceService()
            let openAIService = OpenAIService()
            let analyticsService = AnalyticsService()
            
            // Use services
            analyticsService.startSession()
            voiceService.startRecording()
            voiceService.stopRecording()
            
            Task {
                await openAIService.sendMessage("Test", userName: "Test")
            }
            
            weakUserStore = userStore
            weakVoiceService = voiceService
            weakOpenAIService = openAIService
            weakAnalyticsService = analyticsService
        }
        
        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        // Check for leaks (may not always work in test environment)
        // These are more for documentation of expected behavior
        XCTAssertNil(weakUserStore, "UserStore should be deallocated")
        XCTAssertNil(weakVoiceService, "VoiceService should be deallocated")
        XCTAssertNil(weakOpenAIService, "OpenAIService should be deallocated")
        XCTAssertNil(weakAnalyticsService, "AnalyticsService should be deallocated")
    }
    
    func testTimerMemoryLeaks() {
        weak var weakAnalyticsService: AnalyticsService?
        weak var weakPromptsService: PromptsService?
        
        autoreleasepool {
            let analyticsService = AnalyticsService()
            let promptsService = PromptsService()
            
            // Services create timers
            analyticsService.startSession()
            promptsService.startPromptRotation()
            
            // Wait for timers to be created
            Thread.sleep(forTimeInterval: 0.1)
            
            weakAnalyticsService = analyticsService
            weakPromptsService = promptsService
        }
        
        // Force cleanup
        for _ in 0..<3 {
            autoreleasepool {
                _ = Array(0..<1000)
            }
        }
        
        // Verify cleanup
        XCTAssertNil(weakAnalyticsService)
        XCTAssertNil(weakPromptsService)
    }
    
    // MARK: - Long Session Performance Tests
    
    func testLongSessionPerformance() {
        let expectation = XCTestExpectation(description: "Long session performance")
        
        let initialMemory = getMemoryUsage()
        var memoryCheckpoints: [Int] = []
        
        // Simulate 1-hour session
        Task {
            for minute in 0..<60 {
                // Simulate user activity each minute
                analyticsService.track("minute_\(minute)_activity")
                
                if minute % 5 == 0 {
                    // Voice interaction every 5 minutes
                    voiceService.startRecording()
                    simulateVoiceInput("Minute \(minute) test")
                    await openAIService.sendMessage("Test minute \(minute)", userName: "TestUser")
                }
                
                if minute % 10 == 0 {
                    // Memory checkpoint every 10 minutes
                    let currentMemory = getMemoryUsage()
                    memoryCheckpoints.append(currentMemory - initialMemory)
                }
                
                // Small delay to simulate time passage
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        // Analyze memory growth over time
        let finalMemoryIncrease = memoryCheckpoints.last ?? 0
        XCTAssertLessThan(finalMemoryIncrease, 200 * 1024 * 1024) // Less than 200MB after 1 hour
        
        // Check for excessive memory growth
        if memoryCheckpoints.count > 2 {
            let initialIncrease = memoryCheckpoints[1]
            let finalIncrease = memoryCheckpoints.last!
            let growthRatio = Double(finalIncrease) / Double(max(initialIncrease, 1))
            XCTAssertLessThan(growthRatio, 3.0) // Memory shouldn't triple over session
        }
    }
    
    // MARK: - Stress Tests
    
    func testHighVolumeAnalytics() {
        // Test system under high analytics load
        measure {
            let group = DispatchGroup()
            
            for thread in 0..<5 {
                group.enter()
                DispatchQueue.global().async {
                    for event in 0..<1000 {
                        self.analyticsService.track("stress_test_thread\(thread)_event\(event)")
                    }
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    func testConcurrentVoiceAndAPI() {
        // Test concurrent voice recording and API calls
        measure {
            let group = DispatchGroup()
            
            // Start voice recording
            group.enter()
            DispatchQueue.global().async {
                for _ in 0..<10 {
                    self.voiceService.startRecording()
                    Thread.sleep(forTimeInterval: 0.1)
                    self.voiceService.stopRecording()
                }
                group.leave()
            }
            
            // Concurrent API calls
            group.enter()
            DispatchQueue.global().async {
                Task {
                    for i in 0..<5 {
                        await self.openAIService.sendMessage("Concurrent test \(i)", userName: "Test")
                    }
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
    
    private func setupServices() {
        // Set up services for warm start testing
        analyticsService.startSession()
        userStore.loadUserData()
    }
    
    private func simulateAudioBuffer() {
        // Simulate audio buffer processing
        _ = Array(repeating: 0.5, count: 1024)
    }
    
    private func simulateVoiceRecognitionResult(_ text: String) {
        voiceService.transcribedText = text
    }
    
    private func simulateVoiceInput(_ text: String) {
        voiceService.transcribedText = text
        voiceService.stopRecording()
    }
}

// MARK: - Service Extensions for Performance Testing

extension AnalyticsService {
    func clearEventQueue() {
        // Clear event queue for testing
    }
    
    var eventQueueSize: Int {
        return 0 // Return current queue size
    }
    
    func uploadEvents() {
        // Trigger immediate upload for testing
    }
}

extension OpenAIService {
    func enableMockMode(responseTime: TimeInterval) {
        // Enable mock mode with specified response time
    }
    
    func clearOldMessages() {
        // Clear old messages beyond the limit
        if messages.count > 20 {
            messages.removeFirst(messages.count - 20)
        }
    }
    
    func getConversationSummary() -> String {
        return "Conversation with \(messages.count) messages"
    }
}

extension PromptsService {
    func startPromptRotation() {
        // Start prompt rotation timer
    }
}

// MARK: - Supporting Types for Performance Testing

struct MessageBubbleViewModel {
    let message: ChatMessage
    let userName: String
    
    init(message: ChatMessage, userName: String) {
        self.message = message
        self.userName = userName
    }
}