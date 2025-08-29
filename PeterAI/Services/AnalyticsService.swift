import Foundation
import UIKit

struct AnalyticsEvent: Codable {
    let id: UUID
    let userId: String
    let eventName: String
    let properties: [String: String]
    let timestamp: Date
    let sessionId: String
    
    init(userId: String, eventName: String, properties: [String: String] = [:], sessionId: String) {
        self.id = UUID()
        self.userId = userId
        self.eventName = eventName
        self.properties = properties
        self.timestamp = Date()
        self.sessionId = sessionId
    }
}

struct UserSession: Codable {
    let id: String
    let userId: String
    let startTime: Date
    let endTime: Date?
    let conversationCount: Int
    let appVersion: String
    let deviceModel: String
    let osVersion: String
    
    init(userId: String) {
        self.id = UUID().uuidString
        self.userId = userId
        self.startTime = Date()
        self.endTime = nil
        self.conversationCount = 0
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.deviceModel = UIDevice.current.model
        self.osVersion = UIDevice.current.systemVersion
    }
}

struct AbuseMonitoring: Codable {
    let userId: String
    let dailyQueryCount: Int
    let monthlyQueryCount: Int
    let lastResetDate: Date
    let flaggedForReview: Bool
    let warningsSent: Int
    
    init(userId: String) {
        self.userId = userId
        self.dailyQueryCount = 0
        self.monthlyQueryCount = 0
        self.lastResetDate = Date()
        self.flaggedForReview = false
        self.warningsSent = 0
    }
}

class AnalyticsService: ObservableObject {
    @Published var currentSession: UserSession?
    @Published var isAbuseMonitoringEnabled = true
    @Published var dailyQueryCount = 0
    @Published var monthlyQueryCount = 0
    
    private let userDefaults = UserDefaults.standard
    private var eventQueue: [AnalyticsEvent] = []
    private var uploadTimer: Timer?
    
    // Abuse limits
    private let dailyQueryLimit = 50
    private let monthlyQueryLimit = 500
    
    init() {
        loadAbuseData()
        startSession()
        scheduleEventUpload()
    }
    
    deinit {
        endSession()
        uploadTimer?.invalidate()
    }
    
    // MARK: - Session Management
    
    func startSession() {
        let userId = getUserId()
        currentSession = UserSession(userId: userId)
        
        track("session_started", properties: [
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion
        ])
    }
    
    func endSession() {
        guard let session = currentSession else { return }
        
        track("session_ended", properties: [
            "session_duration": String(Int(Date().timeIntervalSince(session.startTime))),
            "conversation_count": String(session.conversationCount)
        ])
        
        uploadEvents()
        currentSession = nil
    }
    
    private func getUserId() -> String {
        if let existingId = userDefaults.string(forKey: "user_analytics_id") {
            return existingId
        }
        
        let newId = UUID().uuidString
        userDefaults.set(newId, forKey: "user_analytics_id")
        return newId
    }
    
    // MARK: - Event Tracking
    
    func track(_ eventName: String, properties: [String: String] = [:]) {
        let userId = getUserId()
        let sessionId = currentSession?.id ?? "no_session"
        
        let event = AnalyticsEvent(
            userId: userId,
            eventName: eventName,
            properties: properties,
            sessionId: sessionId
        )
        
        eventQueue.append(event)
        
        // Also store locally for debugging
        print("📊 Analytics Event: \(eventName)")
        if !properties.isEmpty {
            print("   Properties: \(properties)")
        }
        
        // Upload immediately for critical events
        if isCriticalEvent(eventName) {
            uploadEvents()
        }
    }
    
    private func isCriticalEvent(_ eventName: String) -> Bool {
        return [
            "subscription_purchased",
            "subscription_cancelled",
            "abuse_limit_reached",
            "app_crashed",
            "session_started"
        ].contains(eventName)
    }
    
    // MARK: - Conversation Analytics
    
    func trackConversationStarted() {
        track("conversation_started")
    }
    
    func trackConversationEnded(messageCount: Int, duration: TimeInterval) {
        track("conversation_ended", properties: [
            "message_count": String(messageCount),
            "duration_seconds": String(Int(duration))
        ])
    }
    
    func trackVoiceInteraction(duration: TimeInterval, successful: Bool) {
        track("voice_interaction", properties: [
            "duration_seconds": String(Int(duration)),
            "successful": String(successful)
        ])
    }
    
    func trackSuggestedPromptUsed(_ prompt: String, category: String) {
        track("suggested_prompt_used", properties: [
            "prompt_text": prompt,
            "category": category
        ])
    }
    
    func trackEmailSummarySent() {
        track("email_summary_sent")
    }
    
    func trackHelpRequested(section: String) {
        track("help_requested", properties: [
            "section": section
        ])
    }
    
    func trackOnboardingStep(_ step: String, completed: Bool) {
        track("onboarding_step", properties: [
            "step": step,
            "completed": String(completed)
        ])
    }
    
    // MARK: - Abuse Monitoring
    
    func trackQuery() -> Bool {
        guard isAbuseMonitoringEnabled else { return true }
        
        updateQueryCounts()
        
        if dailyQueryCount >= dailyQueryLimit {
            track("abuse_daily_limit_reached", properties: [
                "daily_count": String(dailyQueryCount),
                "monthly_count": String(monthlyQueryCount)
            ])
            return false
        }
        
        if monthlyQueryCount >= monthlyQueryLimit {
            track("abuse_monthly_limit_reached", properties: [
                "daily_count": String(dailyQueryCount),
                "monthly_count": String(monthlyQueryCount)
            ])
            return false
        }
        
        return true
    }
    
