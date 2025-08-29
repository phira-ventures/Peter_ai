import Foundation
import Security

class SecureStorage {
    
    static let shared = SecureStorage()
    private init() {}
    
    private let service = "com.phira.peterai"
    
    // MARK: - Secure Storage Methods
    
    func store(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - API Key Management
    
    private let openAIKeyIdentifier = "openai_api_key"
    private let weatherKeyIdentifier = "weather_api_key"
    
    var openAIAPIKey: String? {
        get {
            // First check keychain
            if let storedKey = retrieve(key: openAIKeyIdentifier) {
                return storedKey
            }
            
            // Fallback to environment/configuration
            return getAPIKeyFromConfiguration("OPENAI_API_KEY")
        }
        set {
            if let key = newValue {
                _ = store(key: openAIKeyIdentifier, value: key)
            } else {
                _ = delete(key: openAIKeyIdentifier)
            }
        }
    }
    
    var weatherAPIKey: String? {
        get {
            if let storedKey = retrieve(key: weatherKeyIdentifier) {
                return storedKey
            }
            
            return getAPIKeyFromConfiguration("WEATHER_API_KEY")
        }
        set {
            if let key = newValue {
                _ = store(key: weatherKeyIdentifier, value: key)
            } else {
                _ = delete(key: weatherKeyIdentifier)
            }
        }
    }
    
    private func getAPIKeyFromConfiguration(_ keyName: String) -> String? {
        // Check environment variables first (for debug builds)
        if let envKey = ProcessInfo.processInfo.environment[keyName] {
            return envKey
        }
        
        // Check Info.plist for configuration
        if let plistPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let plistDict = NSDictionary(contentsOfFile: plistPath),
           let apiKey = plistDict[keyName] as? String {
            return apiKey
        }
        
        return nil
    }
    
    // MARK: - Conversation History Encryption
    
    func storeEncryptedConversation(_ conversation: Data, key: String) -> Bool {
        guard let encryptedData = encryptData(conversation) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).conversations",
            kSecAttrAccount as String: key,
            kSecValueData as String: encryptedData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func retrieveEncryptedConversation(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).conversations",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess,
              let encryptedData = dataTypeRef as? Data,
              let decryptedData = decryptData(encryptedData) else {
            return nil
        }
        
        return decryptedData
    }
    
    // MARK: - Simple Encryption/Decryption
    
    private func encryptData(_ data: Data) -> Data? {
        // For production, use proper encryption like CryptoKit
        // This is a simple XOR encryption for demonstration
        guard let key = getEncryptionKey() else { return nil }
        
        var encrypted = Data()
        for (index, byte) in data.enumerated() {
            let keyByte = key[index % key.count]
            encrypted.append(byte ^ keyByte)
        }
        
        return encrypted
    }
    
    private func decryptData(_ encryptedData: Data) -> Data? {
        // XOR encryption is symmetric, so decryption is the same as encryption
        return encryptData(encryptedData)
    }
    
    private func getEncryptionKey() -> Data? {
        // Generate device-specific key
        guard let identifier = UIDevice.current.identifierForVendor?.uuidString else {
            return nil
        }
        
        return identifier.data(using: .utf8)
    }
    
    // MARK: - Security Validation
    
    func validateAPIKeySecurity() -> [String] {
        var issues: [String] = []
        
        // Check if API keys are properly stored
        if openAIAPIKey == nil {
            issues.append("OpenAI API key not configured")
        }
        
        if weatherAPIKey == nil {
            issues.append("Weather API key not configured")
        }
        
        // Check for hardcoded keys (security issue)
        if let openAIKey = openAIAPIKey, openAIKey.hasPrefix("sk-") && openAIKey.count < 20 {
            issues.append("OpenAI API key appears to be placeholder/invalid")
        }
        
        return issues
    }
    
    // MARK: - GDPR Compliance
    
    func clearAllUserData() -> Bool {
        let conversationQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).conversations"
        ]
        
        let mainQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let conversationStatus = SecItemDelete(conversationQuery as CFDictionary)
        let mainStatus = SecItemDelete(mainQuery as CFDictionary)
        
        return (conversationStatus == errSecSuccess || conversationStatus == errSecItemNotFound) &&
               (mainStatus == errSecSuccess || mainStatus == errSecItemNotFound)
    }
}