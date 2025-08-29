import XCTest
@testable import PeterAI

final class UserStoreTests: XCTestCase {
    var userStore: UserStore!
    var secureStorage: SecureStorage!
    
    override func setUp() {
        super.setUp()
        secureStorage = SecureStorage.shared
        userStore = UserStore()
        
        // Clear any existing data
        userStore.clearAllUserData()
    }
    
    override func tearDown() {
        userStore.clearAllUserData()
        userStore = nil
        secureStorage = nil
        super.tearDown()
    }
    
    // MARK: - Data Security Tests
    
    func testSecureDataStorage() {
        // Given
        let testName = "Eleanor Johnson"
        let testEmail = "eleanor@example.com"
        let testLocation = "San Francisco, CA"
        
        // When
        userStore.firstName = testName
        userStore.email = testEmail
        userStore.location = testLocation
        userStore.saveUserData()
        
        // Then
        XCTAssertEqual(userStore.firstName, testName)
        XCTAssertEqual(userStore.email, testEmail)
        XCTAssertEqual(userStore.location, testLocation)
        
        // Verify data is stored securely
        let storedName = secureStorage.retrieve(key: "user_firstName")
        let storedEmail = secureStorage.retrieve(key: "user_email")
        let storedLocation = secureStorage.retrieve(key: "user_location")
        
        XCTAssertEqual(storedName, testName)
        XCTAssertEqual(storedEmail, testEmail)
        XCTAssertEqual(storedLocation, testLocation)
    }
    
    func testDataLoadingFromSecureStorage() {
        // Given - Pre-populate secure storage
        let testName = "Robert Smith"
        let testEmail = "robert@example.com"
        let testLocation = "New York, NY"
        
        _ = secureStorage.store(key: "user_firstName", value: testName)
        _ = secureStorage.store(key: "user_email", value: testEmail)  
        _ = secureStorage.store(key: "user_location", value: testLocation)
        
        // When - Create new UserStore (should load from secure storage)
        let newUserStore = UserStore()
        
        // Then
        XCTAssertEqual(newUserStore.firstName, testName)
        XCTAssertEqual(newUserStore.email, testEmail)
        XCTAssertEqual(newUserStore.location, testLocation)
        
        newUserStore.clearAllUserData()
    }
    
    func testDataIntegrityValidation() {
        // Given
        userStore.firstName = "Margaret Wilson"
        userStore.email = "margaret@example.com"
        userStore.location = "Chicago, IL"
        userStore.saveUserData()
        
        // When
        let isValid = userStore.validateDataIntegrity()
        
        // Then
        XCTAssertTrue(isValid, "Data integrity should be valid after saving")
    }
    
    func testGDPRCompliantDataDeletion() {
        // Given - Store some data
        userStore.firstName = "James Anderson"
        userStore.email = "james@example.com"
        userStore.location = "Boston, MA"
        userStore.isOnboardingCompleted = true
        userStore.hasActiveSubscription = true
        userStore.saveUserData()
        
        // When - Clear all data
        userStore.clearAllUserData()
        
        // Then - Verify all data is removed
        XCTAssertTrue(userStore.firstName.isEmpty)
        XCTAssertTrue(userStore.email.isEmpty)
        XCTAssertTrue(userStore.location.isEmpty)
        XCTAssertFalse(userStore.isOnboardingCompleted)
        XCTAssertFalse(userStore.hasActiveSubscription)
        
        // Verify secure storage is cleared
        XCTAssertNil(secureStorage.retrieve(key: "user_firstName"))
        XCTAssertNil(secureStorage.retrieve(key: "user_email"))
        XCTAssertNil(secureStorage.retrieve(key: "user_location"))
    }
    
    // MARK: - Elderly User Specific Tests
    
    func testElderlyUserFriendlyNames() {
        // Given - Test with common elderly names
        let elderlyNames = ["Dorothy", "Harold", "Evelyn", "Norman", "Betty"]
        
        for name in elderlyNames {
            // When
            userStore.firstName = name
            userStore.saveUserData()
            
            // Then
            XCTAssertEqual(userStore.firstName, name)
            XCTAssertEqual(secureStorage.retrieve(key: "user_firstName"), name)
        }
    }
    
    func testEmailValidationForElderlyUsers() {
        // Given - Common elderly email patterns
        let elderlyEmails = [
            "grandma@aol.com",
            "robert.smith@gmail.com", 
            "m.johnson@yahoo.com",
            "betty123@hotmail.com"
        ]
        
        for email in elderlyEmails {
            // When
            userStore.email = email
            userStore.saveUserData()
            
            // Then
            XCTAssertEqual(userStore.email, email)
            XCTAssertTrue(userStore.validateDataIntegrity())
        }
    }
    
    func testLocationHandlingForElderlyUsers() {
        // Given - Various location formats elderly users might enter
        let locations = [
            "Miami, Florida",
            "Chicago IL",
            "New York City",
            "Los Angeles, CA 90210",
            "Small Town, USA"
        ]
        
        for location in locations {
            // When
            userStore.location = location
            userStore.saveUserData()
            
            // Then
            XCTAssertEqual(userStore.location, location)
            XCTAssertTrue(userStore.validateDataIntegrity())
        }
    }
    
    // MARK: - Onboarding Tests
    
    func testOnboardingCompletion() {
        // Given
        XCTAssertFalse(userStore.isOnboardingCompleted)
        
        // When
        userStore.completeOnboarding()
        
        // Then
        XCTAssertTrue(userStore.isOnboardingCompleted)
        
        // Verify persistence
        let newUserStore = UserStore()
        XCTAssertTrue(newUserStore.isOnboardingCompleted)
        
        newUserStore.clearAllUserData()
    }
    
    func testSubscriptionStatusUpdate() {
        // Given
        XCTAssertFalse(userStore.hasActiveSubscription)
        
        // When
        userStore.updateSubscriptionStatus(true)
        
        // Then
        XCTAssertTrue(userStore.hasActiveSubscription)
        
        // Test toggling
        userStore.updateSubscriptionStatus(false)
        XCTAssertFalse(userStore.hasActiveSubscription)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testEmptyStringHandling() {
        // Given
        userStore.firstName = ""
        userStore.email = ""
        userStore.location = ""
        
        // When
        userStore.saveUserData()
        
        // Then - Should handle empty strings gracefully
        XCTAssertTrue(userStore.firstName.isEmpty)
        XCTAssertTrue(userStore.email.isEmpty)
        XCTAssertTrue(userStore.location.isEmpty)
        XCTAssertTrue(userStore.validateDataIntegrity())
    }
    
    func testSpecialCharacterHandling() {
        // Given - Names with special characters
        userStore.firstName = "José María"
        userStore.email = "josé@exámple.com"
        userStore.location = "São Paulo, Brazil"
        
        // When
        userStore.saveUserData()
        
        // Then
        XCTAssertEqual(userStore.firstName, "José María")
        XCTAssertEqual(userStore.email, "josé@exámple.com")
        XCTAssertEqual(userStore.location, "São Paulo, Brazil")
        XCTAssertTrue(userStore.validateDataIntegrity())
    }
    
    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access")
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        // Given
        var results: [Bool] = []
        let group = DispatchGroup()
        
        // When - Multiple concurrent writes
        for i in 0..<10 {
            group.enter()
            queue.async {
                self.userStore.firstName = "User\(i)"
                self.userStore.saveUserData()
                let isValid = self.userStore.validateDataIntegrity()
                results.append(isValid)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Then - All operations should succeed
            XCTAssertEqual(results.count, 10)
            XCTAssertTrue(results.allSatisfy { $0 })
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}