import Foundation
import UserNotifications

struct EmailSummary {
    let userName: String
    let email: String
    let conversations: [ChatMessage]
    let date: Date
    let introMessage: String
    let outroMessage: String
}

struct EmailTemplate {
    static let intros = [
        "Hi {name},\nIt was great chatting with you today — here's a quick recap of our conversation:",
        "Hi {name},\nI hope you're having a good day. Here's what we discussed together:",
        "Hi {name},\nHere's a summary of our wonderful conversation today:",
        "Hi {name},\nI enjoyed talking with you! Here's what we covered:",
        "Hi {name},\nHope you had a lovely day. Here's our chat recap:"
    ]
    
    static let outros = [
        "Don't forget — I can help you with your shopping list, health tips, or the local weather.",
        "Remember, I'm here whenever you need help with recipes, gardening advice, or just a friendly chat.",
        "I'm always available to help with weather updates, interesting facts, or answer your questions.",
        "Feel free to ask me about cooking tips, current events, or anything else you'd like to know.",
        "I'm here 24/7 to help with weather, recipes, health tips, or just to have a conversation."
    ]
    
    static func generateHTML(summary: EmailSummary) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        
        let conversationHTML = summary.conversations.enumerated().map { index, message in
            if message.role == "user" {
                return """
                <div style="margin: 15px 0; padding: 10px; background-color: #e3f2fd; border-radius: 8px;">
                    <strong>You asked:</strong> \(message.content)
                </div>
                """
            } else {
                return """
                <div style="margin: 15px 0; padding: 10px; background-color: #f5f5f5; border-radius: 8px;">
                    <strong>Peter replied:</strong> \(message.content)
                </div>
                """
            }
        }.joined()
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Your Daily Chat Summary with Peter</title>
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
            
            <div style="text-align: center; margin-bottom: 30px;">
                <h1 style="color: #2196f3; margin-bottom: 10px;">📱 Peter AI</h1>
                <h2 style="color: #666; font-weight: normal; font-size: 18px;">Your Daily Chat Summary</h2>
                <p style="color: #888; font-size: 14px;">\(dateFormatter.string(from: summary.date))</p>
            </div>
            
            <div style="background-color: #fff; border-radius: 12px; padding: 25px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); margin-bottom: 20px;">
                <p style="font-size: 16px; margin-bottom: 20px;">\(summary.introMessage)</p>
                
                \(conversationHTML)
                
                <div style="margin-top: 25px; padding-top: 20px; border-top: 1px solid #eee;">
                    <p style="font-size: 16px; margin-bottom: 20px;">\(summary.outroMessage)</p>
                </div>
            </div>
            
            <div style="text-align: center; margin-top: 30px;">
                <a href="peterai://open" style="display: inline-block; background-color: #2196f3; color: white; text-decoration: none; padding: 15px 30px; border-radius: 25px; font-size: 16px; font-weight: 500;">
                    📱 Open Peter AI
                </a>
            </div>
            
            <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
                <p style="color: #888; font-size: 12px; margin-bottom: 10px;">
                    You're receiving this because you signed up for daily chat summaries.
                </p>
                <a href="https://peterai.app/unsubscribe?email=\(summary.email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" 
                   style="color: #888; font-size: 12px; text-decoration: underline;">
                    Unsubscribe from daily summaries
                </a>
                <p style="color: #888; font-size: 10px; margin-top: 15px;">
                    Peter AI • Made with ❤️ for seniors everywhere
                </p>
            </div>
            
