import SwiftUI
import Speech
import AVFoundation

// Enhanced main app with tabbed interface
struct MainAppView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    Image(systemName: "message.circle.fill")
                    Text("Chat")
                }
                .tag(0)
            
            SuggestedPromptsView()
                .tabItem {
                    Image(systemName: "lightbulb.circle.fill")
                    Text("Ideas")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear.circle.fill")
                    Text("Settings")
                }
                .tag(2)
            
            HelpView()
                .tabItem {
                    Image(systemName: "questionmark.circle.fill")
                    Text("Help")
                }
                .tag(3)
        }
        .accentColor(.blue)
        .font(.title2)
    }
}

struct ContentView: View {
    @AppStorage("user_name") private var userName = "friend"
    @AppStorage("auto_speak") private var autoSpeak = true
    @State private var message = ""
    @State private var typedMessage = ""
    @State private var conversationHistory: [ConversationMessage] = []
    @State private var currentTopic: ConversationTopic = .greeting
    @State private var showingPermissionAlert = false
    
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var ttsService = TextToSpeechService()
    @StateObject private var conversationService = ConversationService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with Peter
                VStack(spacing: 15) {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text("👴🏻")
                                .font(.system(size: 50))
                        )
                    
                    Text("Hi \(userName)! I'm Peter")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                }
                .padding(.top)
                
                // Conversation Area
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if conversationHistory.isEmpty {
                            // Welcome message
                            MessageBubble(
                                message: ConversationMessage(
                                    text: getWelcomeMessage(),
                                    isFromUser: false,
                                    timestamp: Date()
                                ),
                                userName: userName
                            )
                        }
                        
                        ForEach(conversationHistory) { message in
                            MessageBubble(message: message, userName: userName)
                        }
                    }
                    .padding(.horizontal)
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                Spacer()
                
                // Quick action buttons
                if !speechService.isRecording {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(getQuickActions(), id: \.self) { action in
                                Button(action) {
                                    handleQuickAction(action)
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(20)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Text input field
                HStack(spacing: 12) {
                    TextField("Type your message here...", text: $typedMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .disabled(speechService.isRecording)
                        .onSubmit {
                            if !typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                sendMessage(typedMessage)
                                typedMessage = ""
                            }
                        }
                    
                    Button("Send") {
                        if !typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            sendMessage(typedMessage)
                            typedMessage = ""
                        }
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(20)
                    .disabled(typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                
                // Voice Button
                Button(action: {
                    if !speechService.isAuthorized {
                        showingPermissionAlert = true
                    } else {
                        speechService.toggleRecording()
                    }
                }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(speechService.isRecording ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)
                                .scaleEffect(speechService.isRecording ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.3), value: speechService.isRecording)
                            
                            if speechService.isRecording {
                                // Animated recording waves
                                ForEach(0..<3) { i in
                                    Circle()
                                        .stroke(Color.red.opacity(0.4), lineWidth: 2)
                                        .frame(width: CGFloat(100 + i * 20), height: CGFloat(100 + i * 20))
                                        .scaleEffect(speechService.isRecording ? 1.2 : 0.8)
                                        .animation(.easeInOut(duration: 1.5).repeatForever().delay(Double(i) * 0.2), value: speechService.isRecording)
                                }
                            }
                            
                            Image(systemName: speechService.isRecording ? "waveform" : "mic.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        
                        Text(speechService.isRecording ? "Listening..." : "Hold to Speak")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(speechService.isRecording ? .red : .blue)
                        
                        if !speechService.recognizedText.isEmpty {
                            Text(speechService.recognizedText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("Peter AI")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if message.isEmpty {
                message = getWelcomeMessage()
            }
        }
        .onChange(of: speechService.recognizedText) { _, newText in
            if !speechService.isRecording && !newText.isEmpty {
                sendMessage(newText)
                speechService.recognizedText = ""
            }
        }
        .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Peter AI needs microphone permission to hear your voice. Please enable it in Settings > Privacy & Security > Microphone.")
        }
    }
    
    private func getWelcomeMessage() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        
        return "\(timeGreeting), \(userName)! I'm Peter, and I'm here to help you today. What would you like to talk about?"
    }
    
    private func getQuickActions() -> [String] {
        switch currentTopic {
        case .greeting:
            return ["Weather", "How are you?", "Tell me a joke", "Health tips"]
        case .weather:
            return ["Tomorrow's weather", "Weekly forecast", "What to wear?", "Different topic"]
        case .health:
            return ["Exercise tips", "Healthy recipes", "Sleep advice", "Doctor questions"]
        case .general:
            return ["News", "Cooking", "Family", "Hobbies"]
        }
    }
    
    private func sendMessage(_ messageText: String) {
        let userMsg = ConversationMessage(text: messageText, isFromUser: true, timestamp: Date())
        conversationHistory.append(userMsg)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let response = conversationService.getResponseFor(messageText, userName: userName, previousContext: conversationHistory)
            let peterMsg = ConversationMessage(text: response, isFromUser: false, timestamp: Date())
            conversationHistory.append(peterMsg)
            updateTopic(for: messageText)
            
            // Speak the response if auto-speak is enabled
            if autoSpeak {
                ttsService.speak(response)
            }
        }
    }
    
    private func handleQuickAction(_ action: String) {
        sendMessage(action)
    }
    
    
    private func updateTopic(for input: String) {
        let lowerInput = input.lowercased()
        
        if lowerInput.contains("weather") {
            currentTopic = .weather
        } else if lowerInput.contains("health") {
            currentTopic = .health
        } else {
            currentTopic = .general
        }
    }
}

struct ConversationMessage: Identifiable {
    let id = UUID()
    let text: String
    let isFromUser: Bool
    let timestamp: Date
}

struct MessageBubble: View {
    let message: ConversationMessage
    let userName: String
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 50)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .font(.body)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("👴🏻")
                            .font(.title3)
                        
                        Text(message.text)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(18)
                            .font(.body)
                    }
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 36)
                }
                Spacer(minLength: 50)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

enum ConversationTopic {
    case greeting, weather, health, general
}

#Preview {
    MainAppView()
}