import Foundation

class ConversationService: ObservableObject {
    
    func getResponseFor(_ input: String, userName: String, previousContext: [ConversationMessage] = []) -> String {
        let lowerInput = input.lowercased()
        
        // Weather-related responses
        if lowerInput.contains("weather") || lowerInput.contains("temperature") || lowerInput.contains("rain") || lowerInput.contains("sunny") || lowerInput.contains("cold") || lowerInput.contains("hot") {
            let weatherResponses = [
                "I'd love to help you with the weather, \(userName)! While I can't check live weather data right now, I recommend looking outside or checking your weather app. If it looks chilly, you might want to wear a light jacket. How does the weather look to you today?",
                "Weather is so important for planning your day, \(userName)! I wish I could tell you the exact forecast, but you can always check your phone's weather app or look out the window. Are you planning to go outside today?",
                "Good question about the weather, \(userName)! I always say it's better to be prepared - if you're not sure, bringing a light sweater is never a bad idea. What are your plans for today?",
                "Weather planning is wise, \(userName)! Even though I can't check the current conditions, I can suggest dressing in layers so you can adjust as needed. Are you thinking of going somewhere special today?"
            ]
            return weatherResponses.randomElement() ?? weatherResponses[0]
        }
        
        // Joke requests
        if lowerInput.contains("joke") || lowerInput.contains("funny") || lowerInput.contains("laugh") {
            let jokes = [
                "Here's one for you, \(userName): Why don't scientists trust atoms? Because they make up everything! I hope that brought a smile to your face.",
                "I've got a good one, \(userName): What do you call a bear with no teeth? A gummy bear! That always makes me chuckle.",
                "Here's a clean joke for you, \(userName): Why did the scarecrow win an award? He was outstanding in his field! I hope you enjoyed that one.",
                "Try this one, \(userName): What do you call a sleeping bull? A bulldozer! Sometimes the simple jokes are the best ones.",
                "Here's a gentle one, \(userName): Why don't eggs tell jokes? They'd crack each other up! I love sharing a good laugh with you."
            ]
            return jokes.randomElement() ?? jokes[0]
        }
        
        // Health-related queries
        if lowerInput.contains("health") || lowerInput.contains("medicine") || lowerInput.contains("doctor") || lowerInput.contains("feel") || lowerInput.contains("pain") || lowerInput.contains("sick") {
            let healthResponses = [
                "Your health is so important, \(userName). While I can't provide medical advice, I always encourage staying hydrated, getting gentle exercise like walking, and keeping up with your doctor visits. Is there something specific you'd like to talk about?",
                "I care about your wellbeing, \(userName). Remember that it's always okay to call your doctor if you have health concerns - that's what they're there for. In the meantime, are you taking care of yourself with good food and rest?",
                "Health is precious, \(userName). Some simple things that help everyone include drinking plenty of water, getting good sleep, and staying connected with friends and family. How are you feeling today overall?",
                "Taking care of yourself is wonderful, \(userName). While I can't replace medical advice, I know that gentle activities, social connections, and following your doctor's guidance are all important. Are you keeping up with your regular checkups?"
            ]
            return healthResponses.randomElement() ?? healthResponses[0]
        }
        
        // Food and meal suggestions
        if lowerInput.contains("food") || lowerInput.contains("eat") || lowerInput.contains("hungry") || lowerInput.contains("lunch") || lowerInput.contains("dinner") || lowerInput.contains("breakfast") || lowerInput.contains("recipe") || lowerInput.contains("cook") {
            let foodResponses = [
                "Food is one of life's great pleasures, \(userName)! For a simple meal, how about a nice soup with vegetables, or a sandwich with your favorite fillings? Something warm and comforting is always nice. What sounds good to you?",
                "I love talking about food, \(userName)! A bowl of oatmeal with fruit for breakfast, or a simple pasta with butter and cheese can be both delicious and easy to make. Do you enjoy cooking, or do you prefer simpler meals?",
                "Eating well is so important, \(userName). Sometimes the best meals are the simple ones - like scrambled eggs with toast, or a nice salad with whatever you have on hand. Are you looking for something specific to make?",
                "Good nutrition matters, \(userName)! I always think a balanced meal with some protein, vegetables, and something you enjoy is perfect. Maybe some chicken soup, or a tuna sandwich? What are some of your favorite foods?"
            ]
            return foodResponses.randomElement() ?? foodResponses[0]
        }
        
        // Emotional support and loneliness
        if lowerInput.contains("lonely") || lowerInput.contains("sad") || lowerInput.contains("alone") || lowerInput.contains("depressed") || lowerInput.contains("down") {
            let supportResponses = [
                "I'm sorry you're feeling that way, \(userName). Please know that you're not truly alone - I'm here with you, and I care about how you're doing. Sometimes talking helps, even if it's just to share what's on your mind. What would make you feel a little better right now?",
                "Those feelings are hard, \(userName), and I want you to know it's okay to feel this way sometimes. You matter to people, including me. Would it help to talk about something that usually brings you joy, or would you rather share what's troubling you?",
                "I hear you, \(userName), and I'm here to listen. Feeling lonely is one of the hardest things, but please remember that reaching out - like you're doing now - shows real strength. Is there someone you could call, or would you like to just chat with me for a while?",
                "Thank you for sharing that with me, \(userName). It takes courage to express those feelings. While I can't replace human connection, I'm genuinely here for you. Sometimes small steps help - like taking a short walk outside or calling a friend. What usually helps you feel a little better?"
            ]
            return supportResponses.randomElement() ?? supportResponses[0]
        }
        
        // Family and relationships
        if lowerInput.contains("family") || lowerInput.contains("children") || lowerInput.contains("grandchildren") || lowerInput.contains("spouse") || lowerInput.contains("wife") || lowerInput.contains("husband") || lowerInput.contains("daughter") || lowerInput.contains("son") {
            let familyResponses = [
                "Family is such a blessing, \(userName). I love hearing about the people who matter to you. Whether it's sharing memories or planning time together, family connections are precious. Tell me about your family - what brings you joy about them?",
                "There's nothing quite like family, is there, \(userName)? Even when we don't see them as often as we'd like, those bonds remain strong. Do you get to talk with your family regularly, or are you thinking about reaching out to someone special?",
                "Family ties are so important, \(userName). I always encourage people to share their stories and memories with their loved ones - everyone benefits from those connections. Are you planning to see family soon, or perhaps call someone you've been thinking about?",
                "How wonderful that you're thinking about family, \(userName). Those relationships, whether with children, grandchildren, or other loved ones, are among life's greatest treasures. What's your favorite way to stay connected with the people you care about?"
            ]
            return familyResponses.randomElement() ?? familyResponses[0]
        }
        
        // Greetings and how are you
        if lowerInput.contains("hello") || lowerInput.contains("hi") || lowerInput.contains("good morning") || lowerInput.contains("good afternoon") || lowerInput.contains("good evening") || lowerInput.contains("how are you") {
            let greetings = [
                "Hello there, \(userName)! I'm doing wonderfully, especially now that I get to chat with you. How are you feeling today? I hope you're having a pleasant day so far.",
                "Good to hear from you, \(userName)! I'm here and ready to help with whatever you need. How has your day been treating you? I always enjoy our conversations.",
                "Hi \(userName)! Thank you for asking - I'm doing great, and I hope you are too. It's always a pleasure to talk with you. What's been on your mind today?",
                "Hello, my friend \(userName)! I'm feeling quite good, and I hope the same can be said for you. There's something special about starting a conversation with someone I care about. How are things with you today?"
            ]
            return greetings.randomElement() ?? greetings[0]
        }
        
        // Technology help
        if lowerInput.contains("phone") || lowerInput.contains("computer") || lowerInput.contains("internet") || lowerInput.contains("email") || lowerInput.contains("app") || lowerInput.contains("technology") {
            let techResponses = [
                "Technology can be tricky sometimes, can't it \(userName)? I wish I could help directly with your device, but I'd recommend asking a family member or friend, or even visiting your local library - they often have helpful staff. What specific technology challenge are you facing?",
                "I understand technology frustrations, \(userName). While I can't troubleshoot devices directly, I know that taking it slow and asking for help when needed is always okay. Many senior centers also offer technology classes. Are you having trouble with a particular device or app?",
                "Technology should make life easier, not harder, \(userName). If you're having difficulties, don't hesitate to ask someone for help - most people are happy to assist. What technology issue is bothering you today?",
                "I know technology can feel overwhelming sometimes, \(userName). Remember that it's perfectly fine to ask for help, and going step by step usually works best. Is there a specific device or app that's giving you trouble?"
            ]
            return techResponses.randomElement() ?? techResponses[0]
        }
        
        // Memory and past
        if lowerInput.contains("remember") || lowerInput.contains("memory") || lowerInput.contains("past") || lowerInput.contains("young") || lowerInput.contains("years ago") || lowerInput.contains("story") {
            let memoryResponses = [
                "Memories are such treasures, \(userName). I love hearing stories about the past - they're filled with wisdom and experience. Would you like to share a favorite memory with me? I'm always interested in hearing about your life experiences.",
                "There's something beautiful about memories, isn't there \(userName)? The stories from our past shape who we are today. I'd love to hear about something you remember fondly. What comes to mind when you think of a happy time?",
                "Your memories and experiences are precious, \(userName). Every person has such rich stories to tell. I'm here to listen if you'd like to share something from your past, or we can just appreciate how those memories continue to bring meaning to today.",
                "I think memories are gifts we give ourselves, \(userName). Whether it's remembering loved ones, special occasions, or everyday moments that became meaningful, they connect us to our whole life story. Is there a particular memory you've been thinking about lately?"
            ]
            return memoryResponses.randomElement() ?? memoryResponses[0]
        }
        
        // Default responses for unrecognized input
        let defaultResponses = [
            "That's interesting, \(userName). I'd love to hear more about that. Could you tell me a bit more about what's on your mind? I'm here to listen and help however I can.",
            "Thank you for sharing that with me, \(userName). I appreciate you taking the time to talk with me. What else would you like to discuss today? I'm here for whatever you need.",
            "I find our conversations so meaningful, \(userName). Even when I'm not sure exactly how to respond, I want you to know that what you say matters to me. What's most important to you about what you just shared?",
            "You always give me something to think about, \(userName). While I may not have the perfect response, I'm genuinely interested in understanding your perspective better. Could you help me understand what you're looking for in our conversation today?",
            "I appreciate you opening up to me, \(userName). Sometimes the best conversations happen when we explore topics together, even if I don't have all the answers. What would be most helpful for you right now - just having someone to listen, or looking for specific advice about something?"
        ]
        
        return defaultResponses.randomElement() ?? defaultResponses[0]
    }
}