import SwiftUI

struct HelpGuide: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let icon: String
    let category: HelpCategory
}

enum HelpCategory {
    case gettingStarted
    case voiceCommands
    case troubleshooting
    case features
}

struct FAQ: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
    let category: String
}

struct HelpSystemView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedGuide: HelpGuide?
    @State private var showingGuideDetail = false
    @State private var showingFAQ = false
    @State private var searchText = ""
    
    let helpGuides = [
        HelpGuide(
            title: "Getting Started with Peter",
            content: """
            Welcome to Peter AI! Here's how to get the most out of your AI companion:
            
            **First Steps:**
            1. Make sure you're in a quiet environment
            2. Hold your phone comfortably about 6 inches from your mouth
            3. Tap the big blue "TAP TO SPEAK" button
            4. Speak clearly and naturally
            5. Tap "TAP WHEN YOU'RE DONE" when finished
            
            **What Peter Can Help With:**
            • Weather forecasts and current conditions
            • Simple recipes and cooking tips
            • General health and wellness advice
            • Gardening tips and plant care
            • Technology help explained simply
            • Interesting facts and trivia
            • Time zones and basic calculations
            • Entertainment recommendations
            
            **Tips for Best Results:**
            • Speak at a normal pace, not too fast or slow
            • Try to minimize background noise
            • If Peter doesn't understand, try rephrasing your question
            • Be specific - instead of "food" try "chicken recipe"
            """,
            icon: "hand.wave.fill",
            category: .gettingStarted
        ),
        
        HelpGuide(
            title: "Voice Commands & Tips",
            content: """
            **How to Talk to Peter:**
            
            **Good Examples:**
            • "What's the weather like today?"
            • "Can you give me a simple soup recipe?"
            • "Tell me about roses in my garden"
            • "How do I video call my daughter?"
            • "What time is it in New York?"
            
            **Voice Tips:**
            • Speak naturally, like talking to a friend
            • Don't shout - normal conversation volume works best
            • Pause briefly between different questions
            • If you make a mistake, just start over
            
            **If Peter Doesn't Understand:**
            • Check that your microphone isn't covered
            • Make sure you're not too close or far from the phone
            • Try rephrasing your question differently
            • Speak a bit slower if you usually talk fast
            
            **Background Noise:**
            • Turn down TV, radio, or music if possible
            • Move away from washing machines, fans, or AC
            • Close windows if traffic is loud
            • Ask others to speak quietly during your conversation
            """,
            icon: "mic.fill",
            category: .voiceCommands
        ),
        
        HelpGuide(
            title: "Troubleshooting Common Issues",
            content: """
            **Peter Can't Hear Me:**
            1. Check if microphone permission is enabled:
               • Go to Settings on your phone
               • Find "Peter AI" in the app list
               • Make sure "Microphone" is turned ON
            2. Restart the Peter AI app
            3. Make sure your phone's volume is up
            4. Try moving to a quieter location
            
            **Peter Isn't Responding:**
            1. Check your internet connection (WiFi or cellular)
            2. Close and reopen the Peter AI app
            3. Make sure you have the latest version of the app
            4. Restart your phone if problems continue
            
            **Peter's Voice Is Too Fast/Slow:**
            • We're working on voice speed controls
            • For now, you can use your phone's accessibility settings
            • Go to Settings → Accessibility → Spoken Content
            
            **App Crashes or Freezes:**
            1. Close all other apps on your phone
            2. Restart your phone
            3. Update to the latest version of Peter AI
            4. If problems continue, call our support line
            
            **Email Summaries Not Coming:**
            • Check your email spam/junk folder
            • Make sure you entered your email correctly during setup
            • Email summaries are sent at 6 PM local time
            """,
            icon: "wrench.and.screwdriver.fill",
            category: .troubleshooting
        ),
        
        HelpGuide(
            title: "Peter's Features Explained",
            content: """
            **Daily Email Summaries:**
            Every day at 6 PM, Peter sends you a friendly email with:
            • A summary of your conversations that day
            • Highlights of important information discussed
            • Suggestions for tomorrow's chats
            • Easy unsubscribe option if you change your mind
            
            **Suggested Questions:**
            The blue buttons show helpful questions you can ask:
            • They change automatically every few minutes
            • Based on topics popular with other users
            • Customized for your location when possible
            • Tap any button instead of speaking if you prefer
            
            **Voice Recognition:**
            Peter uses advanced technology to understand you:
            • Works with most accents and speaking styles
            • Gets better over time as you use it more
            • Can handle background noise reasonably well
            • Processes your speech privately and securely
            
            **AI Responses:**
            Peter's knowledge comes from:
            • Constantly updated information sources
            • Training focused on helpful, accurate answers
            • Special attention to senior-friendly language
            • Careful filtering of inappropriate content
            
            **Privacy & Security:**
            • Your conversations are kept private
            • No personal information is shared with others
            • You can delete your data anytime by contacting support
            • All communication is encrypted for your protection
            """,
            icon: "star.fill",
            category: .features
        )
    ]
    
    let faqs = [
        FAQ(
            question: "How much does Peter AI cost?",
            answer: "Peter AI offers two subscription options: $14.99 per month or $125 per year (30% savings). All features are included in both plans.",
            category: "Billing"
        ),
        FAQ(
            question: "Can I cancel my subscription anytime?",
            answer: "Yes! You can cancel anytime through your iPhone's Settings → Subscriptions. Your access continues until the end of your current billing period.",
            category: "Billing"
        ),
        FAQ(
            question: "Does Peter AI work offline?",
            answer: "Peter needs an internet connection to answer questions, but you can browse help guides and settings offline.",
            category: "Technical"
        ),
        FAQ(
            question: "Can family members use my account?",
            answer: "Each person should have their own Peter AI account for the best personalized experience. Family sharing through Apple subscriptions may be available.",
            category: "Account"
        ),
        FAQ(
            question: "How accurate is Peter's information?",
            answer: "Peter uses reliable, up-to-date sources but always double-check important medical, financial, or legal information with professionals.",
            category: "General"
        ),
        FAQ(
            question: "Can I change my email address?",
            answer: "Currently, you'll need to contact support to change your email. We're working on making this easier in the app.",
            category: "Account"
        ),
        FAQ(
            question: "Why didn't I receive my daily email?",
            answer: "Check your spam folder first. Emails are sent at 6 PM local time. If you had no conversations that day, no email is sent.",
            category: "Email"
        ),
        FAQ(
            question: "Is my data safe and private?",
            answer: "Yes! Your conversations are encrypted and kept private. We never sell or share your personal information.",
            category: "Privacy"
        ),
        FAQ(
            question: "Can Peter help with medical questions?",
            answer: "Peter can provide general health information but cannot diagnose conditions or replace professional medical advice. Always consult your doctor for health concerns.",
            category: "General"
        ),
        FAQ(
            question: "How do I contact human support?",
            answer: "Tap 'Call a real person' in the help menu, or call +1-800-123-4567 during business hours (9 AM - 6 PM EST, Monday-Friday).",
            category: "Support"
        )
    ]
    
    var filteredFAQs: [FAQ] {
        if searchText.isEmpty {
            return faqs
        } else {
            return faqs.filter { faq in
                faq.question.localizedCaseInsensitiveContains(searchText) ||
                faq.answer.localizedCaseInsensitiveContains(searchText) ||
                faq.category.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    headerView
                    quickActionsView
                    guidesSection
                    faqSection
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .sheet(isPresented: $showingGuideDetail) {
            if let guide = selectedGuide {
                GuideDetailView(guide: guide)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 15) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Need Help?")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("We're here to help you get the most out of Peter AI")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var quickActionsView: some View {
        VStack(spacing: 15) {
            HelpActionButton(
                title: "Call a Real Person",
                subtitle: "Speak with our friendly support team",
                icon: "phone.fill",
                color: .green
            ) {
                if let phoneURL = URL(string: "tel:+18001234567") {
                    UIApplication.shared.open(phoneURL)
                }
            }
            
            HelpActionButton(
                title: "Send Email Support",
                subtitle: "Get help via email within 24 hours",
                icon: "envelope.fill",
                color: .blue
            ) {
                if let emailURL = URL(string: "mailto:support@peterai.app?subject=Help%20Request") {
                    UIApplication.shared.open(emailURL)
                }
            }
        }
    }
    
    private var guidesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                Text("How-To Guides")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                ForEach(helpGuides) { guide in
                    GuideCard(guide: guide) {
                        selectedGuide = guide
                        showingGuideDetail = true
                    }
                }
            }
        }
    }
    
    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "questionmark.bubble.fill")
                    .foregroundColor(.blue)
                Text("Frequently Asked Questions")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            SearchBar(text: $searchText, placeholder: "Search questions...")
            
            LazyVStack(spacing: 10) {
                ForEach(filteredFAQs) { faq in
                    FAQCard(faq: faq)
                }
            }
        }
    }
}

struct HelpActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(color)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(15)
        }
    }
}

struct GuideCard: View {
    let guide: HelpGuide
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: guide.icon)
                    .font(.title)
                    .foregroundColor(.blue)
                    .frame(height: 30)
                
                Text(guide.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(15)
        }
    }
}

struct GuideDetailView: View {
    let guide: HelpGuide
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: guide.icon)
                            .font(.title)
                            .foregroundColor(.blue)
                        
                        Text(guide.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text(guide.content)
                        .font(.body)
                        .lineSpacing(4)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct FAQCard: View {
    let faq: FAQ
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(faq.question)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text(faq.category)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                Text(faq.answer)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .font(.body)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    HelpSystemView()
}