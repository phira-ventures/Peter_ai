import SwiftUI

@main
struct PeterAIApp: App {
    @AppStorage("onboarding_completed") private var onboardingCompleted = false
    
    var body: some Scene {
        WindowGroup {
            if onboardingCompleted {
                MainAppView()
            } else {
                OnboardingView()
            }
        }
    }
}