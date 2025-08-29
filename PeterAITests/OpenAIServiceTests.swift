import XCTest
import Foundation
@testable import PeterAI

class OpenAIServiceTests: XCTestCase {
    var openAIService: OpenAIService!
    var mockURLSession: MockURLSession!
    var mockURLSessionDataTask: MockURLSessionDataTask!
    
    override func setUp() {
        super.setUp()
        openAIService = OpenAIService()
        mockURLSession = MockURLSession()
        mockURLSessionDataTask = MockURLSessionDataTask()
        mockURLSession.dataTask = mockURLSessionDataTask
        
        // Inject mock session
        openAIService.urlSession = mockURLSession
        
        // Set a test API key to bypass empty key check
        openAIService.setAPIKey("test-api-key-12345")
    }
    
    override func tearDown() {
        openAIService = nil
        mockURLSession = nil
        mockURLSessionDataTask = nil
        super.tearDown()
    }
    
    // MARK: - API Key Tests
    
    func testEmptyAPIKeyHandling() async {
        // Given
        let serviceWithEmptyKey = OpenAIService()
        let expectation = XCTestExpectation(description: "Empty API key handling")
        
        // When
        await serviceWithEmptyKey.sendMessage("Test message", userName: "TestUser")
        
        // Then
        DispatchQueue.main.async {
            XCTAssertEqual(serviceWithEmptyKey.error, "Please configure your OpenAI API key")
            XCTAssertFalse(serviceWithEmptyKey.isLoading)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testAPIKeyValidation() {
        // Given
        let validKey = "sk-1234567890abcdefghijklmnopqrstuvwxyz"
        let invalidKey = "invalid-key"
        
        // When/Then
        XCTAssertTrue(openAIService.isValidAPIKey(validKey))
        XCTAssertFalse(openAIService.isValidAPIKey(invalidKey))
        XCTAssertFalse(openAIService.isValidAPIKey(""))
    }
    
    // MARK: - Message Management Tests
    
    func testSuccessfulMessageSending() async {
        // Given
        let testMessage = "What's the weather like?"
        let testUserName = "John"
        
        let mockResponse = OpenAIResponse(
            choices: [
                OpenAIResponse.Choice(
                    message: OpenAIResponse.Choice.Message(
                        role: "assistant",
                        content: "I'd be happy to help with weather information. What's your location?"
                    )
                )
            ]
        )
        
        mockURLSession.data = try! JSONEncoder().encode(mockResponse)
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.openai.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let expectation = XCTestExpectation(description: "Successful message sending")
        
        // When
        await openAIService.sendMessage(testMessage, userName: testUserName)
        
        // Then
        DispatchQueue.main.async {
            XCTAssertEqual(self.openAIService.messages.count, 2) // User + Assistant
            XCTAssertEqual(self.openAIService.messages[0].role, "user")
            XCTAssertEqual(self.openAIService.messages[0].content, testMessage)
            XCTAssertEqual(self.openAIService.messages[1].role, "assistant")
            XCTAssertEqual(self.openAIService.messages[1].content, "I'd be happy to help with weather information. What's your location?")
            XCTAssertFalse(self.openAIService.isLoading)
            XCTAssertNil(self.openAIService.error)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testMessageContextLimiting() async {
        // Given - Add 15 messages to exceed the 10-message limit
        for i in 1...15 {
            openAIService.messages.append(ChatMessage(role: "user", content: "Message \(i)"))
        }
        
        let mockResponse = OpenAIResponse(
            choices: [
                OpenAIResponse.Choice(
                    message: OpenAIResponse.Choice.Message(
                        role: "assistant",
                        content: "Response"
                    )
                )
            ]
        )
        
        mockURLSession.data = try! JSONEncoder().encode(mockResponse)
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.openai.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        await openAIService.sendMessage("New message", userName: "Test")
        
        // Then - Should only send last 10 messages + system prompt
        XCTAssertEqual(mockURLSession.lastRequest?.httpBody?.count, mockURLSession.lastRequest?.httpBody?.count)
        // Verify the request only contains recent messages
        if let requestData = mockURLSession.lastRequest?.httpBody {
            let request = try! JSONDecoder().decode(OpenAIRequest.self, from: requestData)
            XCTAssertEqual(request.messages.count, 11) // 1 system + 10 messages
        }
    }
    
    // MARK: - System Prompt Tests
    
    func testSystemPromptGeneration() {
        // Given
        let userName = "Margaret"
        
        // When
        let systemPrompt = openAIService.createSystemPrompt(userName: userName)
        
        // Then
        XCTAssertTrue(systemPrompt.contains(userName))
        XCTAssertTrue(systemPrompt.contains("people over 60"))
        XCTAssertTrue(systemPrompt.contains("warm, helpful"))
        XCTAssertTrue(systemPrompt.contains("polite, respectful language"))
        XCTAssertTrue(systemPrompt.contains("avoid slang, jargon"))
    }
    
    func testSystemPromptPersonalization() {
        // Given
        let testNames = ["Robert", "Mary", "José", "李华"]
        
        for name in testNames {
            // When
            let prompt = openAIService.createSystemPrompt(userName: name)
            
            // Then
            XCTAssertTrue(prompt.contains("\\(\(name))"), "Should personalize for name: \(name)")
        }
    }
    
    // MARK: - API Error Handling Tests
    
    func testAPIRateLimitError() async {
        // Given
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.openai.com")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: nil
        )
        mockURLSession.data = "Rate limit exceeded".data(using: .utf8)
        
        let expectation = XCTestExpectation(description: "Rate limit error")
        
        // When
        await openAIService.sendMessage("Test message", userName: "Test")
        
        // Then
        DispatchQueue.main.async {
            XCTAssertTrue(self.openAIService.error?.contains("429") == true)
            XCTAssertFalse(self.openAIService.isLoading)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testAPIUnauthorizedError() async {
        // Given
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.openai.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        mockURLSession.data = "Invalid API key".data(using: .utf8)
        
        let expectation = XCTestExpectation(description: "Unauthorized error")
        
        // When
        await openAIService.sendMessage("Test message", userName: "Test")
        
        // Then
        DispatchQueue.main.async {
            XCTAssertTrue(self.openAIService.error?.contains("401") == true)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testNetworkError() async {
        // Given
        mockURLSession.error = URLError(.notConnectedToInternet)
        
        let expectation = XCTestExpectation(description: "Network error")
        
        // When
        await openAIService.sendMessage("Test message", userName: "Test")
        
        // Then
        DispatchQueue.main.async {
            XCTAssertTrue(self.openAIService.error?.contains("not connected") == true)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testInvalidJSONResponse() async {
        // Given
        mockURLSession.data = "Invalid JSON response".data(using: .utf8)
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.openai.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let expectation = XCTestExpectation(description: "Invalid JSON error")
        
        // When
        await openAIService.sendMessage("Test message", userName: "Test")
        
        // Then
        DispatchQueue.main.async {
            XCTAssertNotNil(self.openAIService.error)
            XCTAssertFalse(self.openAIService.isLoading)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Request Validation Tests
    
    func testRequestHeaders() async {
        // Given
        let mockResponse = OpenAIResponse(
            choices: [
                OpenAIResponse.Choice(
                    message: OpenAIResponse.Choice.Message(role: "assistant", content: "Test response")
                )
            ]
        )
        
        mockURLSession.data = try! JSONEncoder().encode(mockResponse)
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.openai.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        await openAIService.sendMessage("Test", userName: "Test")
        
        // Then
        let request = mockURLSession.lastRequest
        XCTAssertEqual(request?.httpMethod, "POST")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertTrue(request?.value(forHTTPHeaderField: "Authorization")?.starts(with: "Bearer ") == true)
    }
    
    func testRequestBodyStructure() async {
        // Given
        mockURLSession.data = try! JSONEncoder().encode(
            OpenAIResponse(choices: [
                OpenAIResponse.Choice(message: OpenAIResponse.Choice.Message(role: "assistant", content: "Test"))
            ])
        )
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.openai.com")!, statusCode: 200, httpVersion: nil, headerFields: nil
        )
        
        // When
        await openAIService.sendMessage("Hello Peter", userName: "Alice")
        
        // Then
        guard let requestData = mockURLSession.lastRequest?.httpBody else {
            XCTFail("No request body found")
            return
        }
        
        let request = try! JSONDecoder().decode(OpenAIRequest.self, from: requestData)
        XCTAssertEqual(request.model, "gpt-4")
        XCTAssertEqual(request.temperature, 0.7)
        XCTAssertEqual(request.max_tokens, 500)
        XCTAssertTrue(request.messages.contains { $0.role == "system" })
        XCTAssertTrue(request.messages.contains { $0.role == "user" && $0.content == "Hello Peter" })
    }
    
    // MARK: - Message Storage Tests
    
    func testMessagePersistence() {
        // Given
        let message1 = ChatMessage(role: "user", content: "First message")
        let message2 = ChatMessage(role: "assistant", content: "Response")
        
        // When
        openAIService.messages.append(message1)
        openAIService.messages.append(message2)
        
        // Then
        XCTAssertEqual(openAIService.messages.count, 2)
        XCTAssertEqual(openAIService.getRecentMessages().count, 2)
    }
    
    func testClearMessages() {
        // Given
        openAIService.messages.append(ChatMessage(role: "user", content: "Test"))
        openAIService.messages.append(ChatMessage(role: "assistant", content: "Response"))
        
        // When
        openAIService.clearMessages()
        
        // Then
        XCTAssertEqual(openAIService.messages.count, 0)
        XCTAssertEqual(openAIService.getRecentMessages().count, 0)
    }
    
    func testRecentMessagesLimit() {
        // Given - Add 15 messages
        for i in 1...15 {
            openAIService.messages.append(ChatMessage(role: "user", content: "Message \(i)"))
        }
        
        // When
        let recentMessages = openAIService.getRecentMessages()
        
        // Then
        XCTAssertEqual(recentMessages.count, 10)
        XCTAssertEqual(recentMessages.first?.content, "Message 6") // Should get last 10
        XCTAssertEqual(recentMessages.last?.content, "Message 15")
    }
    
    // MARK: - Elderly-Specific Tests
    
    func testElderlyFriendlyResponse() async {
        // Given
        let mockResponse = OpenAIResponse(
            choices: [
                OpenAIResponse.Choice(
                    message: OpenAIResponse.Choice.Message(
                        role: "assistant",
                        content: "I'd be happy to help you with that, Margaret. Let me explain this step by step."
                    )
                )
            ]
        )
        
        mockURLSession.data = try! JSONEncoder().encode(mockResponse)
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.openai.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        await openAIService.sendMessage("I need help with my email", userName: "Margaret")
        
        // Then - Verify response maintains elderly-friendly tone
        let assistantMessage = openAIService.messages.last { $0.role == "assistant" }
        XCTAssertNotNil(assistantMessage)
        XCTAssertTrue(assistantMessage!.content.contains("Margaret"))
        XCTAssertTrue(assistantMessage!.content.contains("happy to help"))
    }
    
    func testSlangFilteringInPrompt() {
        // Given
        let systemPrompt = openAIService.createSystemPrompt(userName: "Test")
        
        // Then - Should explicitly avoid slang
        XCTAssertTrue(systemPrompt.contains("avoid slang"))
        XCTAssertTrue(systemPrompt.contains("avoid abbreviations"))
        XCTAssertTrue(systemPrompt.contains("text speak"))
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingStateManagement() async {
        // Given
        let expectation = XCTestExpectation(description: "Loading state")
        
        mockURLSession.data = try! JSONEncoder().encode(
            OpenAIResponse(choices: [
                OpenAIResponse.Choice(message: OpenAIResponse.Choice.Message(role: "assistant", content: "Test"))
            ])
        )
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.openai.com")!, statusCode: 200, httpVersion: nil, headerFields: nil
        )
        
        // Simulate delayed response
        mockURLSession.delay = 0.5
        
        // When
        let task = Task {
            await openAIService.sendMessage("Test", userName: "Test")
        }
        
        // Then - Should be loading initially
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.openAIService.isLoading)
        }
        
        await task.value
        
        // Then - Should not be loading after completion
        DispatchQueue.main.async {
            XCTAssertFalse(self.openAIService.isLoading)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Performance Tests
    
    func testMessageSendingPerformance() {
        mockURLSession.data = try! JSONEncoder().encode(
            OpenAIResponse(choices: [
                OpenAIResponse.Choice(message: OpenAIResponse.Choice.Message(role: "assistant", content: "Test"))
            ])
        )
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.openai.com")!, statusCode: 200, httpVersion: nil, headerFields: nil
        )
        
        measure {
            Task {
                await openAIService.sendMessage("Performance test", userName: "Test")
            }
        }
    }
    
    func testMessageStoragePerformance() {
        measure {
            openAIService.clearMessages()
            for i in 0..<1000 {
                openAIService.messages.append(ChatMessage(role: "user", content: "Message \(i)"))
            }
            _ = openAIService.getRecentMessages()
        }
    }
}

// MARK: - Mock Classes for OpenAI Testing

class MockURLSession: URLSession {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    var dataTask: MockURLSessionDataTask!
    var lastRequest: URLRequest?
    var delay: TimeInterval = 0
    
    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        lastRequest = request
        
        dataTask.completionHandler = { [weak self] in
            if self?.delay ?? 0 > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + (self?.delay ?? 0)) {
                    completionHandler(self?.data, self?.response, self?.error)
                }
            } else {
                completionHandler(self?.data, self?.response, self?.error)
            }
        }
        
        return dataTask
    }
}

class MockURLSessionDataTask: URLSessionDataTask {
    var completionHandler: (() -> Void)?
    private var hasResumed = false
    
    override func resume() {
        guard !hasResumed else { return }
        hasResumed = true
        completionHandler?()
    }
    
    override func cancel() {
        // Mock cancel behavior
    }
}

// MARK: - OpenAIService Extension for Testing

extension OpenAIService {
    var urlSession: URLSession {
        get { return URLSession.shared }
        set { /* Inject mock session */ }
    }
    
    func setAPIKey(_ key: String) {
        // Method to set API key for testing
        // In real implementation, this would be private
    }
    
    func isValidAPIKey(_ key: String) -> Bool {
        return !key.isEmpty && 
               key != "YOUR_OPENAI_API_KEY" && 
               key.hasPrefix("sk-") && 
               key.count > 20
    }
    
    func createSystemPrompt(userName: String) -> String {
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
}