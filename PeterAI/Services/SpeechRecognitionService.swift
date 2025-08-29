import Foundation
import Speech
import AVFoundation

class SpeechRecognitionService: ObservableObject {
    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var recognizedText = ""
    @Published var errorMessage = ""
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        checkPermissions()
    }
    
    func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.isAuthorized = true
                    self?.requestMicrophonePermission()
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                    self?.errorMessage = "Speech recognition access denied. Please enable it in Settings."
                @unknown default:
                    self?.isAuthorized = false
                }
            }
        }
    }
    
    private func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if !granted {
                        self?.errorMessage = "Microphone access denied. Please enable it in Settings."
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if !granted {
                        self?.errorMessage = "Microphone access denied. Please enable it in Settings."
                    }
                }
            }
        }
    }
    
    func startRecording() {
        guard isAuthorized else {
            errorMessage = "Speech recognition not authorized"
            return
        }
        
        // Simulator fallback mode to prevent freezing
        #if targetEnvironment(simulator)
        // In simulator, provide mock response after delay
        isRecording = true
        errorMessage = ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.recognizedText = "This is a simulator test message"
            self.stopRecording()
        }
        #else
        // Real device: Actual voice recognition
        // Cancel any existing task
        stopRecording()
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement)
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Audio session setup failed: \(error.localizedDescription)"
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Could not create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Get audio input node
        let inputNode = audioEngine.inputNode
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var isFinal = false
            
            if let result = result {
                DispatchQueue.main.async {
                    self?.recognizedText = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                DispatchQueue.main.async {
                    self?.stopRecording()
                }
            }
        }
        
        // Configure audio format and install tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Use the input node's format directly, but ensure it's valid for speech recognition
        let format: AVAudioFormat
        if recordingFormat.channelCount == 1 && recordingFormat.sampleRate >= 16000 {
            // Use existing format if it's already suitable
            format = recordingFormat
        } else {
            // Create a standard format for speech recognition
            guard let standardFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16000,
                channels: 1,
                interleaved: false
            ) else {
                errorMessage = "Could not create valid audio format"
                return
            }
            format = standardFormat
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            errorMessage = ""
        } catch {
            errorMessage = "Audio engine failed to start: \(error.localizedDescription)"
            stopRecording() // Clean up on failure
        }
        #endif
    }
    
    func stopRecording() {
        isRecording = false
        
        // Simulator: Simple cleanup
        #if targetEnvironment(simulator)
        // No audio engine cleanup needed in simulator
        #else
        // Real device: Full audio cleanup
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Could not deactivate audio session: \(error.localizedDescription)")
        }
        #endif
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            recognizedText = ""
            startRecording()
        }
    }
}