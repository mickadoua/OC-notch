import SwiftUI

enum NeoHaloState {
    case none
    case thinking
    case permission
    case question
}

struct NeoHaloOverlay: View {
    let state: NeoHaloState
    let cornerRadius: CGFloat
    /// Hardware notch dimensions — all halos are constrained to this size.
    var notchSize: CGSize? = nil

    var body: some View {
        Group {
            switch state {
            case .none:
                EmptyView()
            case .thinking:
                if let size = notchSize {
                    ProgressingHalo(cornerRadius: cornerRadius, glowInset: Self.glowInset)
                        .frame(width: size.width + Self.glowInset * 2, height: size.height + Self.glowInset * 2)
                } else {
                    ProgressingHalo(cornerRadius: cornerRadius, glowInset: 0)
                }
            case .permission:
                haloFrame { FlashingHalo(color: DS.Colors.accentOrange, cornerRadius: cornerRadius) }
            case .question:
                haloFrame { SteadyHalo(color: DS.Colors.accentBlue, cornerRadius: cornerRadius) }
            }
        }
        .allowsHitTesting(false)
    }

    /// Extra room around the stroke so the blur/glow is visible on all sides.
    static let glowInset: CGFloat = 18

    @ViewBuilder
    private func haloFrame<V: View>(@ViewBuilder content: () -> V) -> some View {
        if let size = notchSize {
            content()
                .frame(width: size.width, height: size.height)
        } else {
            content()
        }
    }

    /// Notch shape: flat top, rounded bottom corners.
    static func notchShape(cornerRadius: CGFloat) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: cornerRadius,
            topTrailingRadius: 0,
            style: .continuous
        )
    }
}

// MARK: - Thinking Halo (perimeter trace)

private struct ProgressingHalo: View {
    let cornerRadius: CGFloat
    var glowInset: CGFloat = 0

    private let duration: Double = 2.4
    private let trailLength: Double = 0.30

    private func phase(for date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        return (t.truncatingRemainder(dividingBy: duration)) / duration
    }

    /// Notch perimeter path: flat top, rounded bottom corners.
    /// Starts top-left → down left → bottom-left corner → across bottom →
    /// bottom-right corner → up right → top-right → across top → back.
    private func perimeterPath(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        var p = Path()

        // Start: top-left corner (square — flush with screen edge)
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Down left side
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))

        // Bottom-left corner (rounded)
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        // Across bottom
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY))

        // Bottom-right corner (rounded)
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - r),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        // Up right side
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // Across top (straight — flush with screen edge)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return p
    }

    var body: some View {
        TimelineView(.animation) { context in
            let p = phase(for: context.date)
            Canvas { ctx, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: glowInset, dy: glowInset)
                let path = perimeterPath(in: rect)

                let head = p
                let tail = head - trailLength

                let trimmed: Path
                if tail >= 0 {
                    trimmed = path.trimmedPath(from: tail, to: head)
                } else {
                    var combined = path.trimmedPath(from: 1.0 + tail, to: 1.0)
                    combined.addPath(path.trimmedPath(from: 0, to: head))
                    trimmed = combined
                }

                let style = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                let coreStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)

                // Glow layer
                ctx.drawLayer { glow in
                    glow.addFilter(.blur(radius: 6))
                    glow.stroke(trimmed, with: .color(DS.Colors.accentGreen.opacity(0.8)), style: style)
                }

                // Sharp core
                ctx.stroke(trimmed, with: .color(DS.Colors.accentGreen), style: coreStyle)
            }
        }
    }
}

// MARK: - Permission Halo (flashing orange)

private struct FlashingHalo: View {
    let color: Color
    let cornerRadius: CGFloat

    private func intensity(for date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        let raw = sin(t * 2 * .pi * 2.2)
        return 0.25 + ((raw + 1) / 2) * 0.75
    }

    var body: some View {
        TimelineView(.animation) { context in
            flashFrame(date: context.date)
        }
    }

    @ViewBuilder
    private func flashFrame(date: Date) -> some View {
        let i = intensity(for: date)
        Canvas { ctx, size in
            let path = NeoHaloOverlay.notchShape(cornerRadius: cornerRadius)
                .path(in: CGRect(origin: .zero, size: size))
            let glowStyle = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            let coreStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            ctx.drawLayer { glow in
                glow.addFilter(.blur(radius: 6))
                glow.stroke(path, with: .color(color.opacity(i * 0.9)), style: glowStyle)
            }
            ctx.stroke(path, with: .color(color.opacity(i)), style: coreStyle)
        }
    }
}

// MARK: - Question Halo (subtle flash blue)

private struct SteadyHalo: View {
    let color: Color
    let cornerRadius: CGFloat

    private func opacity(for date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        let raw = sin(t * 2 * .pi * 1.2)
        return 0.4 + ((raw + 1) / 2) * 0.6
    }

    var body: some View {
        TimelineView(.animation) { context in
            steadyFrame(date: context.date)
        }
    }

    @ViewBuilder
    private func steadyFrame(date: Date) -> some View {
        let o = opacity(for: date)
        Canvas { ctx, size in
            let path = NeoHaloOverlay.notchShape(cornerRadius: cornerRadius)
                .path(in: CGRect(origin: .zero, size: size))
            let glowStyle = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            let coreStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            ctx.drawLayer { glow in
                glow.addFilter(.blur(radius: 6))
                glow.stroke(path, with: .color(color.opacity(o * 0.9)), style: glowStyle)
            }
            ctx.stroke(path, with: .color(color.opacity(o)), style: coreStyle)
        }
    }
}
