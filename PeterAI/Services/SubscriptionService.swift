import Foundation
import StoreKit

@available(iOS 15.0, *)
class SubscriptionService: NSObject, ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProducts: Set<String> = []
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    @Published var isLoading = false
    @Published var error: SubscriptionError?
    @Published var serverVerificationPassed: Bool = false
    
    private var updateListenerTask: Task<Void, Error>?
    private var isActive = true
    private var lastServerVerification: Date?
    
    // Product IDs - these must match your App Store Connect configuration
    private let productIdentifiers: Set<String> = [
        "com.phira.peterai.essential_monthly",
        "com.phira.peterai.essential_annual"
    ]
    
    enum SubscriptionStatus {
        case unknown
        case notSubscribed
        case subscribed(Product)
        case expired
        case inGracePeriod
        case inBillingRetryPeriod
        case revoked
    }
    
    enum SubscriptionError: Error, LocalizedError {
        case storeKitError(Error)
        case noProductsFound
        case purchaseFailed
        case verificationFailed
        case networkError
        case userCancelled
        
        var errorDescription: String? {
            switch self {
            case .storeKitError(let error):
                return "Store error: \(error.localizedDescription)"
            case .noProductsFound:
                return "No subscription plans found"
            case .purchaseFailed:
                return "Purchase failed"
            case .verificationFailed:
                return "Could not verify purchase"
            case .networkError:
                return "Network connection required"
            case .userCancelled:
                return "Purchase cancelled"
            }
        }
    }
    
    override init() {
        super.init()
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        isActive = false
        updateListenerTask?.cancel()
        updateListenerTask = nil
    }
    
    // MARK: - Product Loading
    
    @MainActor
    func loadProducts() async {
        isLoading = true
        error = nil
        
        do {
            let storeProducts = try await Product.products(for: productIdentifiers)
            
            // Sort products: monthly first, then annual
            self.products = storeProducts.sorted { product1, product2 in
                if product1.id.contains("monthly") && product2.id.contains("annual") {
                    return true
                } else if product1.id.contains("annual") && product2.id.contains("monthly") {
                    return false
                }
                return product1.displayPrice < product2.displayPrice
            }
            
            if products.isEmpty {
                self.error = .noProductsFound
            }
            
        } catch {
            self.error = .storeKitError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Management
    
    @MainActor
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verificationResult):
                if let transaction = try checkVerified(verificationResult) {
                    await transaction.finish()
                    await updateSubscriptionStatus()
                    isLoading = false
                    return true
                } else {
                    self.error = .verificationFailed
                    isLoading = false
                    return false
                }
                
            case .userCancelled:
                self.error = .userCancelled
                isLoading = false
                return false
                
            case .pending:
                // Handle pending transactions (e.g., Ask to Buy)
                isLoading = false
                return false
                
            @unknown default:
                self.error = .purchaseFailed
                isLoading = false
                return false
            }
            
        } catch {
            self.error = .storeKitError(error)
            isLoading = false
            return false
        }
    }
    
    @MainActor
    func restorePurchases() async {
        isLoading = true
        error = nil
        
        try? await AppStore.sync()
        await updateSubscriptionStatus()
        
        isLoading = false
    }
    
    // MARK: - Subscription Status
    
    @MainActor
    func updateSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if let product = products.first(where: { $0.id == transaction.productID }) {
                    if transaction.revocationDate != nil {
                        subscriptionStatus = .revoked
                    } else if let expirationDate = transaction.expirationDate,
                              expirationDate < Date() {
                        subscriptionStatus = .expired
                    } else {
                        subscriptionStatus = .subscribed(product)
                        purchasedProducts.insert(transaction.productID)
                    }
                    return
                }
            }
        }
        
        subscriptionStatus = .notSubscribed
        purchasedProducts.removeAll()
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T? {
        switch result {
        case .unverified:
            return nil
        case .verified(let safe):
            return safe
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            guard let self = self else { return }
            
            for await result in Transaction.updates {
                guard self.isActive else { break }
                
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    var isSubscribed: Bool {
        switch subscriptionStatus {
        case .subscribed:
            return true
        default:
            return false
        }
    }
    
    var hasValidSubscription: Bool {
        switch subscriptionStatus {
        case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Server Verification (Security)
    
    func verifySubscriptionWithServer() async -> Bool {
        // Check if we've verified recently (cache for 10 minutes to avoid excessive requests)
        if let lastVerification = lastServerVerification,
           Date().timeIntervalSince(lastVerification) < 600 {
            return serverVerificationPassed
        }
        
        guard hasValidSubscription else {
            await MainActor.run {
                self.serverVerificationPassed = false
            }
            return false
        }
        
        do {
            let receiptData = await getReceiptData()
            let verified = await verifyReceiptWithServer(receiptData)
            
            await MainActor.run {
                self.serverVerificationPassed = verified
                self.lastServerVerification = Date()
            }
            
            return verified
        } catch {
            print("Server verification failed: \(error)")
            await MainActor.run {
                self.serverVerificationPassed = false
            }
            return false
        }
    }
    
    private func getReceiptData() async -> Data? {
        // Get App Store receipt
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: appStoreReceiptURL) else {
            return nil
        }
        return receiptData
    }
    
    private func verifyReceiptWithServer(_ receiptData: Data?) async -> Bool {
        guard let receiptData = receiptData else { return false }
        
        // This would be your backend verification endpoint
        let verificationURL = URL(string: "https://your-backend.com/api/verify-receipt")!
        
        var request = URLRequest(url: verificationURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "receipt_data": receiptData.base64EncodedString(),
            "password": "your_app_shared_secret", // From App Store Connect
            "exclude_old_transactions": true
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            // Parse server response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? Int {
                return status == 0 // Apple receipt validation success
            }
            
        } catch {
            print("Network verification error: \(error)")
        }
        
        // For development/testing - remove in production
        #if DEBUG
        return true // Allow development testing
        #else
        return false
        #endif
    }
    
    func getSubscriptionStatusText() -> String {
        switch subscriptionStatus {
        case .unknown:
            return "Checking subscription..."
        case .notSubscribed:
            return "No active subscription"
        case .subscribed(let product):
            return "Subscribed to \(product.displayName)"
        case .expired:
            return "Subscription expired"
        case .inGracePeriod:
            return "Subscription in grace period"
        case .inBillingRetryPeriod:
            return "Payment issue - retrying"
        case .revoked:
            return "Subscription revoked"
        }
    }
    
    func getProductDisplayInfo(for product: Product) -> ProductDisplayInfo {
        let isMonthly = product.id.contains("monthly")
        let price = product.displayPrice
        
        return ProductDisplayInfo(
            id: product.id,
            title: isMonthly ? "Monthly Plan" : "Annual Plan",
            price: price,
            description: isMonthly ? "Billed monthly" : "30% savings - Billed yearly",
            period: isMonthly ? "month" : "year",
            isRecommended: !isMonthly, // Annual is recommended
            savings: isMonthly ? nil : "Save 30%"
        )
    }
    
    // MARK: - Legacy iOS Support
    
    func purchaseLegacy(_ productId: String) async -> Bool {
        // Fallback for iOS < 15.0 using SKPayment
        // This would use the older StoreKit APIs
        return false
    }
}

// MARK: - Supporting Types

struct ProductDisplayInfo {
    let id: String
    let title: String
    let price: String
    let description: String
    let period: String
    let isRecommended: Bool
    let savings: String?
}

// MARK: - Legacy StoreKit Support (iOS < 15.0)

class LegacySubscriptionService: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    @Published var products: [SKProduct] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var hasActiveSubscription = false
    @Published var serverVerificationPassed: Bool = false
    
    private var lastServerVerification: Date?
    
    private let productIdentifiers: Set<String> = [
        "com.phira.peterai.essential_monthly",
        "com.phira.peterai.essential_annual"
    ]
    
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
        loadProducts()
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    func loadProducts() {
        isLoading = true
        let request = SKProductsRequest(productIdentifiers: productIdentifiers)
        request.delegate = self
        request.start()
    }
    
    func purchase(_ product: SKProduct) {
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    // MARK: - Server Verification (Security)
    
    var hasValidSubscription: Bool {
        return hasActiveSubscription
    }
    
    func verifySubscriptionWithServer() async -> Bool {
        // Check if we've verified recently (cache for 10 minutes)
        if let lastVerification = lastServerVerification,
           Date().timeIntervalSince(lastVerification) < 600 {
            return serverVerificationPassed
        }
        
        guard hasActiveSubscription else {
            await MainActor.run {
                self.serverVerificationPassed = false
            }
            return false
        }
        
        let receiptData = getReceiptData()
        let verified = await verifyReceiptWithServer(receiptData)
        
        await MainActor.run {
            self.serverVerificationPassed = verified
            self.lastServerVerification = Date()
        }
        
        return verified
    }
    
    private func getReceiptData() -> Data? {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: appStoreReceiptURL) else {
            return nil
        }
        return receiptData
    }
    
    private func verifyReceiptWithServer(_ receiptData: Data?) async -> Bool {
        guard let receiptData = receiptData else { return false }
        
        // Same server verification logic as modern SubscriptionService
        let verificationURL = URL(string: "https://your-backend.com/api/verify-receipt")!
        
        var request = URLRequest(url: verificationURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "receipt_data": receiptData.base64EncodedString(),
            "password": "your_app_shared_secret",
            "exclude_old_transactions": true
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? Int {
                return status == 0
            }
            
        } catch {
            print("Legacy network verification error: \(error)")
        }
        
        #if DEBUG
        return true // Allow development testing
        #else
        return false
        #endif
    }
    
    // MARK: - SKProductsRequestDelegate
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.products = response.products.sorted { product1, product2 in
                if product1.productIdentifier.contains("monthly") && product2.productIdentifier.contains("annual") {
                    return true
                }
                return false
            }
            self.isLoading = false
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }
    
    // MARK: - SKPaymentTransactionObserver
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                DispatchQueue.main.async {
                    self.hasActiveSubscription = true
                }
                queue.finishTransaction(transaction)
                
            case .failed:
                if let error = transaction.error as? SKError {
                    if error.code != .paymentCancelled {
                        DispatchQueue.main.async {
                            self.error = error.localizedDescription
                        }
                    }
                }
                queue.finishTransaction(transaction)
                
            case .restored:
                DispatchQueue.main.async {
                    self.hasActiveSubscription = true
                }
                queue.finishTransaction(transaction)
                
            case .deferred, .purchasing:
                break
                
            @unknown default:
                break
            }
        }
    }
}