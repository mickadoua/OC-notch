import SpriteKit
import AppKit

enum PixelSpriteGenerator {

    // MARK: - Palette

    private static let pink = NSColor(red: 0.98, green: 0.58, blue: 0.74, alpha: 1)
    private static let pinkShadow = NSColor(red: 0.90, green: 0.38, blue: 0.58, alpha: 1)
    private static let redShoes = NSColor(red: 0.88, green: 0.16, blue: 0.32, alpha: 1)
    private static let blush = NSColor(red: 0.96, green: 0.34, blue: 0.56, alpha: 1)
    private static let black = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    private static let white = NSColor.white
    private static let starYellow = NSColor(red: 1.0, green: 0.93, blue: 0.22, alpha: 1)

    static func generateTextures(for state: AvatarState, size: CGSize) -> [SKTexture] {
        return (0..<state.frameCount).map { frame in
            let image = renderFrame(state: state, frame: frame, size: size)
            let texture = SKTexture(image: image)
            texture.filteringMode = .nearest
            return texture
        }
    }

    // MARK: - Rendering

    private static func renderFrame(state: AvatarState, frame: Int, size: CGSize) -> NSImage {
        let gridW = Int(size.width)
        let gridH = Int(size.height)

        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let grid = buildGrid(state: state, frame: frame, w: gridW, h: gridH)

        for y in 0..<gridH {
            for x in 0..<gridW {
                let color = grid[y][x]
                if color != .clear {
                    color.setFill()
                    NSRect(
                        x: CGFloat(x),
                        y: CGFloat(gridH - 1 - y),
                        width: 1,
                        height: 1
                    ).fill()
                }
            }
        }

        image.unlockFocus()
        return image
    }

    private static func buildGrid(state: AvatarState, frame: Int, w: Int, h: Int) -> [[NSColor]] {
        var grid = Array(repeating: Array(repeating: NSColor.clear, count: w), count: h)
        let cx = w / 2
        let by = h / 2

        switch state {
        case .idle:      drawIdle(grid: &grid, frame: frame, cx: cx, by: by)
        case .thinking:  drawThinking(grid: &grid, frame: frame, cx: cx, by: by)
        case .alert:     drawAlert(grid: &grid, frame: frame, cx: cx, by: by)
        case .celebrate: drawCelebrate(grid: &grid, frame: frame, cx: cx, by: by)
        }

        return grid
    }

    // MARK: - Anatomy Shapes

    // A perfect, squishy circle
    private static let bodyShape: [(dy: Int, hw: Int)] = [
        (-7, 3), (-6, 5), (-5, 6), (-4, 7), (-3, 8),
        (-2, 8), (-1, 8), ( 0, 8), ( 1, 8), ( 2, 8),
        ( 3, 7), ( 4, 6), ( 5, 4)
    ]

    private static func body(_ grid: inout [[NSColor]], cx: Int, by: Int, dx: Int = 0, dy: Int = 0) {
        for row in bodyShape {
            for x in -row.hw...row.hw {
                set(&grid, cx + x + dx, by + row.dy + dy, pink)
            }
        }
        
        // Slight shadow at the bottom edge for depth
        for x in -3...3 { set(&grid, cx + x + dx, by + 5 + dy, pinkShadow) }
        for x in -5...5 { set(&grid, cx + x + dx, by + 4 + dy, pinkShadow) }
    }

    private static func feet(_ grid: inout [[NSColor]], cx: Int, by: Int, dx: Int = 0, dy: Int = 0) {
        for side in [-1, 1] {
            let fx = cx + (side * 5) + dx
            let fy = by + 5 + dy
            
            // Plump oval red shoes
            for y in 0...2 {
                let hw = (y == 1) ? 3 : 2
                for x in -hw...hw {
                    set(&grid, fx + x, fy + y, redShoes)
                }
            }
        }
    }

    private static func arms(_ grid: inout [[NSColor]], cx: Int, by: Int, dx: Int = 0, dy: Int = 0, raised: Bool = false) {
        let ay = raised ? by - 4 + dy : by + 1 + dy
        
        for side in [-1, 1] {
            let ax = cx + (side * 8) + dx
            
            // 3x3 rounded nubs attached to the body
            set(&grid, ax, ay - 1, pink)
            set(&grid, ax + side, ay, pink)
            set(&grid, ax + side, ay + 1, pink)
            set(&grid, ax, ay + 1, pink)
            
            // Outline shadow for contrast
            set(&grid, ax + side * 2, ay, pinkShadow)
            set(&grid, ax + side, ay + 2, pinkShadow)
        }
    }

    // MARK: - Face Features

