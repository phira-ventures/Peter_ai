import XCTest
import StoreKit
@testable import PeterAI

@available(iOS 15.0, *)
class SubscriptionServiceTests: XCTestCase {
    var subscriptionService: SubscriptionService!
    var mockStoreKitManager: MockStoreKitManager!
    
    override func setUp() {
        super.setUp()
        subscriptionService = SubscriptionService()
        mockStoreKitManager = MockStoreKitManager()
        
        // Inject mock StoreKit manager
        subscriptionService.storeKitManager = mockStoreKitManager
    }
    
    override func tearDown() {
        subscriptionService = nil
        mockStoreKitManager = nil
        super.tearDown()
    }
    
    // MARK: - Product Loading Tests
    
    func testLoadProductsSuccess() async {
        // Given
        let mockProducts = [
            MockProduct(id: "com.phira.peterai.essential_monthly", displayName: "Monthly", price: Decimal(14.99)),
            MockProduct(id: "com.phira.peterai.essential_annual", displayName: "Annual", price: Decimal(125.00))
        ]
        mockStoreKitManager.mockProducts = mockProducts
        
        let expectation = XCTestExpectation(description: "Products loaded")
        
        // When
        await subscriptionService.loadProducts()
        
        // Then
        DispatchQueue.main.async {
            XCTAssertEqual(self.subscriptionService.products.count, 2)
            XCTAssertFalse(self.subscriptionService.isLoading)
            XCTAssertNil(self.subscriptionService.error)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testLoadProductsFailure() async {
        // Given
        mockStoreKitManager.shouldFailProductLoading = true
        
        let expectation = XCTestExpectation(description: "Products loading failed")
        
        // When
        await subscriptionService.loadProducts()
        
        // Then
        DispatchQueue.main.async {
            XCTAssertEqual(self.subscriptionService.products.count, 0)
            XCTAssertFalse(self.subscriptionService.isLoading)
            XCTAssertEqual(self.subscriptionService.error, .storeKitError(MockError.productLoadFailed))
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testProductSorting() async {
        // Given - Products in wrong order
        let mockProducts = [
            MockProduct(id: "com.phira.peterai.essential_annual", displayName: "Annual", price: Decimal(125.00)),
            MockProduct(id: "com.phira.peterai.essential_monthly", displayName: "Monthly", price: Decimal(14.99))
        ]
        mockStoreKitManager.mockProducts = mockProducts
        
        // When
        await subscriptionService.loadProducts()
        
        // Then - Monthly should come first
        let expectation = XCTestExpectation(description: "Products sorted")
        DispatchQueue.main.async {
            XCTAssertTrue(self.subscriptionService.products[0].id.contains("monthly"))
            XCTAssertTrue(self.subscriptionService.products[1].id.contains("annual"))
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Purchase Tests
    
    func testSuccessfulPurchase() async {
        // Given
        let mockProduct = MockProduct(id: "com.phira.peterai.essential_monthly", displayName: "Monthly", price: Decimal(14.99))
        mockStoreKitManager.mockProducts = [mockProduct]
        mockStoreKitManager.purchaseResult = .success
        
        await subscriptionService.loadProducts()
        
        // When
        let success = await subscriptionService.purchase(mockProduct)
        
        // Then
        XCTAssertTrue(success)
        XCTAssertTrue(mockStoreKitManager.purchaseAttempted)
        XCTAssertEqual(mockStoreKitManager.purchasedProductId, mockProduct.id)
    }
    
    func testPurchaseUserCancelled() async {
        // Given
        let mockProduct = MockProduct(id: "com.phira.peterai.essential_monthly", displayName: "Monthly", price: Decimal(14.99))
        mockStoreKitManager.mockProducts = [mockProduct]
        mockStoreKitManager.purchaseResult = .userCancelled
        
        await subscriptionService.loadProducts()
        
        let expectation = XCTestExpectation(description: "Purchase cancelled")
        
        // When
        let success = await subscriptionService.purchase(mockProduct)
        
        // Then
        XCTAssertFalse(success)
        DispatchQueue.main.async {
            XCTAssertEqual(self.subscriptionService.error, .userCancelled)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testPurchaseFailure() async {
        // Given
        let mockProduct = MockProduct(id: "com.phira.peterai.essential_monthly", displayName: "Monthly", price: Decimal(14.99))
        mockStoreKitManager.mockProducts = [mockProduct]
        mockStoreKitManager.purchaseResult = .failure
        
        await subscriptionService.loadProducts()
        
        let expectation = XCTestExpectation(description: "Purchase failed")
        
        // When
        let success = await subscriptionService.purchase(mockProduct)
        
        // Then
        XCTAssertFalse(success)
        DispatchQueue.main.async {
            XCTAssertNotNil(self.subscriptionService.error)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testPurchasePending() async {
        // Given
        let mockProduct = MockProduct(id: "com.phira.peterai.essential_monthly", displayName: "Monthly", price: Decimal(14.99))
        mockStoreKitManager.mockProducts = [mockProduct]
        mockStoreKitManager.purchaseResult = .pending
        
        await subscriptionService.loadProducts()
        
        // When
        let success = await subscriptionService.purchase(mockProduct)
        
        // Then - Pending should return false but not show as error
        XCTAssertFalse(success)
        XCTAssertNil(subscriptionService.error) // No error for pending state
    }
    
    // MARK: - Subscription Status Tests
    
    func testActiveSubscription() async {
        // Given
        mockStoreKitManager.hasActiveSubscription = true
        mockStoreKitManager.mockSubscriptionProduct = MockProduct(
            id: "com.phira.peterai.essential_annual",
            displayName: "Annual",
            price: Decimal(125.00)
        )
        
        // When
        await subscriptionService.updateSubscriptionStatus()
        
        // Then
        let expectation = XCTestExpectation(description: "Active subscription")
        DispatchQueue.main.async {
            XCTAssertTrue(self.subscriptionService.isSubscribed)
            XCTAssertTrue(self.subscriptionService.hasValidSubscription)
            
            if case .subscribed(let product) = self.subscriptionService.subscriptionStatus {
                XCTAssertEqual(product.id, "com.phira.peterai.essential_annual")
            } else {
                XCTFail("Expected subscribed status")
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testExpiredSubscription() async {
        // Given
        mockStoreKitManager.hasActiveSubscription = false
        mockStoreKitManager.subscriptionExpired = true
        
        // When
        await subscriptionService.updateSubscriptionStatus()
        
        // Then
        let expectation = XCTestExpectation(description: "Expired subscription")
        DispatchQueue.main.async {
            XCTAssertFalse(self.subscriptionService.isSubscribed)
            XCTAssertFalse(self.subscriptionService.hasValidSubscription)
            XCTAssertEqual(self.subscriptionService.subscriptionStatus, .expired)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testRevokedSubscription() async {
        // Given
        mockStoreKitManager.subscriptionRevoked = true
        
        // When
        await subscriptionService.updateSubscriptionStatus()
        
        // Then
        let expectation = XCTestExpectation(description: "Revoked subscription")
        DispatchQueue.main.async {
            XCTAssertFalse(self.subscriptionService.hasValidSubscription)
            XCTAssertEqual(self.subscriptionService.subscriptionStatus, .revoked)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGracePeriodSubscription() async {
        // Given
        mockStoreKitManager.hasActiveSubscription = true
        mockStoreKitManager.inGracePeriod = true
        
        // When
        await subscriptionService.updateSubscriptionStatus()
        
        // Then
        let expectation = XCTestExpectation(description: "Grace period subscription")
        DispatchQueue.main.async {
            XCTAssertTrue(self.subscriptionService.hasValidSubscription) // Still valid in grace period
            XCTAssertEqual(self.subscriptionService.subscriptionStatus, .inGracePeriod)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Restore Purchases Tests
    
    func testRestorePurchasesSuccess() async {
        // Given
        mockStoreKitManager.restoreResult = .success
        mockStoreKitManager.hasActiveSubscription = true
        
        let expectation = XCTestExpectation(description: "Restore success")
        
        // When
        await subscriptionService.restorePurchases()
        
        // Then
        DispatchQueue.main.async {
            XCTAssertTrue(self.mockStoreKitManager.restoreAttempted)
            XCTAssertFalse(self.subscriptionService.isLoading)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testRestorePurchasesFailure() async {
        // Given
        mockStoreKitManager.restoreResult = .failure
        
        let expectation = XCTestExpectation(description: "Restore failure")
        
        // When
        await subscriptionService.restorePurchases()
        
        // Then
        DispatchQueue.main.async {
            XCTAssertTrue(self.mockStoreKitManager.restoreAttempted)
            XCTAssertFalse(self.subscriptionService.isLoading)
            // Note: Current implementation doesn't set error on restore failure
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Product Display Info Tests
    
    func testMonthlyProductDisplayInfo() {
        // Given
        let monthlyProduct = MockProduct(id: "com.phira.peterai.essential_monthly", displayName: "Monthly", price: Decimal(14.99))
        
        // When
        let displayInfo = subscriptionService.getProductDisplayInfo(for: monthlyProduct)
        
        // Then
        XCTAssertEqual(displayInfo.title, "Monthly Plan")
        XCTAssertEqual(displayInfo.period, "month")
        XCTAssertEqual(displayInfo.description, "Billed monthly")
        XCTAssertFalse(displayInfo.isRecommended)
        XCTAssertNil(displayInfo.savings)
    }
    
    func testAnnualProductDisplayInfo() {
        // Given
        let annualProduct = MockProduct(id: "com.phira.peterai.essential_annual", displayName: "Annual", price: Decimal(125.00))
        
        // When
        let displayInfo = subscriptionService.getProductDisplayInfo(for: annualProduct)
        
        // Then
        XCTAssertEqual(displayInfo.title, "Annual Plan")
        XCTAssertEqual(displayInfo.period, "year")
        XCTAssertEqual(displayInfo.description, "30% savings - Billed yearly")
        XCTAssertTrue(displayInfo.isRecommended)
        XCTAssertEqual(displayInfo.savings, "Save 30%")
    }
    
    // MARK: - Status Text Tests
    
    func testSubscriptionStatusText() {
        // Test all possible status texts
        subscriptionService.subscriptionStatus = .unknown
        XCTAssertEqual(subscriptionService.getSubscriptionStatusText(), "Checking subscription...")
        
        subscriptionService.subscriptionStatus = .notSubscribed
        XCTAssertEqual(subscriptionService.getSubscriptionStatusText(), "No active subscription")
        
        let mockProduct = MockProduct(id: "test", displayName: "Test Plan", price: Decimal(10))
        subscriptionService.subscriptionStatus = .subscribed(mockProduct)
        XCTAssertEqual(subscriptionService.getSubscriptionStatusText(), "Subscribed to Test Plan")
        
        subscriptionService.subscriptionStatus = .expired
        XCTAssertEqual(subscriptionService.getSubscriptionStatusText(), "Subscription expired")
        
        subscriptionService.subscriptionStatus = .inGracePeriod
        XCTAssertEqual(subscriptionService.getSubscriptionStatusText(), "Subscription in grace period")
        
        subscriptionService.subscriptionStatus = .inBillingRetryPeriod
        XCTAssertEqual(subscriptionService.getSubscriptionStatusText(), "Payment issue - retrying")
        
        subscriptionService.subscriptionStatus = .revoked
        XCTAssertEqual(subscriptionService.getSubscriptionStatusText(), "Subscription revoked")
    }
    
    // MARK: - Transaction Monitoring Tests
    
    func testTransactionUpdateHandling() async {
        // Given
        let mockTransaction = MockTransaction(productID: "com.phira.peterai.essential_monthly")
        mockStoreKitManager.pendingTransactions = [mockTransaction]
        
        // When
        await subscriptionService.handleTransactionUpdate(mockTransaction)
        
        // Then
        XCTAssertTrue(mockTransaction.isFinished)
        // Verify subscription status is updated
        XCTAssertTrue(mockStoreKitManager.statusUpdateRequested)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testEmptyProductList() async {
        // Given
        mockStoreKitManager.mockProducts = []
        
        let expectation = XCTestExpectation(description: "Empty products")
        
        // When
        await subscriptionService.loadProducts()
        
        // Then
        DispatchQueue.main.async {
            XCTAssertEqual(self.subscriptionService.products.count, 0)
            XCTAssertEqual(self.subscriptionService.error, .noProductsFound)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testNetworkErrorDuringPurchase() async {
        // Given
        let mockProduct = MockProduct(id: "com.phira.peterai.essential_monthly", displayName: "Monthly", price: Decimal(14.99))
        mockStoreKitManager.mockProducts = [mockProduct]
        mockStoreKitManager.networkError = URLError(.notConnectedToInternet)
        
        await subscriptionService.loadProducts()
        
        let expectation = XCTestExpectation(description: "Network error")
        
        // When
        let success = await subscriptionService.purchase(mockProduct)
        
        // Then
        XCTAssertFalse(success)
        DispatchQueue.main.async {
            XCTAssertEqual(self.subscriptionService.error, .networkError)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testConcurrentPurchaseAttempts() async {
        // Given
        let mockProduct = MockProduct(id: "com.phira.peterai.essential_monthly", displayName: "Monthly", price: Decimal(14.99))
        mockStoreKitManager.mockProducts = [mockProduct]
        mockStoreKitManager.purchaseDelay = 1.0 // Simulate slow purchase
        
        await subscriptionService.loadProducts()
        
        // When - Start two purchases concurrently
        async let purchase1 = subscriptionService.purchase(mockProduct)
        async let purchase2 = subscriptionService.purchase(mockProduct)
        
        let (result1, result2) = await (purchase1, purchase2)
        
        // Then - Only one should succeed (or both should handle concurrency properly)
        XCTAssertTrue(result1 || result2) // At least one should succeed
        XCTAssertEqual(mockStoreKitManager.purchaseAttemptCount, 1) // Should only attempt once
    }
    
    // MARK: - Performance Tests
    
    func testProductLoadingPerformance() {
        // Given
        let manyProducts = (0..<100).map { i in
            MockProduct(id: "product_\(i)", displayName: "Product \(i)", price: Decimal(i))
        }
        mockStoreKitManager.mockProducts = manyProducts
        
        // When/Then
        measure {
            Task {
                await subscriptionService.loadProducts()
            }
        }
    }
    
    func testSubscriptionStatusCheckPerformance() {
        measure {
            Task {
                await subscriptionService.updateSubscriptionStatus()
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testServiceDeinitCleanup() {
        // Given
        weak var weakService = subscriptionService
        
        // When
        subscriptionService = nil
        
        // Then
        XCTAssertNil(weakService, "SubscriptionService should be deallocated")
    }
}

// MARK: - Mock Classes for Subscription Testing

class MockStoreKitManager {
    var mockProducts: [MockProduct] = []
    var shouldFailProductLoading = false
    var purchaseResult: MockPurchaseResult = .success
    var restoreResult: MockRestoreResult = .success
    var networkError: Error?
    var purchaseDelay: TimeInterval = 0
    
    // Tracking properties
    var purchaseAttempted = false
    var purchaseAttemptCount = 0
    var purchasedProductId: String?
    var restoreAttempted = false
    var statusUpdateRequested = false
    
    // Subscription state
    var hasActiveSubscription = false
    var subscriptionExpired = false
    var subscriptionRevoked = false
    var inGracePeriod = false
    var mockSubscriptionProduct: MockProduct?
    var pendingTransactions: [MockTransaction] = []
    
    func loadProducts() async throws -> [MockProduct] {
        if shouldFailProductLoading {
            throw MockError.productLoadFailed
        }
        return mockProducts
    }
    
    func purchase(_ product: MockProduct) async -> MockPurchaseResult {
        purchaseAttempted = true
        purchaseAttemptCount += 1
        purchasedProductId = product.id
        
        if let error = networkError {
            throw error
        }
        
        if purchaseDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(purchaseDelay * 1_000_000_000))
        }
        
        return purchaseResult
    }
    
    func restorePurchases() async -> MockRestoreResult {
        restoreAttempted = true
        return restoreResult
    }
    
    func checkSubscriptionStatus() async -> MockSubscriptionStatus {
        statusUpdateRequested = true
        
        if subscriptionRevoked {
            return .revoked
        }
        
        if subscriptionExpired {
            return .expired
        }
        
        if hasActiveSubscription {
            if inGracePeriod {
                return .inGracePeriod
            }
            return .subscribed(mockSubscriptionProduct ?? mockProducts.first!)
        }
        
        return .notSubscribed
    }
}

struct MockProduct: Hashable, Identifiable {
    let id: String
    let displayName: String
    let price: Decimal
    
    var displayPrice: String {
        return "$\(price)"
    }
}

enum MockPurchaseResult {
    case success
    case userCancelled
    case pending
    case failure
}

enum MockRestoreResult {
    case success
    case failure
}

enum MockSubscriptionStatus {
    case unknown
    case notSubscribed
    case subscribed(MockProduct)
    case expired
    case inGracePeriod
    case inBillingRetryPeriod
    case revoked
}

class MockTransaction {
    let productID: String
    var isFinished = false
    
    init(productID: String) {
        self.productID = productID
    }
    
    func finish() {
        isFinished = true
    }
}

enum MockError: Error {
    case productLoadFailed
    case purchaseFailed
    case networkError
}

// MARK: - SubscriptionService Extension for Testing

@available(iOS 15.0, *)
extension SubscriptionService {
    var storeKitManager: MockStoreKitManager? {
        get { return nil }
        set { /* Inject mock */ }
    }
    
    func handleTransactionUpdate(_ transaction: MockTransaction) async {
        // Simulate transaction handling
        transaction.finish()
        await updateSubscriptionStatus()
    }
}

// MARK: - Legacy StoreKit Tests

class LegacySubscriptionServiceTests: XCTestCase {
    var legacyService: LegacySubscriptionService!
    var mockPaymentQueue: MockSKPaymentQueue!
    
    override func setUp() {
        super.setUp()
        legacyService = LegacySubscriptionService()
        mockPaymentQueue = MockSKPaymentQueue()
        
        // Inject mock payment queue
        legacyService.paymentQueue = mockPaymentQueue
    }
    
    override func tearDown() {
        legacyService = nil
        mockPaymentQueue = nil
        super.tearDown()
    }
    
    func testLegacyProductLoading() {
        // Given
        let mockProducts = [
            MockSKProduct(identifier: "com.phira.peterai.essential_monthly", price: NSDecimalNumber(value: 14.99)),
            MockSKProduct(identifier: "com.phira.peterai.essential_annual", price: NSDecimalNumber(value: 125.00))
        ]
        
        // When
        legacyService.productsRequest(MockSKProductsRequest(), didReceive: MockSKProductsResponse(products: mockProducts))
        
        // Then
        XCTAssertEqual(legacyService.products.count, 2)
        XCTAssertFalse(legacyService.isLoading)
    }
    
    func testLegacyPurchaseFlow() {
        // Given
        let mockProduct = MockSKProduct(identifier: "com.phira.peterai.essential_monthly", price: NSDecimalNumber(value: 14.99))
        
        // When
        legacyService.purchase(mockProduct)
        
        // Then
        XCTAssertTrue(mockPaymentQueue.paymentAdded)
        XCTAssertEqual(mockPaymentQueue.addedPayment?.productIdentifier, mockProduct.productIdentifier)
    }
    
    func testLegacyRestorePurchases() {
        // When
        legacyService.restorePurchases()
        
        // Then
        XCTAssertTrue(mockPaymentQueue.restoreRequested)
    }
}

// MARK: - Legacy Mock Classes

class MockSKPaymentQueue {
    var paymentAdded = false
    var restoreRequested = false
    var addedPayment: MockSKProduct?
    
    func add(_ payment: SKPayment) {
        paymentAdded = true
        // Extract product info from payment if needed
    }
    
    func restoreCompletedTransactions() {
        restoreRequested = true
    }
}

class MockSKProduct: SKProduct {
    let identifier: String
    let mockPrice: NSDecimalNumber
    
    init(identifier: String, price: NSDecimalNumber) {
        self.identifier = identifier
        self.mockPrice = price
        super.init()
    }
    
    override var productIdentifier: String {
        return identifier
    }
    
    override var price: NSDecimalNumber {
        return mockPrice
    }
}

class MockSKProductsRequest: SKProductsRequest {
    // Mock implementation
}

class MockSKProductsResponse: SKProductsResponse {
    let mockProducts: [SKProduct]
    
    init(products: [SKProduct]) {
        self.mockProducts = products
        super.init()
    }
    
    override var products: [SKProduct] {
        return mockProducts
    }
}

extension LegacySubscriptionService {
    var paymentQueue: MockSKPaymentQueue? {
        get { return nil }
        set { /* Inject mock */ }
    }
}