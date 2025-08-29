import SwiftUI

struct SubscriptionGuard<Content: View>: View {
    @EnvironmentObject var userStore: UserStore
    @StateObject private var subscriptionService = SubscriptionService()
    @State private var showingPaywall = false
    @State private var isVerifying = true
    @State private var verificationFailed = false
    
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        Group {
            if isVerifying {
                verifyingSubscriptionView
            } else if hasValidatedSubscription {
                content
            } else {
                subscriptionRequiredView
            }
        }
        .task {
            await verifySubscription()
        }
        .sheet(isPresented: $showingPaywall) {
            if #available(iOS 15.0, *) {
                SubscriptionPaywallView {
                    showingPaywall = false
                }
                .environmentObject(userStore)
            } else {
                LegacySubscriptionPaywallView {
                    showingPaywall = false
                }
                .environmentObject(userStore)
            }
        }
    }
    
    // MARK: - Security Logic
    
    private var hasValidatedSubscription: Bool {
        // Require BOTH local subscription AND server verification to be true
        return subscriptionService.hasValidSubscription && 
               subscriptionService.serverVerificationPassed &&
               userStore.hasActiveSubscription
    }
    
    private func verifySubscription() async {
        isVerifying = true
        verificationFailed = false
        
        // Step 1: Update local subscription status
        await subscriptionService.updateSubscriptionStatus()
        
        // Step 2: Verify with server (critical security step)
        let serverVerified = await subscriptionService.verifySubscriptionWithServer()
        
        // Step 3: Update user store only if server verification passes
        if subscriptionService.hasValidSubscription && serverVerified {
            userStore.updateSubscriptionStatus(true)
        } else {
            userStore.updateSubscriptionStatus(false)
            verificationFailed = !serverVerified
        }
        
        isVerifying = false
    }
    
    private var verifyingSubscriptionView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            Text("Verifying your subscription...")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var subscriptionRequiredView: some View {
        VStack(spacing: 30) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            VStack(spacing: 15) {
                Text("Subscription Required")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Peter AI requires an active subscription to continue chatting. Your subscription may have expired or there may be a billing issue.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 15) {
                Button("View Subscription Plans") {
                    showingPaywall = true
                }
                .font(.title2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.blue)
                .cornerRadius(30)
                
                Button("Restore Purchases") {
                    Task {
                        await subscriptionService.restorePurchases()
                        
                        if subscriptionService.hasValidSubscription {
                            userStore.updateSubscriptionStatus(true)
                        }
                    }
                }
                .font(.title3)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(25)
                
                Button("Contact Support") {
                    if let url = URL(string: "tel:+18001234567") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(30)
    }
}

struct SubscriptionStatusView: View {
    @EnvironmentObject var userStore: UserStore
    @StateObject private var subscriptionService = SubscriptionService()
    @State private var showingPaywall = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                headerSection
                statusSection
                actionsSection
                Spacer()
            }
            .padding(30)
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await subscriptionService.updateSubscriptionStatus()
        }
        .sheet(isPresented: $showingPaywall) {
            if #available(iOS 15.0, *) {
                SubscriptionPaywallView {
                    showingPaywall = false
                }
                .environmentObject(userStore)
            } else {
                LegacySubscriptionPaywallView {
                    showingPaywall = false
                }
                .environmentObject(userStore)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: subscriptionIcon)
                .font(.system(size: 60))
                .foregroundColor(subscriptionColor)
            
            Text("Peter AI Subscription")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
    
    private var statusSection: some View {
        VStack(spacing: 15) {
            Text("Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(subscriptionService.getSubscriptionStatusText())
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(subscriptionStatusDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: subscriptionIcon)
                    .font(.title2)
                    .foregroundColor(subscriptionColor)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 15) {
            if !subscriptionService.hasValidSubscription {
                Button("Subscribe Now") {
                    showingPaywall = true
                }
                .font(.title2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(25)
            }
            
            Button("Restore Purchases") {
                Task {
                    await subscriptionService.restorePurchases()
                }
            }
            .font(.title3)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(25)
            
            if subscriptionService.hasValidSubscription {
                Button("Manage Subscription") {
                    if let settingsUrl = URL(string: "App-prefs:root=SUBSCRIPTIONS") {
                        UIApplication.shared.open(settingsUrl)
                    } else if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }
        }
    }
    
    private var subscriptionIcon: String {
        switch subscriptionService.subscriptionStatus {
        case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
            return "checkmark.circle.fill"
        case .expired:
            return "exclamationmark.triangle.fill"
        case .revoked:
            return "xmark.circle.fill"
        case .notSubscribed, .unknown:
            return "minus.circle.fill"
        }
    }
    
    private var subscriptionColor: Color {
        switch subscriptionService.subscriptionStatus {
        case .subscribed, .inGracePeriod:
            return .green
        case .inBillingRetryPeriod:
            return .orange
        case .expired, .revoked:
            return .red
        case .notSubscribed, .unknown:
            return .gray
        }
    }
    
    private var subscriptionStatusDescription: String {
        switch subscriptionService.subscriptionStatus {
        case .unknown:
            return "Checking your subscription status..."
        case .notSubscribed:
            return "You don't have an active Peter AI subscription."
        case .subscribed:
            return "You have full access to all Peter AI features."
        case .expired:
            return "Your subscription has expired. Renew to continue using Peter AI."
        case .inGracePeriod:
            return "Your subscription has a billing issue but you still have access."
        case .inBillingRetryPeriod:
            return "There's a payment issue. Apple is retrying the payment."
        case .revoked:
            return "Your subscription has been revoked. Please contact support."
        }
    }
}

#Preview {
    SubscriptionGuard {
        Text("Main Content Here")
    }
    .environmentObject(UserStore())
}