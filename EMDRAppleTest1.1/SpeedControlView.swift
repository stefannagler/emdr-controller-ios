import SwiftUI

struct SpeedControlView: View {
    @Binding var speed: Int
    var onSpeedChange: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Speed: \(speed)")
                .font(.caption)
            HStack {
                Image(systemName: "tortoise")
                Slider(
                    value: Binding(
                        get: { Double(speed) },
                        set: { speed = Int($0) }
                    ),
                    in: 0...50,
                    step: 1
                ) { isEditing in
                    if !isEditing {
                        onSpeedChange(speed)
                    }
                }
                Image(systemName: "hare")
            }
        }
        .padding(.horizontal)
    }
} 