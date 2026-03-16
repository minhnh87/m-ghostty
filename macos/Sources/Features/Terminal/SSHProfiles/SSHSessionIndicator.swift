import SwiftUI

/// A small pill overlay shown at the top-right of the terminal surface
/// when an SSH session is detected.
struct SSHSessionIndicator: View {
    let session: SSHSessionInfo

    @State private var relativeTime: String = ""
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text("🔗")
                        .font(.system(size: 10))
                    Text("\(session.user)@\(session.hostname)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                    if !relativeTime.isEmpty {
                        Text(relativeTime)
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                )
                .foregroundColor(.white)
                .padding(.top, 6)
                .padding(.trailing, 8)
            }
            Spacer()
        }
        .allowsHitTesting(false)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: session)
        .onAppear {
            updateRelativeTime()
        }
        .onReceive(timer) { _ in
            updateRelativeTime()
        }
    }

    private func updateRelativeTime() {
        let elapsed = Date().timeIntervalSince(session.connectedAt)
        if elapsed < 60 {
            relativeTime = "<1m"
        } else if elapsed < 3600 {
            relativeTime = "\(Int(elapsed / 60))m"
        } else if elapsed < 86400 {
            let hours = Int(elapsed / 3600)
            let mins = Int((elapsed.truncatingRemainder(dividingBy: 3600)) / 60)
            relativeTime = mins > 0 ? "\(hours)h\(mins)m" : "\(hours)h"
        } else {
            let days = Int(elapsed / 86400)
            relativeTime = "\(days)d"
        }
    }
}

