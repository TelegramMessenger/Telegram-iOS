import Foundation

enum TLottieTestFixtures {
    /// A composition filled edge to edge with red, fading from fully opaque at
    /// frame 0 to transparent at the last frame.
    ///
    /// Two properties matter for the tests built on it:
    ///
    /// - The fill is solid, so interior pixels at frame 0 are exact regardless
    ///   of the rasterizer's antialiasing, and pixel assertions are meaningful.
    /// - The opacity is *animated*. tlottie's `Composition::frame_count()`
    ///   returns 1 for any composition it can prove static, so a motionless
    ///   fixture would report one frame rather than `frameCount`.
    static func solidRed(width: Int = 32, height: Int = 32,
                         frameRate: Int = 60, frameCount: Int = 60) -> Data {
        let opacity = """
        {"a":1,"k":[\
        {"i":{"x":[1],"y":[1]},"o":{"x":[0],"y":[0]},"t":0,"s":[100],"e":[0]},\
        {"t":\(frameCount),"s":[0]}]}
        """
        return self.composition(width: width, height: height,
                                frameRate: frameRate, frameCount: frameCount,
                                layerOpacity: opacity)
    }

    /// The same composition with a constant opacity, so tlottie can prove it
    /// static. Used only to pin the frame-count divergence between backends.
    static func staticSolidRed(width: Int = 32, height: Int = 32,
                               frameRate: Int = 60, frameCount: Int = 60) -> Data {
        return self.composition(width: width, height: height,
                                frameRate: frameRate, frameCount: frameCount,
                                layerOpacity: "{\"a\":0,\"k\":100}")
    }

    private static func composition(width: Int, height: Int,
                                    frameRate: Int, frameCount: Int,
                                    layerOpacity: String) -> Data {
        let json = """
        {"v":"5.5.2","fr":\(frameRate),"ip":0,"op":\(frameCount),\
        "w":\(width),"h":\(height),"nm":"t","ddd":0,"assets":[],\
        "layers":[{"ddd":0,"ind":1,"ty":4,"nm":"r","sr":1,\
        "ks":{"o":\(layerOpacity),"r":{"a":0,"k":0},\
        "p":{"a":0,"k":[\(width / 2),\(height / 2),0]},\
        "a":{"a":0,"k":[0,0,0]},"s":{"a":0,"k":[100,100,100]}},"ao":0,\
        "shapes":[{"ty":"gr","it":[\
        {"ty":"rc","d":1,"s":{"a":0,"k":[\(width),\(height)]},\
        "p":{"a":0,"k":[0,0]},"r":{"a":0,"k":0},"nm":"p"},\
        {"ty":"fl","c":{"a":0,"k":[1,0,0,1]},"o":{"a":0,"k":100},"r":1,"nm":"f"},\
        {"ty":"tr","p":{"a":0,"k":[0,0]},"a":{"a":0,"k":[0,0]},\
        "s":{"a":0,"k":[100,100]},"r":{"a":0,"k":0},"o":{"a":0,"k":100}}],\
        "nm":"g"}],"ip":0,"op":\(frameCount),"st":0,"bm":0}]}
        """
        return json.data(using: .utf8)!
    }
}
