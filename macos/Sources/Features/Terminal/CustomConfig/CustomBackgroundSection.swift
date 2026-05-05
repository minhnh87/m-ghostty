import SwiftUI

struct CustomBackgroundSection: View {
    @ObservedObject var store: CustomBackgroundStore

    /// The current effective background as `#rrggbb`, used to pre-fill the field on first open
    /// and to revert the field on Clear.
    var initialBackgroundHex: String

    /// Called after the store has been updated. The hex value (or nil for clear) is forwarded
    /// so the caller can dispatch the OSC 11 broadcast.
    var onApply: (String?) -> Void

    @State private var inputText: String = ""
    @State private var isInvalid: Bool = false
    @State private var hoveredSwatch: String? = nil

    private static let swatchHexes: [String] = [
        "#202940",
        "#4B4038",
        "#093C5D",
        "#2C3947",
        "#574964",
        "#355872",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Custom Background")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65))

            HStack(spacing: 4) {
                ForEach(Self.swatchHexes, id: \.self) { hex in
                    Button(action: { applySwatch(hex) }) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Self.color(fromHex: hex))
                            .frame(width: 20, height: 20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        hoveredSwatch == hex
                                            ? Color(red: 0.55, green: 0.55, blue: 0.55)
                                            : Color(red: 0.20, green: 0.20, blue: 0.20),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help(hex)
                    .onHover { isHovering in
                        hoveredSwatch = isHovering ? hex : nil
                    }
                }
                Spacer()
            }

            TextField("#1e1e1e", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(red: 0.07, green: 0.07, blue: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isInvalid ? Color.red.opacity(0.6) : Color(red: 0.20, green: 0.20, blue: 0.20),
                            lineWidth: 1
                        )
                )
                .onSubmit { applyTapped() }

            HStack(spacing: 6) {
                Button("Apply") { applyTapped() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                Button("Clear") { clearTapped() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            inputText = store.customBackground ?? initialBackgroundHex
        }
        .onChange(of: store.customBackground) { newValue in
            inputText = newValue ?? initialBackgroundHex
            isInvalid = false
        }
    }

    // MARK: - Actions

    private func applyTapped() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if store.setBackground(trimmed) {
            isInvalid = false
            onApply(trimmed)
        } else {
            isInvalid = true
        }
    }

    private func clearTapped() {
        store.clear()
        inputText = initialBackgroundHex
        isInvalid = false
        onApply(nil)
    }

    private func applySwatch(_ hex: String) {
        if store.setBackground(hex) {
            inputText = hex
            isInvalid = false
            onApply(hex)
        }
    }

    /// Parse a 6-digit hex string (with leading `#`) into a SwiftUI Color.
    /// Inputs are hardcoded swatch values, so no validation is performed.
    private static func color(fromHex hex: String) -> Color {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        let value = UInt32(s, radix: 16) ?? 0
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

#if DEBUG
#Preview {
    CustomBackgroundSection(
        store: CustomBackgroundStore.shared,
        initialBackgroundHex: "#1e1e1e",
        onApply: { _ in }
    )
    .frame(width: 240)
    .background(Color(red: 0.11, green: 0.11, blue: 0.11))
}
#endif
