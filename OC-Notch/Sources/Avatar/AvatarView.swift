import SwiftUI
import SpriteKit

/// SwiftUI wrapper for the SpriteKit avatar scene.
struct AvatarView: View {
    let scene: AvatarScene
    var size: CGFloat = 36

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 10, options: [.allowsTransparency])
            .frame(width: size, height: size)
            .background(.clear)
            .allowsHitTesting(false)
    }
}
