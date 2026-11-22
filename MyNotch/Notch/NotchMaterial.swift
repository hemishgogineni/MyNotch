import SwiftUI

/// The top corners flare outward where the panel meets the menu bar.
struct ExpandedNotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let lip = min(9, rect.width / 8)
        let radius = min(19, rect.height / 2, rect.width / 4)
        let w = rect.width
        let h = rect.height
        return Path { path in
            path.move(to: .zero)
            path.addQuadCurve(to: CGPoint(x: lip, y: lip), control: CGPoint(x: lip, y: 0))
            path.addLine(to: CGPoint(x: lip, y: h - radius))
            path.addArc(tangent1End: CGPoint(x: lip, y: h),
                        tangent2End: CGPoint(x: w / 2, y: h), radius: radius)
            path.addLine(to: CGPoint(x: w - lip - radius, y: h))
            path.addArc(tangent1End: CGPoint(x: w - lip, y: h),
                        tangent2End: CGPoint(x: w - lip, y: 0), radius: radius)
            path.addLine(to: CGPoint(x: w - lip, y: lip))
            path.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w - lip, y: 0))
            path.closeSubpath()
        }
    }
}

struct NotchMaterial: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let shape = ExpandedNotchShape()

    var body: some View {
        Group {
            if reduceTransparency {
                shape.fill(Color(white: 0.10))
            } else if #available(macOS 26, *) {
                Color.clear.glassEffect(.regular.tint(.black.opacity(0.34)), in: shape)
            } else {
                shape.fill(.regularMaterial)
            }
        }
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
