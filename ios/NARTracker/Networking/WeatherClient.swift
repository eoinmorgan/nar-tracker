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
        // ~10 km bounding box (~0.09 degrees)
        let delta = 0.09
        var components = URLComponents(string: "https://api.purpleair.com/v1/sensors")!
        components.queryItems = [
            URLQueryItem(name: "fields",        value: "pm2.5,pm10.0,latitude,longitude"),
            URLQueryItem(name: "location_type", value: "0"),  // outdoor only
            URLQueryItem(name: "nwlat",         value: String(latitude  + delta)),
            URLQueryItem(name: "nwlng",         value: String(longitude - delta)),
            URLQueryItem(name: "selat",         value: String(latitude  - delta)),
            URLQueryItem(name: "selng",         value: String(longitude + delta)),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(Constants.purpleAirApiKey, forHTTPHeaderField: "X-API-Key")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response  = try JSONDecoder().decode(PurpleAirResponse.self, from: data)

        // Fields order: sensor_index, pm2.5, pm10.0, latitude, longitude
        guard let pm25Idx = response.fields.firstIndex(of: "pm2.5"),
              let pm10Idx = response.fields.firstIndex(of: "pm10.0"),
              let latIdx  = response.fields.firstIndex(of: "latitude"),
              let lngIdx  = response.fields.firstIndex(of: "longitude")
        else { throw AirQualityError.missingFields }

        // Pick the nearest sensor
        let nearest = response.data
            .compactMap { row -> (pm25: Double, pm10: Double, dist: Double)? in
                guard row.count > max(pm25Idx, pm10Idx, latIdx, lngIdx),
                      let pm25  = row[pm25Idx].doubleValue,
                      let pm10  = row[pm10Idx].doubleValue,
                      let sLat  = row[latIdx].doubleValue,
                      let sLng  = row[lngIdx].doubleValue
                else { return nil }
                let dist = (sLat - latitude) * (sLat - latitude)
                         + (sLng - longitude) * (sLng - longitude)
                return (pm25, pm10, dist)
            }
            .min(by: { $0.dist < $1.dist })

        guard let sensor = nearest else { throw AirQualityError.noSensorsFound }
        return AirQuality(pm25: sensor.pm25, pm10: sensor.pm10)
    }

    enum AirQualityError: Error {
        case missingFields
        case noSensorsFound
    }
}

private struct WeatherResponse: Decodable {
    let current: Current
    struct Current: Decodable {
        let relative_humidity_2m: Int
    }
}

private struct PurpleAirResponse: Decodable {
    let fields: [String]
    let data: [[JSONValue]]
}

// Heterogeneous JSON array values
private enum JSONValue: Decodable {
    case int(Int), double(Double), string(String), null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(Int.self)    { self = .int(v);    return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        self = .null
    }

    var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v):    return Double(v)
        default:             return nil
        }
    }
}
