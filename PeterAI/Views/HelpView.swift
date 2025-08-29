import SwiftUI

struct HelpView: View {
    @AppStorage("user_name") private var userName = "friend"
    @State private var selectedSection: HelpSection = .gettingStarted
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 15) {
                    Circle()
                        .fill(Color.green.gradient)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("❓")
                                .font(.system(size: 40))
                        )
                    
                    VStack(spacing: 8) {
                        Text("Help & Support")
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text("I'm here to help you, \(userName)!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Section Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(HelpSection.allCases, id: \.self) { section in
                            HelpSectionButton(
                                section: section,
                                isSelected: selectedSection == section
                            ) {
                                withAnimation(.easeInOut) {
                                    selectedSection = section
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 25)
                
                // Help Content
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(getHelpItemsFor(selectedSection)) { item in
                            HelpCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    private func getHelpItemsFor(_ section: HelpSection) -> [HelpItem] {
        switch section {
        case .gettingStarted:
            return [
                HelpItem(
                    id: "first-conversation",
                    icon: "message.circle.fill",
                    title: "Starting Your First Conversation",
                    content: "Tap the microphone button on the main screen and speak clearly. I'll listen and respond to your questions or comments. You can also use the quick action buttons for common requests."
                ),
                HelpItem(
                    id: "voice-tips",
                    icon: "mic.fill",
                    title: "Voice Tips",
                    content: "Speak at a normal pace and volume. Make sure you're in a quiet environment for best results. If I don't understand, try rephrasing your question or speaking a bit more slowly."
                ),
                HelpItem(
                    id: "navigation",
                    icon: "square.grid.2x2.fill",
                    title: "Navigating the App",
                    content: "Use the tabs at the bottom to move between Chat, Ideas, Settings, and Help. The Chat tab is where we have our conversations, Ideas shows you things to ask me, and Settings lets you customize your experience."
                )
            ]
        case .voiceAndAudio:
            return [
                HelpItem(
                    id: "microphone-permission",
                    icon: "mic.circle.fill",
                    title: "Microphone Permission",
                    content: "If the app can't hear you, check that you've given microphone permission. Go to your phone's Settings > Privacy & Security > Microphone, and make sure Peter AI is turned on."
                ),
                HelpItem(
                    id: "audio-problems",
                    icon: "speaker.wave.3.fill",
                    title: "If You Can't Hear Me",
                    content: "Check your phone's volume using the side buttons. You can also turn off 'Auto-Speak Responses' in Settings if you prefer to read my replies instead of hearing them."
                ),
                HelpItem(
                    id: "voice-quality",
                    icon: "waveform",
                    title: "Improving Voice Quality",
                    content: "For best results, hold your phone about 6-12 inches from your mouth. Speak clearly but naturally - you don't need to shout or whisper. Try to use the app in a quiet room when possible."
                )
            ]
        case .conversation:
            return [
                HelpItem(
                    id: "what-to-ask",
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "What Can I Ask Peter?",
                    content: "Ask me about weather, health tips, recipes, jokes, stories, or just chat about your day. I enjoy talking about family, hobbies, memories, and helping with daily planning. Check the Ideas tab for specific suggestions."
                ),
                HelpItem(
                    id: "personal-info",
                    icon: "person.fill",
                    title: "Your Personal Information",
                    content: "I remember your name, email, and location from when you set up the app. This helps me give you personalized responses, like weather for your area. You can update this information in Settings anytime."
                ),
                HelpItem(
                    id: "conversation-history",
                    icon: "clock.fill",
                    title: "Conversation History",
                    content: "I remember our conversation during each session, so you can refer back to things we discussed. However, I start fresh each time you open the app - this helps protect your privacy."
                )
            ]
        case .troubleshooting:
            return [
                HelpItem(
                    id: "app-not-responding",
                    icon: "exclamationmark.triangle.fill",
                    title: "App Not Responding",
                    content: "If the app freezes or doesn't respond, try closing it completely and opening it again. On iPhones with a home button, double-tap it and swipe up on Peter AI. On newer iPhones, swipe up and pause, then swipe up on the app."
                ),
                HelpItem(
                    id: "voice-not-working",
                    icon: "mic.slash.fill",
                    title: "Voice Features Not Working",
                    content: "First, check that microphone permission is enabled. Restart the app if needed. Make sure your internet connection is working, as voice features need an active connection."
                ),
                HelpItem(
                    id: "reset-app",
                    icon: "arrow.clockwise.circle.fill",
                    title: "Starting Over",
                    content: "If you want to reset everything and start fresh, go to Settings and tap 'Reset Onboarding'. This will take you through the initial setup again and clear your personal information."
                )
            ]
        case .contact:
            return [
                HelpItem(
                    id: "get-help",
                    icon: "person.crop.circle.fill.badge.questionmark",
                    title: "Need More Help?",
                    content: "If you're still having trouble, you can contact our support team. We're here to help make sure you have the best experience with Peter AI."
                ),
                HelpItem(
                    id: "feedback",
                    icon: "star.fill",
                    title: "Share Your Feedback",
                    content: "We love hearing from users! Let us know what you like about Peter AI, what could be better, or suggest new features. Your input helps us make the app even better for everyone."
                ),
                HelpItem(
                    id: "emergency",
                    icon: "phone.fill.arrow.down.left",
                    title: "Emergency Situations",
                    content: "Peter AI is not for emergencies. If you need immediate medical help or are in danger, call 911 (or your local emergency number) right away. For urgent but non-emergency health concerns, contact your doctor or local urgent care."
                )
            ]
        }
    }
}

struct HelpSectionButton: View {
    let section: HelpSection
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(section.title)
                .font(.body.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    isSelected ? Color.green : Color(UIColor.systemBackground)
                )
                .foregroundColor(
                    isSelected ? .white : .primary
                )
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HelpCard: View {
    let item: HelpItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 15) {
                    // Icon
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: item.icon)
                                .font(.title2)
                                .foregroundColor(.green)
                        )
                    
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // Expand/Collapse Icon
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.horizontal)
                    
                    Text(item.content)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .multilineTextAlignment(.leading)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

enum HelpSection: String, CaseIterable {
    case gettingStarted = "getting_started"
    case voiceAndAudio = "voice_audio"
    case conversation = "conversation"
    case troubleshooting = "troubleshooting"
    case contact = "contact"
    
    var title: String {
        switch self {
        case .gettingStarted: return "Getting Started"
        case .voiceAndAudio: return "Voice & Audio"
        case .conversation: return "Conversation"
        case .troubleshooting: return "Troubleshooting"
        case .contact: return "Contact & Support"
        }
    }
}

struct HelpItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let content: String
}

#Preview {
    HelpView()
}