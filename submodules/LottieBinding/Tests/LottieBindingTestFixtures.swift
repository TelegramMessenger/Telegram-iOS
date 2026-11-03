import Foundation

/// A duplicate of TLottieTestFixtures, deliberately. Sharing it would mean a
/// testonly module that both packages depend on, which is a heavier price than
/// ~20 lines of fixture JSON.
enum LottieBindingTestFixtures {
    /// A composition filled edge to edge with red, fading from fully opaque at
    /// frame 0 to transparent at the last frame.
    ///
    /// The opacity is *animated* on purpose: tlottie's `frame_count()` returns 1
    /// for any composition it can prove static, so a motionless fixture would
    /// make the two backends disagree on metadata for a reason that has nothing
    /// to do with the factory.
    static func solidRed(width: Int = 32, height: Int = 32,
                         frameRate: Int = 60, frameCount: Int = 60) -> Data {
        let opacity = """
        {"a":1,"k":[\
        {"i":{"x":[1],"y":[1]},"o":{"x":[0],"y":[0]},"t":0,"s":[100],"e":[0]},\
        {"t":\(frameCount),"s":[0]}]}
        """
        let json = """
        {"v":"5.5.2","fr":\(frameRate),"ip":0,"op":\(frameCount),\
        "w":\(width),"h":\(height),"nm":"t","ddd":0,"assets":[],\
        "layers":[{"ddd":0,"ind":1,"ty":4,"nm":"r","sr":1,\
        "ks":{"o":\(opacity),"r":{"a":0,"k":0},\
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
