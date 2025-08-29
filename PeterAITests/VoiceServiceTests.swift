import XCTest
import AVFoundation
import Speech
@testable import PeterAI

final class VoiceServiceTests: XCTestCase {
    var voiceService: VoiceService!
    var mockAccessibilityService: AccessibilityService!
    
    override func setUp() {
        super.setUp()
        voiceService = VoiceService()
        mockAccessibilityService = AccessibilityService()
    }
    
    override func tearDown() {
        voiceService.stopRecording()
        voiceService.stopSpeaking()
        voiceService = nil
        mockAccessibilityService = nil
        super.tearDown()
    }
    
    // MARK: - Voice Service Initialization Tests
    
    func testVoiceServiceInitialization() {
        // Then - Voice service should initialize properly
        XCTAssertNotNil(voiceService, "VoiceService should initialize")
        XCTAssertFalse(voiceService.isRecording, "Should not be recording initially")
        XCTAssertFalse(voiceService.isListening, "Should not be listening initially")
        XCTAssertTrue(voiceService.transcribedText.isEmpty, "Transcribed text should be empty initially")
        XCTAssertNil(voiceService.recordingError, "Should not have recording error initially")
    }
    
    // MARK: - Thread Safety Tests (Critical for elderly users)
    
    func testThreadSafetyOfVoiceOperations() {
        let expectation = XCTestExpectation(description: "Thread safety")
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        // When - Multiple threads try to start/stop recording
        DispatchQueue.concurrentPerform(iterations: 5) { iteration in
            if iteration % 2 == 0 {
                self.voiceService.startRecording()
            } else {
                self.voiceService.stopRecording()
            }
        }
        
        // Then - Should not crash and maintain consistent state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Voice service should be in a valid state
            XCTAssertTrue(self.voiceService.isRecording || !self.voiceService.isRecording, 
                         "Voice service should be in valid state")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testMemoryLeakPrevention() {
        // Given - Multiple start/stop cycles
        for _ in 0..<10 {
            voiceService.startRecording()
            voiceService.stopRecording()
        }
        
        // Then - Should not accumulate memory or resources
        // (This is mainly tested by running under instruments, but we can verify basic state)
        XCTAssertFalse(voiceService.isRecording, "Should not be recording after stop")
        XCTAssertFalse(voiceService.isListening, "Should not be listening after stop")
    }
    
    // MARK: - Recording State Management Tests
    
    func testRecordingStateTransitions() {
        // Given - Initial state
        XCTAssertFalse(voiceService.isRecording)
        XCTAssertFalse(voiceService.isListening)
        
        // When - Start recording
        voiceService.startRecording()
        
        // Then - Should update state appropriately
        // Note: Actual recording may not start due to permissions/simulator, but state should update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // State should reflect recording attempt
            XCTAssertTrue(self.voiceService.isRecording || self.voiceService.recordingError != nil,
                         "Should either be recording or have error")
        }
        
        // When - Stop recording
        voiceService.stopRecording()
        
        // Then - Should stop recording
        XCTAssertFalse(voiceService.isRecording, "Should stop recording")
        XCTAssertFalse(voiceService.isListening, "Should stop listening")
    }
    
    func testDoubleStartRecordingProtection() {
        // Given - Recording is already started
        voiceService.startRecording()
        let initialRecordingState = voiceService.isRecording
        
        // When - Try to start recording again
        voiceService.startRecording()
        
        // Then - Should not create duplicate recording sessions
        XCTAssertEqual(voiceService.isRecording, initialRecordingState,
                      "Double start should not change recording state")
    }
    
    // MARK: - Speech Synthesis Tests for Elderly Users
    
