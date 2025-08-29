import SwiftUI

struct SuggestedPromptsView: View {
    @AppStorage("user_name") private var userName = "friend"
    @State private var selectedCategory: PromptCategory = .daily
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 15) {
                    Circle()
                        .fill(Color.yellow.gradient)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("💡")
                                .font(.system(size: 40))
                        )
                    
                    VStack(spacing: 8) {
                        Text("Ideas for Peter")
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.primary)
                        
                        Text("Here are some things you can ask me about")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Category Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PromptCategory.allCases, id: \.self) { category in
                            CategoryButton(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation(.easeInOut) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 25)
                
                // Prompts List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(getPromptsFor(selectedCategory)) { prompt in
                            PromptCard(prompt: prompt, userName: userName)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
    
    private func getPromptsFor(_ category: PromptCategory) -> [SuggestedPrompt] {
        switch category {
        case .daily:
            return [
                SuggestedPrompt(
                    id: "weather-today",
                    text: "What's the weather like today?",
                    icon: "cloud.sun.fill",
                    description: "Get today's weather forecast and clothing suggestions"
                ),
                SuggestedPrompt(
                    id: "good-morning",
                    text: "Good morning, Peter!",
                    icon: "sun.max.fill",
                    description: "Start your day with a friendly greeting"
                ),
                SuggestedPrompt(
                    id: "daily-plan",
                    text: "Help me plan my day",
                    icon: "calendar",
                    description: "Get suggestions for structuring your daily activities"
                ),
                SuggestedPrompt(
                    id: "reminder-medicine",
                    text: "Remind me about my medicine",
                    icon: "pills.fill",
                    description: "Get help with medication reminders and schedules"
                )
            ]
        case .health:
            return [
                SuggestedPrompt(
                    id: "exercise-tips",
                    text: "What are some gentle exercises I can do?",
                    icon: "figure.walk",
                    description: "Get safe, age-appropriate exercise suggestions"
                ),
                SuggestedPrompt(
                    id: "healthy-meals",
                    text: "Suggest a healthy meal for today",
                    icon: "leaf.fill",
                    description: "Get nutritious meal ideas that are easy to prepare"
                ),
                SuggestedPrompt(
                    id: "sleep-better",
                    text: "How can I sleep better?",
                    icon: "moon.zzz.fill",
                    description: "Learn tips for improving your sleep quality"
                ),
                SuggestedPrompt(
                    id: "stay-hydrated",
                    text: "Remind me to drink more water",
                    icon: "drop.fill",
                    description: "Get hydration reminders and tips"
                )
            ]
        case .social:
            return [
                SuggestedPrompt(
                    id: "feeling-lonely",
                    text: "I'm feeling a bit lonely today",
                    icon: "heart.fill",
                    description: "Get emotional support and conversation"
                ),
                SuggestedPrompt(
                    id: "family-call",
                    text: "Help me call my family",
                    icon: "phone.fill",
                    description: "Get reminders to stay in touch with loved ones"
                ),
                SuggestedPrompt(
                    id: "tell-story",
                    text: "Tell me an interesting story",
                    icon: "book.fill",
                    description: "Enjoy engaging stories and conversation"
                ),
                SuggestedPrompt(
                    id: "share-memory",
                    text: "I want to share a memory",
                    icon: "photo.fill",
                    description: "Share your memories with a good listener"
                )
            ]
        case .entertainment:
            return [
                SuggestedPrompt(
                    id: "tell-joke",
                    text: "Tell me a clean, funny joke",
                    icon: "theatermasks.fill",
                    description: "Enjoy some lighthearted humor"
                ),
                SuggestedPrompt(
                    id: "riddle-puzzle",
                    text: "Give me a fun riddle to solve",
                    icon: "puzzlepiece.fill",
                    description: "Exercise your mind with gentle brain teasers"
                ),
                SuggestedPrompt(
                    id: "music-memories",
                    text: "Let's talk about music from my era",
                    icon: "music.note",
                    description: "Discuss music and songs from your generation"
                ),
                SuggestedPrompt(
                    id: "interesting-facts",
                    text: "Share an interesting fact",
                    icon: "lightbulb.fill",
                    description: "Learn something new and fascinating"
                )
            ]
        }
    }
}

struct CategoryButton: View {
    let category: PromptCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(category.icon)
                    .font(.title3)
                
                Text(category.title)
                    .font(.body.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.blue : Color(UIColor.systemBackground)
            )
            .foregroundColor(
                isSelected ? .white : .primary
            )
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PromptCard: View {
    let prompt: SuggestedPrompt
    let userName: String
    
    var body: some View {
        Button(action: {
            // In a real app, this would send the prompt to the chat
            print("Selected prompt: \(prompt.text)")
        }) {
            HStack(spacing: 15) {
                // Icon
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: prompt.icon)
                            .font(.title2)
                            .foregroundColor(.blue)
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt.text)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(prompt.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

enum PromptCategory: String, CaseIterable {
    case daily = "daily"
    case health = "health"
    case social = "social"
    case entertainment = "entertainment"
    
    var title: String {
        switch self {
        case .daily: return "Daily"
        case .health: return "Health"
        case .social: return "Social"
        case .entertainment: return "Fun"
        }
    }
    
    var icon: String {
        switch self {
        case .daily: return "☀️"
        case .health: return "🏥"
        case .social: return "💬"
        case .entertainment: return "🎭"
        }
    }
}

struct SuggestedPrompt: Identifiable {
    let id: String
    let text: String
    let icon: String
    let description: String
}

#Preview {
    SuggestedPromptsView()
}