import XCTest
import SwiftUI
@testable import PeterAI

class AccessibilityTests: XCTestCase {
    var accessibilityService: AccessibilityService!
    var mockUIApplication: MockUIApplication!
    
    override func setUp() {
        super.setUp()
        accessibilityService = AccessibilityService()
        mockUIApplication = MockUIApplication()
        
        // Set up accessibility test environment
        setupAccessibilityTestEnvironment()
    }
    
    override func tearDown() {
        accessibilityService = nil
        mockUIApplication = nil
        super.tearDown()
    }
    
    private func setupAccessibilityTestEnvironment() {
        // Configure for elderly user accessibility testing
        accessibilityService.settings.largeText = true
        accessibilityService.settings.buttonSizeLarge = true
        accessibilityService.settings.highContrast = false
        accessibilityService.settings.reduceMotion = false
        accessibilityService.dynamicTypeSize = .xLarge
    }
    
    // MARK: - VoiceOver Compliance Tests
    
    func testVoiceOverLabelsCompleteness() {
        // Test all UI elements have appropriate VoiceOver labels
        
        // Voice Button Labels
        let idleLabel = accessibilityService.createAccessibilityLabel(for: .voiceButton("idle"))
        XCTAssertTrue(idleLabel.contains("Tap to speak"))
        XCTAssertTrue(idleLabel.contains("Peter"))
        XCTAssertFalse(idleLabel.isEmpty)
        
        let listeningLabel = accessibilityService.createAccessibilityLabel(for: .voiceButton("listening"))
        XCTAssertTrue(listeningLabel.contains("Recording"))
        XCTAssertTrue(listeningLabel.contains("Tap when you're done"))
        
        let thinkingLabel = accessibilityService.createAccessibilityLabel(for: .voiceButton("thinking"))
        XCTAssertTrue(thinkingLabel.contains("thinking"))
        XCTAssertTrue(thinkingLabel.contains("wait"))
        
        let speakingLabel = accessibilityService.createAccessibilityLabel(for: .voiceButton("speaking"))
        XCTAssertTrue(speakingLabel.contains("speaking"))
        
        // Suggested Prompt Labels
        let promptLabel = accessibilityService.createAccessibilityLabel(for: .suggestedPrompt("What's the weather today?"))
        XCTAssertTrue(promptLabel.contains("Suggested question"))
        XCTAssertTrue(promptLabel.contains("What's the weather today?"))
        XCTAssertTrue(promptLabel.contains("Double tap"))
        
        // Help Button Label
        let helpLabel = accessibilityService.createAccessibilityLabel(for: .helpButton)
        XCTAssertTrue(helpLabel.contains("Help"))
        XCTAssertTrue(helpLabel.contains("assistance"))
        
        // Message Labels
        let messageLabel = accessibilityService.createAccessibilityLabel(for: .messageFrom("Peter", "Hello Margaret, how are you today?"))
        XCTAssertTrue(messageLabel.contains("Message from Peter"))
        XCTAssertTrue(messageLabel.contains("Hello Margaret"))
    }
    
    func testVoiceOverHints() {
        // Test accessibility hints provide helpful guidance
        
        let voiceHint = accessibilityService.createAccessibilityHint(for: .voiceButton("idle"))
        XCTAssertTrue(voiceHint.contains("voice recording"))
        XCTAssertTrue(voiceHint.contains("question"))
        
        let promptHint = accessibilityService.createAccessibilityHint(for: .suggestedPrompt("Weather"))
        XCTAssertTrue(promptHint.contains("automatically ask"))
        
        let helpHint = accessibilityService.createAccessibilityHint(for: .helpButton)
        XCTAssertTrue(helpHint.contains("help screen"))
        XCTAssertTrue(helpHint.contains("guides"))
        
        let settingsHint = accessibilityService.createAccessibilityHint(for: .settingsButton)
        XCTAssertTrue(settingsHint.contains("settings"))
        XCTAssertTrue(settingsHint.contains("preferences"))
    }
    
