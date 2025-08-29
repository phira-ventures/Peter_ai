import SwiftUI

struct SettingsView: View {
    @AppStorage("user_name") private var userName = "friend"
    @AppStorage("user_email") private var userEmail = ""
    @AppStorage("user_location") private var userLocation = ""
    @AppStorage("voice_enabled") private var voiceEnabled = true
    @AppStorage("large_text") private var largeText = false
    @AppStorage("high_contrast") private var highContrast = false
    @AppStorage("auto_speak") private var autoSpeak = true
    @AppStorage("daily_reminders") private var dailyReminders = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 15) {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("⚙️")
                                .font(.system(size: 40))
                        )
                    
                    Text("Settings")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Settings List
                ScrollView {
                    VStack(spacing: 20) {
                        // Personal Information Section
                        SettingsSection(title: "Personal Information") {
                            VStack(spacing: 15) {
                                SettingsRow(
                                    icon: "person.circle.fill",
                                    title: "Your Name",
                                    subtitle: userName.isEmpty ? "Not set" : userName
                                )
                                
                                SettingsRow(
                                    icon: "envelope.circle.fill",
                                    title: "Email Address", 
                                    subtitle: userEmail.isEmpty ? "Not set" : userEmail
                                )
                                
                                SettingsRow(
                                    icon: "location.circle.fill",
                                    title: "Location",
                                    subtitle: userLocation.isEmpty ? "Not set" : userLocation
                                )
                            }
                        }
                        
                        // Voice & Audio Section
                        SettingsSection(title: "Voice & Audio") {
                            VStack(spacing: 15) {
                                SettingsToggle(
                                    icon: "mic.circle.fill",
                                    title: "Voice Input",
                                    subtitle: "Allow Peter to listen to your voice",
                                    isOn: $voiceEnabled
                                )
                                
                                SettingsToggle(
                                    icon: "speaker.wave.2.circle.fill",
                                    title: "Auto-Speak Responses",
                                    subtitle: "Peter will speak responses out loud",
                                    isOn: $autoSpeak
                                )
                            }
                        }
                        
                        // Accessibility Section
                        SettingsSection(title: "Accessibility") {
                            VStack(spacing: 15) {
                                SettingsToggle(
                                    icon: "textformat.size.larger.circle.fill",
                                    title: "Large Text",
                                    subtitle: "Use larger font sizes throughout the app",
                                    isOn: $largeText
                                )
                                
                                SettingsToggle(
                                    icon: "circle.righthalf.filled",
                                    title: "High Contrast",
                                    subtitle: "Increase contrast for better visibility",
                                    isOn: $highContrast
                                )
                            }
                        }
                        
                        // Notifications Section  
                        SettingsSection(title: "Notifications") {
                            VStack(spacing: 15) {
                                SettingsToggle(
                                    icon: "bell.circle.fill",
                                    title: "Daily Check-ins",
                                    subtitle: "Get friendly reminders throughout the day",
                                    isOn: $dailyReminders
                                )
                            }
                        }
                        
                        // Support Section
                        SettingsSection(title: "Support") {
                            VStack(spacing: 15) {
                                SettingsRow(
                                    icon: "questionmark.circle.fill",
                                    title: "Help & FAQ",
                                    subtitle: "Get help using Peter"
                                )
                                
                                SettingsRow(
                                    icon: "phone.circle.fill", 
                                    title: "Contact Support",
                                    subtitle: "Reach out if you need assistance"
                                )
                                
                                SettingsRow(
                                    icon: "star.circle.fill",
                                    title: "Rate Peter AI",
                                    subtitle: "Help us improve with your feedback"
                                )
                            }
                        }
                        
                        // Reset Section
                        SettingsSection(title: "Reset") {
                            VStack(spacing: 15) {
                                Button(action: resetOnboarding) {
                                    SettingsRow(
                                        icon: "arrow.clockwise.circle.fill",
                                        title: "Reset Onboarding",
                                        subtitle: "Start the setup process again",
                                        showArrow: false
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // App Version
                        VStack(spacing: 8) {
                            Text("Peter AI")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Version 1.0")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 30)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "onboarding_completed")
        UserDefaults.standard.set("", forKey: "user_name") 
        UserDefaults.standard.set("", forKey: "user_email")
        UserDefaults.standard.set("", forKey: "user_location")
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let showArrow: Bool
    
    init(icon: String, title: String, subtitle: String, showArrow: Bool = true) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.showArrow = showArrow
    }
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            if showArrow {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}

struct SettingsToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 28, height: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .scaleEffect(1.1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView()
}