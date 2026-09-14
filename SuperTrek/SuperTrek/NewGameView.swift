import SwiftUI
import TrekEngine

struct NewGameView: View {
    @Environment(GameStore.self) private var store
    @State private var seedText = ""
    @AppStorage("missionLength") private var length = MissionLength.medium.rawValue
    @AppStorage("missionSkill") private var skill = Skill.good.rawValue

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
                Text("WHAT LENGTH GAME?")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.dim)
                HStack(spacing: 8) {
                    ForEach(MissionLength.allCases, id: \.rawValue) { option in
                        Button(option.rawValue.uppercased()) { length = option.rawValue }
                            .buttonStyle(TerminalButtonStyle(tint: length == option.rawValue ? Theme.phosphor : Theme.dim))
                            .accessibilityIdentifier("length.\(option.rawValue)")
                    }
                }
                Text("ARE YOU A NOVICE, FAIR, GOOD, EXPERT, OR SKILLED PLAYER?")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 8)
                HStack(spacing: 6) {
                    ForEach(Skill.allCases, id: \.rawValue) { option in
                        Button(option.rawValue.uppercased()) { skill = option.rawValue }
                            .buttonStyle(TerminalButtonStyle(tint: skill == option.rawValue ? Theme.phosphor : Theme.dim))
                            .accessibilityIdentifier("skill.\(option.rawValue)")
                    }
                }
            }
            .padding(.horizontal, 32)
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
                let profile = MissionProfile(
                    length: MissionLength(rawValue: length) ?? .medium,
                    skill: Skill(rawValue: skill) ?? .good
                )
                store.newGame(seed: UInt64(seedText.trimmingCharacters(in: .whitespaces)), profile: profile)
            }
            .accessibilityIdentifier("newgame.begin")
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
