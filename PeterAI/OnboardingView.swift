import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var userStore: UserStore
    @State private var currentScreen = 0
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var userLocation = ""
    @State private var showingPayment = false
    @State private var isAnimating = false
    
    let totalScreens = 11
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Help") {
                        }
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                    
                    ScrollView {
                        VStack(spacing: 40) {
                            switch currentScreen {
                            case 0:
                                WelcomeScreen()
                            case 1:
                                NameInputScreen(userName: $userName)
                            case 2:
                                GreetingScreen(userName: userName)
                            case 3:
                                EmailInputScreen(userEmail: $userEmail)
                            case 4:
                                EmailConfirmationScreen()
                            case 5:
                                LocationInputScreen(userLocation: $userLocation)
                            case 6:
                                LocationConfirmationScreen(location: userLocation)
                            case 7:
                                PaymentSelectionScreen {
                                    advanceScreen()
                                }
                            case 8:
                                PaymentProcessingScreen()
                            case 9:
                                PaymentProcessingScreen()
                            case 10:
                                CompletionScreen {
                                    completeOnboarding()
                                }
                            default:
                                WelcomeScreen()
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            startAutoAdvancement()
        }
    }
    
    private func startAutoAdvancement() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if currentScreen == 0 || currentScreen == 2 || currentScreen == 4 || currentScreen == 6 {
                advanceScreen()
            }
        }
    }
    
    private func advanceScreen() {
        withAnimation(.easeInOut(duration: 0.5)) {
            if currentScreen < totalScreens - 1 {
                currentScreen += 1
            } else {
                completeOnboarding()
            }
        }
        
        if currentScreen == 0 || currentScreen == 2 || currentScreen == 4 || currentScreen == 6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                advanceScreen()
            }
        }
    }
    
    private func completeOnboarding() {
        userStore.firstName = userName
        userStore.email = userEmail
        userStore.location = userLocation
        userStore.completeOnboarding()
    }
}

struct WelcomeScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "person.wave.2.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Hi 👋 My name is Peter. I'm your friendly AI companion.")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct NameInputScreen: View {
    @Binding var userName: String
    
    var body: some View {
        VStack(spacing: 30) {
            Text("What's your name?")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
            
            TextField("Your Name", text: $userName)
                .font(.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 20)
            
            Button("OK") {
            }
            .font(.title2)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.blue)
            .cornerRadius(30)
            .padding(.horizontal, 20)
        }
    }
}

struct GreetingScreen: View {
    let userName: String
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Nice to meet you, \(userName)! I'm here to help you 24/7.")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct EmailInputScreen: View {
    @Binding var userEmail: String
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Almost done! I just need your email address to send you your daily summary.")
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
            
            TextField("Your Email", text: $userEmail)
                .font(.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding(.horizontal, 20)
            
            Button("OK") {
            }
            .font(.title2)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.blue)
            .cornerRadius(30)
            .padding(.horizontal, 20)
        }
    }
}

struct EmailConfirmationScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Great, that worked! Let's continue with the last steps.")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct LocationInputScreen: View {
    @Binding var userLocation: String
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Where are you based?")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
            
            Text("Please select")
                .font(.title2)
                .foregroundColor(.secondary)
            
            TextField("City", text: $userLocation)
                .font(.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 20)
            
            Button("Confirm") {
            }
            .font(.title2)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.blue)
            .cornerRadius(30)
            .padding(.horizontal, 20)
        }
    }
}

struct LocationConfirmationScreen: View {
    let location: String
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "location.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("\(location) is a lovely place! One last step and then you're done.")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct PaymentSelectionScreen: View {
    let onPaymentComplete: () -> Void
    @State private var showingPaywall = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Please choose your subscription:")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 20) {
                SubscriptionOption(
                    title: "$14.99/month",
                    isSelected: true
                )
                
                SubscriptionOption(
                    title: "$125/year",
                    subtitle: "30% discount",
                    isSelected: false
                )
            }
            
            Button("Subscribe now") {
                showingPaywall = true
            }
            .font(.title2)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.blue)
            .cornerRadius(30)
            .padding(.horizontal, 20)
            
            Text("Terms & Conditions and Privacy Policy")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showingPaywall) {
            if #available(iOS 15.0, *) {
                SubscriptionPaywallView {
                    showingPaywall = false
                    onPaymentComplete()
                }
            } else {
                LegacySubscriptionPaywallView {
                    showingPaywall = false
                    onPaymentComplete()
                }
            }
        }
    }
}

struct SubscriptionOption: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    
    init(title: String, subtitle: String? = nil, isSelected: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? .blue : .secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

struct PaymentProcessingScreen: View {
    var body: some View {
        VStack(spacing: 30) {
            ProgressView()
                .scaleEffect(2)
            
            Text("Processing payment...")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

struct CompletionScreen: View {
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)
            
            Text("You're all set! 🎉 Congrats, you've finished the onboarding. Let's get started!")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Let's go") {
                onComplete()
            }
            .font(.title2)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.blue)
            .cornerRadius(30)
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(UserStore())
}