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
    var body: some View {
        NotchMaterialSurface().modifier(NotchAppearanceModifier())
    }
}

private struct NotchMaterialSurface: View {
    @AppStorage("notchOpacity") private var opacity = 0.9
    @AppStorage("notchReduceTransparency") private var opaque = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let shape = ExpandedNotchShape()

    var body: some View {
        Group {
            if reduceTransparency || opaque {
                shape.fill(scheme == .dark ? Color(white: 0.10) : Color(white: 0.95))
            } else if #available(macOS 26, *) {
                Color.clear.glassEffect(.regular.tint(scheme == .dark ? .black.opacity(0.34) : .white.opacity(0.2)), in: shape)
            } else {
                shape.fill(.regularMaterial)
            }
        }
        .opacity(reduceTransparency || opaque ? 1 : min(1, max(0.35, opacity)))
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
