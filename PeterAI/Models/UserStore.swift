import Foundation
import Combine

class UserStore: ObservableObject {
    @Published var firstName: String = ""
    @Published var email: String = ""
    @Published var location: String = ""
    @Published var isOnboardingCompleted: Bool = false
    @Published var hasActiveSubscription: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let secureStorage = SecureStorage.shared
    
    init() {
        loadUserData()
    }
    
    private func loadUserData() {
        // Load sensitive data from secure storage
        firstName = secureStorage.retrieve(key: "user_firstName") ?? ""
        email = secureStorage.retrieve(key: "user_email") ?? ""
        location = secureStorage.retrieve(key: "user_location") ?? ""
        
        // Non-sensitive app state can stay in UserDefaults
        isOnboardingCompleted = userDefaults.bool(forKey: "isOnboardingCompleted")
        hasActiveSubscription = userDefaults.bool(forKey: "hasActiveSubscription")
    }
    
    func saveUserData() {
        // Save sensitive data to secure storage
        _ = secureStorage.store(key: "user_firstName", value: firstName)
        _ = secureStorage.store(key: "user_email", value: email)
        _ = secureStorage.store(key: "user_location", value: location)
        
        // Non-sensitive app state can stay in UserDefaults
        userDefaults.set(isOnboardingCompleted, forKey: "isOnboardingCompleted")
        userDefaults.set(hasActiveSubscription, forKey: "hasActiveSubscription")
    }
    
    func completeOnboarding() {
        isOnboardingCompleted = true
        saveUserData()
    }
    
    func updateSubscriptionStatus(_ isActive: Bool) {
        hasActiveSubscription = isActive
        saveUserData()
    }
    
    // MARK: - Data Security and GDPR Compliance
    
    func clearAllUserData() {
        // Clear published properties
        firstName = ""
        email = ""
        location = ""
        isOnboardingCompleted = false
        hasActiveSubscription = false
        
        // Remove from secure storage
        _ = secureStorage.delete(key: "user_firstName")
        _ = secureStorage.delete(key: "user_email")
        _ = secureStorage.delete(key: "user_location")
        
        // Remove from UserDefaults
        userDefaults.removeObject(forKey: "isOnboardingCompleted")
        userDefaults.removeObject(forKey: "hasActiveSubscription")
    }
    
    func validateDataIntegrity() -> Bool {
        // Check if stored data matches loaded data
        let storedFirstName = secureStorage.retrieve(key: "user_firstName") ?? ""
        let storedEmail = secureStorage.retrieve(key: "user_email") ?? ""
        let storedLocation = secureStorage.retrieve(key: "user_location") ?? ""
        
        return firstName == storedFirstName && 
               email == storedEmail && 
               location == storedLocation
    }
}