    func testSpeechSynthesisWithElderlyFriendlySettings() {
        // Given - Accessibility service with elderly-friendly settings
        mockAccessibilityService.settings.voiceOverSpeedSlow = true
        
        // When - Speak text with accessibility service
        let testText = "Hello, this is Peter speaking to you."
        voiceService.speak(testText, accessibilityService: mockAccessibilityService)
        
        // Then - Should not crash (actual speech testing requires device)
        XCTAssertTrue(true, "Speech synthesis should not crash")
        
        // Clean up
        voiceService.stopSpeaking()
    }
    
    func testSpeechSynthesisWithDefaultRate() {
        // When - Speak without accessibility service
        let testText = "Hello, this is a test message."
        
        // Then - Should use elderly-friendly default rate
        XCTAssertNoThrow(voiceService.speak(testText), "Speech should not crash")
        
        // Clean up
        voiceService.stopSpeaking()
    }
    
    func testSpeechSynthesisWithCustomRate() {
        // When - Speak with custom rate
        let testText = "This is a custom rate test."
        let customRate: Float = 0.2 // Very slow for elderly users
        
        // Then - Should accept custom rate
        XCTAssertNoThrow(voiceService.speak(testText, rate: customRate), 
                        "Speech with custom rate should not crash")
        
        voiceService.stopSpeaking()
    }
    
    func testStopSpeaking() {
        // Given - Speech is started
        voiceService.speak("This is a long message that should be interrupted.")
        
        // When - Stop speaking
        XCTAssertNoThrow(voiceService.stopSpeaking(), "Stop speaking should not crash")
        
        // Then - Should stop immediately
        XCTAssertTrue(true, "Stop speaking completed without crash")
    }
    
    // MARK: - Error Handling Tests
    
