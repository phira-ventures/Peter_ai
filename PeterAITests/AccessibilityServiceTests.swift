import XCTest
import SwiftUI
@testable import PeterAI

final class AccessibilityServiceTests: XCTestCase {
    var accessibilityService: AccessibilityService!
    
    override func setUp() {
        super.setUp()
        accessibilityService = AccessibilityService()
    }
    
    override func tearDown() {
        accessibilityService = nil
        super.tearDown()
    }
    
    // MARK: - Font Size Tests for Elderly Users
    
    func testOptimalFontSizesForElderlyUsers() {
        // Given - Default elderly settings
        accessibilityService.settings.largeText = true
        
        // When - Test different text styles
        let bodySize = accessibilityService.getOptimalFontSize(for: .body)
        let titleSize = accessibilityService.getOptimalFontSize(for: .title)
        let captionSize = accessibilityService.getOptimalFontSize(for: .caption)
        
        // Then - Should be larger than standard sizes
        XCTAssertGreaterThanOrEqual(bodySize, 22, "Body text should be at least 22pt for elderly users")
        XCTAssertGreaterThanOrEqual(titleSize, 36, "Title text should be at least 36pt for elderly users")
        XCTAssertGreaterThanOrEqual(captionSize, 16, "Even caption text should be at least 16pt for elderly users")
    }
    
    func testExtraLargeFontSettings() {
        // Given - Extra large text enabled
        accessibilityService.settings.extraLargeText = true
        accessibilityService.settings.largeText = true
        
        // When
        let bodySize = accessibilityService.getOptimalFontSize(for: .body)
        let normalBodySize = 18 // Normal body size
        
        // Then - Should be significantly larger
        XCTAssertGreaterThan(bodySize, normalBodySize * 1.3, "Extra large text should be at least 30% larger")
    }
    
    func testMinimumFontSizeEnforcement() {
        // Given - Even with small text settings
        accessibilityService.settings.largeText = false
        accessibilityService.settings.extraLargeText = false
        
        // When
        let captionSize = accessibilityService.getOptimalFontSize(for: .caption)
        
        // Then - Should still meet minimum elderly-friendly size
        XCTAssertGreaterThanOrEqual(captionSize, 16, "Minimum font size should be 16pt for elderly users")
    }
    
    // MARK: - Touch Target Tests
    
    func testMinimumTouchTargetSizes() {
        // Given - Standard large buttons setting
        accessibilityService.settings.buttonSizeLarge = true
        
        // When
        let touchTargetSize = accessibilityService.getMinimumTouchTargetSize()
        
        // Then - Should be at least 60pt (larger than standard 44pt)
        XCTAssertGreaterThanOrEqual(touchTargetSize, 60, "Touch targets should be at least 60pt for elderly users")
    }
    
    func testExtraLargeTouchTargets() {
        // Given - Extra large buttons for users with dexterity issues
        accessibilityService.settings.extraLargeButtons = true
        
        // When
        let touchTargetSize = accessibilityService.getMinimumTouchTargetSize()
        
        // Then - Should be 80pt for users with motor difficulties
        XCTAssertEqual(touchTargetSize, 80, "Extra large buttons should be 80pt for elderly users with dexterity issues")
    }
    
    // MARK: - Accessibility Labels for Elderly Users
    
    func testVoiceButtonAccessibilityLabels() {
        // Given - Different voice states
        let idleElement = AccessibilityElement.voiceButton("idle")
        let listeningElement = AccessibilityElement.voiceButton("listening")
        let thinkingElement = AccessibilityElement.voiceButton("thinking")
        
        // When - Generate labels for normal mode
        accessibilityService.settings.simplifiedInterface = false
        let idleLabel = accessibilityService.createAccessibilityLabel(for: idleElement)
        let listeningLabel = accessibilityService.createAccessibilityLabel(for: listeningElement)
        let thinkingLabel = accessibilityService.createAccessibilityLabel(for: thinkingElement)
        
        // Then - Should be descriptive and elderly-friendly
        XCTAssertTrue(idleLabel.contains("Peter"), "Should mention Peter by name")
        XCTAssertTrue(idleLabel.contains("Tap"), "Should include clear action instruction")
        XCTAssertTrue(listeningLabel.contains("listening"), "Should indicate current state")
        XCTAssertTrue(thinkingLabel.contains("thinking"), "Should explain what Peter is doing")
    }
    
