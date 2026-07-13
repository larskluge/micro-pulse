import SwiftUI

struct ContentView: View {
    @StateObject private var ring = RingController()
    @State private var customMinutes = 3

    private let presets = [1, 3, 5, 7, 10, 20]
    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 10)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(ring.isReady ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                        Text(ring.status.rawValue)
                        Spacer()
                    }
                    if !ring.lastMessage.isEmpty {
                        Text(ring.lastMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                    if !ring.lastReply.isEmpty {
                        Text(ring.lastReply).font(.caption2).foregroundStyle(.tertiary)
                    }
                }

                Section("Interval") {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(presets, id: \.self) { minutes in
                            Button("\(minutes) min") { ring.setInterval(minutes: minutes) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)

                    Stepper("Custom: \(customMinutes) min", value: $customMinutes, in: 1...120)
                    Button("Set \(customMinutes) min") { ring.setInterval(minutes: customMinutes) }
                }

                Section("Vibration") {
                    ForEach(RingCommands.vibrations, id: \.name) { vibration in
                        Button(vibration.name) {
                            ring.setVibration(name: vibration.name, pattern: vibration.pattern)
                        }
                    }
                }
            }
            .disabled(!ring.isReady)
            .navigationTitle("micro-pulse")
        }
    }
}

#Preview {
    ContentView()
}
