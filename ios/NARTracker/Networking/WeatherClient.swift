import Foundation

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
}

private struct WeatherResponse: Decodable {
    let current: Current
    struct Current: Decodable {
        let relative_humidity_2m: Int
    }
}
