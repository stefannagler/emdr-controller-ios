import SwiftUI

struct MainVisualizationView: View {
    var animationDegrees: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                .frame(width: 200, height: 200)
            
            Circle()
                .fill(Color.blue)
                .frame(width: 20, height: 20)
                .offset(x: 90 * cos(animationDegrees * .pi / 180))
                .animation(.linear(duration: 0.016), value: animationDegrees)
        }
        .padding()
    }
} 