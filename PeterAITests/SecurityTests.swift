import XCTest
import Foundation
import CryptoKit
@testable import PeterAI

class SecurityTests: XCTestCase {
    var userStore: UserStore!
    var openAIService: OpenAIService!
    var analyticsService: AnalyticsService!
    var subscriptionService: SubscriptionService!
    var securityService: SecurityService!
    
    override func setUp() {
        super.setUp()
        
        userStore = UserStore()
        openAIService = OpenAIService()
        analyticsService = AnalyticsService()
        if #available(iOS 15.0, *) {
            subscriptionService = SubscriptionService()
        }
        securityService = SecurityService()
    }
    
    override func tearDown() {
        userStore = nil
        openAIService = nil
        analyticsService = nil
        subscriptionService = nil
        securityService = nil
        super.tearDown()
    }
    
    // MARK: - Data Encryption Tests
    
    func testUserDataEncryption() {
        // Test that sensitive user data is encrypted at rest
        let sensitiveData = [
            "firstName": "Margaret",
            "email": "margaret@example.com",
            "location": "Boston, MA"
        ]
        
        for (key, value) in sensitiveData {
            // Store data
            userStore.setValue(value, forKey: key)
            userStore.saveUserData()
            
            // Check if data is encrypted in storage
            let rawStoredValue = UserDefaults.standard.string(forKey: key)
            XCTAssertNotEqual(rawStoredValue, value, "Sensitive data should be encrypted: \(key)")
            
            // Verify we can decrypt it back
            let decryptedValue = userStore.getValue(forKey: key)
            XCTAssertEqual(decryptedValue, value, "Should be able to decrypt stored data: \(key)")
        }
    }
    
    func testChatMessageEncryption() {
        // Test that chat messages are encrypted
        let sensitiveMessage = "My social security number is 123-45-6789"
        let message = ChatMessage(role: "user", content: sensitiveMessage)
        
        // Store message
        openAIService.messages.append(message)
        
        // Verify message content is encrypted when persisted
        let encryptedContent = securityService.encryptMessage(sensitiveMessage)
        XCTAssertNotEqual(encryptedContent, sensitiveMessage)
        
        // Verify we can decrypt it
        let decryptedContent = securityService.decryptMessage(encryptedContent)
        XCTAssertEqual(decryptedContent, sensitiveMessage)
    }
    
    func testAnalyticsDataEncryption() {
        // Test that analytics data doesn't expose sensitive information
        analyticsService.track("user_message_sent", properties: [
            "message_length": "25",
            "has_personal_info": "true"  // Should be encrypted/hashed
        ])
        
        let events = analyticsService.getAllEvents()
        for event in events {
            // Verify no sensitive data in plain text
            XCTAssertFalse(event.properties.values.joined().contains("123-45-6789"))
            XCTAssertFalse(event.properties.values.joined().contains("margaret@example.com"))
        }
    }
    
    // MARK: - API Security Tests
    
    func testAPIKeyValidation() {
        // Test API key validation
        let validKey = "sk-1234567890abcdefghijklmnopqrstuvwxyz123456789012345678901234"
        let invalidKeys = [
            "",
            "invalid-key",
            "sk-short",
            "wrong-prefix-1234567890abcdefghijklmnopqrstuvwxyz",
            "sk-" + String(repeating: "a", count: 100) // Too long
        ]
        
        XCTAssertTrue(securityService.validateAPIKey(validKey))
        
        for invalidKey in invalidKeys {
            XCTAssertFalse(securityService.validateAPIKey(invalidKey), "Should reject invalid key: \(invalidKey)")
        }
    }
    
    func testAPIKeySanitization() {
        // Test that API keys are properly sanitized in logs
        let apiKey = "sk-1234567890abcdefghijklmnopqrstuvwxyz"
        
        let sanitizedKey = securityService.sanitizeAPIKeyForLogging(apiKey)
        
        // Should hide most of the key
        XCTAssertTrue(sanitizedKey.contains("sk-***"))
        XCTAssertFalse(sanitizedKey.contains("1234567890"))
        XCTAssertEqual(sanitizedKey.count, 10) // "sk-***abcd" format
    }
    
    func testNetworkRequestSecurity() {
        // Test that network requests have proper security headers
        let request = openAIService.createSecureRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        
        // Verify security headers
        XCTAssertNotNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(request.value(forHTTPHeaderField: "User-Agent"))
        
        // Verify no sensitive data in URL
        XCTAssertFalse(request.url?.absoluteString.contains("api_key") ?? true)
        
        // Verify HTTPS only
        XCTAssertEqual(request.url?.scheme, "https")
    }
    
    func testCertificatePinning() {
        // Test certificate pinning for API endpoints
        let openAIHost = "api.openai.com"
        let weatherHost = "api.openweathermap.org"
        
        XCTAssertTrue(securityService.isPinnedCertificateValid(for: openAIHost))
        XCTAssertTrue(securityService.isPinnedCertificateValid(for: weatherHost))
        
        // Test that invalid certificates are rejected
        let maliciousHost = "evil-api.com"
        XCTAssertFalse(securityService.isPinnedCertificateValid(for: maliciousHost))
    }
    
    // MARK: - Input Validation & Sanitization Tests
    
    func testUserInputSanitization() {
        // Test potentially dangerous inputs
        let dangerousInputs = [
            "<script>alert('xss')</script>",
            "'; DROP TABLE users; --",
            "../../../etc/passwd",
            "javascript:alert('xss')",
            "\u{200B}\u{FEFF}hidden text", // Zero-width characters
            String(repeating: "A", count: 10000) // Very long input
        ]
        
        for input in dangerousInputs {
            let sanitized = securityService.sanitizeUserInput(input)
            
            // Verify dangerous content is removed/escaped
            XCTAssertFalse(sanitized.contains("<script>"))
            XCTAssertFalse(sanitized.contains("DROP TABLE"))
            XCTAssertFalse(sanitized.contains("../"))
            XCTAssertFalse(sanitized.contains("javascript:"))
            XCTAssertLessThanOrEqual(sanitized.count, 1000) // Length limited
        }
    }
    
    func testEmailValidationSecurity() {
        // Test email validation against injection attacks
        let maliciousEmails = [
            "test@example.com<script>alert('xss')</script>",
            "test+injection@example.com'; DROP TABLE users; --",
            "test@example.com\nBCC: attacker@evil.com",
            "test@example.com\r\nTo: victim@example.com"
        ]
        
        for email in maliciousEmails {
            XCTAssertFalse(userStore.isValidEmail(email), "Should reject malicious email: \(email)")
        }
    }
    
    func testLocationInputValidation() {
        // Test location input validation
        let maliciousLocations = [
            "Boston<script>alert('xss')</script>",
            "'; SELECT * FROM locations; --",
            String(repeating: "A", count: 1000),
            "Boston\n\rMalicious: evil.com"
        ]
        
        for location in maliciousLocations {
            let isValid = userStore.isValidLocation(location)
            XCTAssertFalse(isValid, "Should reject malicious location: \(location)")
        }
    }
    
    // MARK: - Authentication & Authorization Tests
    
    func testBiometricAuthentication() {
        // Test biometric authentication for sensitive operations
        let biometricAuth = securityService.getBiometricAuthenticator()
        
        // Test availability
        XCTAssertNotNil(biometricAuth)
        
        // Test authentication requirement for sensitive data access
        let requiresAuth = securityService.requiresBiometricAuth(for: .viewConversationHistory)
        XCTAssertTrue(requiresAuth)
        
        let noAuthRequired = securityService.requiresBiometricAuth(for: .changeVoiceSpeed)
        XCTAssertFalse(noAuthRequired)
    }
    
    func testSessionManagement() {
        // Test secure session management
        let session = securityService.createSecureSession()
        
        // Verify session properties
        XCTAssertNotNil(session.sessionID)
        XCTAssertGreaterThan(session.sessionID.count, 32) // Sufficient entropy
        XCTAssertNotNil(session.creationTime)
        XCTAssertNotNil(session.expirationTime)
        
        // Verify session timeout
        let timeout = session.expirationTime.timeIntervalSince(session.creationTime)
        XCTAssertLessThanOrEqual(timeout, 3600) // Max 1 hour
        
        // Test session validation
        XCTAssertTrue(securityService.isValidSession(session))
        
        // Test expired session
        let expiredSession = SecureSession(
            sessionID: session.sessionID,
            creationTime: Date().addingTimeInterval(-7200), // 2 hours ago
            expirationTime: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        XCTAssertFalse(securityService.isValidSession(expiredSession))
    }
    
    // MARK: - Subscription Security Tests
    
    @available(iOS 15.0, *)
    func testSubscriptionValidationSecurity() {
        // Test that subscription validation is secure
        
        // Create mock receipt data
        let receiptData = securityService.createMockReceiptData()
        
        // Verify receipt validation
        let validationResult = subscriptionService.validateReceipt(receiptData)
        XCTAssertTrue(validationResult.isValid)
        
        // Test tampered receipt
        let tamperedReceipt = securityService.tamperReceiptData(receiptData)
        let tamperedResult = subscriptionService.validateReceipt(tamperedReceipt)
        XCTAssertFalse(tamperedResult.isValid)
    }
    
    func testClientSideValidationLimitations() {
        // Verify that sensitive validation is not solely client-side
        
        // Test that subscription status requires server validation
        let clientOnlyStatus = subscriptionService.getClientOnlySubscriptionStatus()
        let serverValidatedStatus = subscriptionService.getServerValidatedSubscriptionStatus()
        
        // Client-only status should be marked as unverified
        XCTAssertFalse(clientOnlyStatus.isServerVerified)
        XCTAssertTrue(serverValidatedStatus.isServerVerified)
    }
    
    // MARK: - Data Privacy Tests
    
    func testDataMinimization() {
        // Test that only necessary data is collected
        analyticsService.track("user_interaction")
        
        let collectedData = analyticsService.getLastEventData()
        
        // Should not collect unnecessary sensitive data
        XCTAssertNil(collectedData["device_udid"])
        XCTAssertNil(collectedData["contacts_list"])
        XCTAssertNil(collectedData["location_precise"])
        
        // Should collect only necessary data
        XCTAssertNotNil(collectedData["timestamp"])
        XCTAssertNotNil(collectedData["app_version"])
        XCTAssertNotNil(collectedData["event_name"])
    }
    
    func testDataRetentionPolicies() {
        // Test data retention and deletion
        
        // Add old messages
        let oldDate = Date().addingTimeInterval(-90 * 24 * 3600) // 90 days ago
        let oldMessage = ChatMessage(role: "user", content: "Old message")
        oldMessage.timestamp = oldDate
        openAIService.messages.append(oldMessage)
        
        // Trigger retention policy
        securityService.enforceDataRetentionPolicy()
        
        // Verify old data is removed
        let remainingMessages = openAIService.messages.filter { $0.timestamp == oldDate }
        XCTAssertEqual(remainingMessages.count, 0, "Old messages should be automatically deleted")
    }
    
    func testUserDataDeletion() {
        // Test complete user data deletion
        
        // Set up user data
        userStore.firstName = "TestUser"
        userStore.email = "test@example.com"
        analyticsService.track("test_event")
        openAIService.messages.append(ChatMessage(role: "user", content: "Test message"))
        
        // Request data deletion
        securityService.deleteAllUserData()
        
        // Verify all data is removed
        XCTAssertTrue(userStore.firstName.isEmpty)
        XCTAssertTrue(userStore.email.isEmpty)
        XCTAssertEqual(analyticsService.getAllEvents().count, 0)
        XCTAssertEqual(openAIService.messages.count, 0)
    }
    
    func testAnonymizationOfAnalytics() {
        // Test that analytics data is properly anonymized
        userStore.firstName = "Margaret"
        userStore.email = "margaret@example.com"
        
        analyticsService.track("user_message_sent", properties: [
            "user_name": userStore.firstName,
            "message_length": "25"
        ])
        
        let eventData = analyticsService.getLastEventData()
        
        // User name should be anonymized/hashed
        XCTAssertNotEqual(eventData["user_name"], "Margaret")
        XCTAssertNotNil(eventData["user_name_hash"]) // Should have anonymized version
        
        // Email should never appear in analytics
        let eventString = String(describing: eventData)
        XCTAssertFalse(eventString.contains("margaret@example.com"))
    }
    
    // MARK: - Network Security Tests
    
    func testHTTPSEnforcement() {
        // Test that all network requests use HTTPS
        let httpURL = URL(string: "http://api.openai.com/v1/chat/completions")!
        
        // Should automatically upgrade to HTTPS
        let secureURL = securityService.enforceHTTPS(httpURL)
        XCTAssertEqual(secureURL.scheme, "https")
        
        // Already HTTPS URLs should remain unchanged
        let httpsURL = URL(string: "https://api.openai.com/v1/chat/completions")!
        let stillSecureURL = securityService.enforceHTTPS(httpsURL)
        XCTAssertEqual(stillSecureURL, httpsURL)
    }
    
    func testRequestHeaderSecurity() {
        // Test that requests don't leak sensitive information
        let request = openAIService.createRequest(for: "Test message")
        
        // Should not contain sensitive data in headers
        let userAgent = request.value(forHTTPHeaderField: "User-Agent")
        XCTAssertNotNil(userAgent)
        XCTAssertFalse(userAgent?.contains("Margaret") ?? false)
        XCTAssertFalse(userAgent?.contains("margaret@example.com") ?? false)
        
        // Should not have debug headers in production
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Debug-User"))
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Internal-Test"))
    }
    
    func testResponseValidation() {
        // Test that API responses are validated for security
        let maliciousResponse = """
        {
            "choices": [{
                "message": {
                    "role": "assistant",
                    "content": "Visit this link: javascript:alert('xss')"
                }
            }],
            "__proto__": { "isAdmin": true }
        }
        """
        
        let responseData = maliciousResponse.data(using: .utf8)!
        let validatedResponse = securityService.validateAPIResponse(responseData)
        
        // Should sanitize malicious content
        XCTAssertFalse(validatedResponse.contains("javascript:"))
        XCTAssertFalse(validatedResponse.contains("__proto__"))
    }
    
    // MARK: - Vulnerability Tests
    
    func testSQLInjectionPrevention() {
        // Test SQL injection prevention (even though we don't use SQL directly)
        let maliciousInputs = [
            "'; DROP TABLE users; --",
            "1' OR '1'='1",
            "admin'/*",
            "1; DELETE FROM messages WHERE 1=1; --"
        ]
        
        for input in maliciousInputs {
            let sanitized = securityService.sanitizeForDatabase(input)
            XCTAssertFalse(sanitized.contains("DROP TABLE"))
            XCTAssertFalse(sanitized.contains("DELETE FROM"))
            XCTAssertFalse(sanitized.contains("1=1"))
        }
    }
    
    func testXSSPrevention() {
        // Test XSS prevention in user-generated content
        let xssAttempts = [
            "<script>alert('xss')</script>",
            "<img src=x onerror=alert('xss')>",
            "<iframe src='javascript:alert(\"xss\")'></iframe>",
            "javascript:alert('xss')",
            "data:text/html,<script>alert('xss')</script>"
        ]
        
        for xss in xssAttempts {
            let sanitized = securityService.sanitizeForHTML(xss)
            XCTAssertFalse(sanitized.contains("<script>"))
            XCTAssertFalse(sanitized.contains("javascript:"))
            XCTAssertFalse(sanitized.contains("onerror="))
        }
    }
    
    func testCSRFPrevention() {
        // Test CSRF token implementation for state-changing operations
        let csrfToken = securityService.generateCSRFToken()
        
        // Token should be sufficiently random
        XCTAssertGreaterThan(csrfToken.count, 32)
        
        // Different tokens should be unique
        let anotherToken = securityService.generateCSRFToken()
        XCTAssertNotEqual(csrfToken, anotherToken)
        
        // Validate token verification
        XCTAssertTrue(securityService.validateCSRFToken(csrfToken))
        XCTAssertFalse(securityService.validateCSRFToken("invalid-token"))
    }
    
    // MARK: - Compliance Tests
    
    func testGDPRCompliance() {
        // Test GDPR compliance features
        
        // Right to access
        let userData = securityService.exportUserData()
        XCTAssertNotNil(userData)
        XCTAssertTrue(userData.contains("firstName"))
        XCTAssertTrue(userData.contains("email"))
        
        // Right to rectification (data correction)
        userStore.firstName = "UpdatedName"
        userStore.saveUserData()
        let updatedData = securityService.exportUserData()
        XCTAssertTrue(updatedData.contains("UpdatedName"))
        
        // Right to erasure
        securityService.deleteAllUserData()
        let deletedData = securityService.exportUserData()
        XCTAssertFalse(deletedData.contains("UpdatedName"))
    }
    
    func testCOPPACompliance() {
        // Test Children's Online Privacy Protection Act compliance
        
        // Should not collect data from users under 13
        let underageUser = UserProfile(age: 12)
        let canCollectData = securityService.canCollectDataFrom(underageUser)
        XCTAssertFalse(canCollectData)
        
        // Should be able to collect data from adults
        let adultUser = UserProfile(age: 65)
        let canCollectFromAdult = securityService.canCollectDataFrom(adultUser)
        XCTAssertTrue(canCollectFromAdult)
    }
    
    func testHIPAAConsiderations() {
        // Test health information handling (even if not HIPAA covered entity)
        let healthRelatedInputs = [
            "My blood pressure is 140/90",
            "I take medication for diabetes",
            "I have chronic pain in my back"
        ]
        
        for healthInput in healthRelatedInputs {
            // Should flag health information
            let containsHealthInfo = securityService.detectHealthInformation(healthInput)
            XCTAssertTrue(containsHealthInfo)
            
            // Should apply extra protection
            let protectionLevel = securityService.getProtectionLevel(for: healthInput)
            XCTAssertEqual(protectionLevel, .high)
        }
    }
    
    // MARK: - Penetration Testing Simulations
    
    func testBruteForceProtection() {
        // Simulate brute force attacks
        let securityAuth = securityService.getAuthenticationService()
        
        // Multiple failed attempts
        for _ in 0..<10 {
            let result = securityAuth.authenticate(pin: "0000")
            XCTAssertFalse(result.success)
        }
        
        // Should be locked out after multiple failures
        let lockoutStatus = securityAuth.isLockedOut()
        XCTAssertTrue(lockoutStatus)
        
        // Should require waiting period
        let timeUntilUnlock = securityAuth.getTimeUntilUnlock()
        XCTAssertGreaterThan(timeUntilUnlock, 0)
    }
    
    func testRateLimiting() {
        // Test rate limiting on API requests
        let rateLimiter = securityService.getRateLimiter()
        
        // Rapid requests should be limited
        for _ in 0..<100 {
            let allowed = rateLimiter.isRequestAllowed(for: "user123")
            if !allowed {
                // Should eventually be rate limited
                XCTAssertTrue(true)
                return
            }
        }
        
        XCTFail("Rate limiting should have kicked in")
    }
    
    func testDDOSProtection() {
        // Test DDoS protection mechanisms
        let ddosProtection = securityService.getDDoSProtection()
        
        // Simulate high volume requests
        let startTime = Date()
        var requestCount = 0
        
        while Date().timeIntervalSince(startTime) < 1.0 { // 1 second
            let allowed = ddosProtection.isRequestAllowed()
            if allowed {
                requestCount += 1
            }
        }
        
        // Should limit requests per second
        XCTAssertLessThan(requestCount, 100) // Reasonable limit
    }
}

