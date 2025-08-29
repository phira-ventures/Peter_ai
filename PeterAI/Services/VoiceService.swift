import Foundation
import Speech
import AVFoundation

class VoiceService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var isListening = false
    @Published var recordingError: String?
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let synthesizer = AVSpeechSynthesizer()
    
    // Thread safety
    private let voiceQueue = DispatchQueue(label: "com.peterai.voice", qos: .userInitiated)
    private var isDestroyed = false
    
    override init() {
        super.init()
        setupAudioSession()
        requestPermissions()
        configureSynthesizer()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    self.recordingError = "Speech recognition not authorized"
                @unknown default:
                    self.recordingError = "Unknown authorization status"
                }
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.recordingError = "Microphone access not granted"
                }
            }
        }
    }
    
    private func configureSynthesizer() {
        synthesizer.delegate = self
    }
    
    func startRecording() {
        voiceQueue.async { [weak self] in
            guard let self = self, !self.isDestroyed else { return }
            
            DispatchQueue.main.async {
                guard !self.isRecording else { return }
                
                if self.audioEngine.isRunning {
                    self.stopRecording()
                    return
                }
                
                do {
                    try self.startSpeechRecognition()
                } catch {
                    self.recordingError = "Failed to start recording: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func stopRecording() {
        voiceQueue.async { [weak self] in
            guard let self = self, !self.isDestroyed else { return }
            
            DispatchQueue.main.async {
                if self.audioEngine.isRunning {
                    self.audioEngine.stop()
                }
                
                // Safely remove tap
                if self.audioEngine.inputNode.numberOfInputs > 0 {
                    self.audioEngine.inputNode.removeTap(onBus: 0)
                }
                
                self.recognitionRequest?.endAudio()
                self.recognitionRequest = nil
                self.recognitionTask?.cancel()
                self.recognitionTask = nil
                
                self.isRecording = false
                self.isListening = false
            }
        }
    }
    
    private func startSpeechRecognition() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        isListening = true
        transcribedText = ""
        recordingError = nil
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                    if result.isFinal {
                        self?.stopRecording()
                    }
                }
                
                if let error = error {
                    self?.recordingError = error.localizedDescription
                    self?.stopRecording()
                }
            }
        }
    }
    
    func speak(_ text: String, rate: Float? = nil, accessibilityService: AccessibilityService? = nil) {
        let utterance = AVSpeechUtterance(string: text)
        
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        
        // Use accessibility service rate if provided, otherwise use default elderly-friendly rate
        if let service = accessibilityService {
            utterance.rate = rate ?? service.getVoiceOverRate()
        } else {
            utterance.rate = rate ?? 0.35 // Slower default for elderly users
        }
        
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    deinit {
        isDestroyed = true
        stopRecording()
        stopSpeaking()
    }
}

extension VoiceService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        
    }
}