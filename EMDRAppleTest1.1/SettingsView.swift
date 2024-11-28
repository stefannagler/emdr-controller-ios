import SwiftUI

struct SettingsView: View {
    @Binding var hapticIntensity: Double
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Haptic Feedback")) {
                    Slider(value: $hapticIntensity, in: 0...1) {
                        Text("Intensity")
                    }
                    Button("Test Haptic") {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred(intensity: hapticIntensity)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 