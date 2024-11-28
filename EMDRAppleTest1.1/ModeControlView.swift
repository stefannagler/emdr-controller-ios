import SwiftUI

struct ModeControlView: View {
    let title: String
    @Binding var enabled: Bool
    @Binding var intensity: Int
    @Binding var duration: Int
    let intensityRange: ClosedRange<Int>
    let durationRange: ClosedRange<Int>
    let onToggle: (Bool) -> Void
    let onIntensityChange: (Int) -> Void
    let onDurationChange: (Int) -> Void
    
    private func debugPrint(_ message: String) {
        if message.contains("Intensity") {
            print("🟣 UI [\(title)]: Intensity changed to \(intensity)")
        } else if message.contains("Duration") {
            print("⏱️ UI [\(title)]: Duration changed to \(duration)")
        } else {
            print("🔄 UI [\(title)]: \(message)")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Toggle(title, isOn: Binding(
                get: { enabled },
                set: {
                    enabled = $0
                    debugPrint("Enabled: \($0)")
                    onToggle($0)
                }
            ))
            .font(.headline)
            
            if enabled {
                VStack(spacing: 8) {
                    HStack {
                        Text("Intensity")
                        Slider(value: Binding(
                            get: { Double(intensity) },
                            set: { intensity = Int($0) }
                        ), in: Double(intensityRange.lowerBound)...Double(intensityRange.upperBound), step: 1) { isEditing in
                            if !isEditing {
                                debugPrint("Intensity: \(intensity)")
                                onIntensityChange(intensity)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Duration: \(duration)")
                        Slider(value: Binding(
                            get: { Double(duration) },
                            set: { duration = Int($0) }
                        ), in: Double(durationRange.lowerBound)...Double(durationRange.upperBound), step: 1) { isEditing in
                            if !isEditing {
                                debugPrint("Duration: \(duration)")
                                onDurationChange(duration)
                            }
                        }
                    }
                }
                .padding(.leading)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
} 