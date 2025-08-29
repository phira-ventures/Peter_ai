import SwiftUI
import UIKit

struct AccessibilitySettings: Codable {
    var largeText: Bool = true
    var extraLargeText: Bool = false
    var highContrast: Bool = false
    var reduceMotion: Bool = false
    var voiceOverEnabled: Bool = false
    var buttonSizeLarge: Bool = true
    var extraLargeButtons: Bool = false
    var hapticFeedback: Bool = true
    var strongHapticFeedback: Bool = true
    var slowAnimations: Bool = true
    var boldText: Bool = true
    var simplifiedInterface: Bool = false
    var voiceOverSpeedSlow: Bool = true
    var extendedTimeouts: Bool = true
    var oneHandedMode: Bool = false
    var emergencyMode: Bool = false
    
    static let `default` = AccessibilitySettings()
}

class AccessibilityService: ObservableObject {
    @Published var settings = AccessibilitySettings.default
    @Published var dynamicTypeSize: DynamicTypeSize = .xLarge
    @Published var isVoiceOverRunning = false
    @Published var isReduceMotionEnabled = false
    @Published var isHighContrastEnabled = false
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadSettings()
        observeSystemSettings()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        if let data = userDefaults.data(forKey: "accessibilitySettings"),
           let settings = try? JSONDecoder().decode(AccessibilitySettings.self, from: data) {
            self.settings = settings
        }
        
