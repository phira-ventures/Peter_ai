#!/bin/bash

echo "🚀 Launching Enhanced Peter AI with REAL VOICE RECOGNITION..."

# Build and run the app in the simulator
xcodebuild -project PeterAI.xcodeproj \
           -scheme PeterAI \
           -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' \
           build

if [ $? -eq 0 ]; then
    echo "✅ Build successful! Opening Simulator..."
    
    # Install and launch the app
    xcrun simctl install booted "/Users/Abraham/Library/Developer/Xcode/DerivedData/PeterAI-cjzpowpqoujvcdctztebghzdqmjd/Build/Products/Debug-iphonesimulator/PeterAI.app"
    xcrun simctl launch booted com.phira.peterai
    
    echo "🎉 Enhanced Peter AI is now running with FULL VOICE CAPABILITIES:"
    echo ""
    echo "NEW VOICE FEATURES:"
    echo "   🎤 Real iOS Speech Recognition (not simulation!)"  
    echo "   🔊 Text-to-Speech with elderly-friendly voice settings"
    echo "   📱 Microphone permission handling with user-friendly alerts"
    echo "   🎯 Live voice-to-text conversion with visual feedback"
    echo "   ⚡ Animated recording indicators with sound waves"
    echo ""
    echo "ENHANCED INTERACTION:"
    echo "   ⌨️  Text input field for typing messages"
    echo "   📝 Send button with smart enable/disable"
    echo "   💬 Dual input modes: voice OR text"
    echo "   🎨 Beautiful visual feedback during recording"
    echo "   🔄 Real-time speech recognition display"
    echo ""
    echo "IMPROVED CONVERSATION:"
    echo "   🧠 Expanded response database with 50+ varied responses"
    echo "   🎯 Context-aware responses based on conversation topics"
    echo "   👥 Personalized responses using user's name"
    echo "   💝 Emotional support and empathetic responses"
    echo "   🏥 Health, family, technology, and memory discussions"
    echo ""
    echo "PREVIOUS FEATURES STILL INCLUDED:"
    echo "   📝 6-step elderly-friendly onboarding"
    echo "   💡 Categorized suggested prompts" 
    echo "   ⚙️  Comprehensive accessibility settings"
    echo "   ❓ Detailed help system with troubleshooting"
    echo "   🏠 Tabbed navigation interface"
    echo ""
    echo "🔥 This is now a FULLY FUNCTIONAL voice-enabled AI assistant!"
else
    echo "❌ Build failed. Please check the error messages above."
fi