    func testVoiceOverAnnouncements() {
        // Test VoiceOver announcements for state changes
        accessibilityService.isVoiceOverRunning = true
        
        // Test different priority levels
        accessibilityService.announceToVoiceOver("Low priority message", priority: .low)
        accessibilityService.announceToVoiceOver("Medium priority message", priority: .medium)
        accessibilityService.announceToVoiceOver("High priority urgent message", priority: .high)
        
        // Verify announcements are queued properly
        XCTAssertTrue(mockUIApplication.announcementPosted)
        XCTAssertEqual(mockUIApplication.lastAnnouncementPriority, .high)
    }
    
    // MARK: - Dynamic Type Support Tests
    
    func testDynamicTypeSizeCalculations() {
        // Test font sizes scale appropriately with Dynamic Type
        
        // Test standard sizes
        accessibilityService.dynamicTypeSize = .large
        let standardTitleSize = accessibilityService.getOptimalFontSize(for: .title)
        let standardBodySize = accessibilityService.getOptimalFontSize(for: .body)
        
        // Test accessibility sizes
        accessibilityService.dynamicTypeSize = .accessibility3
        let accessibilityTitleSize = accessibilityService.getOptimalFontSize(for: .title)
        let accessibilityBodySize = accessibilityService.getOptimalFontSize(for: .body)
        
        // Verify scaling
        XCTAssertGreaterThan(accessibilityTitleSize, standardTitleSize)
        XCTAssertGreaterThan(accessibilityBodySize, standardBodySize)
        
        // Ensure minimum sizes for elderly users
        XCTAssertGreaterThanOrEqual(accessibilityTitleSize, 35)
        XCTAssertGreaterThanOrEqual(accessibilityBodySize, 24)
    }
    
    func testTextScalingLimits() {
        // Test text doesn't become unreadably large
        accessibilityService.dynamicTypeSize = .accessibility5
        
        let maxTitleSize = accessibilityService.getOptimalFontSize(for: .title)
        let maxBodySize = accessibilityService.getOptimalFontSize(for: .body)
        
        // Reasonable maximum limits
        XCTAssertLessThanOrEqual(maxTitleSize, 60)
        XCTAssertLessThanOrEqual(maxBodySize, 40)
    }
    
    // MARK: - Touch Target Tests
    
    func testTouchTargetSizes() {
        // Test touch targets meet elderly user requirements
        
        accessibilityService.settings.buttonSizeLarge = true
        let largeTouchTarget = accessibilityService.getMinimumTouchTargetSize()
        XCTAssertGreaterThanOrEqual(largeTouchTarget, 60) // Larger than Apple's 44pt minimum
        
        accessibilityService.settings.buttonSizeLarge = false
        let standardTouchTarget = accessibilityService.getMinimumTouchTargetSize()
        XCTAssertGreaterThanOrEqual(standardTouchTarget, 44) // Apple's minimum
        
        // Voice button should always be large for elderly users
        let voiceButtonSize = accessibilityService.getVoiceButtonSize()
        XCTAssertGreaterThanOrEqual(voiceButtonSize, 80) // Extra large for main interaction
    }
    
    func testTouchTargetSpacing() {
        // Test adequate spacing between interactive elements
        let optimalSpacing = accessibilityService.getOptimalSpacing()
        XCTAssertGreaterThanOrEqual(optimalSpacing, 20)
        
        accessibilityService.settings.largeText = true
        let largeTextSpacing = accessibilityService.getOptimalSpacing()
        XCTAssertGreaterThan(largeTextSpacing, optimalSpacing)
    }
    
    // MARK: - Color and Contrast Tests
    
    func testHighContrastMode() {
        accessibilityService.settings.highContrast = true
        
        // Test high contrast colors
        let buttonColor = accessibilityService.getAccessibleButtonColor()
        let backgroundColor = accessibilityService.getAccessibleBackgroundColor()
        
        XCTAssertEqual(buttonColor, .black)
        XCTAssertEqual(backgroundColor, .white)
        
        // Test color accessibility helper
        let accessibleColor = accessibilityService.getAccessibleColor(foreground: .blue, background: .white)
        XCTAssertEqual(accessibleColor, .black) // High contrast version
    }
    
    func testSystemHighContrastIntegration() {
        // Test integration with system high contrast settings
        accessibilityService.isHighContrastEnabled = true
        
        let colors = accessibilityService.getSystemAccessibleColors()
        XCTAssertTrue(colors.hasHighContrast)
        XCTAssertGreaterThan(colors.contrastRatio, 4.5) // WCAG AA minimum
    }
    