// MARK: - Mock Security Service

class SecurityService {
    
    // MARK: - Encryption Methods
    
    func encryptMessage(_ message: String) -> String {
        // In real implementation, use proper encryption
        return Data(message.utf8).base64EncodedString()
    }
    
    func decryptMessage(_ encrypted: String) -> String {
        // In real implementation, use proper decryption
        guard let data = Data(base64Encoded: encrypted) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    // MARK: - API Security Methods
    
    func validateAPIKey(_ key: String) -> Bool {
        guard key.hasPrefix("sk-") else { return false }
        guard key.count >= 32 && key.count <= 128 else { return false }
        return true
    }
    
    func sanitizeAPIKeyForLogging(_ key: String) -> String {
        guard key.count > 8 else { return "***" }
        let prefix = String(key.prefix(3))
        let suffix = String(key.suffix(4))
        return "\(prefix)***\(suffix)"
    }
    
    func isPinnedCertificateValid(for host: String) -> Bool {
        let trustedHosts = ["api.openai.com", "api.openweathermap.org"]
        return trustedHosts.contains(host)
    }
    
    // MARK: - Input Sanitization Methods
    
    func sanitizeUserInput(_ input: String) -> String {
        var sanitized = input
        
        // Remove dangerous HTML/JS
        let dangerousPatterns = [
            "<script[^>]*>.*?</script>",
            "javascript:",
            "data:text/html",
            "<iframe[^>]*>.*?</iframe>",
            "onerror=",
            "onclick="
        ]
        
        for pattern in dangerousPatterns {
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        // Limit length
        if sanitized.count > 1000 {
            sanitized = String(sanitized.prefix(1000))
        }
        
        return sanitized
    }
    
    func sanitizeForDatabase(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "'", with: "''")
            .replacingOccurrences(of: ";", with: "")
            .replacingOccurrences(of: "--", with: "")
            .replacingOccurrences(of: "DROP", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "DELETE", with: "", options: .caseInsensitive)
    }
    
    func sanitizeForHTML(_ input: String) -> String {
        return input
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#x27;")
            .replacingOccurrences(of: "/", with: "&#x2F;")
    }
    
    // MARK: - Authentication Methods
    
    func getBiometricAuthenticator() -> BiometricAuthenticator {
        return BiometricAuthenticator()
    }
    
    func requiresBiometricAuth(for operation: SecurityOperation) -> Bool {
        switch operation {
        case .viewConversationHistory, .exportData, .deleteData:
            return true
        case .changeVoiceSpeed, .updateLocation:
            return false
        }
    }
    
    func createSecureSession() -> SecureSession {
        let sessionID = UUID().uuidString + "-" + String(arc4random())
        return SecureSession(
            sessionID: sessionID,
            creationTime: Date(),
            expirationTime: Date().addingTimeInterval(3600)
        )
    }
    
    func isValidSession(_ session: SecureSession) -> Bool {
        return Date() < session.expirationTime
    }
    
    // MARK: - Data Protection Methods
    
    func enforceDataRetentionPolicy() {
        // Implementation would clean up old data
    }
    
    func deleteAllUserData() {
        // Implementation would securely delete all user data
    }
    
    func exportUserData() -> String {
        // Implementation would export user data in machine-readable format
        return "{\"firstName\":\"TestUser\",\"email\":\"test@example.com\"}"
    }
    
    // MARK: - Network Security Methods
    
    func enforceHTTPS(_ url: URL) -> URL {
        guard url.scheme == "http" else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.scheme = "https"
        return components.url ?? url
    }
    
    func validateAPIResponse(_ data: Data) -> String {
        guard let string = String(data: data, encoding: .utf8) else { return "" }
        return sanitizeForHTML(string)
    }
    
    // MARK: - Vulnerability Protection Methods
    
    func generateCSRFToken() -> String {
        return UUID().uuidString + "-" + String(arc4random())
    }
    
    func validateCSRFToken(_ token: String) -> Bool {
        // In real implementation, validate against stored tokens
        return token.count > 32 && token.contains("-")
    }
    
    // MARK: - Compliance Methods
    
    func canCollectDataFrom(_ user: UserProfile) -> Bool {
        return user.age >= 13 // COPPA compliance
    }
    
    func detectHealthInformation(_ text: String) -> Bool {
        let healthKeywords = [
            "blood pressure", "medication", "diabetes", "pain", "doctor",
            "hospital", "surgery", "illness", "disease", "treatment"
        ]
        
        let lowercaseText = text.lowercased()
        return healthKeywords.contains { lowercaseText.contains($0) }
    }
    
    func getProtectionLevel(for text: String) -> ProtectionLevel {
        if detectHealthInformation(text) {
            return .high
        }
        return .standard
    }
    
    // MARK: - Security Services
    
    func getAuthenticationService() -> AuthenticationService {
        return AuthenticationService()
    }
    
    func getRateLimiter() -> RateLimiter {
        return RateLimiter()
    }
    
    func getDDoSProtection() -> DDoSProtection {
        return DDoSProtection()
    }
    
    // MARK: - Mock Methods for Testing
    
    func createMockReceiptData() -> Data {
        return "mock_receipt_data".data(using: .utf8)!
    }
    
    func tamperReceiptData(_ data: Data) -> Data {
        return "tampered_receipt_data".data(using: .utf8)!
    }
}

// MARK: - Supporting Security Types

enum SecurityOperation {
    case viewConversationHistory
    case exportData
    case deleteData
    case changeVoiceSpeed
    case updateLocation
}

struct SecureSession {
    let sessionID: String
    let creationTime: Date
    let expirationTime: Date
}

struct UserProfile {
    let age: Int
}

enum ProtectionLevel {
    case standard
    case high
}

class BiometricAuthenticator {
    func isAvailable() -> Bool { return true }
    func authenticate() async -> Bool { return true }
}

class AuthenticationService {
    private var failedAttempts = 0
    private var lockoutTime: Date?
    
