import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("Hello World")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)

                Text("My first iOS app")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ContentView()
}