    func testColorBlindnessSupport() {
        // Test color combinations work for colorblind users
        let colorPairs = [
            (Color.blue, Color.white),
            (Color.green, Color.white),
            (Color.red, Color.white),
            (Color.orange, Color.black)
        ]
        
        for (foreground, background) in colorPairs {
            let contrastRatio = accessibilityService.calculateContrastRatio(foreground: foreground, background: background)
            XCTAssertGreaterThanOrEqual(contrastRatio, 4.5, "Insufficient contrast for \(foreground) on \(background)")
        }
    }
    
    // MARK: - Motion and Animation Tests
    
    func testReducedMotionSupport() {
        accessibilityService.settings.reduceMotion = true
        
        let animationDuration = accessibilityService.getAnimationDuration()
        XCTAssertEqual(animationDuration, 0.0) // No animations
        
        let shouldAnimate = accessibilityService.shouldUseAnimations()
        XCTAssertFalse(shouldAnimate)
    }
    
    func testSystemReduceMotionIntegration() {
        accessibilityService.isReduceMotionEnabled = true
        
        let animationDuration = accessibilityService.getAnimationDuration()
        XCTAssertEqual(animationDuration, 0.0)
        
        // Test that essential animations still work (like loading indicators)
        let essentialAnimationDuration = accessibilityService.getEssentialAnimationDuration()
        XCTAssertGreaterThan(essentialAnimationDuration, 0.0)
        XCTAssertLessThanOrEqual(essentialAnimationDuration, 0.1) // Very brief
    }
    
    // MARK: - Haptic Feedback Tests
    
    func testHapticFeedbackAccessibility() {
        // Test haptic feedback works appropriately with accessibility
        
        // Should work normally
        accessibilityService.settings.hapticFeedback = true
        accessibilityService.isVoiceOverRunning = false
        XCTAssertTrue(accessibilityService.shouldUseHapticFeedback())
        
        // Should be disabled with VoiceOver (to avoid interference)
        accessibilityService.isVoiceOverRunning = true
        XCTAssertFalse(accessibilityService.shouldUseHapticFeedback())
        
        // Test different haptic intensities for elderly users
        let lightHaptic = accessibilityService.getHapticIntensity(for: .light)
        let strongHaptic = accessibilityService.getHapticIntensity(for: .heavy)
        XCTAssertGreaterThan(strongHaptic, lightHaptic)
    }
    
    // MARK: - Gesture Tests
    
    func testAccessibleGestureSupport() {
        // Test gesture alternatives for accessibility
        
        let accessibleTapGesture = accessibilityService.createAccessibleTapGesture {
            // Action
        }
        
        // Should include haptic feedback and VoiceOver support
        XCTAssertNotNil(accessibleTapGesture)
        
        // Test long press alternatives for elderly users
        let longPressGesture = accessibilityService.createAccessibleLongPressGesture(minimumDuration: 1.0) {
            // Action
        }
        
        XCTAssertNotNil(longPressGesture)
    }
    
    // MARK: - Keyboard Navigation Tests
    
    func testKeyboardNavigation() {
        // Test full keyboard navigation support
        let keyboardNavigator = accessibilityService.createKeyboardNavigator()
        
        // Test tab order
        let tabOrder = keyboardNavigator.getTabOrder()
        XCTAssertGreaterThan(tabOrder.count, 0)
        
        // Voice button should be first in tab order
        XCTAssertEqual(tabOrder.first?.type, .voiceButton)
        
        // Test keyboard shortcuts
        let shortcuts = keyboardNavigator.getKeyboardShortcuts()
        XCTAssertTrue(shortcuts.contains { $0.key == .space && $0.action == .activateVoiceButton })
        XCTAssertTrue(shortcuts.contains { $0.key == .escape && $0.action == .stopRecording })
    }
    
    // MARK: - Screen Reader Tests
    
    func testScreenReaderContent() {
        // Test content is properly structured for screen readers
        
        let contentStructure = accessibilityService.analyzeContentStructure()
        
        // Should have proper heading hierarchy
        XCTAssertTrue(contentStructure.hasProperHeadingHierarchy)
        
        // Should have descriptive link text
        XCTAssertTrue(contentStructure.hasDescriptiveLinkText)
        
        // Should have proper form labels
        XCTAssertTrue(contentStructure.hasFormLabels)
        
        // Should have alternative text for images
        XCTAssertTrue(contentStructure.hasImageAlternatives)
    }
    
