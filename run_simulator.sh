#!/bin/bash

echo "🚀 Launching Enhanced Peter AI in iOS Simulator..."

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
    
    echo "🎉 Enhanced Peter AI is now running with:"
    echo "   📝 6-step onboarding flow"
    echo "   💬 Improved conversation system" 
    echo "   💡 Suggested prompts with categories"
    echo "   ⚙️  Accessibility-focused settings"
    echo "   ❓ Comprehensive help system"
    echo "   🏠 Tabbed navigation interface"
else
    echo "❌ Build failed. Please check the error messages above."
fi