    private static func face(_ grid: inout [[NSColor]], cx: Int, by: Int, dx: Int = 0, dy: Int = 0, state: AvatarState) {
        let eyeY = by - 3 + dy
        
        for side in [-1, 1] {
            let ex = cx + (side * 2) + dx
            
            if state == .celebrate {
                // Happy ^ ^ eyes
                set(&grid, ex - 1, eyeY, black)
                set(&grid, ex, eyeY - 1, black)
                set(&grid, ex + 1, eyeY, black)
            } else {
                // Classic tall oval eyes
                for y in -1...2 {
                    set(&grid, ex, eyeY + y, black)
                }
                // Shine (top center of the eye oval)
                set(&grid, ex, eyeY - 1, white)
            }
            
            // Deep pink blush
            set(&grid, ex + (side * 3), eyeY + 3, blush)
            set(&grid, ex + (side * 4), eyeY + 3, blush)
        }

        // Mouth
        let mouthY = by + 1 + dy
        switch state {
        case .idle:
            // Tiny cute smile
            set(&grid, cx + dx, mouthY, black)
        case .thinking:
            // Holding breath (puffed out)
            set(&grid, cx - 1 + dx, mouthY, black)
            set(&grid, cx + 1 + dx, mouthY, black)
            set(&grid, cx + dx, mouthY - 1, black)
            set(&grid, cx + dx, mouthY + 1, black)
        case .alert:
            // The INHALE! Massive black void.
            for mx in -3...3 {
                for my in -1...4 {
                    if abs(mx) == 3 && (my == -1 || my == 4) { continue } // round corners
                    set(&grid, cx + mx + dx, mouthY + my, black)
                }
            }
            // Deep throat gradient
            set(&grid, cx + dx, mouthY + 2, pinkShadow)
            set(&grid, cx - 1 + dx, mouthY + 2, pinkShadow)
            set(&grid, cx + 1 + dx, mouthY + 2, pinkShadow)
        case .celebrate:
            // Open, happy mouth
            set(&grid, cx - 1 + dx, mouthY, black)
            set(&grid, cx + dx, mouthY, black)
            set(&grid, cx + 1 + dx, mouthY, black)
            set(&grid, cx + dx, mouthY + 1, redShoes) // Little red tongue
        }
    }

    // MARK: - Animations

    private static func drawIdle(grid: inout [[NSColor]], frame: Int, cx: Int, by: Int) {
        let bob = frame % 2 == 0 ? 0 : 1 // Gentle squish/breathe

        feet(&grid, cx: cx, by: by) // Planted firmly
        arms(&grid, cx: cx, by: by, dy: bob)
        body(&grid, cx: cx, by: by, dy: bob)
        face(&grid, cx: cx, by: by, dy: bob, state: .idle)
    }

    private static func drawThinking(grid: inout [[NSColor]], frame: Int, cx: Int, by: Int) {
        // Kirby puffing up and floating slightly!
        let float = frame % 2 == 0 ? -1 : -2
        
        feet(&grid, cx: cx, by: by, dy: float)
        arms(&grid, cx: cx, by: by, dy: float, raised: true) // Arms act as wings
        body(&grid, cx: cx, by: by, dy: float)
        face(&grid, cx: cx, by: by, dy: float, state: .thinking)
    }

    private static func drawAlert(grid: inout [[NSColor]], frame: Int, cx: Int, by: Int) {
        // Firmly planted, leaning back slightly to inhale
        let pull = 1
        
        feet(&grid, cx: cx, by: by)
        arms(&grid, cx: cx, by: by, raised: true) // Arms up to channel energy
        body(&grid, cx: cx, by: by)
        face(&grid, cx: cx, by: by, state: .alert)

        // Inhale Star Particles drawing inwards
        if frame >= 1 {
            let distance = frame == 1 ? 9 : 5
            let sparks = [(-1, 0), (1, 0), (-1, -1), (1, -1)]
            for s in sparks {
                let sx = cx + (s.0 * distance)
                let sy = by + 2 + (s.1 * distance)
                set(&grid, sx, sy, starYellow)
                set(&grid, sx + 1, sy, starYellow)
                set(&grid, sx, sy + 1, starYellow)
            }
        }
    }

    private static func drawCelebrate(grid: inout [[NSColor]], frame: Int, cx: Int, by: Int) {
        let bounce = frame % 2 == 0 ? 0 : -3
        let sway = (frame / 2) % 2 == 0 ? -1 : 1

        feet(&grid, cx: cx, by: by, dx: sway, dy: bounce)
        arms(&grid, cx: cx, by: by, dx: sway, dy: bounce, raised: true)
        body(&grid, cx: cx, by: by, dx: sway, dy: bounce)
        face(&grid, cx: cx, by: by, dx: sway, dy: bounce, state: .celebrate)

        // Classic warp star sparkles!
        if frame % 2 == 0 {
            let stars = [(-8, -6), (8, -4), (0, -10)]
            for s in stars {
                set(&grid, cx + s.0 + sway, by + s.1 + bounce, starYellow)
            }
        } else {
            let stars = [(-6, -8), (6, -7), (-3, -11)]
            for s in stars {
                set(&grid, cx + s.0 + sway, by + s.1 + bounce, starYellow)
            }
        }
    }

    // MARK: - Safe Pixel Setter

    private static func set(_ grid: inout [[NSColor]], _ x: Int, _ y: Int, _ c: NSColor) {
        guard y >= 0, y < grid.count, x >= 0, x < grid[0].count else { return }
        grid[y][x] = c
    }
}