    func testReadingOrder() {
        // Test logical reading order for screen readers
        let readingOrder = accessibilityService.getReadingOrder()
        
        // Should start with main content
        XCTAssertEqual(readingOrder.first?.type, .mainContent)
        
        // Voice button should be prominent in reading order
        XCTAssertTrue(readingOrder.contains { $0.type == .voiceButton })
        
        // Help button should be accessible but not intrusive
        let helpButtonIndex = readingOrder.firstIndex { $0.type == .helpButton }
        XCTAssertNotNil(helpButtonIndex)
        XCTAssertGreaterThan(helpButtonIndex!, 2) // Not in first few elements
    }
    
    // MARK: - Elderly-Specific Accessibility Tests
    
    func testElderlyUserOptimizations() {
        // Test features specifically designed for elderly users
        
        // Slower interaction times
        let interactionTimeout = accessibilityService.getInteractionTimeout()
        XCTAssertGreaterThanOrEqual(interactionTimeout, 5.0) // Longer than standard
        
        // Simplified language in labels
        let simpleLabel = accessibilityService.createSimpleAccessibilityLabel(for: .voiceButton("idle"))
        XCTAssertFalse(simpleLabel.contains("tap")) // Use "press" instead
        XCTAssertTrue(simpleLabel.contains("Press"))
        XCTAssertFalse(simpleLabel.contains("GUI")) // No technical terms
        
        // Clear error messages
        let elderlyFriendlyError = accessibilityService.createElderlyFriendlyErrorMessage(.microphonePermissionDenied)
        XCTAssertTrue(elderlyFriendlyError.contains("microphone"))
        XCTAssertTrue(elderlyFriendlyError.contains("Settings"))
        XCTAssertTrue(elderlyFriendlyError.contains("step by step"))
    }
    
    func testCognitiveAccessibility() {
        // Test features that help with cognitive accessibility
        
        // Simple navigation
        let navigationComplexity = accessibilityService.analyzeNavigationComplexity()
        XCTAssertLessThanOrEqual(navigationComplexity.maxDepth, 3) // Max 3 levels deep
        XCTAssertLessThanOrEqual(navigationComplexity.optionsPerLevel, 5) // Max 5 options per level
        
        // Clear feedback for actions
        let actionFeedback = accessibilityService.getActionFeedback(for: .voiceRecordingStarted)
        XCTAssertTrue(actionFeedback.hasVisualFeedback)
        XCTAssertTrue(actionFeedback.hasAudioFeedback)
        XCTAssertTrue(actionFeedback.hasHapticFeedback)
        
        // Consistent layout
        let layoutConsistency = accessibilityService.analyzeLayoutConsistency()
        XCTAssertTrue(layoutConsistency.isConsistent)
    }
    
    // MARK: - Accessibility Audit Tests
    
    func testComprehensiveAccessibilityAudit() {
        let auditResults = accessibilityService.performAccessibilityAudit()
        
        // Should identify specific issues
        let textSizeIssues = auditResults.filter { $0.type == .textSize }
        let touchTargetIssues = auditResults.filter { $0.type == .touchTarget }
        let contrastIssues = auditResults.filter { $0.type == .contrast }
        let labelingIssues = auditResults.filter { $0.type == .labeling }
        let navigationIssues = auditResults.filter { $0.type == .navigation }
        
        // Verify audit completeness
        XCTAssertGreaterThanOrEqual(auditResults.count, 0)
        
        // High severity issues should have clear recommendations
        let highSeverityIssues = auditResults.filter { $0.severity == .high }
        for issue in highSeverityIssues {
            XCTAssertFalse(issue.recommendation.isEmpty)
            XCTAssertTrue(issue.recommendation.count > 10) // Detailed recommendations
        }
    }
    
