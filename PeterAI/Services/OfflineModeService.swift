import Foundation
import Network

class OfflineModeService: ObservableObject {
    @Published var isOffline = false
    @Published var canUseOfflineFeatures = true
    @Published var offlineMessage = ""
    @Published var lastOnlineTime: Date?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "OfflineModeService")
    private let secureStorage = SecureStorage.shared
    
    // Offline capabilities for elderly users
    private var offlineResponses: [String: String] = [:]
    private var cachedWeatherData: WeatherData?
    private var conversationHistory: [ChatMessage] = []
    
    init() {
        setupOfflineCapabilities()
        startNetworkMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = self?.isOffline ?? false
                self?.isOffline = path.status != .satisfied
                
                if self?.isOffline == true {
                    self?.handleOfflineMode()
                } else {
                    self?.handleOnlineMode(wasOffline: wasOffline)
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func handleOfflineMode() {
        offlineMessage = createElderlyFriendlyOfflineMessage()
        MonitoringService.shared.trackElderlyUserInteraction(
            .errorEncountered(
                ElderlyUserError(
                    type: .performanceIssue,
                    severity: .medium,
                    description: "Device went offline",
                    context: "Network connectivity lost",
                    timestamp: Date(),
                    affectedFeature: "ai_responses"
                )
            )
        )
    }
    
    private func handleOnlineMode(wasOffline: Bool) {
        lastOnlineTime = Date()
        
        if wasOffline {
            offlineMessage = "Great news! Your internet connection is back. Peter can now answer all your questions again."
            
            // Sync any cached data
            Task {
                await syncOfflineData()
            }
        } else {
            offlineMessage = ""
        }
    }
    
    // MARK: - Offline Capabilities Setup
    
    private func setupOfflineCapabilities() {
        // Pre-built responses for common elderly user questions
        offlineResponses = [
            // Time and date
            "what time is it": "I can't check the exact time right now because I need an internet connection. You can check the time on your device's home screen or ask Siri.",
            
            "what day is it": "I need an internet connection to check the current date. You can see today's date at the top of your device's screen.",
            
            // Weather - will use cached data if available
            "weather": "I need an internet connection to get current weather. If you'd like, I can tell you about the last weather report I received.",
            
            "temperature": "I can't check the current temperature without internet. The weather app on your device might have recent information.",
            
            // Emergency/Help
            "help": """
            I'm having trouble connecting to the internet right now, but I can still help in some ways:
            
            • For emergencies, call 911
            • To call family, use your phone app
            • I can remind you about basic tasks
            • When internet returns, I'll be back to full capability
            """,
            
            "emergency": """
            For any emergency, please call 911 immediately.
            
            I can't access emergency services right now because I need an internet connection, but your phone's emergency calling will always work.
            """,
            
            // Basic reassurance
            "are you there": "Yes, I'm still here! I just can't access the internet right now, so I can only help with basic things until the connection returns.",
            
            "confused": """
            I understand this can be confusing. Here's what's happening:
            
            • Your internet connection is not working right now
            • I need internet to answer most questions
            • Your device is fine - this is just temporary
            • When internet comes back, I'll work normally again
            
            In the meantime, you can still use your phone, text messages, and other apps that don't need internet.
            """,
            
            // Technical help
            "internet not working": """
            Here are some simple steps that often help:
            
            1. Check if WiFi is turned on in your device settings
            2. Try turning WiFi off and back on
            3. Move closer to your WiFi router
            4. Ask a family member to check if internet is working on their devices
            5. Contact your internet provider if problems continue
            
            Don't worry - these things happen and usually fix themselves.
            """
        ]
        
        loadCachedData()
    }
    
    // MARK: - Offline Response Generation
    
    func generateOfflineResponse(for message: String) -> ChatMessage? {
        guard isOffline else { return nil }
        
        let lowercaseMessage = message.lowercased()
        
        // Check for exact matches first
        for (key, response) in offlineResponses {
            if lowercaseMessage.contains(key) {
                return ChatMessage(role: "assistant", content: response)
            }
        }
        
        // Check for weather requests with cached data
        if lowercaseMessage.contains("weather") || lowercaseMessage.contains("temperature") {
            if let cachedWeather = getCachedWeatherResponse() {
                return ChatMessage(role: "assistant", content: cachedWeather)
            }
        }
        
        // Check for time-related requests
        if lowercaseMessage.contains("time") {
            return ChatMessage(role: "assistant", content: getCurrentTimeOffline())
        }
        
        // Default helpful offline response
        return ChatMessage(role: "assistant", content: createDefaultOfflineResponse())
    }
    
    private func getCachedWeatherResponse() -> String? {
        guard let weather = cachedWeatherData else { return nil }
        
        let cacheAge = abs(weather.timestamp?.timeIntervalSinceNow ?? TimeInterval.infinity)
        
        // Only use cached weather if it's less than 3 hours old
        if cacheAge < 10800 { // 3 hours
            return """
            I can't get current weather because I need internet, but I do have recent information from a few hours ago:
            
            \(weather.location) was \(weather.description) with a temperature of \(weather.temperatureString).
            
            For the most current weather, please check your weather app or try again when internet returns.
            """
        }
        
        return nil
    }
    
    private func getCurrentTimeOffline() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        
        let currentDateTime = formatter.string(from: Date())
        
        return """
        I can tell you the current time from your device: \(currentDateTime)
        
        I need an internet connection for more detailed information, but your device's clock should be accurate.
        """
    }
    
    private func createDefaultOfflineResponse() -> String {
        return """
        I'm sorry, but I need an internet connection to answer that question properly. Right now, I can only help with basic information like:
        
        • Telling you the current time
        • Providing emergency guidance
        • Giving simple reminders about using your device
        
        When your internet connection returns, I'll be able to help you with everything again. Don't worry - this is temporary!
        """
    }
    
    private func createElderlyFriendlyOfflineMessage() -> String {
        return """
        Don't worry - Peter is still here! 
        
        Your internet connection seems to be having trouble right now. This happens sometimes and usually fixes itself.
        
        I can still help with basic questions, but I won't be able to get current information like weather or news until the internet comes back.
        
        Your device is working fine - this is just a temporary internet issue.
        """
    }
    
    // MARK: - Data Caching and Sync
    
    func cacheWeatherData(_ weather: WeatherData) {
        // Add timestamp for cache expiry
        var weatherWithTimestamp = weather
        // Note: This would require modifying WeatherData to include timestamp
        cachedWeatherData = weatherWithTimestamp
        
        // Store in secure storage
        if let data = try? JSONEncoder().encode(weather) {
            _ = secureStorage.store(key: "cached_weather", value: data.base64EncodedString())
        }
    }
    
    func cacheConversationMessage(_ message: ChatMessage) {
        conversationHistory.append(message)
        
        // Keep only last 10 messages to prevent excessive storage
        if conversationHistory.count > 10 {
            conversationHistory.removeFirst()
        }
        
        // Store in secure storage
        if let data = try? JSONEncoder().encode(conversationHistory) {
            _ = secureStorage.store(key: "offline_conversation_history", value: data.base64EncodedString())
        }
    }
    
    private func loadCachedData() {
        // Load cached weather
        if let weatherData = secureStorage.retrieve(key: "cached_weather"),
           let data = Data(base64Encoded: weatherData),
           let weather = try? JSONDecoder().decode(WeatherData.self, from: data) {
            cachedWeatherData = weather
        }
        
        // Load conversation history
        if let historyData = secureStorage.retrieve(key: "offline_conversation_history"),
           let data = Data(base64Encoded: historyData),
           let history = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            conversationHistory = history
        }
    }
    
    private func syncOfflineData() async {
        // When coming back online, this would sync any offline interactions
        // For elderly users, we want to minimize complexity, so we mainly just
        // clear old cached data and prepare for fresh requests
        
        // Clear old cached weather (will be refreshed with new requests)
        if let cachedWeather = cachedWeatherData {
            let cacheAge = abs(cachedWeather.timestamp?.timeIntervalSinceNow ?? 0)
            if cacheAge > 3600 { // Older than 1 hour
                cachedWeatherData = nil
                _ = secureStorage.delete(key: "cached_weather")
            }
        }
    }
    
    // MARK: - Public Interface
    
    func canHandleOffline(message: String) -> Bool {
        guard isOffline else { return false }
        
        let lowercaseMessage = message.lowercased()
        
        // Check if we have any appropriate offline response
        for key in offlineResponses.keys {
            if lowercaseMessage.contains(key) {
                return true
            }
        }
        
        // Check for weather with cached data
        if (lowercaseMessage.contains("weather") || lowercaseMessage.contains("temperature")) && cachedWeatherData != nil {
            return true
        }
        
        // Can always handle time requests
        if lowercaseMessage.contains("time") {
            return true
        }
        
        // Can provide general help
        return true
    }
    
    func getOfflineCapabilityMessage() -> String {
        return """
        While offline, I can help with:
        
        ✓ Basic questions about using your device
        ✓ Emergency guidance
        ✓ Current time and date
        ✓ Simple reminders
        \(cachedWeatherData != nil ? "✓ Recent weather information\n" : "")
        
        When internet returns, I'll be able to:
        • Get current weather
        • Answer detailed questions  
        • Provide personalized assistance
        """
    }
    
    func getElderlyFriendlyNetworkStatus() -> String {
        if isOffline {
            if let lastOnline = lastOnlineTime {
                let timeAgo = Date().timeIntervalSince(lastOnline)
                if timeAgo < 300 { // Less than 5 minutes
                    return "Your internet connection was working just a few minutes ago. It should come back soon."
                } else if timeAgo < 3600 { // Less than 1 hour
                    return "Your internet has been down for a little while. You might want to check with family or call your internet provider."
                } else {
                    return "Your internet has been down for over an hour. Consider asking for help or calling your internet provider."
                }
            } else {
                return "I haven't been able to connect to the internet since you opened the app. Please check your WiFi settings or ask for help."
            }
        } else {
            return "Your internet connection is working perfectly!"
        }
    }
}

// MARK: - Extensions

extension WeatherData {
    var timestamp: Date? {
        // This would need to be added to the actual WeatherData struct
        return nil
    }
}