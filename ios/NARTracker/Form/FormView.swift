import SwiftUI

struct FormView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var vm = FormViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Symptoms") {
                    StarRatingView(label: "Congestion", rating: $vm.congestion)
                    StarRatingView(label: "Headaches",  rating: $vm.headaches)
                    StarRatingView(label: "Fatigue",    rating: $vm.fatigue)
                    StarRatingView(label: "Mood",       rating: $vm.mood)
                }

                Section("Context") {
                    switch vm.locationStatus {
                    case .loading:
                        Label("Getting location…", systemImage: "location")
                            .foregroundStyle(.secondary)
                    case .ready:
                        switch vm.humidity {
                        case .loading:
                            Label { Text("Humidity…").foregroundStyle(.secondary) } icon: { ProgressView() }
                        case .loaded(let h):
                            Label("Humidity: \(h)%", systemImage: "humidity")
                        case .unavailable:
                            Label("Humidity unavailable", systemImage: "humidity").foregroundStyle(.secondary)
                        }
                        switch vm.pm25 {
                        case .loading:
                            Label { Text("PM2.5…").foregroundStyle(.secondary) } icon: { ProgressView() }
                        case .loaded(let v):
                            Label("PM2.5: \(Int(v.rounded())) µg/m³", systemImage: "aqi.low")
                        case .unavailable:
                            Label("PM2.5 unavailable", systemImage: "aqi.low").foregroundStyle(.secondary)
                        }
                        switch vm.pm10 {
                        case .loading:
                            Label { Text("PM10…").foregroundStyle(.secondary) } icon: { ProgressView() }
                        case .loaded(let v):
                            Label("PM10: \(Int(v.rounded())) µg/m³", systemImage: "aqi.medium")
                        case .unavailable:
                            Label("PM10 unavailable", systemImage: "aqi.medium").foregroundStyle(.secondary)
                        }
                    case .failed:
                        Label("Location denied — grant access in Settings", systemImage: "location.slash")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await vm.submit(authManager: authManager)
                        }
                    } label: {
                        if vm.isSubmitting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Submit").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(vm.isSubmitting || vm.locationStatus == .loading)
                }
            }
            .navigationTitle("Check-in")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") { authManager.signOut() }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .alert("Logged!", isPresented: successBinding) {
                Button("OK") { vm.submitResult = nil }
            }
            .alert("Submission failed", isPresented: failureBinding, presenting: vm.submitResult) { _ in
                Button("OK") { vm.submitResult = nil }
            } message: { result in
                if case .failure(let msg) = result { Text(msg) }
            }
        }
        .task {
            await vm.loadContext()
        }
    }

    private var successBinding: Binding<Bool> {
        Binding(
            get: { vm.submitResult == .success },
            set: { if !$0 { vm.submitResult = nil } }
        )
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { if case .failure = vm.submitResult { return true }; return false },
            set: { if !$0 { vm.submitResult = nil } }
        )
    }
}
