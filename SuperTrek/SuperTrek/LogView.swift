import SwiftUI
import TrekEngine

/// The teletype. Scrolls to the newest line whenever one arrives.
struct LogView: View {
    let lines: [LogLine]
    /// Characters per line; lines longer than this wrap with a hanging indent.
    var columns: Int = 38
    var fontSize: CGFloat = 11

    /// A monospaced character is about 0.605 of the point size wide.
    static func columns(forWidth width: CGFloat, fontSize: CGFloat = 11) -> Int {
        max(20, Int((width - 16) / (fontSize * 0.605)))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(lines) { line in
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(wrapped(line).enumerated()), id: \.offset) { _, piece in
                                Text(styled(piece, line))
                                    .font(Theme.mono(fontSize, weight: line.isCommand ? .bold : .regular))
                                    .foregroundStyle(line.isCommand ? Theme.amber : line.isAlert ? Theme.alert : Theme.phosphor)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .id(line.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .defaultScrollAnchor(.bottomLeading)
            .onChange(of: lines.last?.id) { _, id in
                if let id {
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .bottomLeading) }
                }
            }
        }
    }

    private func wrapped(_ line: LogLine) -> [String] {
        Narrator(columns: columns).wrap(line.text.isEmpty ? " " : line.text)
    }

    /// Colors the condition word in the scan's side panel.
    private func styled(_ piece: String, _ line: LogLine) -> AttributedString {
        var text = AttributedString(piece)
        guard !line.isCommand, !line.isAlert, piece.contains("CONDITION") else { return text }
        for (token, color) in [("*RED*", Theme.alert), ("YELLOW", Theme.amber), ("DOCKED", Theme.cyan)] {
            if let range = text.range(of: token) {
                text[range].foregroundColor = color
            }
        }
        return text
    }
}
