import Foundation

struct SuggestedPrompt: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let category: PromptCategory
    let requiresLocation: Bool
    let isActive: Bool
    let priority: Int
    
    init(text: String, category: PromptCategory, requiresLocation: Bool = false, priority: Int = 1) {
        self.id = UUID()
        self.text = text
        self.category = category
        self.requiresLocation = requiresLocation
        self.isActive = true
        self.priority = priority
    }
}

enum PromptCategory: String, CaseIterable, Codable {
    case weather = "weather"
    case cooking = "cooking"
    case health = "health"
    case gardening = "gardening"
    case technology = "technology"
    case entertainment = "entertainment"
    case general = "general"
    case news = "news"
    case family = "family"
    
    var displayName: String {
        switch self {
        case .weather: return "Weather"
        case .cooking: return "Cooking & Recipes"
        case .health: return "Health & Wellness"
        case .gardening: return "Gardening"
        case .technology: return "Technology Help"
        case .entertainment: return "Entertainment"
        case .general: return "General Questions"
        case .news: return "News & Current Events"
        case .family: return "Family & Relationships"
        }
    }
}

class PromptsService: ObservableObject {
    @Published var currentPrompts: [SuggestedPrompt] = []
    @Published var allPrompts: [SuggestedPrompt] = []
    @Published var isLoading = false
    
    private let userDefaults = UserDefaults.standard
    private let maxVisiblePrompts = 2
    private var rotationTimer: Timer?
    
    init() {
        loadPrompts()
        startPromptRotation()
    }
    
    deinit {
        rotationTimer?.invalidate()
    }
    
    private func loadPrompts() {
        if let savedData = userDefaults.data(forKey: "savedPrompts"),
           let savedPrompts = try? JSONDecoder().decode([SuggestedPrompt].self, from: savedData) {
            allPrompts = savedPrompts
        } else {
            allPrompts = createDefaultPrompts()
            savePrompts()
        }
        
        updateCurrentPrompts()
    }
    
    private func savePrompts() {
        if let encoded = try? JSONEncoder().encode(allPrompts) {
            userDefaults.set(encoded, forKey: "savedPrompts")
        }
    }
    
    private func createDefaultPrompts() -> [SuggestedPrompt] {
        return [
            // Weather (Location-based)
            SuggestedPrompt(text: "What's the weather forecast?", category: .weather, requiresLocation: true, priority: 3),
            SuggestedPrompt(text: "Will it rain today?", category: .weather, requiresLocation: true, priority: 2),
            SuggestedPrompt(text: "How hot will it be this weekend?", category: .weather, requiresLocation: true, priority: 2),
            SuggestedPrompt(text: "Should I bring an umbrella today?", category: .weather, requiresLocation: true, priority: 2),
            
            // Cooking & Recipes
            SuggestedPrompt(text: "Give me an easy soup recipe", category: .cooking, priority: 3),
            SuggestedPrompt(text: "What's a simple dinner for two people?", category: .cooking, priority: 3),
            SuggestedPrompt(text: "How do I make a perfect cup of tea?", category: .cooking, priority: 2),
            SuggestedPrompt(text: "What's a healthy breakfast idea?", category: .cooking, priority: 2),
            SuggestedPrompt(text: "How long should I cook chicken breast?", category: .cooking, priority: 2),
            SuggestedPrompt(text: "What can I make with leftover vegetables?", category: .cooking, priority: 2),
            
            // Health & Wellness
            SuggestedPrompt(text: "What are some gentle exercises for seniors?", category: .health, priority: 3),
            SuggestedPrompt(text: "How can I improve my sleep?", category: .health, priority: 2),
            SuggestedPrompt(text: "What foods are good for heart health?", category: .health, priority: 2),
            SuggestedPrompt(text: "How much water should I drink daily?", category: .health, priority: 1),
            SuggestedPrompt(text: "What are signs of dehydration?", category: .health, priority: 1),
            
            // Gardening
            SuggestedPrompt(text: "Tell me a fun fact about gardening", category: .gardening, priority: 3),
            SuggestedPrompt(text: "What flowers bloom in spring?", category: .gardening, priority: 2),
            SuggestedPrompt(text: "How often should I water my plants?", category: .gardening, priority: 2),
            SuggestedPrompt(text: "What vegetables are easy to grow?", category: .gardening, priority: 2),
            
            // Technology Help
            SuggestedPrompt(text: "How do I make text bigger on my phone?", category: .technology, priority: 2),
            SuggestedPrompt(text: "What is WiFi and how does it work?", category: .technology, priority: 1),
            SuggestedPrompt(text: "How do I video call my family?", category: .technology, priority: 2),
            SuggestedPrompt(text: "What's the difference between email and texting?", category: .technology, priority: 1),
            
            // Entertainment
            SuggestedPrompt(text: "Tell me a joke", category: .entertainment, priority: 2),
            SuggestedPrompt(text: "What's a good book to read?", category: .entertainment, priority: 2),
            SuggestedPrompt(text: "Suggest a classic movie to watch", category: .entertainment, priority: 2),
            SuggestedPrompt(text: "What's an interesting historical fact?", category: .entertainment, priority: 2),
            
            // General Questions
            SuggestedPrompt(text: "What time is it in Chicago?", category: .general, priority: 2),
            SuggestedPrompt(text: "How far is the moon from Earth?", category: .general, priority: 1),
            SuggestedPrompt(text: "What's the capital of Australia?", category: .general, priority: 1),
            SuggestedPrompt(text: "Tell me something interesting about elephants", category: .general, priority: 2),
            
            // News & Current Events
            SuggestedPrompt(text: "What's happening in the news today?", category: .news, priority: 2),
            SuggestedPrompt(text: "Tell me about today's weather news", category: .news, priority: 1),
            
            // Family & Relationships
            SuggestedPrompt(text: "How can I stay in touch with my grandchildren?", category: .family, priority: 2),
            SuggestedPrompt(text: "What are good conversation starters?", category: .family, priority: 1),
            SuggestedPrompt(text: "How do I show someone I care about them?", category: .family, priority: 1)
        ]
    }
    