    func testSimplifiedAccessibilityLabels() {
        // Given - Simplified interface enabled for confused elderly users
        accessibilityService.settings.simplifiedInterface = true
        let voiceButton = AccessibilityElement.voiceButton("idle")
        
        // When
        let label = accessibilityService.createAccessibilityLabel(for: voiceButton)
        
        // Then - Should be much simpler
        XCTAssertTrue(label.contains("Talk to Peter"), "Simplified label should be direct")
        XCTAssertTrue(label.contains("Press"), "Should use simple language")
        XCTAssertFalse(label.contains("Double tap"), "Should not include complex instructions")
    }
    
    func testHelpfulAccessibilityHints() {
        // Given
        let helpButton = AccessibilityElement.helpButton
        accessibilityService.settings.simplifiedInterface = false
        
        // When
        let hint = accessibilityService.createAccessibilityHint(for: helpButton)
        
        // Then
        XCTAssertFalse(hint.isEmpty, "Help button should have a hint")
        XCTAssertTrue(hint.contains("help") || hint.contains("assistance"), "Should mention help/assistance")
    }
    
    // MARK: - Visual Accessibility Tests
    
    func testHighContrastColors() {
        // Given - High contrast mode enabled
        accessibilityService.settings.highContrast = true
        
        // When
        let textColor = accessibilityService.getElderlyFriendlyTextColor()
        let buttonColor = accessibilityService.getAccessibleButtonColor()
        
        // Then - Should return high contrast colors
        XCTAssertEqual(textColor, Color.black, "Text should be black in high contrast mode")
        XCTAssertEqual(buttonColor, Color.black, "Buttons should be black in high contrast mode")
    }
    
    func testElderlyFriendlySecondaryColors() {
        // Given - Standard settings
        accessibilityService.settings.highContrast = false
        
        // When
        let secondaryColor = accessibilityService.getElderlyFriendlySecondaryColor()
        
        // Then - Should have higher opacity than standard secondary text
        XCTAssertNotEqual(secondaryColor, Color.secondary, "Should be different from standard secondary color")
    }
    
    // MARK: - Spacing and Layout Tests
    
    func testOptimalSpacingForElderlyUsers() {
        // Given - Large text enabled
        accessibilityService.settings.largeText = true
        
        // When
        let spacing = accessibilityService.getOptimalSpacing()
        
        // Then - Should provide generous spacing
        XCTAssertGreaterThanOrEqual(spacing, 28, "Spacing should be generous for elderly users")
    }
    
    func testSimplifiedInterfaceSpacing() {
        // Given - Simplified interface
        accessibilityService.settings.simplifiedInterface = true
        
        // When
        let spacing = accessibilityService.getOptimalSpacing()
        
        // Then - Should provide extra spacing for simplified layouts
        XCTAssertGreaterThanOrEqual(spacing, 35, "Simplified interface should have extra spacing")
    }
    
    func testLineSpacingOptimization() {
        // Given - Extra large text
        accessibilityService.settings.extraLargeText = true
        
        // When
        let lineSpacing = accessibilityService.getElderlyOptimizedLineSpacing()
        
        // Then - Should increase line spacing for readability
        XCTAssertGreaterThanOrEqual(lineSpacing, 6, "Line spacing should increase with larger text")
    }
    
    // MARK: - Haptic Feedback Tests
    
    func testHapticFeedbackSettings() {
        // Given - Strong haptic feedback enabled
        accessibilityService.settings.strongHapticFeedback = true
        accessibilityService.settings.hapticFeedback = true
        
        // When
        let shouldUseHaptic = accessibilityService.shouldUseHapticFeedback()
        let hapticStyle = accessibilityService.getHapticFeedbackStyle()
        
        // Then
        XCTAssertTrue(shouldUseHaptic, "Should use haptic feedback when enabled")
        XCTAssertEqual(hapticStyle, .heavy, "Should use heavy haptic feedback for elderly users")
    }
    
    func testVoiceOverHapticDisabling() {
        // Given - VoiceOver is running
        accessibilityService.isVoiceOverRunning = true
        accessibilityService.settings.hapticFeedback = true
        
        // When
        let shouldUseHaptic = accessibilityService.shouldUseHapticFeedback()
        
        // Then - Should disable haptic to avoid conflict with VoiceOver
        XCTAssertFalse(shouldUseHaptic, "Haptic should be disabled when VoiceOver is running")
    }
    
