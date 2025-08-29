import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var userLocation = ""
    
    let totalSteps = 6
    
    var body: some View {
        VStack(spacing: 40) {
            // Progress indicator
            HStack {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Main content based on current step
            Group {
                switch currentStep {
                case 0: welcomeScreen
                case 1: nameInputScreen
                case 2: emailInputScreen
                case 3: locationInputScreen
                case 4: permissionsScreen
                case 5: completionScreen
                default: welcomeScreen
                }
            }
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 20) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut) {
                            currentStep = max(0, currentStep - 1)
                        }
                    }
                    .font(.title2)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(25)
                }
                
                Spacer()
                
                Button(currentStep == totalSteps - 1 ? "Let's Start!" : "Continue") {
                    withAnimation(.easeInOut) {
                        if currentStep < totalSteps - 1 {
                            currentStep += 1
                        } else {
                            completeOnboarding()
                        }
                    }
                }
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(canProceed ? Color.blue : Color.gray)
                .cornerRadius(25)
                .disabled(!canProceed)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 1: return !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2: return !userEmail.isEmpty && userEmail.contains("@")
        case 3: return !userLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default: return true
        }
    }
    
    // MARK: - Onboarding Screens
    
    private var welcomeScreen: some View {
        VStack(spacing: 30) {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 150, height: 150)
                .overlay(
                    Text("👴🏻")
                        .font(.system(size: 80))
                )
            
            VStack(spacing: 15) {
                Text("Hello! I'm Peter")
                    .font(.largeTitle.weight(.bold))
                
                Text("I'm your friendly AI assistant, designed especially for you.")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                Text("I can help you with:")
                    .font(.title3.weight(.medium))
                
                VStack(alignment: .leading, spacing: 8) {
                    HelpFeature(icon: "☀️", text: "Weather and daily planning")
                    HelpFeature(icon: "💬", text: "Friendly conversations")
                    HelpFeature(icon: "ℹ️", text: "General questions and information")
                    HelpFeature(icon: "🏥", text: "Health and wellness tips")
                }
            }
        }
    }
    
    private var nameInputScreen: some View {
        VStack(spacing: 30) {
            Text("What should I call you?")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            
            Text("I'd love to know your name so I can address you properly.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            TextField("Enter your first name", text: $userName)
                .font(.title2)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .frame(height: 60)
                .autocorrectionDisabled()
            
            if !userName.isEmpty {
                Text("Nice to meet you, \(userName)!")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var emailInputScreen: some View {
        VStack(spacing: 30) {
            Text("Email Address")
                .font(.largeTitle.weight(.bold))
            
            Text("I can send you daily summaries of our conversations (optional).")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            TextField("your@email.com", text: $userEmail)
                .font(.title2)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .autocapitalization(.none)
                .padding(.horizontal)
                .frame(height: 60)
            
            Text("Don't worry - I'll never share your email with anyone else.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
    
    private var locationInputScreen: some View {
        VStack(spacing: 30) {
            Text("Where are you located?")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            
            Text("This helps me provide accurate weather information and local recommendations.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            TextField("City, State", text: $userLocation)
                .font(.title2)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .frame(height: 60)
            
            Text("For example: Boston, MA or London, UK")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
    
    private var permissionsScreen: some View {
        VStack(spacing: 30) {
            Text("Let's set up voice chat")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            
            Text("Peter works best when he can hear and speak with you.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 20) {
                PermissionItem(
                    icon: "🎤",
                    title: "Microphone Access",
                    description: "So I can hear your questions and requests"
                )
                
                PermissionItem(
                    icon: "🔊",
                    title: "Speech Playback", 
                    description: "So I can speak my responses out loud"
                )
            }
            
            Text("You can change these permissions anytime in Settings.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var completionScreen: some View {
        VStack(spacing: 30) {
            Circle()
                .fill(Color.green.gradient)
                .frame(width: 120, height: 120)
                .overlay(
                    Text("🎉")
                        .font(.system(size: 60))
                )
            
            VStack(spacing: 15) {
                Text("You're all set, \(userName)!")
                    .font(.largeTitle.weight(.bold))
                
                Text("I'm excited to start chatting with you.")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                Text("Remember:")
                    .font(.title3.weight(.medium))
                
                VStack(alignment: .leading, spacing: 8) {
                    TipItem(text: "Speak clearly and at a normal pace")
                    TipItem(text: "I'm here to help with any questions")
                    TipItem(text: "You can ask for help anytime")
                }
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        UserDefaults.standard.set(userName, forKey: "user_name")
        UserDefaults.standard.set(userEmail, forKey: "user_email")
        UserDefaults.standard.set(userLocation, forKey: "user_location")
    }
}

struct HelpFeature: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title2)
            Text(text)
                .font(.title3)
            Spacer()
        }
    }
}

struct PermissionItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Text(icon)
                .font(.title)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TipItem: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text("💡")
                .font(.title3)
            Text(text)
                .font(.title3)
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}