        </body>
        </html>
        """
    }
}

class EmailService: ObservableObject {
    @Published var isScheduled = false
    @Published var lastSentDate: Date?
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadEmailSettings()
        scheduleDaily6PMNotification()
    }
    
    private func loadEmailSettings() {
        if let lastSent = userDefaults.object(forKey: "lastEmailSent") as? Date {
            lastSentDate = lastSent
        }
        isScheduled = userDefaults.bool(forKey: "emailScheduled")
    }
    
    private func saveEmailSettings() {
        if let lastSent = lastSentDate {
            userDefaults.set(lastSent, forKey: "lastEmailSent")
        }
        userDefaults.set(isScheduled, forKey: "emailScheduled")
    }
    
    func scheduleDaily6PMNotification() {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                self.scheduleDailyEmailTrigger()
            }
        }
    }
    
    private func scheduleDailyEmailTrigger() {
        let center = UNUserNotificationCenter.current()
        
        center.removeAllPendingNotificationRequests()
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Email Summary Ready"
        content.body = "Peter is preparing your daily chat summary..."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 18
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "dailyEmailSummary",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling daily email notification: \(error)")
            } else {
                DispatchQueue.main.async {
                    self.isScheduled = true
                    self.saveEmailSettings()
                }
            }
        }
    }
    
    func generateDailySummary(
        userName: String,
        email: String,
        conversations: [ChatMessage]
    ) -> EmailSummary {
        let today = Date()
        
        let todaysConversations = conversations.filter { message in
            Calendar.current.isDate(message.timestamp, inSameDayAs: today)
        }
        
        let randomIntro = EmailTemplate.intros.randomElement()!
            .replacingOccurrences(of: "{name}", with: userName)
        
        let randomOutro = EmailTemplate.outros.randomElement()!
        
        return EmailSummary(
            userName: userName,
            email: email,
            conversations: todaysConversations,
            date: today,
            introMessage: randomIntro,
            outroMessage: randomOutro
        )
    }
    
    func sendDailySummary(
        userName: String,
        email: String,
        conversations: [ChatMessage]
    ) async {
        let summary = generateDailySummary(
            userName: userName,
            email: email,
            conversations: conversations
        )
        
        guard !summary.conversations.isEmpty else {
            print("No conversations today, skipping email")
            return
        }
        
        let htmlContent = EmailTemplate.generateHTML(summary: summary)
        
        await sendEmail(
            to: email,
            subject: "Your Daily Chat Summary with Peter - \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))",
            htmlContent: htmlContent
        )
        
        DispatchQueue.main.async {
            self.lastSentDate = Date()
            self.saveEmailSettings()
        }
    }
    
    private func sendEmail(to email: String, subject: String, htmlContent: String) async {
        print("📧 Email Summary Generated")
        print("To: \(email)")
        print("Subject: \(subject)")
        print("Content Length: \(htmlContent.count) characters")
        print("\n--- EMAIL CONTENT PREVIEW ---")
        print("HTML Content: \(htmlContent.prefix(200))...")
        print("--- END PREVIEW ---\n")
        
        // TODO: Implement actual email sending with SendGrid/Mailgun
        // For now, we're just logging the email content
        // In production, this would make an API call to your email service
        
        /*
        Example SendGrid implementation:
        
        let request = SendGridEmailRequest(
            to: email,
            subject: subject,
            htmlContent: htmlContent,
            from: "hello@peterai.app"
        )
        
        try await sendGridService.send(request)
        */
    }
    
    func previewTodaysEmail(userName: String, email: String, conversations: [ChatMessage]) -> String {
        let summary = generateDailySummary(userName: userName, email: email, conversations: conversations)
        return EmailTemplate.generateHTML(summary: summary)
    }
}

// MARK: - SendGrid Integration (for future implementation)

struct SendGridEmailRequest: Codable {
    let personalizations: [Personalization]
    let from: EmailAddress
    let subject: String
    let content: [Content]
    
    struct Personalization: Codable {
        let to: [EmailAddress]
    }
    
    struct EmailAddress: Codable {
        let email: String
        let name: String?
    }
    
    struct Content: Codable {
        let type: String
        let value: String
    }
    
    static func create(to: String, toName: String, subject: String, htmlContent: String) -> SendGridEmailRequest {
        return SendGridEmailRequest(
            personalizations: [
                Personalization(to: [EmailAddress(email: to, name: toName)])
            ],
            from: EmailAddress(email: "hello@peterai.app", name: "Peter AI"),
            subject: subject,
            content: [
                Content(type: "text/html", value: htmlContent)
            ]
        )
    }
}