    // MARK: - Animation and Motion Tests
    
    func testSlowAnimationsForElderlyUsers() {
        // Given - Slow animations enabled
        accessibilityService.settings.slowAnimations = true
        accessibilityService.settings.reduceMotion = false
        
        // When
        let animationDuration = accessibilityService.getAnimationDuration()
        
        // Then - Should be slower than normal
        XCTAssertGreaterThanOrEqual(animationDuration, 0.5, "Animations should be slower for elderly users")
    }
    
    func testReducedMotionCompliance() {
        // Given - Reduce motion enabled
        accessibilityService.settings.reduceMotion = true
        
        // When
        let animationDuration = accessibilityService.getAnimationDuration()
        
        // Then - Should disable animations
        XCTAssertEqual(animationDuration, 0.0, "Animations should be disabled with reduce motion")
    }
    
    func testExtendedTimeouts() {
        // Given - Extended timeouts enabled
        accessibilityService.settings.extendedTimeouts = true
        
        // When
        let timeout = accessibilityService.getTimeoutDuration()
        
        // Then - Should be longer than standard
        XCTAssertGreaterThanOrEqual(timeout, 45.0, "Timeouts should be extended for elderly users")
    }
    
    // MARK: - Voice Settings Tests
    
    func testSlowerVoiceOverRate() {
        // Given - Slow VoiceOver speed enabled
        accessibilityService.settings.voiceOverSpeedSlow = true
        
        // When
        let voiceRate = accessibilityService.getVoiceOverRate()
        
        // Then - Should be slower than normal
        XCTAssertLessThanOrEqual(voiceRate, 0.3, "VoiceOver should be slower for elderly users")
    }
    
    // MARK: - Accessibility Audit Tests
    
    func testAccessibilityAuditFindsIssues() {
        // Given - Suboptimal settings for elderly users
        accessibilityService.settings.largeText = false
        accessibilityService.settings.highContrast = false
        accessibilityService.settings.extendedTimeouts = false
        accessibilityService.dynamicTypeSize = .small
        
        // When
        let issues = accessibilityService.performAccessibilityAudit()
        
        // Then - Should identify multiple issues
        XCTAssertGreaterThan(issues.count, 0, "Audit should find accessibility issues")
        
        let textSizeIssues = issues.filter { $0.type == .textSize }
        XCTAssertGreaterThan(textSizeIssues.count, 0, "Should identify text size issues")
        
        let timeoutIssues = issues.filter { $0.description.contains("timeout") }
        XCTAssertGreaterThan(timeoutIssues.count, 0, "Should identify timeout issues")
    }
    
    func testAccessibilityAuditPassesWithOptimalSettings() {
        // Given - Optimal settings for elderly users
        accessibilityService.settings.largeText = true
        accessibilityService.settings.extraLargeText = true
        accessibilityService.settings.highContrast = true
        accessibilityService.settings.extendedTimeouts = true
        accessibilityService.settings.strongHapticFeedback = true
        accessibilityService.dynamicTypeSize = .accessibility1
        
        // When
        let issues = accessibilityService.performAccessibilityAudit()
        
        // Then - Should have minimal high-severity issues
        let highSeverityIssues = issues.filter { $0.severity == .high }
        XCTAssertEqual(highSeverityIssues.count, 0, "Should have no high-severity issues with optimal settings")
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testEmergencyModeColors() {
        // Given - Emergency mode enabled
        accessibilityService.settings.emergencyMode = true
        
        // When
        let emergencyColor = accessibilityService.getEmergencyColor()
        
        // Then - Should return red for emergency
        XCTAssertEqual(emergencyColor, Color.red, "Emergency mode should use red color")
    }
    
    func testOneHandedModeSupport() {
        // Given - One-handed mode enabled
        accessibilityService.settings.oneHandedMode = true
        
        // When
        let isOneHanded = accessibilityService.shouldUseOneHandedMode()
        
        // Then
        XCTAssertTrue(isOneHanded, "Should support one-handed mode")
    }
    
    func testVoiceOverAnnouncements() {
        // Given - VoiceOver running
        accessibilityService.isVoiceOverRunning = true
        
        // When/Then - Should not crash when making announcements
        XCTAssertNoThrow(accessibilityService.announceToVoiceOver("Test message"))
        XCTAssertNoThrow(accessibilityService.announceToVoiceOver("Priority message", priority: .high))
    }
}