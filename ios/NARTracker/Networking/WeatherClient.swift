import Foundation

struct AirQuality {
    let pm25: Double
    let pm10: Double
}

enum WeatherClient {
    static func fetchHumidity(latitude: Double, longitude: Double) async throws -> Int {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude",  value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current",   value: "relative_humidity_2m"),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response  = try JSONDecoder().decode(WeatherResponse.self, from: data)
        return response.current.relative_humidity_2m
    }

    static func fetchAirQuality(latitude: Double, longitude: Double) async throws -> AirQuality {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")!
        components.queryItems = [
            URLQueryItem(name: "latitude",  value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current",   value: "pm2_5,pm10"),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response  = try JSONDecoder().decode(AirQualityResponse.self, from: data)
        return AirQuality(pm25: response.current.pm2_5, pm10: response.current.pm10)
    }
}

private struct WeatherResponse: Decodable {
    let current: Current
    struct Current: Decodable {
        let relative_humidity_2m: Int
    }
}

private struct AirQualityResponse: Decodable {
    let current: Current
    struct Current: Decodable {
        let pm2_5: Double
        let pm10: Double
    }
}
