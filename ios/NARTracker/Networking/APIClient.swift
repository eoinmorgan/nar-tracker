import Foundation

enum APIClient {
    static func logSymptoms(_ payload: SymptomPayload, accessToken: String) async throws {
        var request = URLRequest(url: URL(string: Constants.apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json",        forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)",   forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.unexpectedStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    enum APIError: LocalizedError {
        case unexpectedStatus(Int)
        var errorDescription: String? { "Server returned status \(self)" }
    }
}

struct SymptomPayload: Encodable {
    let submission_time:   String
    let latitude:          Double
    let longitude:         Double
    let humidity_pct:      Int
    let congestion:        Int
    let headaches:         Int
    let fatigue:           Int
    let mood:              Int
}
