import SwiftUI

// MARK: - Data Models

struct CurrentWeather {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    let weatherCode: Int
    let isDay: Bool
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let maxTemp: Double
    let minTemp: Double
    let weatherCode: Int
}

// MARK: - Weather Service

class WeatherService: ObservableObject {
    @Published var current: CurrentWeather?
    @Published var forecast: [DailyForecast] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    // Nanjing coordinates
    private let latitude = 32.0603
    private let longitude = 118.7969

    func fetchWeather() {
        isLoading = true
        errorMessage = nil

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=Asia%2FShanghai&forecast_days=5"

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                    return
                }

                guard let data = data else {
                    self?.errorMessage = "No data received"
                    self?.isLoading = false
                    return
                }

                self?.parseWeatherData(data)
                self?.isLoading = false
            }
        }.resume()
    }

    private func parseWeatherData(_ data: Data) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                errorMessage = "Invalid JSON"
                return
            }

            // Parse current weather
            if let currentData = json["current"] as? [String: Any] {
                current = CurrentWeather(
                    temperature: currentData["temperature_2m"] as? Double ?? 0,
                    apparentTemperature: currentData["apparent_temperature"] as? Double ?? 0,
                    humidity: currentData["relative_humidity_2m"] as? Int ?? 0,
                    windSpeed: currentData["wind_speed_10m"] as? Double ?? 0,
                    weatherCode: currentData["weather_code"] as? Int ?? 0,
                    isDay: (currentData["is_day"] as? Int ?? 1) == 1
                )
            }

            // Parse daily forecast
            if let dailyData = json["daily"] as? [String: Any],
               let dates = dailyData["time"] as? [String],
               let maxTemps = dailyData["temperature_2m_max"] as? [Double],
               let minTemps = dailyData["temperature_2m_min"] as? [Double],
               let codes = dailyData["weather_code"] as? [Int] {

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")

                forecast = zip(dates, zip(maxTemps, zip(minTemps, codes))).compactMap { dateStr, rest in
                    guard let date = dateFormatter.date(from: dateStr) else { return nil }
                    return DailyForecast(
                        date: date,
                        maxTemp: rest.0,
                        minTemp: rest.1.0,
                        weatherCode: rest.1.1
                    )
                }
            }
        } catch {
            errorMessage = "Parse error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Weather Helpers

struct WeatherInfo {
    let description: String
    let icon: String // SF Symbol name

    static func from(code: Int, isDay: Bool = true) -> WeatherInfo {
        switch code {
        case 0:
            return WeatherInfo(description: "Clear Sky", icon: isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1:
            return WeatherInfo(description: "Mostly Clear", icon: isDay ? "sun.min.fill" : "moon.fill")
        case 2:
            return WeatherInfo(description: "Partly Cloudy", icon: isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3:
            return WeatherInfo(description: "Overcast", icon: "cloud.fill")
        case 45, 48:
            return WeatherInfo(description: "Foggy", icon: "cloud.fog.fill")
        case 51, 53, 55:
            return WeatherInfo(description: "Drizzle", icon: "cloud.drizzle.fill")
        case 56, 57:
            return WeatherInfo(description: "Freezing Drizzle", icon: "cloud.sleet.fill")
        case 61, 63, 65:
            return WeatherInfo(description: "Rain", icon: "cloud.rain.fill")
        case 66, 67:
            return WeatherInfo(description: "Freezing Rain", icon: "cloud.sleet.fill")
        case 71, 73, 75:
            return WeatherInfo(description: "Snowfall", icon: "cloud.snow.fill")
        case 77:
            return WeatherInfo(description: "Snow Grains", icon: "cloud.snow.fill")
        case 80, 81, 82:
            return WeatherInfo(description: "Rain Showers", icon: "cloud.heavyrain.fill")
        case 85, 86:
            return WeatherInfo(description: "Snow Showers", icon: "cloud.snow.fill")
        case 95:
            return WeatherInfo(description: "Thunderstorm", icon: "cloud.bolt.rain.fill")
        case 96, 99:
            return WeatherInfo(description: "Thunderstorm w/ Hail", icon: "cloud.bolt.fill")
        default:
            return WeatherInfo(description: "Unknown", icon: "questionmark.circle.fill")
        }
    }
}

// MARK: - Background Gradient

extension LinearGradient {
    static func weatherGradient(isDay: Bool, weatherCode: Int) -> LinearGradient {
        let colors: [Color]
        if !isDay {
            colors = [
                Color(red: 0.05, green: 0.05, blue: 0.2),
                Color(red: 0.1, green: 0.1, blue: 0.35),
                Color(red: 0.15, green: 0.12, blue: 0.4)
            ]
        } else {
            switch weatherCode {
            case 0, 1:
                colors = [
                    Color(red: 0.15, green: 0.55, blue: 0.95),
                    Color(red: 0.3, green: 0.7, blue: 1.0),
                    Color(red: 0.55, green: 0.85, blue: 1.0)
                ]
            case 2, 3:
                colors = [
                    Color(red: 0.35, green: 0.45, blue: 0.6),
                    Color(red: 0.5, green: 0.6, blue: 0.75),
                    Color(red: 0.65, green: 0.75, blue: 0.85)
                ]
            case 61...82:
                colors = [
                    Color(red: 0.2, green: 0.25, blue: 0.4),
                    Color(red: 0.3, green: 0.38, blue: 0.55),
                    Color(red: 0.4, green: 0.5, blue: 0.65)
                ]
            case 95, 96, 99:
                colors = [
                    Color(red: 0.12, green: 0.12, blue: 0.25),
                    Color(red: 0.2, green: 0.2, blue: 0.35),
                    Color(red: 0.3, green: 0.28, blue: 0.4)
                ]
            default:
                colors = [
                    Color(red: 0.2, green: 0.5, blue: 0.85),
                    Color(red: 0.35, green: 0.65, blue: 0.95),
                    Color(red: 0.5, green: 0.78, blue: 1.0)
                ]
            }
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Main View

struct WeatherHomeView: View {
    @StateObject private var weatherService = WeatherService()
    @State private var animateContent = false

    var body: some View {
        ZStack {
            // Dynamic background
            backgroundGradient
                .ignoresSafeArea()

            if weatherService.isLoading {
                loadingView
            } else if let error = weatherService.errorMessage {
                errorView(error)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header / Current weather
                        currentWeatherSection
                            .padding(.top, 60)

                        // Detail cards row
                        detailCardsSection
                            .padding(.top, 28)

                        // 5-Day Forecast
                        forecastSection
                            .padding(.top, 28)
                            .padding(.bottom, 50)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            weatherService.fetchWeather()
            withAnimation(.easeOut(duration: 1.0)) {
                animateContent = true
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        Group {
            if let current = weatherService.current {
                LinearGradient.weatherGradient(isDay: current.isDay, weatherCode: current.weatherCode)
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.55, blue: 0.95),
                        Color(red: 0.3, green: 0.7, blue: 1.0),
                        Color(red: 0.55, green: 0.85, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
            Text("Fetching Nanjing Weather…")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.7))
            Text("Unable to Load Weather")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Text(message)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                weatherService.fetchWeather()
            } label: {
                Text("Retry")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    // MARK: - Current Weather Section

    private var currentWeatherSection: some View {
        VStack(spacing: 8) {
            // Location
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14))
                Text("Nanjing, China")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.85))
            .offset(y: animateContent ? 0 : -20)
            .opacity(animateContent ? 1 : 0)

            if let current = weatherService.current {
                let info = WeatherInfo.from(code: current.weatherCode, isDay: current.isDay)

                // Weather icon
                Image(systemName: info.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.3), radius: 12, x: 0, y: 4)
                    .padding(.top, 12)
                    .scaleEffect(animateContent ? 1 : 0.5)
                    .opacity(animateContent ? 1 : 0)

                // Temperature
                Text("\(Int(current.temperature))°")
                    .font(.system(size: 96, weight: .thin, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    .offset(y: animateContent ? 0 : 30)
                    .opacity(animateContent ? 1 : 0)

                // Condition
                Text(info.description)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)

                // Feels like
                Text("Feels like \(Int(current.apparentTemperature))°")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Detail Cards

    private var detailCardsSection: some View {
        Group {
            if let current = weatherService.current {
                HStack(spacing: 12) {
                    detailCard(icon: "humidity.fill", title: "Humidity", value: "\(current.humidity)%")
                    detailCard(icon: "wind", title: "Wind", value: String(format: "%.1f km/h", current.windSpeed))
                    detailCard(icon: "thermometer.medium", title: "Feels Like", value: "\(Int(current.apparentTemperature))°")
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
            }
        }
    }

    private func detailCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.8))

            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.55))

            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - 5 Day Forecast Section

    private var forecastSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Label {
                Text("5-DAY FORECAST")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            } icon: {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
            }
            .foregroundColor(.white.opacity(0.55))
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider()
                .background(.white.opacity(0.15))
                .padding(.horizontal, 16)

            // Forecast rows
            ForEach(Array(weatherService.forecast.enumerated()), id: \.element.id) { index, day in
                forecastRow(day: day, isLast: index == weatherService.forecast.count - 1)
            }
        }
        .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 30)
    }

    private func forecastRow(day: DailyForecast, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                // Day name
                Text(dayName(from: day.date))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 90, alignment: .leading)

                Spacer()

                // Weather icon
                Image(systemName: WeatherInfo.from(code: day.weatherCode).icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36)

                Spacer()

                // Temperature range bar
                temperatureBar(min: day.minTemp, max: day.maxTemp)

                // High / Low
                HStack(spacing: 4) {
                    Text("\(Int(day.minTemp))°")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 34, alignment: .trailing)

                    Text("\(Int(day.maxTemp))°")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 34, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .background(.white.opacity(0.1))
                    .padding(.horizontal, 16)
            }
        }
    }

    private func temperatureBar(min: Double, max: Double) -> some View {
        // Determine the overall range from all forecasts
        let allMin = weatherService.forecast.map(\.minTemp).min() ?? min
        let allMax = weatherService.forecast.map(\.maxTemp).max() ?? max
        let range = allMax - allMin
        let safeDenom = range == 0 ? 1.0 : range

        let startFraction = (min - allMin) / safeDenom
        let endFraction = (max - allMin) / safeDenom

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(.white.opacity(0.1))
                    .frame(height: 4)

                // Filled portion
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.3, green: 0.75, blue: 1.0),
                                Color(red: 1.0, green: 0.75, blue: 0.25)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: max(4, geo.size.width * (endFraction - startFraction)),
                        height: 4
                    )
                    .offset(x: geo.size.width * startFraction)
            }
        }
        .frame(width: 80, height: 4)
    }

    // MARK: - Helpers

    private func dayName(from date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    WeatherHomeView()
}
