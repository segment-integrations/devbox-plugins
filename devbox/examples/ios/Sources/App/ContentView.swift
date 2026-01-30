import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Devbox iOS Example")
                .font(.title)
            Text("Running on simulator")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
