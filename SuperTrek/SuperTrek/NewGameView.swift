import SwiftUI
import TrekEngine

struct NewGameView: View {
    @Environment(GameStore.self) private var store
    @State private var seedText = ""

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 6) {
                Text("SUPER TREK")
                    .font(Theme.mono(34, weight: .bold))
                Text("A 1978 STARSHIP SIMULATION")
                    .font(Theme.mono(13))
                    .foregroundStyle(Theme.dim)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("MISSION SEED (OPTIONAL)")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.dim)
                TextField("RANDOM", text: $seedText)
                    .font(Theme.mono(16))
                    .keyboardType(.numberPad)
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.dim, lineWidth: 1))
            }
            .padding(.horizontal, 32)
            Button("BEGIN MISSION") {
                store.newGame(seed: UInt64(seedText.trimmingCharacters(in: .whitespaces)))
            }
            .buttonStyle(TerminalButtonStyle())
            .padding(.horizontal, 32)
            FeedbackToggles()
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .foregroundStyle(Theme.phosphor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

#Preview {
    NewGameView()
        .environment(GameStore(game: Game(fixture: Game.Fixture())))
}
