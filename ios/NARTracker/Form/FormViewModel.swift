import CoreLocation
import Foundation

@MainActor
class FormViewModel: NSObject, ObservableObject {
    // Symptom scores
    @Published var congestion = 3
    @Published var headaches  = 3
    @Published var fatigue    = 3
    @Published var mood       = 3

    // State
    @Published var locationStatus: LocationStatus = .loading
    @Published var humidity: Int?
    @Published var isSubmitting = false
    @Published var submitResult: SubmitResult?

    private let locationManager = CLLocationManager()
    private var location: CLLocation?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // Called on view appear: fetch location then weather.
    func loadContext() async {
        locationStatus = .loading
        do {
            let loc = try await requestLocation()
            location       = loc
            locationStatus = .ready
            humidity = try? await WeatherClient.fetchHumidity(
                latitude:  loc.coordinate.latitude,
                longitude: loc.coordinate.longitude
            )
        } catch {
            locationStatus = .failed
        }
    }

    func submit(authManager: AuthManager) async {
        guard let loc = location else {
            submitResult = .failure("Location unavailable — please try again.")
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let payload = SymptomPayload(
            submission_time: ISO8601DateFormatter().string(from: Date()),
            latitude:          loc.coordinate.latitude,
            longitude:         loc.coordinate.longitude,
            humidity_pct:      humidity ?? 0,
            congestion:        congestion,
            headaches:         headaches,
            fatigue:           fatigue,
            mood:              mood
        )

        do {
            try await authManager.withFreshToken { token in
                try await APIClient.logSymptoms(payload, accessToken: token)
            }
            submitResult = .success
        } catch {
            submitResult = .failure(error.localizedDescription)
        }
    }

    // MARK: - Location

    private func requestLocation() async throws -> CLLocation {
        if locationManager.authorizationStatus == .notDetermined {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                authorizationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    enum LocationStatus { case loading, ready, failed }

    enum SubmitResult: Equatable {
        case success
        case failure(String)
    }
}

extension FormViewModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                authorizationContinuation?.resume()
                authorizationContinuation = nil
            case .denied, .restricted:
                authorizationContinuation?.resume(throwing: CLError(.denied))
                authorizationContinuation = nil
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations[0])
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }
}
