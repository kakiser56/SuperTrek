import SwiftUI

/// The teletype. Scrolls to the newest line whenever one arrives.
struct LogView: View {
    let lines: [LogLine]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(lines) { line in
                        Text(styled(line))
                            .font(Theme.mono(11, weight: line.isCommand ? .bold : .regular))
                            .foregroundStyle(line.isCommand ? Theme.amber : line.isAlert ? Theme.alert : Theme.phosphor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .id(line.id)
                    }
                }
                .padding(.horizontal, 12)
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
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.dim), alignment: .top)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.dim), alignment: .bottom)
    }

    /// Colors the condition word in the scan's side panel.
    private func styled(_ line: LogLine) -> AttributedString {
        var text = AttributedString(line.text.isEmpty ? " " : line.text)
        guard !line.isCommand, !line.isAlert, line.text.contains("CONDITION") else { return text }
        for (token, color) in [("*RED*", Theme.alert), ("YELLOW", Theme.amber), ("DOCKED", Theme.cyan)] {
            if let range = text.range(of: token) {
                text[range].foregroundColor = color
            }
        }
        return text
    }
}
