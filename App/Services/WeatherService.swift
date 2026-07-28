import Foundation

/// Trip-dates weather forecast via Open-Meteo (free, no API key).
struct DayForecast: Identifiable, Equatable {
    let date: Date
    let weatherCode: Int
    let highF: Double
    let lowF: Double
    let precipChance: Int

    var id: Date { date }

    var symbolName: String {
        switch weatherCode {
        case 0: "sun.max.fill"
        case 1, 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    var summary: String {
        switch weatherCode {
        case 0: "Sunny"
        case 1, 2: "Partly cloudy"
        case 3: "Overcast"
        case 45, 48: "Foggy"
        case 51...57: "Drizzle"
        case 61...67: "Rain"
        case 71...77: "Snow"
        case 80...82: "Showers"
        case 85, 86: "Snow showers"
        case 95...99: "Thunderstorms"
        default: "Mixed"
        }
    }
}

enum WeatherService {
    struct GeocodeResponse: Decodable {
        struct Result: Decodable {
            let latitude: Double
            let longitude: Double
            let name: String
        }
        let results: [Result]?
    }

    struct ForecastResponse: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let weather_code: [Int]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let precipitation_probability_max: [Int]?
        }
        let daily: Daily
    }

    /// Geocodes the destination name, then fetches a daily forecast clipped to
    /// the trip's date range (Open-Meteo covers ~16 days out).
    static func forecast(for trip: Trip) async throws -> [DayForecast] {
        let coords = try await geocode(trip.destination)

        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(coords.latitude)),
            .init(name: "longitude", value: String(coords.longitude)),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            .init(name: "temperature_unit", value: "fahrenheit"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "16"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let response = try JSONDecoder().decode(ForecastResponse.self, from: data)

        let tripDays = Set(trip.days)
        var result: [DayForecast] = []
        let daily = response.daily
        for (index, dayString) in daily.time.enumerated() {
            guard let date = Trip.dayFormatter.date(from: dayString),
                  tripDays.contains(Calendar.current.startOfDay(for: date)),
                  index < daily.weather_code.count,
                  index < daily.temperature_2m_max.count,
                  index < daily.temperature_2m_min.count else { continue }
            result.append(DayForecast(
                date: date,
                weatherCode: daily.weather_code[index],
                highF: daily.temperature_2m_max[index],
                lowF: daily.temperature_2m_min[index],
                precipChance: daily.precipitation_probability_max?[index] ?? 0
            ))
        }
        return result
    }

    /// Users type destinations like "Gulf Shores, Alabama", but the geocoder
    /// matches plain place names best — so retry with just the first segment.
    static func geocode(_ place: String) async throws -> (latitude: Double, longitude: Double) {
        if let match = try? await geocodeOnce(place) { return match }
        let simplified = place.split(separator: ",").first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? place
        return try await geocodeOnce(simplified)
    }

    private static func geocodeOnce(_ place: String) async throws -> (latitude: Double, longitude: Double) {
        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comps.queryItems = [
            .init(name: "name", value: place),
            .init(name: "count", value: "1"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let response = try JSONDecoder().decode(GeocodeResponse.self, from: data)
        guard let first = response.results?.first else {
            throw URLError(.resourceUnavailable)
        }
        return (first.latitude, first.longitude)
    }
}
