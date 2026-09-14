import SwiftUI
import TrekEngine

/// The library computer's help function: legend, rules, commands, strategy.
struct HelpView: View {
    let lexicon: Lexicon

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("SENSOR LEGEND") {
                    legend("<*>", "YOUR SHIP, THE \(lexicon.shipName)", Theme.phosphor)
                    legend("+K+", lexicon.name(of: .cruiser), Theme.alert)
                    legend("+R+", lexicon.name(of: .warbird), Theme.warbird)
                    legend(">!<", "STARBASE. DOCK TO RESUPPLY AND REPAIR.", Theme.cyan)
                    legend(" * ", "STAR. BLOCKS SHIPS AND ABSORBS TORPEDOES.", Theme.amber)
                }
                section("YOUR MISSION") {
                    para("The galaxy is 8 by 8 quadrants. Each quadrant is 8 by 8 sectors. Invader warships have entered the galaxy, and you must destroy every one of them before the deadline in stardates shown in your orders.")
                    para("Warbirds carry weaker shields than battle cruisers but hit harder. In a crowded quadrant, take them out first.")
                    para("Docking next to a starbase refills energy and torpedoes and drops your shields. A damage report while docked offers to repair everything at once for a little time.")
                }
                section("COMMANDS") {
                    command("NAV", "Warp along a course. Tap a sector to plot to it, or tap a quadrant on the computer's chart.")
                    command("SRS", "Short range scan of this quadrant. Docking happens when you scan next to a starbase.")
                    command("LRS", "Long range scan of the surrounding quadrants. Each cell shows enemies, bases, stars.")
                    command("LAS", "Fire \(lexicon.beamWeapon.lowercased())s. Energy is split across every enemy in the quadrant and weakens with distance.")
                    command("TOR", "Fire a torpedo along a course. Tap an enemy to aim. It stops at the first thing it hits.")
                    command("SHE", "Move energy between shields and reserve. Shields absorb hits; total energy stays the same.")
                    command("DAM", "Damage report. Negative is damaged, positive is a cushion against later hits.")
                    command("COM", "Library computer: galactic record, status, torpedo data, starbase bearing, region map, help.")
                    command("XXX", "Resign command.")
                }
                section("COURSES") {
                    Text("  4  3  2\n   \\ | /\n 5 - * - 1\n   / | \\\n  6  7  8")
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.dim)
                    para("Course 1 is east and the numbers run counterclockwise. Fractions point between them: 1.5 is halfway from east to northeast. Warp 1 moves 8 sectors, a full quadrant. Any warp of 1 or more costs one stardate, so a long jump costs no more time than a short one.")
                }
                section("STRATEGY") {
                    tip("Keep shields up in any quadrant with enemies. Enemy fire lands on your shields, and a hit that empties them destroys the ship.")
                    tip("Scan before you jump. A long range scan shows what waits in the quadrants around you.")
                    tip("Torpedoes are sure kills but limited to ten. Lasers cost energy but never run out. Use torpedoes on distant or dangerous targets and lasers up close.")
                    tip("Each move costs its length in sectors plus ten energy. Never let total energy fall near ten, or the ship is stranded.")
                    tip("Cross the galaxy in one jump. Time, not distance, is the scarce resource.")
                    tip("Go home when you are hurt. A starbase repairs everything, and starbase shields protect a docked ship.")
                    tip("Never fire a torpedo through a starbase. Fleet command remembers.")
                }
            }
            .padding(.bottom, 24)
        }
        .foregroundStyle(Theme.phosphor)
        .accessibilityIdentifier("help")
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.mono(13, weight: .bold))
            content()
        }
    }

    private func legend(_ glyph: String, _ text: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(glyph).font(Theme.mono(13, weight: .bold)).foregroundStyle(color).frame(width: 34, alignment: .leading)
            Text(text).font(Theme.mono(11)).foregroundStyle(Theme.phosphor.opacity(0.85))
        }
    }

    private func command(_ code: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(code).font(Theme.mono(12, weight: .bold)).frame(width: 34, alignment: .leading)
            Text(text).font(Theme.mono(11)).foregroundStyle(Theme.phosphor.opacity(0.85))
        }
    }

    private func para(_ text: String) -> some View {
        Text(text).font(Theme.mono(11)).foregroundStyle(Theme.phosphor.opacity(0.85))
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").font(Theme.mono(11))
            Text(text).font(Theme.mono(11)).foregroundStyle(Theme.phosphor.opacity(0.85))
        }
    }
}
