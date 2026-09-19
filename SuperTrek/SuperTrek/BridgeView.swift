import SwiftUI
import TrekEngine

/// The one screen: status, the sector grid, the log, and the controls.
struct BridgeView: View {
    @Environment(GameStore.self) private var store
    @State private var mode: PanelMode = BridgeView.initialMode
    @State private var showComputer = ["computer", "help"].contains(UserDefaults.standard.string(forKey: "autoPanel") ?? "")
    @State private var confirmResign = false
    @State private var flashOpacity = 0.0
    @AppStorage(FeedbackSettings.hapticsKey) private var hapticsEnabled = true

    var body: some View {
        if let game = store.game {
            GeometryReader { geometry in
            // Full width where the screen is tall enough; on short screens leave room
            // for a dozen log lines and the command bar.
            let compact = geometry.size.height < 700
            let gridSide = min(geometry.size.width - 32, geometry.size.height - (compact ? 360 : 345))
            let logColumns = LogView.columns(forWidth: geometry.size.width - 24 - 92 - 12 - 1)
            VStack(spacing: 0) {
                SectorGridView(game: game, highlights: highlights(game), bursts: store.bursts, shots: store.shots, ghosts: store.ghosts, onTap: { tapped($0, game: game) })
                    .keyframeAnimator(initialValue: 0.0, trigger: store.hitPulse) { view, offset in
                        view.offset(x: offset)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(-9, duration: 0.04)
                            LinearKeyframe(8, duration: 0.05)
                            LinearKeyframe(-6, duration: 0.05)
                            LinearKeyframe(4, duration: 0.05)
                            LinearKeyframe(0, duration: 0.06)
                        }
                    }
                    .overlay {
                        if let scan = store.lastLongRangeScan {
                            LongRangeOverlay(scan: scan) { store.dismissLongRangeScan() }
                        }
                    }
                    .frame(width: gridSide, height: gridSide)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                HStack(alignment: .top, spacing: 0) {
                    LogView(lines: store.log, columns: logColumns)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Rectangle().frame(width: 1).foregroundStyle(Theme.dim)
                    ReadoutPanel(game: game, lexicon: store.lexicon, compact: compact)
                        .frame(width: 92)
                        .padding(.horizontal, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(Rectangle().stroke(Theme.dim, lineWidth: 1))
                .padding(.horizontal, 12)
                panel(game)
                    .padding(12)
                    .animation(.easeOut(duration: 0.15), value: mode == .commands)
            }
            .background(Theme.background.ignoresSafeArea())
            .overlay {
                Theme.alert.opacity(flashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .onChange(of: store.hitPulse) { _, _ in
                flashOpacity = 0.55
                withAnimation(.easeOut(duration: 0.5)) { flashOpacity = 0 }
            }
            .sensoryFeedback(trigger: store.hitPulse) { _, _ in
                hapticsEnabled ? .impact(weight: .heavy, intensity: 1) : nil
            }
            .sensoryFeedback(trigger: store.explosionPulse) { _, _ in
                hapticsEnabled ? .success : nil
            }
            .sensoryFeedback(trigger: store.refusalPulse) { _, _ in
                hapticsEnabled ? .error : nil
            }
            .sheet(isPresented: $showComputer) {
                ComputerView(game: game, lexicon: store.lexicon, startOnHelp: UserDefaults.standard.string(forKey: "autoPanel") == "help") { function in
                    store.send(.computer(function))
                } onPlot: { quadrant in
                    if let plot = game.plotCourse(toQuadrant: quadrant) {
                        mode = .navigation(course: plot.course, warp: plot.warp)
                    }
                }
                .presentationDetents([.large])
                .presentationBackground(Theme.background)
            }
            .alert("REPAIR ORDER", isPresented: repairPrompt) {
                Button("AUTHORIZE") { store.send(.authorizeRepairs(true)) }
                Button("DECLINE", role: .cancel) { store.send(.authorizeRepairs(false)) }
            } message: {
                Text("Technicians estimate \(String(format: "%.2f", game.pendingRepairEstimate ?? 0)) stardates. Authorize the repair order?")
            }
            .confirmationDialog("RESIGN COMMAND?", isPresented: $confirmResign, titleVisibility: .visible) {
                Button("RESIGN", role: .destructive) { store.send(.resign) }
            }
            .overlay {
                if game.status != .playing {
                    GameOverView(game: game)
                }
            }
            .onChange(of: game.status.isOver) { _, over in
                if over { mode = .commands }
            }
            }
        }
    }

    // MARK: Panel

    @ViewBuilder
    private func panel(_ game: Game) -> some View {
        switch mode {
        case .commands:
            CommandBar(lexicon: store.lexicon, isPlaying: game.status == .playing, onCommand: { perform($0, game: game) })
        case let .navigation(course, warp):
            NavigationPanel(
                game: game, lexicon: store.lexicon,
                course: Binding(get: { course }, set: { mode = .navigation(course: $0, warp: warp) }),
                warp: Binding(get: { warp }, set: { mode = .navigation(course: course, warp: $0) }),
                onEngage: { commit(.navigate(course: course, warp: warp)) },
                onCancel: { mode = .commands }
            )
        case let .torpedo(course):
            TorpedoPanel(
                game: game, lexicon: store.lexicon,
                course: Binding(get: { course }, set: { mode = .torpedo(course: $0) }),
                onFire: { commit(.fireTorpedo(course: course)) },
                onCancel: { mode = .commands }
            )
        case let .beams(energy):
            EnergyPanel(
                title: "\(store.lexicon.beamWeapon)S LOCKED ON TARGET", prompt: "ENERGY TO FIRE", action: "FIRE",
                maximum: Int(game.ship.energy), tint: Theme.alert,
                value: Binding(get: { energy }, set: { mode = .beams(energy: $0) }),
                onCommit: { commit(.fireBeams(energy: Int(energy))) },
                onCancel: { mode = .commands }
            )
        case let .shields(energy):
            EnergyPanel(
                title: "SHIELD CONTROL", prompt: "UNITS TO SHIELDS", action: "SET",
                maximum: Int(game.ship.totalEnergy), tint: Theme.phosphor,
                value: Binding(get: { energy }, set: { mode = .shields(energy: $0) }),
                onCommit: { commit(.setShields(energy: Int(energy))) },
                onCancel: { mode = .commands }
            )
        }
    }

    private func commit(_ command: Command) {
        mode = .commands
        store.send(command)
    }

    private func perform(_ action: CommandBar.Action, game: Game) {
        store.dismissLongRangeScan()
        switch action {
        case .navigate: mode = .navigation(course: 1, warp: 1)
        case .shortRangeScan: store.send(.shortRangeScan)
        case .longRangeScan: store.send(.longRangeScan)
        case .beams: mode = .beams(energy: Double(min(Int(game.ship.energy), 200)))
        case .torpedo: mode = .torpedo(course: defaultTorpedoCourse(game))
        case .shields: mode = .shields(energy: game.ship.shields)
        case .damage: store.send(.damageReport)
        case .computer: showComputer = true
        case .resign: confirmResign = true
        }
    }

    /// Aim at the nearest enemy by default, or straight ahead if there is none.
    private func defaultTorpedoCourse(_ game: Game) -> Double {
        let nearest = game.enemies.filter(\.isAlive).min { game.sector.distance(to: $0.position) < game.sector.distance(to: $1.position) }
        guard let nearest else { return 1 }
        return (Course.heading(from: game.sector, to: nearest.position).course * 100).rounded() / 100
    }

    // MARK: Grid

    private func tapped(_ position: SectorPosition, game: Game) {
        guard game.status == .playing, position != game.sector else { return }
        store.dismissLongRangeScan()
        let aim = (Course.heading(from: game.sector, to: position).course * 100).rounded() / 100
        switch mode {
        case .commands:
            if game.map[position] == .enemy {
                mode = .torpedo(course: aim)
            } else if let plot = game.plotCourse(to: position) {
                mode = .navigation(course: plot.course, warp: plot.warp)
            }
        case .navigation:
            if let plot = game.plotCourse(to: position) {
                mode = .navigation(course: plot.course, warp: plot.warp)
            }
        case .torpedo:
            mode = .torpedo(course: aim)
        case .beams, .shields:
            break
        }
    }

    private func highlights(_ game: Game) -> [SectorPosition: SectorHighlight] {
        var result: [SectorPosition: SectorHighlight] = [:]
        switch mode {
        case let .navigation(course, warp):
            guard let preview = game.previewNavigation(course: course, warp: warp) else { return [:] }
            for p in preview.path { result[p] = .path }
            if let landing = preview.landing { result[landing] = .landing }
            if let blocked = preview.blockedBy { result[blocked] = .blocked }
        case let .torpedo(course):
            guard let preview = game.previewTorpedo(course: course) else { return [:] }
            for p in preview.track { result[p] = .track }
            if preview.target != nil, let last = preview.track.last { result[last] = .impact }
        default:
            break
        }
        return result
    }

    private var repairPrompt: Binding<Bool> {
        Binding(
            get: { store.game?.pendingRepairEstimate != nil },
            set: { if !$0, store.game?.pendingRepairEstimate != nil { store.send(.authorizeRepairs(false)) } }
        )
    }
}

extension BridgeView {
    /// `-autoPanel nav|torpedo` opens a control panel at launch (screenshots).
    static var initialMode: PanelMode {
        switch UserDefaults.standard.string(forKey: "autoPanel") {
        case "nav": .navigation(course: 2.5, warp: 0.5)
        case "torpedo": .torpedo(course: 2)
        default: .commands
        }
    }
}

struct GameOverView: View {
    @Environment(GameStore.self) private var store
    let game: Game

    var body: some View {
        VStack(spacing: 16) {
            Text(headline)
                .font(Theme.mono(20, weight: .bold))
                .multilineTextAlignment(.center)
            Text(detail)
                .font(Theme.mono(13))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.dim)
            Button("NEW MISSION") { store.abandon() }
                .buttonStyle(TerminalButtonStyle())
                .accessibilityIdentifier("gameover.new")
        }
        .padding(24)
        .background(Theme.background.opacity(0.94))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.phosphor, lineWidth: 1))
        .padding(32)
        .foregroundStyle(Theme.phosphor)
    }

    private var headline: String {
        switch game.status {
        case .playing: ""
        case .won: "MISSION ACCOMPLISHED"
        case .lost(.shipDestroyed): "SHIP DESTROYED"
        case .lost(.timeExpired): "OUT OF TIME"
        case .lost(.stranded): "STRANDED IN SPACE"
        case .lost(.relievedOfCommand): "RELIEVED OF COMMAND"
        case .lost(.resigned): "COMMAND RESIGNED"
        }
    }

    private var detail: String {
        switch game.status {
        case let .won(efficiency):
            "EFFICIENCY RATING \(String(format: "%.2f", efficiency))\n\(game.profile.length.rawValue.uppercased()) GAME · \(game.profile.skill.rawValue.uppercased()) SKILL"
        default:
            "\(game.enemiesRemaining) \(store.lexicon.enemyPlural) LEFT AT STARDATE \(String(format: "%.1f", game.stardate))"
        }
    }
}

#Preview("Bridge") {
    let game = Game(fixture: GameStore.fixture(named: "battle")!)
    return BridgeView()
        .environment(GameStore(game: game, events: [.missionBegins(quadrantName: game.quadrantName), .combatAreaConditionRed, .shortRangeScan(game.scanSnapshot)]))
}