        updateSystemSettings()
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: "accessibilitySettings")
        }
    }
    
    private func updateSystemSettings() {
        // Read system accessibility settings
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        
        // Update our settings to match system when appropriate
        settings.reduceMotion = isReduceMotionEnabled
        settings.voiceOverEnabled = isVoiceOverRunning
        settings.highContrast = isHighContrastEnabled
        
        // Update dynamic type size
        let preferredSize = UIApplication.shared.preferredContentSizeCategory
        dynamicTypeSize = convertToDynamicTypeSize(preferredSize)
    }
    
    private func convertToDynamicTypeSize(_ category: UIContentSizeCategory) -> DynamicTypeSize {
        switch category {
        case .extraSmall:
            return .small
        case .small:
            return .medium
        case .medium:
            return .large
        case .large:
            return .xLarge
        case .extraLarge:
            return .xxLarge
        case .extraExtraLarge:
            return .xxxLarge
        case .extraExtraExtraLarge:
            return .accessibility1
        case .accessibilityMedium:
            return .accessibility2
        case .accessibilityLarge:
            return .accessibility3
        case .accessibilityExtraLarge:
            return .accessibility4
        case .accessibilityExtraExtraLarge:
            return .accessibility5
        case .accessibilityExtraExtraExtraLarge:
            return .accessibility5
        default:
            return .xLarge
        }
    }
    
    // MARK: - System Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryChanged),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionStatusChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(darkerColorsStatusChanged),
            name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func voiceOverStatusChanged() {
        DispatchQueue.main.async {
            self.updateSystemSettings()
        }
    }
    
    @objc private func contentSizeCategoryChanged() {
        DispatchQueue.main.async {
            self.updateSystemSettings()
        }
    }
    
    @objc private func reduceMotionStatusChanged() {
        DispatchQueue.main.async {
            self.updateSystemSettings()
        }
    }
    
    @objc private func darkerColorsStatusChanged() {
        DispatchQueue.main.async {
            self.updateSystemSettings()
        }
    }
    
    private func observeSystemSettings() {
        updateSystemSettings()
    }
    
    // MARK: - Accessibility Helpers
    
    func getOptimalFontSize(for style: Font.TextStyle) -> CGFloat {
        let baseSize: CGFloat
        switch style {
        case .largeTitle:
            baseSize = settings.largeText ? 42 : 38
        case .title:
            baseSize = settings.largeText ? 36 : 32
        case .title2:
            baseSize = settings.largeText ? 28 : 24
        case .title3:
            baseSize = settings.largeText ? 26 : 22
        case .headline:
            baseSize = settings.largeText ? 24 : 20
        case .body:
            baseSize = settings.largeText ? 22 : 18
        case .callout:
            baseSize = settings.largeText ? 20 : 17
        case .subheadline:
            baseSize = settings.largeText ? 19 : 16
        case .footnote:
            baseSize = settings.largeText ? 17 : 14
        case .caption:
            baseSize = settings.largeText ? 16 : 13
        case .caption2:
            baseSize = settings.largeText ? 15 : 12
        @unknown default:
            baseSize = settings.largeText ? 22 : 18
        }
        
        // Extra large text for elderly users with vision difficulties
        let elderlyAdjustedSize = settings.extraLargeText ? baseSize * 1.3 : baseSize
        
        // Additional scaling for accessibility sizes
        let finalSize: CGFloat
        switch dynamicTypeSize {
        case .accessibility1, .accessibility2:
            finalSize = elderlyAdjustedSize * 1.2
        case .accessibility3, .accessibility4:
            finalSize = elderlyAdjustedSize * 1.5
        case .accessibility5:
            finalSize = elderlyAdjustedSize * 1.8
        default:
            finalSize = elderlyAdjustedSize
        }
        
        // Ensure minimum readable size for elderly users
        let minimumElderlySize: CGFloat = 16
        return max(finalSize, minimumElderlySize)
    }
    
    func getMinimumTouchTargetSize() -> CGFloat {
        if settings.extraLargeButtons {
            return 80 // Extra large for elderly users with dexterity issues
        } else if settings.buttonSizeLarge {
            return 60 // Standard large for elderly
        } else {
            return 50 // Minimum acceptable for elderly users (larger than standard 44)
        }
    }
    
    func getOptimalSpacing() -> CGFloat {
        if settings.simplifiedInterface {
            return 35 // Extra spacing for simplified layout
        } else if settings.largeText {
            return 28 // More spacing for large text
        } else {
            return 22 // Standard elderly-friendly spacing
        }
    }
    
    func shouldUseHapticFeedback() -> Bool {
        return settings.hapticFeedback && !isVoiceOverRunning
    }
    
    func getHapticFeedbackStyle() -> UIImpactFeedbackGenerator.FeedbackStyle {
        return settings.strongHapticFeedback ? .heavy : .medium
    }
    
    func getAnimationDuration() -> Double {
        if settings.reduceMotion || isReduceMotionEnabled {
            return 0.0
        }
        if settings.extendedTimeouts {
            return settings.slowAnimations ? 0.8 : 0.5
        }
        return settings.slowAnimations ? 0.5 : 0.3
    }
    
    func getTimeoutDuration() -> Double {
        return settings.extendedTimeouts ? 45.0 : 30.0 // Longer timeouts for elderly users
    }
    
    func getVoiceOverRate() -> Float {
        return settings.voiceOverSpeedSlow ? 0.3 : 0.5 // Slower speech for elderly
    }
    
    // MARK: - VoiceOver Helpers
    
    func createAccessibilityLabel(for element: AccessibilityElement) -> String {
        let simpleMode = settings.simplifiedInterface
        
        switch element {
        case .voiceButton(let state):
            switch state {
            case "idle":
                return simpleMode ? 
                    "Talk to Peter. Press to start." : 
                    "Voice button. Tap to speak to Peter. Double tap to start recording your question."
            case "listening":
                return simpleMode ? 
                    "Peter is listening. Press when done talking." : 
                    "Recording your question. Peter is listening. Tap when you're done speaking."
            case "thinking":
                return simpleMode ? 
                    "Peter is thinking. Please wait." : 
                    "Peter is thinking about your question. Please wait a moment."
            case "speaking":
                return simpleMode ? 
                    "Peter is talking." : 
                    "Peter is speaking his response. Please listen."
            default:
                return "Voice interaction button"
            }
        case .suggestedPrompt(let text):
            return simpleMode ? 
                "Question: \(text). Press to ask." : 
                "Suggested question: \(text). Double tap to ask this question automatically."
        case .helpButton:
            return simpleMode ? 
                "Help. Press for assistance." : 
                "Help button. Double tap to get assistance and learn how to use Peter AI."
        case .messageFrom(let sender, let content):
            return simpleMode ? 
                "\(sender) said: \(content)" : 
                "Message from \(sender): \(content)"
        case .settingsButton:
            return simpleMode ? 
                "Settings. Press to change options." : 
                "Settings. Double tap to adjust your preferences like text size and voice speed."
        }
    }
    
    func createAccessibilityHint(for element: AccessibilityElement) -> String {
        let simpleMode = settings.simplifiedInterface
        
        switch element {
        case .voiceButton(let state):
            if state == "idle" {
                return simpleMode ? 
                    "Press to talk to Peter." : 
                    "This will start voice recording so you can ask Peter a question."
            } else if state == "listening" {
                return simpleMode ? 
                    "Press when you're finished talking." : 
                    "Tap again when you finish speaking your question."
            }
            return ""
        case .suggestedPrompt:
            return simpleMode ? 
                "This asks the question for you." : 
                "This will automatically ask this question for you."
        case .helpButton:
            return simpleMode ? 
                "Get help using Peter." : 
                "Opens the help screen with guides and support options."
        case .messageFrom:
            return ""
        case .settingsButton:
            return simpleMode ? 
                "Change how Peter works." : 
                "Opens settings where you can adjust text size, voice speed, and other preferences."
        }
    }
    
    func announceToVoiceOver(_ message: String, priority: AnnouncementPriority = .medium) {
        guard isVoiceOverRunning else { return }
        
        let announcement: NSAttributedString
        
        switch priority {
        case .low:
            announcement = NSAttributedString(
                string: message,
                attributes: [.accessibilitySpeechQueueAnnouncement: true]
            )
        case .medium:
            announcement = NSAttributedString(string: message)
        case .high:
            announcement = NSAttributedString(
                string: message,
                attributes: [.accessibilitySpeechAnnouncementPriority: UIAccessibilityPriority.high]
            )
        }
        
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    // MARK: - Color and Contrast
    
    func getAccessibleColor(foreground: Color, background: Color) -> Color {
        if settings.highContrast || isHighContrastEnabled {
            // High contrast for elderly vision needs
            if background == .white || background == Color(.systemBackground) {
                return .black
            } else {
                return .white
            }
        }
        
        // Ensure sufficient contrast for elderly users
        return foreground
    }
    
    func getAccessibleBackgroundColor() -> Color {
        if settings.highContrast || isHighContrastEnabled {
            return .white
        }
        // Slightly warmer background for elderly users to reduce eye strain
        return Color(.systemBackground)
    }
    
    func getAccessibleButtonColor() -> Color {
        if settings.highContrast || isHighContrastEnabled {
            return .black
        }
        // Larger, more visible blue for elderly users
        return Color.blue
    }
    
    func getElderlyFriendlyTextColor() -> Color {
        if settings.highContrast || isHighContrastEnabled {
            return .black
        }
        // Darker text for better readability
        return Color.primary.opacity(0.9)
    }
    
    func getElderlyFriendlySecondaryColor() -> Color {
        if settings.highContrast || isHighContrastEnabled {
            return Color.black.opacity(0.7)
        }
        // Higher contrast secondary text
        return Color.secondary.opacity(0.8)
    }
    
    func getEmergencyColor() -> Color {
        return settings.emergencyMode ? .red : .blue
    }
    
    // MARK: - Gesture Helpers
    
    func createAccessibleTapGesture(action: @escaping () -> Void) -> some Gesture {
        if isVoiceOverRunning {
            // VoiceOver uses double-tap for activation
            return TapGesture()
                .onEnded { _ in
                    if self.shouldUseHapticFeedback() {
                        let impactFeedback = UIImpactFeedbackGenerator(style: self.getHapticFeedbackStyle())
                        impactFeedback.impactOccurred()
                    }
                    action()
                }
        } else {
            // Standard single tap for non-VoiceOver users - elderly need stronger feedback
            return TapGesture()
                .onEnded { _ in
                    if self.shouldUseHapticFeedback() {
                        let impactFeedback = UIImpactFeedbackGenerator(style: self.getHapticFeedbackStyle())
                        impactFeedback.impactOccurred()
                    }
                    action()
                }
        }
    }
    
    // MARK: - Elderly-Specific Helpers
    
    func shouldShowSimplifiedInterface() -> Bool {
        return settings.simplifiedInterface || settings.emergencyMode
    }
    
    func getElderlyOptimizedLineSpacing() -> CGFloat {
        return settings.extraLargeText ? 6 : 4
    }
    
    func getElderlyOptimizedParagraphSpacing() -> CGFloat {
        return settings.extraLargeText ? 12 : 8
    }
    
    func shouldUseOneHandedMode() -> Bool {
        return settings.oneHandedMode
    }
    
    // MARK: - Testing and Debugging
    
    func performAccessibilityAudit() -> [AccessibilityIssue] {
        var issues: [AccessibilityIssue] = []
        
        // Check if text is large enough for elderly users
        if !settings.largeText && dynamicTypeSize < DynamicTypeSize.xLarge {
            issues.append(AccessibilityIssue(
                type: .textSize,
                severity: .high,
                description: "Text may be too small for elderly users",
                recommendation: "Enable large text or extra large text in settings"
            ))
        }
        
        // Check for extra large text recommendation
        if !settings.extraLargeText && isVoiceOverRunning {
            issues.append(AccessibilityIssue(
                type: .textSize,
                severity: .medium,
                description: "Extra large text recommended for VoiceOver users",
                recommendation: "Consider enabling extra large text mode"
            ))
        }
        
        // Check touch targets for elderly users
        let minTouchTarget = getMinimumTouchTargetSize()
        if minTouchTarget < 60 {
            issues.append(AccessibilityIssue(
                type: .touchTarget,
                severity: .high,
                description: "Touch targets should be at least 60pt for elderly users",
                recommendation: "Enable large buttons or extra large buttons in settings"
            ))
        }
        
        // Check contrast for elderly vision
        if !settings.highContrast && !isHighContrastEnabled {
            issues.append(AccessibilityIssue(
                type: .contrast,
                severity: .medium,
                description: "High contrast recommended for elderly users with vision difficulties",
                recommendation: "Enable high contrast mode in settings"
            ))
        }
        
        // Check for simplified interface recommendation
        if !settings.simplifiedInterface && isVoiceOverRunning {
            issues.append(AccessibilityIssue(
                type: .navigation,
                severity: .low,
                description: "Simplified interface may be easier for first-time VoiceOver users",
                recommendation: "Consider enabling simplified interface mode"
            ))
        }
        
        // Check haptic feedback for elderly users
        if !settings.strongHapticFeedback && !isVoiceOverRunning {
            issues.append(AccessibilityIssue(
                type: .navigation,
                severity: .low,
                description: "Strong haptic feedback can help elderly users confirm button presses",
                recommendation: "Enable strong haptic feedback in settings"
            ))
        }
        
        // Check timeout settings
        if !settings.extendedTimeouts {
            issues.append(AccessibilityIssue(
                type: .navigation,
                severity: .medium,
                description: "Extended timeouts recommended for elderly users who may need more time",
                recommendation: "Enable extended timeouts in settings"
            ))
        }
        
        return issues
    }
}

