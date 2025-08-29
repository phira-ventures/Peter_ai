import Foundation

struct ChatMessage: Codable, Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let timestamp: Date
    
    init(role: String, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let role: String
            let content: String
        }
    }
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [RequestMessage]
    let temperature: Double
    let max_tokens: Int
    
    struct RequestMessage: Codable {
        let role: String
        let content: String
    }
}

class OpenAIService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var apiKey: String? {
        return SecureStorage.shared.openAIAPIKey
    }
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    func sendMessage(_ userMessage: String, userName: String = "friend") async {
        // Input sanitization and validation
        let sanitizedMessage = sanitizeInput(userMessage)
        let sanitizedUserName = sanitizeInput(userName)
        
        guard !sanitizedMessage.isEmpty else {
            DispatchQueue.main.async {
                self.error = "Please provide a valid message"
            }
            return
        }
        
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.error = "Please configure your OpenAI API key"
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
            self.messages.append(ChatMessage(role: "user", content: sanitizedMessage))
        }
        
        let systemPrompt = createSystemPrompt(userName: sanitizedUserName)
        
        var requestMessages = [OpenAIRequest.RequestMessage]()
        requestMessages.append(OpenAIRequest.RequestMessage(role: "system", content: systemPrompt))
        
        for message in messages.suffix(10) {
            requestMessages.append(OpenAIRequest.RequestMessage(role: message.role, content: message.content))
        }
        
        let request = OpenAIRequest(
            model: "gpt-4",
            messages: requestMessages,
            temperature: 0.7,
            max_tokens: 500
        )
        
        do {
            let response = try await performRequest(request)
            
            DispatchQueue.main.async {
                if let assistantMessage = response.choices.first?.message.content {
                    self.messages.append(ChatMessage(role: "assistant", content: assistantMessage))
                }
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func createSystemPrompt(userName: String) -> String {
        return """
        You are Peter, a warm, helpful AI assistant designed specifically for people over 60. Your personality traits:
        
        - Always greet users by their name (\(userName))
        - Use polite, respectful language suitable for elderly users
        - Speak clearly and avoid slang, jargon, or overly technical terms
        - Be patient and understanding
        - Provide thorough but not overwhelming explanations
        - Show genuine interest and care
        - Use a warm, friendly tone like a helpful son-in-law
        - Keep responses concise but complete
        - Avoid abbreviations and text speak
        - Be encouraging and never condescending
        
        Topics you excel at:
        - General knowledge and interesting facts
        - Weather information
        - Simple recipes and cooking tips
        - Health and wellness (general advice only, never medical diagnosis)
        - Technology help (explained simply)
        - News and current events
        - Gardening and home care
        - Entertainment recommendations
        
        Always remember that you're speaking to someone who values respect, courtesy, and clear communication.
        """
    }
    
    private func performRequest(_ request: OpenAIRequest) async throws -> OpenAIResponse {
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "OpenAIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        guard let secureAPIKey = apiKey, !secureAPIKey.isEmpty else {
            throw NSError(domain: "OpenAIService", code: -3, userInfo: [NSLocalizedDescriptionKey: "API key not available"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(secureAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30.0
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenAIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(OpenAIResponse.self, from: data)
    }
    
    func clearMessages() {
        messages.removeAll()
    }
    
    func getRecentMessages() -> [ChatMessage] {
        return Array(messages.suffix(10))
    }
    
    // MARK: - Security Methods
    
    private func sanitizeInput(_ input: String) -> String {
        // Remove potential harmful characters and trim whitespace
        let sanitized = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\0", with: "") // Remove null bytes
            .replacingOccurrences(of: "\u{FEFF}", with: "") // Remove BOM
        
        // Limit length to prevent abuse
        let maxLength = 1000
        if sanitized.count > maxLength {
            return String(sanitized.prefix(maxLength))
        }
        
        return sanitized
    }
}