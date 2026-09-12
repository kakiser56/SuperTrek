import SwiftUI
import TrekEngine

/// The nine-point compass as a dial. Drag anywhere on it to set a course;
/// the needle follows the original's square interpolation, so course 1.5
/// points where the ship would actually go.
struct CourseDial: View {
    @Binding var course: Double
    var tint: Color = Theme.phosphor

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2
            ZStack {
                Circle().stroke(Theme.dim, lineWidth: 1).frame(width: size, height: size)
                Circle().stroke(Theme.dim.opacity(0.4), lineWidth: 1).frame(width: size * 0.5, height: size * 0.5)
                ForEach(1...8, id: \.self) { point in
                    let p = position(forCourse: Double(point), center: center, radius: radius * 0.82)
                    Text("\(point)")
                        .font(Theme.mono(11, weight: .bold))
                        .foregroundStyle(Theme.dim)
                        .position(p)
                }
                Path { path in
                    path.move(to: center)
                    path.addLine(to: position(forCourse: course, center: center, radius: radius * 0.62))
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                Circle().fill(tint).frame(width: 8, height: 8)
                    .position(position(forCourse: course, center: center, radius: radius * 0.62))
                Circle().fill(Theme.dim).frame(width: 4, height: 4).position(center)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        guard abs(dx) + abs(dy) > 6 else { return }
                        let heading = Course.heading(fromRow: 0, fromCol: 0, toRow: dy, toCol: dx)
                        course = (heading.course * 100).rounded() / 100
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Course dial")
        .accessibilityValue(String(format: "%.2f", course))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: course = min(8.99, course + 0.25)
            case .decrement: course = max(1, course - 0.25)
            @unknown default: break
            }
        }
    }

    private func position(forCourse course: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let v = Course.vector(course)
        let length = max(0.0001, (v.dRow * v.dRow + v.dCol * v.dCol).squareRoot())
        return CGPoint(x: center.x + v.dCol / length * radius, y: center.y + v.dRow / length * radius)
    }
}