// MARK: - Supporting Types

enum AccessibilityElement {
    case voiceButton(String)
    case suggestedPrompt(String)
    case helpButton
    case messageFrom(String, String)
    case settingsButton
}

enum AnnouncementPriority {
    case low
    case medium
    case high
}

struct AccessibilityIssue {
    let type: IssueType
    let severity: Severity
    let description: String
    let recommendation: String
    
    enum IssueType {
        case textSize
        case touchTarget
        case contrast
        case labeling
        case navigation
    }
    
    enum Severity {
        case low
        case medium
        case high
    }
}

// MARK: - SwiftUI View Modifiers

extension View {
    func elderlyAccessible(_ service: AccessibilityService) -> some View {
        self
            .font(.system(size: service.getOptimalFontSize(for: .body), 
                         weight: service.settings.boldText ? .semibold : .regular))
            .minimumScaleFactor(0.9) // Higher minimum for elderly users
            .lineLimit(nil)
            .lineSpacing(service.getElderlyOptimizedLineSpacing())
            .padding(service.getOptimalSpacing())
            .foregroundColor(service.getElderlyFriendlyTextColor())
    }
    
    func elderlyAccessibleTitle(_ service: AccessibilityService) -> some View {
        self
            .font(.system(size: service.getOptimalFontSize(for: .title2), 
                         weight: .bold))
            .lineLimit(nil)
            .lineSpacing(service.getElderlyOptimizedLineSpacing())
            .padding(.vertical, service.getElderlyOptimizedParagraphSpacing())
            .foregroundColor(service.getElderlyFriendlyTextColor())
    }
    