    private func updateQueryCounts() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastReset = userDefaults.object(forKey: "last_query_reset") as? Date ?? Date.distantPast
        
        // Reset daily count if new day
        if !Calendar.current.isDate(lastReset, inSameDayAs: today) {
            dailyQueryCount = 0
            userDefaults.set(today, forKey: "last_query_reset")
        }
        
        // Reset monthly count if new month
        let monthStart = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        let lastMonthlyReset = userDefaults.object(forKey: "last_monthly_reset") as? Date ?? Date.distantPast
        
        if lastMonthlyReset < monthStart {
            monthlyQueryCount = 0
            userDefaults.set(monthStart, forKey: "last_monthly_reset")
        }
        
        // Increment counters
        dailyQueryCount += 1
        monthlyQueryCount += 1
        
        // Save updated counts
        saveAbuseData()
    }
    
    private func loadAbuseData() {
        dailyQueryCount = userDefaults.integer(forKey: "daily_query_count")
        monthlyQueryCount = userDefaults.integer(forKey: "monthly_query_count")
    }
    
    private func saveAbuseData() {
        userDefaults.set(dailyQueryCount, forKey: "daily_query_count")
        userDefaults.set(monthlyQueryCount, forKey: "monthly_query_count")
    }
    
    func getAbuseStatus() -> (daily: Int, monthly: Int, dailyLimit: Int, monthlyLimit: Int, isBlocked: Bool) {
        let isBlocked = dailyQueryCount >= dailyQueryLimit || monthlyQueryCount >= monthlyQueryLimit
        return (
            daily: dailyQueryCount,
            monthly: monthlyQueryCount,
            dailyLimit: dailyQueryLimit,
            monthlyLimit: monthlyQueryLimit,
            isBlocked: isBlocked
        )
    }
    
    // MARK: - Error Tracking
    
    func trackError(_ error: Error, context: String) {
        track("error_occurred", properties: [
            "error_message": error.localizedDescription,
            "context": context,
            "error_type": String(describing: type(of: error))
        ])
    }
    
    func trackAPIError(endpoint: String, statusCode: Int, message: String) {
        track("api_error", properties: [
            "endpoint": endpoint,
            "status_code": String(statusCode),
            "message": message
        ])
    }
    
    // MARK: - Data Upload
    
    private func scheduleEventUpload() {
        uploadTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.uploadEvents()
        }
    }
    
    private func uploadEvents() {
        guard !eventQueue.isEmpty else { return }
        
        let eventsToUpload = eventQueue
        eventQueue.removeAll()
        
        // In production, this would upload to your analytics backend
        uploadToBackend(eventsToUpload)
    }
    
    private func uploadToBackend(_ events: [AnalyticsEvent]) {
        print("📊 Uploading \(events.count) analytics events to backend...")
        
        // TODO: Implement actual backend upload
        // For now, we're just logging the events
        
        for event in events {
            print("   Event: \(event.eventName) at \(event.timestamp)")
            if !event.properties.isEmpty {
                print("      Properties: \(event.properties)")
            }
        }
        
        /*
        Example backend upload implementation:
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(events) else { return }
        
        var request = URLRequest(url: URL(string: "https://api.peterai.app/analytics")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer YOUR_API_KEY", forHTTPHeaderField: "Authorization")
        request.httpBody = data
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Analytics upload failed: \(error)")
                // Re-queue events for retry
                self.eventQueue.append(contentsOf: events)
            }
        }.resume()
        */
    }
    
    // MARK: - User Insights
    
    func getUserInsights() -> [String: Any] {
        let userId = getUserId()
        let abuseStatus = getAbuseStatus()
        
        return [
            "user_id": userId,
            "daily_queries": abuseStatus.daily,
            "monthly_queries": abuseStatus.monthly,
            "is_blocked": abuseStatus.isBlocked,
            "session_active": currentSession != nil,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown",
            "device_model": UIDevice.current.model,
            "os_version": UIDevice.current.systemVersion
        ]
    }
    
    // MARK: - Privacy Compliance
    
    func clearAllAnalyticsData() {
        eventQueue.removeAll()
        userDefaults.removeObject(forKey: "user_analytics_id")
        userDefaults.removeObject(forKey: "daily_query_count")
        userDefaults.removeObject(forKey: "monthly_query_count")
        userDefaults.removeObject(forKey: "last_query_reset")
        userDefaults.removeObject(forKey: "last_monthly_reset")
        
        track("analytics_data_cleared")
        uploadEvents() // Upload the clear event, then stop tracking
    }
    
    func exportUserData() -> Data? {
        let insights = getUserInsights()
        return try? JSONSerialization.data(withJSONObject: insights, options: .prettyPrinted)
    }
}

// MARK: - Backend Models (for future implementation)

struct BackendAnalyticsConfig: Codable {
    let apiEndpoint: String
    let apiKey: String
    let uploadInterval: TimeInterval
    let batchSize: Int
    let retryAttempts: Int
    
    static let `default` = BackendAnalyticsConfig(
        apiEndpoint: "https://api.peterai.app/analytics",
        apiKey: "", // Set in production
        uploadInterval: 30.0,
        batchSize: 50,
        retryAttempts: 3
    )
}