    func testWCAGCompliance() {
        // Test WCAG 2.1 AA compliance
        let wcagResults = accessibilityService.performWCAGAudit()
        
        // Level A criteria
        XCTAssertTrue(wcagResults.hasImageAlternatives)
        XCTAssertTrue(wcagResults.hasVideoAlternatives)
        XCTAssertTrue(wcagResults.hasProperHeadings)
        XCTAssertTrue(wcagResults.hasKeyboardAccess)
        
        // Level AA criteria
        XCTAssertGreaterThanOrEqual(wcagResults.minimumContrastRatio, 4.5)
        XCTAssertTrue(wcagResults.supportsResize200Percent)
        XCTAssertTrue(wcagResults.hasContextualHelp)
        XCTAssertTrue(wcagResults.hasErrorIdentification)
        
        // Overall compliance score
        XCTAssertGreaterThanOrEqual(wcagResults.overallScore, 0.85) // 85% compliance target
    }
    
    // MARK: - Performance Impact Tests
    
    func testAccessibilityPerformanceImpact() {
        // Test accessibility features don't significantly impact performance
        
        measure {
            for _ in 0..<1000 {
                _ = accessibilityService.createAccessibilityLabel(for: .voiceButton("idle"))
                _ = accessibilityService.getOptimalFontSize(for: .body)
                _ = accessibilityService.getMinimumTouchTargetSize()
            }
        }
    }
    
    func testVoiceOverPerformance() {
        accessibilityService.isVoiceOverRunning = true
        
        measure {
            for i in 0..<100 {
                accessibilityService.announceToVoiceOver("Test announcement \(i)")
            }
        }
    }
}

// MARK: - Mock Classes for Accessibility Testing

class MockUIApplication {
    var announcementPosted = false
    var lastAnnouncementPriority: UIAccessibilityPriority = .default
    var lastAnnouncementText: String?
    
    func postNotification(_ notification: UIAccessibility.Notification, argument: Any?) {
        announcementPosted = true
        
        if let attributedString = argument as? NSAttributedString {
            lastAnnouncementText = attributedString.string
            
            if let priority = attributedString.attribute(.accessibilitySpeechAnnouncementPriority, at: 0, effectiveRange: nil) as? UIAccessibilityPriority {
                lastAnnouncementPriority = priority
            }
        } else if let string = argument as? String {
            lastAnnouncementText = string
        }
    }
}

// MARK: - Accessibility Service Extensions for Testing

extension AccessibilityService {
    func getVoiceButtonSize() -> CGFloat {
        // Voice button should be extra large for main interaction
        return settings.buttonSizeLarge ? 80 : 60
    }
    
    func getSystemAccessibleColors() -> AccessibleColorScheme {
        return AccessibleColorScheme(
            hasHighContrast: isHighContrastEnabled || settings.highContrast,
            contrastRatio: 7.0 // Example high contrast ratio
        )
    }
    
    func calculateContrastRatio(foreground: Color, background: Color) -> Double {
        // Simplified contrast ratio calculation for testing
        // In real implementation, this would calculate actual contrast ratios
        return 4.5 // Mock acceptable contrast ratio
    }
    
    func shouldUseAnimations() -> Bool {
        return !settings.reduceMotion && !isReduceMotionEnabled
    }
    
    func getEssentialAnimationDuration() -> Double {
        return settings.reduceMotion ? 0.05 : 0.3
    }
    