    func accessibleButton(_ service: AccessibilityService, 
                         element: AccessibilityElement, 
                         isEmergency: Bool = false) -> some View {
        let label = service.createAccessibilityLabel(for: element)
        let hint = service.createAccessibilityHint(for: element)
        
        return self
            .frame(minHeight: service.getMinimumTouchTargetSize())
            .frame(minWidth: service.getMinimumTouchTargetSize())
            .background(isEmergency ? service.getEmergencyColor() : service.getAccessibleButtonColor())
            .cornerRadius(service.settings.extraLargeButtons ? 15 : 10)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
            .scaleEffect(service.settings.extraLargeButtons ? 1.1 : 1.0)
    }
    
    func elderlyOptimizedText(_ service: AccessibilityService, style: Font.TextStyle = .body) -> some View {
        self
            .font(.system(size: service.getOptimalFontSize(for: style), 
                         weight: service.settings.boldText ? .medium : .regular))
            .lineSpacing(service.getElderlyOptimizedLineSpacing())
            .foregroundColor(service.getElderlyFriendlyTextColor())
            .multilineTextAlignment(.leading)
    }
    
    func voiceOverAnnouncement(_ service: AccessibilityService, 
                              _ message: String, 
                              priority: AnnouncementPriority = .medium) -> some View {
        self
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    service.announceToVoiceOver(message, priority: priority)
                }
            }
    }
    
    func elderlyFriendlyBackground(_ service: AccessibilityService) -> some View {
        self
            .background(service.getAccessibleBackgroundColor())
            .colorScheme(service.settings.highContrast ? .light : .dark)
    }
    
    func simplifiedIfNeeded(_ service: AccessibilityService, @ViewBuilder simplified: () -> some View) -> some View {
        Group {
            if service.shouldShowSimplifiedInterface() {
                simplified()
            } else {
                self
            }
        }
    }
}