    func getPromptsForLocation(_ location: String?) -> [SuggestedPrompt] {
        var availablePrompts = allPrompts.filter { $0.isActive }
        
        // If no location, filter out location-based prompts
        if location == nil || location?.isEmpty == true {
            availablePrompts = availablePrompts.filter { !$0.requiresLocation }
        }
        
        // Sort by priority and randomize within priority groups
        let highPriority = availablePrompts.filter { $0.priority == 3 }.shuffled()
        let mediumPriority = availablePrompts.filter { $0.priority == 2 }.shuffled()
        let lowPriority = availablePrompts.filter { $0.priority == 1 }.shuffled()
        
        return highPriority + mediumPriority + lowPriority
    }
    
    func updateCurrentPrompts(for location: String? = nil) {
        let availablePrompts = getPromptsForLocation(location)
        currentPrompts = Array(availablePrompts.prefix(maxVisiblePrompts))
    }
    
    private func startPromptRotation() {
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            self.rotatePrompts()
        }
    }
    
    func rotatePrompts() {
        let availablePrompts = getPromptsForLocation(nil) // TODO: Use actual user location
        
        // Get next batch of prompts, avoiding recently shown ones
        let recentPromptTexts = Set(currentPrompts.map { $0.text })
        let freshPrompts = availablePrompts.filter { !recentPromptTexts.contains($0.text) }
        
        if freshPrompts.count >= maxVisiblePrompts {
            currentPrompts = Array(freshPrompts.prefix(maxVisiblePrompts))
        } else {
            // If not enough fresh prompts, mix with some previous ones
            let mixedPrompts = (freshPrompts + availablePrompts.shuffled()).prefix(maxVisiblePrompts)
            currentPrompts = Array(mixedPrompts)
        }
    }
    
    func addCustomPrompt(_ text: String, category: PromptCategory, requiresLocation: Bool = false) {
        let newPrompt = SuggestedPrompt(
            text: text,
            category: category,
            requiresLocation: requiresLocation,
            priority: 2
        )
        
        allPrompts.append(newPrompt)
        savePrompts()
        updateCurrentPrompts()
    }
    
    func removePrompt(_ prompt: SuggestedPrompt) {
        allPrompts.removeAll { $0.id == prompt.id }
        savePrompts()
        updateCurrentPrompts()
    }
    
    func togglePromptActive(_ prompt: SuggestedPrompt) {
        if let index = allPrompts.firstIndex(where: { $0.id == prompt.id }) {
            allPrompts[index] = SuggestedPrompt(
                text: prompt.text,
                category: prompt.category,
                requiresLocation: prompt.requiresLocation,
                priority: prompt.priority
            )
        }
        savePrompts()
        updateCurrentPrompts()
    }
    
    func getPromptsByCategory() -> [PromptCategory: [SuggestedPrompt]] {
        return Dictionary(grouping: allPrompts) { $0.category }
    }
    
    func searchPrompts(_ query: String) -> [SuggestedPrompt] {
        guard !query.isEmpty else { return allPrompts }
        
        return allPrompts.filter { prompt in
            prompt.text.lowercased().contains(query.lowercased()) ||
            prompt.category.displayName.lowercased().contains(query.lowercased())
        }
    }
    
    // For admin/testing purposes
    func resetToDefaults() {
        allPrompts = createDefaultPrompts()
        savePrompts()
        updateCurrentPrompts()
    }
    
    func getPromptStats() -> (total: Int, active: Int, byCategory: [PromptCategory: Int]) {
        let active = allPrompts.filter { $0.isActive }.count
        let byCategory = Dictionary(grouping: allPrompts) { $0.category }
            .mapValues { $0.count }
        
        return (total: allPrompts.count, active: active, byCategory: byCategory)
    }
}

// MARK: - Location-based prompt customization
extension PromptsService {
    func personalizePromptForLocation(_ prompt: SuggestedPrompt, location: String?) -> String {
        guard let location = location, !location.isEmpty else {
            return prompt.text
        }
        
        switch prompt.category {
        case .weather:
            if prompt.text.contains("weather forecast") {
                return "What's the weather forecast in \(location)?"
            }
            if prompt.text.contains("rain today") {
                return "Will it rain in \(location) today?"
            }
            if prompt.text.contains("hot will it be") {
                return "How hot will it be in \(location) this weekend?"
            }
            if prompt.text.contains("umbrella") {
                return "Should I bring an umbrella in \(location) today?"
            }
        case .gardening:
            if prompt.text.contains("flowers bloom") {
                return "What flowers bloom in \(location) during spring?"
            }
        case .news:
            if prompt.text.contains("weather news") {
                return "Tell me about today's weather news in \(location)"
            }
        default:
            break
        }
        
        return prompt.text
    }
}