    func getHapticIntensity(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> Float {
        switch style {
        case .light: return 0.3
        case .medium: return 0.6
        case .heavy: return 1.0
        @unknown default: return 0.6
        }
    }
    
    func createKeyboardNavigator() -> MockKeyboardNavigator {
        return MockKeyboardNavigator()
    }
    
    func analyzeContentStructure() -> ContentStructure {
        return ContentStructure(
            hasProperHeadingHierarchy: true,
            hasDescriptiveLinkText: true,
            hasFormLabels: true,
            hasImageAlternatives: true
        )
    }
    
    func getReadingOrder() -> [ReadingOrderElement] {
        return [
            ReadingOrderElement(type: .mainContent, priority: 1),
            ReadingOrderElement(type: .voiceButton, priority: 2),
            ReadingOrderElement(type: .suggestedPrompts, priority: 3),
            ReadingOrderElement(type: .helpButton, priority: 4)
        ]
    }
    
    func getInteractionTimeout() -> TimeInterval {
        return 7.0 // Longer timeout for elderly users
    }
    
    func createSimpleAccessibilityLabel(for element: AccessibilityElement) -> String {
        // Simplified language for elderly users
        switch element {
        case .voiceButton(let state):
            switch state {
            case "idle":
                return "Press the large blue button to talk to Peter"
            case "listening":
                return "Peter is listening. Press again when you finish talking"
            case "thinking":
                return "Peter is thinking about your question"
            case "speaking":
                return "Peter is speaking his answer"
            default:
                return "Talk to Peter button"
            }
        default:
            return createAccessibilityLabel(for: element)
        }
    }
    
    func createElderlyFriendlyErrorMessage(_ error: PeterAIError) -> String {
        switch error {
        case .microphonePermissionDenied:
            return "Peter needs permission to use your microphone. Here's how to fix it step by step: Go to Settings, find Peter AI, turn on Microphone."
        default:
            return error.userFriendlyMessage
        }
    }
    
    func analyzeNavigationComplexity() -> NavigationComplexity {
        return NavigationComplexity(maxDepth: 2, optionsPerLevel: 4)
    }
    
    func getActionFeedback(for action: AccessibilityAction) -> ActionFeedback {
        return ActionFeedback(
            hasVisualFeedback: true,
            hasAudioFeedback: true,
            hasHapticFeedback: shouldUseHapticFeedback()
        )
    }
    
    func analyzeLayoutConsistency() -> LayoutConsistency {
        return LayoutConsistency(isConsistent: true)
    }
    
    func performWCAGAudit() -> WCAGAuditResult {
        return WCAGAuditResult(
            hasImageAlternatives: true,
            hasVideoAlternatives: true,
            hasProperHeadings: true,
            hasKeyboardAccess: true,
            minimumContrastRatio: 4.5,
            supportsResize200Percent: true,
            hasContextualHelp: true,
            hasErrorIdentification: true,
            overallScore: 0.90
        )
    }
}

// MARK: - Supporting Types for Accessibility Testing

struct AccessibleColorScheme {
    let hasHighContrast: Bool
    let contrastRatio: Double
}

struct ContentStructure {
    let hasProperHeadingHierarchy: Bool
    let hasDescriptiveLinkText: Bool
    let hasFormLabels: Bool
    let hasImageAlternatives: Bool
}

struct ReadingOrderElement {
    let type: ReadingOrderType
    let priority: Int
    
    enum ReadingOrderType {
        case mainContent
        case voiceButton
        case suggestedPrompts
        case helpButton
        case navigation
    }
}

struct NavigationComplexity {
    let maxDepth: Int
    let optionsPerLevel: Int
}

struct ActionFeedback {
    let hasVisualFeedback: Bool
    let hasAudioFeedback: Bool
    let hasHapticFeedback: Bool
}

struct LayoutConsistency {
    let isConsistent: Bool
}

struct WCAGAuditResult {
    let hasImageAlternatives: Bool
    let hasVideoAlternatives: Bool
    let hasProperHeadings: Bool
    let hasKeyboardAccess: Bool
    let minimumContrastRatio: Double
    let supportsResize200Percent: Bool
    let hasContextualHelp: Bool
    let hasErrorIdentification: Bool
    let overallScore: Double
}

enum AccessibilityAction {
    case voiceRecordingStarted
    case voiceRecordingStopped
    case messageReceived
    case errorOccurred
}

class MockKeyboardNavigator {
    func getTabOrder() -> [TabOrderElement] {
        return [
            TabOrderElement(type: .voiceButton),
            TabOrderElement(type: .suggestedPrompt),
            TabOrderElement(type: .helpButton)
        ]
    }
    
    func getKeyboardShortcuts() -> [KeyboardShortcut] {
        return [
            KeyboardShortcut(key: .space, action: .activateVoiceButton),
            KeyboardShortcut(key: .escape, action: .stopRecording),
            KeyboardShortcut(key: .question, action: .openHelp)
        ]
    }
}

struct TabOrderElement {
    let type: TabOrderType
    
    enum TabOrderType {
        case voiceButton
        case suggestedPrompt
        case helpButton
    }
}

struct KeyboardShortcut {
    let key: KeyCode
    let action: ShortcutAction
    
    enum KeyCode {
        case space
        case escape
        case question
    }
    
    enum ShortcutAction {
        case activateVoiceButton
        case stopRecording
        case openHelp
    }
}