import AppAuth
import Foundation
import Security
import UIKit

@MainActor
class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false

    private var authState: OIDAuthState? {
        didSet { saveToKeychain() }
    }

    private var currentFlow: OIDExternalUserAgentSession?
    private let keychainKey = "nartracker.authstate"

    override init() {
        super.init()
        loadFromKeychain()
    }

    // MARK: - Public

    func signIn() async throws {
        let issuer = URL(string: "https://cognito-idp.\(Constants.awsRegion).amazonaws.com/\(Constants.userPoolId)")!
        let config = try await discoverConfiguration(issuer: issuer)

        let request = OIDAuthorizationRequest(
            configuration: config,
            clientId: Constants.userPoolClientId,
            scopes: [OIDScopeOpenID, OIDScopeEmail, "profile"],
            redirectURL: URL(string: Constants.cognitoRedirectUri)!,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )

        let agent = OIDExternalUserAgentIOS(presenting: try presentingViewController())!

        let state: OIDAuthState = try await withCheckedThrowingContinuation { continuation in
            currentFlow = OIDAuthState.authState(
                byPresenting: request,
                externalUserAgent: agent
            ) { authState, error in
                if let error { continuation.resume(throwing: error); return }
                if let authState { continuation.resume(returning: authState); return }
                continuation.resume(throwing: AuthError.unknown)
            }
        }

        state.stateChangeDelegate = self
        state.errorDelegate = self
        authState = state
        isAuthenticated = true
    }

    /// Gets a valid access token, refreshing silently if the current one is expired.
    /// If the refresh token is also expired, sets isAuthenticated = false so the
    /// app returns to the sign-in screen.
    func withFreshToken(_ action: @escaping (String) async throws -> Void) async throws {
        guard let authState else { throw AuthError.notSignedIn }

        // performAction checks expiry and calls /oauth2/token with the refresh
        // token if needed — all transparent to the caller.
        let token: String = try await withCheckedThrowingContinuation { continuation in
            authState.performAction { [weak self] accessToken, _, error in
                if let error {
                    // If isAuthorized is now false, the refresh token expired.
                    if !(self?.authState?.isAuthorized ?? true) {
                        Task { @MainActor [weak self] in self?.isAuthenticated = false }
                    }
                    continuation.resume(throwing: error)
                    return
                }
                guard let token = accessToken else {
                    continuation.resume(throwing: AuthError.noToken)
                    return
                }
                continuation.resume(returning: token)
            }
        }

        try await action(token)
    }

    func signOut() {
        authState = nil   // didSet → saveToKeychain deletes the entry
        isAuthenticated = false
    }

    // MARK: - Private

    private func discoverConfiguration(issuer: URL) async throws -> OIDServiceConfiguration {
        try await withCheckedThrowingContinuation { continuation in
            OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { config, error in
                if let error { continuation.resume(throwing: error); return }
                if let config { continuation.resume(returning: config); return }
                continuation.resume(throwing: AuthError.discoveryFailed)
            }
        }
    }

    private func presentingViewController() throws -> UIViewController {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root  = scene.windows.first(where: \.isKeyWindow)?.rootViewController
        else { throw AuthError.noWindow }
        return root
    }

    private func loadFromKeychain() {
        guard
            let data  = KeychainHelper.load(key: keychainKey),
            let state = try? NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data)
        else { return }
        state.stateChangeDelegate = self
        state.errorDelegate = self
        authState = state
        isAuthenticated = state.isAuthorized
    }

    private func saveToKeychain() {
        guard let authState else {
            KeychainHelper.delete(key: keychainKey)
            return
        }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: authState, requiringSecureCoding: true) {
            KeychainHelper.save(key: keychainKey, data: data)
        }
    }

    enum AuthError: LocalizedError {
        case notSignedIn, noToken, discoveryFailed, noWindow, unknown
        var errorDescription: String? {
            switch self {
            case .notSignedIn:     return "Not signed in."
            case .noToken:         return "Could not get access token."
            case .discoveryFailed: return "Could not reach Cognito. Check your network."
            case .noWindow:        return "No window available to present sign-in."
            case .unknown:         return "Sign-in failed."
            }
        }
    }
}

// Auto-saves to Keychain after silent token refreshes.
extension AuthManager: OIDAuthStateChangeDelegate {
    nonisolated func didChange(_ state: OIDAuthState) {
        Task { @MainActor in self.saveToKeychain() }
    }
}

// Drops isAuthenticated if Cognito reports a fatal auth error.
extension AuthManager: OIDAuthStateErrorDelegate {
    nonisolated func authState(_ state: OIDAuthState, didEncounterAuthorizationError error: Error) {
        Task { @MainActor in self.isAuthenticated = false }
    }
}

// MARK: - Keychain

private enum KeychainHelper {
    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData   as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData  as String: true,
            kSecMatchLimit  as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
