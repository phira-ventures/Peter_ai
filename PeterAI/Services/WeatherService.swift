import Foundation
import CoreLocation

struct WeatherData: Codable {
    let location: String
    let temperature: Double
    let condition: String
    let description: String
    let humidity: Int
    let windSpeed: Double
    let feelsLike: Double
    let uvIndex: Int?
    let forecast: [WeatherForecast]?
    
    var temperatureString: String {
        return "\(Int(temperature))°F"
    }
    
    var feelsLikeString: String {
        return "\(Int(feelsLike))°F"
    }
    
    var windSpeedString: String {
        return "\(Int(windSpeed)) mph"
    }
}

struct WeatherForecast: Codable {
    let date: String
    let high: Double
    let low: Double
    let condition: String
    let description: String
    let chanceOfRain: Int
    
    var highString: String {
        return "\(Int(high))°F"
    }
    
    var lowString: String {
        return "\(Int(low))°F"
    }
}

// OpenWeatherMap API Response Models
struct OpenWeatherResponse: Codable {
    let weather: [WeatherCondition]
    let main: MainWeather
    let wind: Wind
    let name: String
    
    struct WeatherCondition: Codable {
        let main: String
        let description: String
    }
    
    struct MainWeather: Codable {
        let temp: Double
        let feelsLike: Double
        let humidity: Int
        
        enum CodingKeys: String, CodingKey {
            case temp
            case feelsLike = "feels_like"
            case humidity
        }
    }
    
    struct Wind: Codable {
        let speed: Double
    }
}

struct OpenWeatherForecastResponse: Codable {
    let list: [ForecastItem]
    let city: City
    
    struct ForecastItem: Codable {
        let dt: TimeInterval
        let main: MainWeather
        let weather: [WeatherCondition]
        let pop: Double // Probability of precipitation
        
        struct MainWeather: Codable {
            let tempMin: Double
            let tempMax: Double
            
            enum CodingKeys: String, CodingKey {
                case tempMin = "temp_min"
                case tempMax = "temp_max"
            }
        }
        
        struct WeatherCondition: Codable {
            let main: String
            let description: String
        }
    }
    
    struct City: Codable {
        let name: String
    }
}

class WeatherService: ObservableObject {
    @Published var currentWeather: WeatherData?
    @Published var isLoading = false
    @Published var error: String?
    
    private var apiKey: String? {
        return SecureStorage.shared.weatherAPIKey
    }
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    
    func getCurrentWeather(for location: String) async {
        await fetchWeather(for: location)
    }
    
    func getWeatherForCoordinates(latitude: Double, longitude: Double) async {
        await fetchWeatherByCoordinates(lat: latitude, lon: longitude)
    }
    
