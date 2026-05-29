import SwiftUI

// MARK: - Data Models

struct CurrentWeather {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    let weatherCode: Int
    let isDay: Bool
    let uvIndex: Double
    let visibility: Double
    let pressure: Double
}

struct HourlyForecast: Identifiable {
    let id = UUID()
    let time: Date
    let temperature: Double
    let weatherCode: Int
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let maxTemp: Double
    let minTemp: Double
    let weatherCode: Int
    let sunrise: Date?
    let sunset: Date?
}

// MARK: - Weather Service

class WeatherService: ObservableObject {
    @Published var current: CurrentWeather?
    @Published var forecast: [DailyForecast] = []
    @Published var hourly: [HourlyForecast] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let latitude = 32.0603
    private let longitude = 118.7969

    func fetchWeather() {
        isLoading = true
        errorMessage = nil

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,is_day,uv_index,visibility,surface_pressure&hourly=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&timezone=Asia%2FShanghai&forecast_days=7&forecast_hours=24"

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
                self?.lastUpdated = Date()
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
                    isDay: (currentData["is_day"] as? Int ?? 1) == 1,
                    uvIndex: currentData["uv_index"] as? Double ?? 0,
                    visibility: currentData["visibility"] as? Double ?? 0,
                    pressure: currentData["surface_pressure"] as? Double ?? 0
                )
            }

            // Parse hourly forecast
            if let hourlyData = json["hourly"] as? [String: Any],
               let times = hourlyData["time"] as? [String],
               let temps = hourlyData["temperature_2m"] as? [Double],
               let codes = hourlyData["weather_code"] as? [Int] {

                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
                dateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")

                hourly = zip(times, zip(temps, codes)).compactMap { timeStr, rest in
                    guard let date = dateFormatter.date(from: timeStr) else { return nil }
                    return HourlyForecast(time: date, temperature: rest.0, weatherCode: rest.1)
                }
            }

            // Parse daily forecast
            if let dailyData = json["daily"] as? [String: Any],
               let dates = dailyData["time"] as? [String],
               let maxTemps = dailyData["temperature_2m_max"] as? [Double],
               let minTemps = dailyData["temperature_2m_min"] as? [Double],
               let codes = dailyData["weather_code"] as? [Int],
               let sunrises = dailyData["sunrise"] as? [String],
               let sunsets = dailyData["sunset"] as? [String] {

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                dateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")

                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
                isoFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")

                forecast = (0..<dates.count).compactMap { i in
                    guard let date = dateFormatter.date(from: dates[i]) else { return nil }
                    let sunrise = isoFormatter.date(from: sunrises[i])
                    let sunset = isoFormatter.date(from: sunsets[i])
                    return DailyForecast(
                        date: date,
                        maxTemp: maxTemps[i],
                        minTemp: minTemps[i],
                        weatherCode: codes[i],
                        sunrise: sunrise,
                        sunset: sunset
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
    let icon: String

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

// MARK: - Floating Particles View

struct WeatherParticlesView: View {
    let weatherCode: Int
    let isDay: Bool
    @State private var particles: [Particle] = []
    @State private var timer: Timer?

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var opacity: Double
        var size: CGFloat
        var speed: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { particle in
                particleView
                    .frame(width: particle.size, height: particle.size)
                    .position(x: particle.x, y: particle.y)
                    .opacity(particle.opacity)
            }
        }
        .onAppear { startParticles() }
        .onDisappear { timer?.invalidate() }
    }

    private var particleView: some View {
        Group {
            if weatherCode >= 61 && weatherCode <= 82 {
                // Rain drops
                Capsule()
                    .fill(.white.opacity(0.4))
            } else if weatherCode >= 71 && weatherCode <= 86 {
                // Snow
                Circle()
                    .fill(.white.opacity(0.6))
            } else if !isDay {
                // Stars at night
                Circle()
                    .fill(.white.opacity(0.8))
            } else {
                // Subtle floating particles for clear day
                Circle()
                    .fill(.white.opacity(0.2))
            }
        }
    }

    private func startParticles() {
        // Generate initial particles
        particles = (0..<20).map { _ in
            Particle(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: 0...UIScreen.main.bounds.height),
                opacity: Double.random(in: 0.1...0.6),
                size: CGFloat.random(in: 2...5),
                speed: CGFloat.random(in: 0.5...2.0)
            )
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                for i in particles.indices {
                    particles[i].y += particles[i].speed
                    if weatherCode >= 61 && weatherCode <= 82 {
                        particles[i].x += CGFloat.random(in: -0.3...0.3)
                    } else {
                        particles[i].x += CGFloat.random(in: -0.5...0.5)
                    }
                    // Reset when off screen
                    if particles[i].y > UIScreen.main.bounds.height + 20 {
                        particles[i].y = -10
                        particles[i].x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
                    }
                }
            }
        }
    }
}

