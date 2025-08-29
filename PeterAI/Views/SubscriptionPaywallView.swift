import SwiftUI
import StoreKit

struct SubscriptionPaywallView: View {
    @StateObject private var subscriptionService = SubscriptionService()
    @EnvironmentObject var userStore: UserStore
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedProductId: String?
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    @State private var purchaseInProgress = false
    
    let onSubscribed: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        headerSection
                        benefitsSection
                        pricingSection
                        subscribeButton
                        legalSection
                        restoreButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            if subscriptionService.products.isEmpty {
                await subscriptionService.loadProducts()
            }
        }
        .alert(item: Binding<AlertItem?>(
            get: { 
                if let error = subscriptionService.error {
                    return AlertItem(error: error)
                }
                return nil
            },
            set: { _ in subscriptionService.error = nil }
        )) { alertItem in
            Alert(
                title: Text("Subscription Error"),
                message: Text(alertItem.error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "person.wave.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Welcome to Peter AI")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Your friendly AI companion designed specifically for seniors")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var benefitsSection: some View {
        VStack(spacing: 20) {
            Text("What You Get:")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 15) {
                BenefitRow(
                    icon: "mic.fill",
                    title: "Unlimited Voice Conversations",
                    description: "Ask Peter anything, anytime with natural voice interaction"
                )
                
                BenefitRow(
                    icon: "envelope.fill",
                    title: "Daily Email Summaries",
                    description: "Get a friendly recap of your conversations every day at 6 PM"
                )
                
                BenefitRow(
                    icon: "lightbulb.fill",
                    title: "Smart Suggested Questions",
                    description: "Helpful prompts for weather, recipes, health tips, and more"
                )
                
                BenefitRow(
                    icon: "phone.fill",
                    title: "24/7 Support",
                    description: "Access to help guides and human support when you need it"
                )
                
                BenefitRow(
                    icon: "heart.fill",
                    title: "Senior-Friendly Design",
                    description: "Large text, simple interface, and patient responses"
                )
            }
        }
        .padding(.vertical, 10)
    }
    
    private var pricingSection: some View {
        VStack(spacing: 15) {
            Text("Choose Your Plan:")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if subscriptionService.isLoading {
                ProgressView("Loading plans...")
                    .frame(height: 100)
            } else if subscriptionService.products.isEmpty {
                VStack {
                    Text("Unable to load subscription plans")
                        .foregroundColor(.secondary)
                    
                    Button("Retry") {
                        Task {
                            await subscriptionService.loadProducts()
                        }
                    }
                    .foregroundColor(.blue)
                }
                .frame(height: 100)
            } else {
                ForEach(subscriptionService.products, id: \.id) { product in
                    PricingCard(
                        product: product,
                        displayInfo: subscriptionService.getProductDisplayInfo(for: product),
                        isSelected: selectedProductId == product.id
                    ) {
                        selectedProductId = product.id
                    }
                }
            }
        }
    }
    
    private var subscribeButton: some View {
        Button(action: handleSubscribe) {
            HStack {
                if purchaseInProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(purchaseInProgress ? "Processing..." : "Subscribe Now")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(selectedProductId != nil ? Color.blue : Color.gray)
            .cornerRadius(30)
        }
        .disabled(selectedProductId == nil || purchaseInProgress)
    }
    
    private var legalSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                Button("Terms of Service") {
                    showingTerms = true
                }
                .font(.footnote)
                .foregroundColor(.blue)
                
                Button("Privacy Policy") {
                    showingPrivacy = true
                }
                .font(.footnote)
                .foregroundColor(.blue)
            }
            
            Text("Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. You can manage your subscription in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
    }
    
    private var restoreButton: some View {
        Button("Already subscribed? Restore Purchases") {
            Task {
                await subscriptionService.restorePurchases()
                
                if subscriptionService.hasValidSubscription {
                    userStore.updateSubscriptionStatus(true)
                    onSubscribed()
                }
            }
        }
        .font(.callout)
        .foregroundColor(.blue)
        .padding(.top, 10)
    }
    
    private func handleSubscribe() {
        guard let productId = selectedProductId,
              let product = subscriptionService.products.first(where: { $0.id == productId }) else {
            return
        }
        
        purchaseInProgress = true
        
        Task {
            let success = await subscriptionService.purchase(product)
            
            await MainActor.run {
                purchaseInProgress = false
                
                if success {
                    userStore.updateSubscriptionStatus(true)
                    onSubscribed()
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
                .frame(minWidth: 24)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 5)
    }
}

@available(iOS 15.0, *)
struct PricingCard: View {
    let product: Product
    let displayInfo: ProductDisplayInfo
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(displayInfo.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        if displayInfo.isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                    
                    Text(product.displayPrice)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text(displayInfo.description)
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    if let savings = displayInfo.savings {
                        Text(savings)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(isSelected ? Color.blue.opacity(0.05) : Color(.systemGray6))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let error: SubscriptionService.SubscriptionError
}

// MARK: - Legacy iOS Support

struct LegacySubscriptionPaywallView: View {
    @StateObject private var subscriptionService = LegacySubscriptionService()
    @EnvironmentObject var userStore: UserStore
    @State private var selectedProduct: SKProduct?
    
    let onSubscribed: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Subscribe to Peter AI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if subscriptionService.isLoading {
                    ProgressView("Loading plans...")
                } else if subscriptionService.products.isEmpty {
                    Text("No subscription plans available")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(subscriptionService.products, id: \.productIdentifier) { product in
                        LegacyPricingCard(
                            product: product,
                            isSelected: selectedProduct?.productIdentifier == product.productIdentifier
                        ) {
                            selectedProduct = product
                        }
                    }
                }
                
                Button("Subscribe") {
                    if let product = selectedProduct {
                        subscriptionService.purchase(product)
                    }
                }
                .disabled(selectedProduct == nil)
                .font(.title2)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(selectedProduct != nil ? Color.blue : Color.gray)
                .cornerRadius(25)
                
                Button("Restore Purchases") {
                    subscriptionService.restorePurchases()
                }
                .foregroundColor(.blue)
                
                Spacer()
            }
            .padding(30)
        }
        .onChange(of: subscriptionService.hasActiveSubscription) { _, hasSubscription in
            if hasSubscription {
                userStore.updateSubscriptionStatus(true)
                onSubscribed()
            }
        }
    }
}

struct LegacyPricingCard: View {
    let product: SKProduct
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(product.localizedTitle)
                        .font(.headline)
                    
                    Text(product.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(formatPrice(product))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatPrice(_ product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "\(product.price)"
    }
}

#Preview {
    if #available(iOS 15.0, *) {
        SubscriptionPaywallView(onSubscribed: {})
            .environmentObject(UserStore())
    } else {
        LegacySubscriptionPaywallView(onSubscribed: {})
            .environmentObject(UserStore())
    }
}