    private func fetchWeather(for location: String) async {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.error = "Weather service not configured"
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        guard let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/weather?q=\(encodedLocation)&appid=\(apiKey)&units=imperial") else {
            DispatchQueue.main.async {
                self.error = "Invalid location"
                self.isLoading = false
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let weatherResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
            
            // Fetch forecast data
            let forecastData = await fetchForecast(for: location)
            
            let weather = WeatherData(
                location: weatherResponse.name,
                temperature: weatherResponse.main.temp,
                condition: weatherResponse.weather.first?.main ?? "Unknown",
                description: weatherResponse.weather.first?.description.capitalized ?? "No description",
                humidity: weatherResponse.main.humidity,
                windSpeed: weatherResponse.wind.speed,
                feelsLike: weatherResponse.main.feelsLike,
                uvIndex: nil, // Would need separate UV API call
                forecast: forecastData
            )
            
            DispatchQueue.main.async {
                self.currentWeather = weather
                self.isLoading = false
            }
            
        } catch {
            DispatchQueue.main.async {
                self.error = "Unable to fetch weather data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func fetchWeatherByCoordinates(lat: Double, lon: Double) async {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            DispatchQueue.main.async {
                self.error = "Weather service not configured"
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }
        
        guard let url = URL(string: "\(baseURL)/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=imperial") else {
            DispatchQueue.main.async {
                self.error = "Invalid coordinates"
                self.isLoading = false
            }
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let weatherResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
            
            let weather = WeatherData(
                location: weatherResponse.name,
                temperature: weatherResponse.main.temp,
                condition: weatherResponse.weather.first?.main ?? "Unknown",
                description: weatherResponse.weather.first?.description.capitalized ?? "No description",
                humidity: weatherResponse.main.humidity,
                windSpeed: weatherResponse.wind.speed,
                feelsLike: weatherResponse.main.feelsLike,
                uvIndex: nil,
                forecast: nil
            )
            
            DispatchQueue.main.async {
                self.currentWeather = weather
                self.isLoading = false
            }
            
        } catch {
            DispatchQueue.main.async {
                self.error = "Unable to fetch weather data: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func fetchForecast(for location: String) async -> [WeatherForecast]? {
        guard let apiKey = apiKey, !apiKey.isEmpty,
              let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/forecast?q=\(encodedLocation)&appid=\(apiKey)&units=imperial") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let forecastResponse = try JSONDecoder().decode(OpenWeatherForecastResponse.self, from: data)
            
            // Group forecast items by day and get daily highs/lows
            let calendar = Calendar.current
            let today = Date()
            
            var dailyForecasts: [WeatherForecast] = []
            var processedDays: Set<String> = []
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE"
            
            for item in forecastResponse.list.prefix(15) { // Next 5 days (3-hour intervals)
                let itemDate = Date(timeIntervalSince1970: item.dt)
                let dayString = dateFormatter.string(from: itemDate)
                
                // Skip today and only process each day once
                if calendar.isDate(itemDate, inSameDayAs: today) || processedDays.contains(dayString) {
                    continue
                }
                
                processedDays.insert(dayString)
                
                // Find all items for this day to get high/low
                let dayItems = forecastResponse.list.filter { forecastItem in
                    calendar.isDate(Date(timeIntervalSince1970: forecastItem.dt), inSameDayAs: itemDate)
                }
                
                let high = dayItems.map { $0.main.tempMax }.max() ?? item.main.tempMax
                let low = dayItems.map { $0.main.tempMin }.min() ?? item.main.tempMin
                let avgPrecipitation = dayItems.map { $0.pop }.reduce(0, +) / Double(dayItems.count)
                
                let forecast = WeatherForecast(
                    date: dayString,
                    high: high,
                    low: low,
                    condition: item.weather.first?.main ?? "Unknown",
                    description: item.weather.first?.description.capitalized ?? "No description",
                    chanceOfRain: Int(avgPrecipitation * 100)
                )
                
                dailyForecasts.append(forecast)
                
                if dailyForecasts.count >= 5 {
                    break
                }
            }
            
            return dailyForecasts
            
        } catch {
            print("Error fetching forecast: \(error)")
            return nil
        }
    }
    
    func getWeatherSummaryForAI(location: String) -> String {
        guard let weather = currentWeather else {
            return "I don't have current weather information. Please try asking again."
        }
        
        var summary = "The weather in \(weather.location) is currently \(weather.description) with a temperature of \(weather.temperatureString). It feels like \(weather.feelsLikeString). "
        
        summary += "The humidity is \(weather.humidity)% and winds are at \(weather.windSpeedString). "
        
        // Add clothing recommendations
        if weather.temperature < 40 {
            summary += "It's quite cold, so make sure to bundle up with warm clothing. "
        } else if weather.temperature < 60 {
            summary += "It's a bit chilly, so you might want to wear a jacket. "
        } else if weather.temperature > 85 {
            summary += "It's quite warm, so light clothing would be comfortable. "
        }
        
        // Add rain recommendations
        if weather.condition.lowercased().contains("rain") || weather.description.lowercased().contains("rain") {
            summary += "Don't forget to bring an umbrella! "
        }
        
        // Add forecast if available
        if let forecast = weather.forecast, !forecast.isEmpty {
            summary += "\nLooking ahead, here's the forecast for the next few days: "
            for (index, day) in forecast.prefix(3).enumerated() {
                if index > 0 { summary += ", " }
                summary += "\(day.date): \(day.description) with highs around \(day.highString) and lows near \(day.lowString)"
                if day.chanceOfRain > 30 {
                    summary += " (\(day.chanceOfRain)% chance of rain)"
                }
            }
        }
        
        return summary
    }
    
    func shouldRecommendUmbrella() -> Bool {
        guard let weather = currentWeather else { return false }
        
        let rainConditions = ["rain", "drizzle", "shower", "thunderstorm"]
        let condition = weather.condition.lowercased()
        let description = weather.description.lowercased()
        
        return rainConditions.contains { condition.contains($0) || description.contains($0) } ||
               weather.forecast?.first(where: { $0.chanceOfRain > 50 }) != nil
    }
    
    func getClothingRecommendation() -> String {
        guard let weather = currentWeather else {
            return "I'd recommend checking the weather before deciding what to wear."
        }
        
        let feelsLike = weather.feelsLike
        let condition = weather.condition.lowercased()
        
        var recommendation = ""
        
        // Temperature-based recommendations
        if feelsLike <= 32 {
            recommendation = "It's freezing! Wear heavy winter clothing, including a warm coat, gloves, and a hat."
        } else if feelsLike <= 50 {
            recommendation = "It's quite cold. A warm jacket or coat would be perfect."
        } else if feelsLike <= 65 {
            recommendation = "It's a bit cool. A light jacket or sweater should be comfortable."
        } else if feelsLike <= 75 {
            recommendation = "The temperature is pleasant. Light layers would work well."
        } else if feelsLike <= 85 {
            recommendation = "It's warm. Light, breathable clothing would be most comfortable."
        } else {
            recommendation = "It's quite hot! Light, loose-fitting clothing and staying hydrated are important."
        }
        
        // Add weather condition specifics
        if condition.contains("rain") || condition.contains("drizzle") {
            recommendation += " Don't forget a raincoat or umbrella!"
        } else if condition.contains("snow") {
            recommendation += " Wear waterproof boots and warm, dry clothing."
        } else if condition.contains("wind") || weather.windSpeed > 15 {
            recommendation += " It's windy, so consider a windproof jacket."
        }
        
        return recommendation
    }
}

// MARK: - Location Manager for GPS-based weather
class LocationWeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocation?
    @Published var locationError: String?
    
    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getCurrentLocationWeather() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationError = "Location services are disabled"
            return
        }
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable in Settings."
        @unknown default:
            locationError = "Unknown location authorization status"
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        userLocation = location
        locationError = nil
        
        Task {
            await weatherService.getWeatherForCoordinates(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationError = "Failed to get location: \(error.localizedDescription)"
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            getCurrentLocationWeather()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable in Settings."
        default:
            break
        }
    }
}