// MARK: - Main View

struct WeatherHomeView: View {
    @StateObject private var weatherService = WeatherService()
    @State private var animateContent = false
    @State private var showRefreshIndicator = false

    var body: some View {
        ZStack {
            // Dynamic background
            backgroundGradient
                .ignoresSafeArea()

            // Animated particles overlay
            if let current = weatherService.current {
                WeatherParticlesView(weatherCode: current.weatherCode, isDay: current.isDay)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if weatherService.isLoading && weatherService.current == nil {
                loadingView
            } else if let error = weatherService.errorMessage, weatherService.current == nil {
                errorView(error)
            } else {
                mainContent
            }
        }
        .onAppear {
            weatherService.fetchWeather()
            withAnimation(.easeOut(duration: 1.0)) {
                animateContent = true
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Pull to refresh indicator
                refreshHeader

                // Current weather
                currentWeatherSection
                    .padding(.top, 40)

                // Hourly forecast
                hourlyForecastSection
                    .padding(.top, 28)

                // Detail grid
                detailGridSection
                    .padding(.top, 20)

                // Sunrise/Sunset
                sunriseSunsetSection
                    .padding(.top, 20)

                // 7-Day Forecast
                forecastSection
                    .padding(.top, 20)
                    .padding(.bottom, 50)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Refresh Header

    private var refreshHeader: some View {
        VStack(spacing: 4) {
            if let lastUpdated = weatherService.lastUpdated {
                Text("Updated \(timeAgo(from: lastUpdated))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }

            Button {
                withAnimation(.spring()) { showRefreshIndicator = true }
                weatherService.fetchWeather()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.spring()) { showRefreshIndicator = false }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .rotationEffect(.degrees(showRefreshIndicator ? 360 : 0))
                    .animation(.easeInOut(duration: 1.0), value: showRefreshIndicator)
            }
        }
        .padding(.top, 8)
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
            Text("Fetching Weather…")
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

                // Weather icon with glow
                ZStack {
                    Image(systemName: info.icon)
                        .font(.system(size: 70))
                        .foregroundStyle(.white.opacity(0.15))
                        .blur(radius: 20)

                    Image(systemName: info.icon)
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.4), radius: 16, x: 0, y: 4)
                }
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

                // High/Low for today
                if let today = weatherService.forecast.first {
                    Text("H:\(Int(today.maxTemp))°  L:\(Int(today.minTemp))°")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Hourly Forecast Section

    private var hourlyForecastSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text("HOURLY FORECAST")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            } icon: {
                Image(systemName: "clock")
                    .font(.system(size: 13))
            }
            .foregroundColor(.white.opacity(0.55))
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .background(.white.opacity(0.15))
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(weatherService.hourly.prefix(24)) { hour in
                        hourlyItem(hour: hour)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
    }

    private func hourlyItem(hour: HourlyForecast) -> some View {
        VStack(spacing: 8) {
            Text(hourString(from: hour.time))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            Image(systemName: WeatherInfo.from(code: hour.weatherCode, isDay: true).icon)
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.85))
                .frame(height: 28)

            Text("\(Int(hour.temperature))°")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    // MARK: - Detail Grid Section

    private var detailGridSection: some View {
        Group {
            if let current = weatherService.current {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    detailTile(icon: "humidity.fill", title: "HUMIDITY", value: "\(current.humidity)%", subtitle: humidityDescription(current.humidity))
                    detailTile(icon: "wind", title: "WIND", value: String(format: "%.1f", current.windSpeed), subtitle: "km/h")
                    detailTile(icon: "sun.max.fill", title: "UV INDEX", value: String(format: "%.0f", current.uvIndex), subtitle: uvDescription(current.uvIndex))
                    detailTile(icon: "eye.fill", title: "VISIBILITY", value: String(format: "%.0f", current.visibility / 1000), subtitle: "km")
                    detailTile(icon: "thermometer.medium", title: "FEELS LIKE", value: "\(Int(current.apparentTemperature))°", subtitle: feelsLikeDescription(current))
                    detailTile(icon: "gauge.medium", title: "PRESSURE", value: String(format: "%.0f", current.pressure), subtitle: "hPa")
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
            }
        }
    }

    private func detailTile(icon: String, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 11))
            }
            .foregroundColor(.white.opacity(0.5))

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(2)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(height: 130)
        .background(.ultraThinMaterial.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Sunrise / Sunset Section

    private var sunriseSunsetSection: some View {
        Group {
            if let today = weatherService.forecast.first,
               let sunrise = today.sunrise,
               let sunset = today.sunset {
                HStack(spacing: 12) {
                    sunTimeCard(icon: "sunrise.fill", title: "SUNRISE", time: sunrise)
                    sunTimeCard(icon: "sunset.fill", title: "SUNSET", time: sunset)
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
            }
        }
    }

    private func sunTimeCard(icon: String, title: String, time: Date) -> some View {
        VStack(spacing: 10) {
            Label {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 11))
            }
            .foregroundColor(.white.opacity(0.5))

            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.orange.opacity(0.9))
                .shadow(color: .orange.opacity(0.3), radius: 8)

            Text(formatTime(time))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
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

    // MARK: - 7 Day Forecast Section

    private var forecastSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text("7-DAY FORECAST")
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
                Text(dayName(from: day.date))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 90, alignment: .leading)

                Spacer()

                Image(systemName: WeatherInfo.from(code: day.weatherCode).icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36)

                Spacer()

                temperatureBar(min: day.minTemp, max: day.maxTemp)

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
        let allMin = weatherService.forecast.map(\.minTemp).min() ?? min
        let allMax = weatherService.forecast.map(\.maxTemp).max() ?? max
        let range = allMax - allMin
        let safeDenom = range == 0 ? 1.0 : range

        let startFraction = (min - allMin) / safeDenom
        let endFraction = (max - allMin) / safeDenom

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.1))
                    .frame(height: 4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.3, green: 0.75, blue: 1.0),
                                Color(red: 1.0, green: 0.85, blue: 0.2)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: Swift.max(4, geo.size.width * (endFraction - startFraction)),
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
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }

    private func hourString(from date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let now = calendar.component(.hour, from: Date())
        if hour == now { return "Now" }
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date).lowercased()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }

    private func humidityDescription(_ humidity: Int) -> String {
        if humidity < 30 { return "Low. Skin may feel dry." }
        if humidity < 60 { return "Comfortable." }
        return "High. It may feel muggy."
    }

    private func uvDescription(_ uv: Double) -> String {
        if uv < 3 { return "Low" }
        if uv < 6 { return "Moderate" }
        if uv < 8 { return "High" }
        if uv < 11 { return "Very High" }
        return "Extreme"
    }

    private func feelsLikeDescription(_ current: CurrentWeather) -> String {
        let diff = current.apparentTemperature - current.temperature
        if abs(diff) < 2 { return "Similar to actual." }
        if diff > 0 { return "Humidity makes it feel warmer." }
        return "Wind makes it feel cooler."
    }
}

// MARK: - Preview

struct WeatherHomeView_Previews: PreviewProvider {
    static var previews: some View {
        WeatherHomeView()
    }
}