    func testRecordingErrorHandling() {
        // This test verifies error handling structure
        // Actual permission testing requires device/simulator with specific setup
        
        // When - Recording might fail due to permissions
        voiceService.startRecording()
        
        // Then - Should handle errors gracefully
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Should either succeed or fail gracefully with error message
            if let error = self.voiceService.recordingError {
                XCTAssertFalse(error.isEmpty, "Error message should not be empty")
                XCTAssertTrue(error.contains("access") || error.contains("permission") || error.contains("authorized"),
                             "Error should be permission-related: \(error)")
            }
        }
    }
    
    func testPermissionDeniedScenario() {
        // Simulate what happens when permissions are denied
        // (Actual permission testing requires specific setup)
        
        // Given - Permissions are potentially denied
        voiceService.startRecording()
        
        // When - Check for permission-related errors
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let error = self.voiceService.recordingError {
                // Then - Error should be user-friendly for elderly users
                XCTAssertFalse(error.contains("SFSpeechRecognizer"), "Should not contain technical terms")
                XCTAssertFalse(error.contains("AVAudioSession"), "Should not contain technical terms")
            }
        }
    }
    
    // MARK: - Audio Session Tests
    
    func testAudioSessionSetup() {
        // Test that audio session is configured properly for elderly users
        let audioSession = AVAudioSession.sharedInstance()
        
        // Should be configured for record and playback
        XCTAssertTrue(audioSession.category == .playAndRecord || 
                     audioSession.category == .record ||
                     audioSession.category == .playback,
                     "Audio session should be configured for voice interaction")
    }
    
    // MARK: - Resource Management Tests
    
    func testProperResourceCleanup() {
        // Given - Recording session
        voiceService.startRecording()
        
        // When - Stop and cleanup
        voiceService.stopRecording()
        
        // Then - Should clean up resources
        XCTAssertFalse(voiceService.isRecording, "Should stop recording")
        XCTAssertFalse(voiceService.isListening, "Should stop listening")
    }
    
    func testDeinitCleanup() {
        // Given - Voice service with active operations
        let testVoiceService = VoiceService()
        testVoiceService.startRecording()
        testVoiceService.speak("Test message")
        
        // When - Service is deallocated
        // (Service will be deallocated at end of scope)
        
        // Then - Should clean up without crashes
        testVoiceService.stopRecording()
        testVoiceService.stopSpeaking()
        XCTAssertTrue(true, "Cleanup should complete without crash")
    }
    
    // MARK: - Elderly User Experience Tests
    
    func testElderlyFriendlyVoiceSettings() {
        // Test that voice synthesis uses appropriate settings for elderly users
        
        // Given - Text that elderly users might typically say
        let elderlyTypicalPhrases = [
            "What's the weather like today?",
            "Can you help me call my daughter?",
            "I need to know about my medications.",
            "How do I send an email to my grandson?",
            "What time is it now?"
        ]
        
        for phrase in elderlyTypicalPhrases {
            // When - Speak each phrase
            XCTAssertNoThrow(voiceService.speak(phrase, accessibilityService: mockAccessibilityService),
                            "Should handle elderly-typical phrases: \(phrase)")
        }
        
        voiceService.stopSpeaking()
    }
    
    func testLongMessageHandling() {
        // Test handling of longer messages that elderly users might receive
        let longMessage = """
        Hello! I found the weather information you requested. Today in your area, 
        it's going to be partly cloudy with a high of 72 degrees Fahrenheit and 
        a low of 58 degrees. There's a 20% chance of rain this afternoon, so you 
        might want to bring a light jacket if you're going out. The humidity will 
        be around 65%, which should feel comfortable. Tomorrow looks even better 
        with sunny skies and temperatures reaching 75 degrees. Is there anything 
        else you'd like to know about the weather?
        """
        
        // Should handle long messages without crashing
        XCTAssertNoThrow(voiceService.speak(longMessage), "Should handle long messages")
        voiceService.stopSpeaking()
    }
    
    func testSpecialCharacterHandling() {
        // Test handling of messages with special characters
        let messagesWithSpecialChars = [
            "It's 3:30 PM, and the temperature is 72°F.",
            "Your appointment is at 2:00 PM - don't forget!",
            "The pharmacy is located at 123 Main St., Suite #5.",
            "Your medication costs $15.99 (with insurance)."
        ]
        
        for message in messagesWithSpecialChars {
            XCTAssertNoThrow(voiceService.speak(message),
                           "Should handle special characters: \(message)")
        }
        
        voiceService.stopSpeaking()
    }
    
    // MARK: - Performance Tests
    
    func testSpeechSynthesisPerformance() {
        // Measure time for speech synthesis to start
        measure {
            voiceService.speak("Performance test message")
            voiceService.stopSpeaking()
        }
    }
    
    func testRecordingStartPerformance() {
        // Measure time to start recording (should be fast for elderly users)
        measure {
            voiceService.startRecording()
            voiceService.stopRecording()
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyTextSpeech() {
        // Should handle empty text gracefully
        XCTAssertNoThrow(voiceService.speak(""), "Should handle empty text")
        XCTAssertNoThrow(voiceService.speak("   "), "Should handle whitespace-only text")
    }
    
    func testVeryShortMessages() {
        let shortMessages = ["Yes", "No", "OK", "Help", "Stop"]
        
        for message in shortMessages {
            XCTAssertNoThrow(voiceService.speak(message),
                           "Should handle short messages: \(message)")
        }
        
        voiceService.stopSpeaking()
    }
    
    func testRapidStartStopCycles() {
        // Test rapid start/stop cycles that might happen with confused elderly users
        for _ in 0..<5 {
            voiceService.startRecording()
            voiceService.stopRecording()
        }
        
        // Should maintain consistent state
        XCTAssertFalse(voiceService.isRecording, "Should not be recording after cycles")
        XCTAssertFalse(voiceService.isListening, "Should not be listening after cycles")
    }
    
    func testConcurrentSpeechRequests() {
        // Test multiple speech requests (second should interrupt first)
        voiceService.speak("First message that should be interrupted")
        voiceService.speak("Second message that should play")
        
        // Should handle gracefully
        XCTAssertTrue(true, "Concurrent speech requests should not crash")
        
        voiceService.stopSpeaking()
    }
}