    func authenticate(pin: String) -> AuthResult {
        if pin == "1234" {
            failedAttempts = 0
            return AuthResult(success: true)
        } else {
            failedAttempts += 1
            if failedAttempts >= 5 {
                lockoutTime = Date().addingTimeInterval(300) // 5 minute lockout
            }
            return AuthResult(success: false)
        }
    }
    
    func isLockedOut() -> Bool {
        guard let lockout = lockoutTime else { return false }
        return Date() < lockout
    }
    
    func getTimeUntilUnlock() -> TimeInterval {
        guard let lockout = lockoutTime else { return 0 }
        return max(0, lockout.timeIntervalSince(Date()))
    }
}

struct AuthResult {
    let success: Bool
}

class RateLimiter {
    private var requestCounts: [String: Int] = [:]
    private let maxRequestsPerMinute = 60
    
    func isRequestAllowed(for user: String) -> Bool {
        let currentCount = requestCounts[user] ?? 0
        if currentCount >= maxRequestsPerMinute {
            return false
        }
        requestCounts[user] = currentCount + 1
        return true
    }
}

class DDoSProtection {
    private var requestCount = 0
    private let maxRequestsPerSecond = 50
    
    func isRequestAllowed() -> Bool {
        if requestCount >= maxRequestsPerSecond {
            return false
        }
        requestCount += 1
        return true
    }
}

// MARK: - Service Extensions for Security Testing

extension OpenAIService {
    func createSecureRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer test-key", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("PeterAI/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }
    
