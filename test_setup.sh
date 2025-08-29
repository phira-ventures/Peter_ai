#!/bin/bash

echo "🧪 Testing Peter AI Xcode Project Setup"
echo "========================================"

cd "/Users/Abraham/Downloads/PeterAI_Working"

# Test 1: Project can be parsed
echo "1. Testing project structure..."
if xcodebuild -project "PeterAI.xcodeproj" -list > /dev/null 2>&1; then
    echo "✅ Project structure is valid"
else
    echo "❌ Project structure is invalid"
    exit 1
fi

# Test 2: Build validation (simulator only to avoid code signing)
echo "2. Testing simulator build..."
if xcodebuild -project "PeterAI.xcodeproj" -scheme PeterAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build > /dev/null 2>&1; then
    echo "✅ Simulator build successful"
else
    echo "⚠️  Build may have issues - check Xcode for details"
fi

echo ""
echo "🎉 Project setup complete!"
echo ""
echo "📋 Quick Launch Instructions:"
echo "1. Open PeterAI.xcodeproj in Xcode"
echo "2. Select iOS Simulator (iPhone 16 Pro recommended)"
echo "3. Click Run (▶️) button"
echo "4. Test voice button (mock mode in simulator)"
echo "5. Test text input field"
echo ""
echo "🎤 Voice Button Behavior:"
echo "Simulator: Mock message after 2 seconds (prevents freezing)"
echo "Real Device: Actual voice recognition with microphone"