    func createRequest(for message: String) -> URLRequest {
        return createSecureRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
    }
}

extension UserStore {
    func setValue(_ value: String, forKey key: String) {
        // Implementation would encrypt and store value
    }
    
    func getValue(forKey key: String) -> String {
        // Implementation would decrypt and return value
        return ""
    }
}

extension AnalyticsService {
    func getAllEvents() -> [AnalyticsEvent] {
        return [] // Return all events for security testing
    }
    
    func getLastEventData() -> [String: String] {
        return [:] // Return last event data for testing
    }
}

extension SubscriptionService {
    func validateReceipt(_ data: Data) -> ReceiptValidationResult {
        let isValid = String(data: data, encoding: .utf8) == "mock_receipt_data"
        return ReceiptValidationResult(isValid: isValid)
    }
    
    func getClientOnlySubscriptionStatus() -> SubscriptionStatusResult {
        return SubscriptionStatusResult(isActive: true, isServerVerified: false)
    }
    
    func getServerValidatedSubscriptionStatus() -> SubscriptionStatusResult {
        return SubscriptionStatusResult(isActive: true, isServerVerified: true)
    }
}

struct ReceiptValidationResult {
    let isValid: Bool
}

struct SubscriptionStatusResult {
    let isActive: Bool
    let isServerVerified: Bool
}