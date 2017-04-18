import Foundation
import UIKit
import GLKit
import OpenGLES
import Display
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import TelegramCore

private final class MultiplexedSoftwareVideoTrackingNode: ASDisplayNode {
    var inHierarchyUpdated: ((Bool) -> Void)?
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.inHierarchyUpdated?(true)
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.inHierarchyUpdated?(false)
    }
}

private final class VisibleVideoItem {
    let file: TelegramMediaFile
    let frame: CGRect
    
    init(file: TelegramMediaFile, frame: CGRect) {
        self.file = file
        self.frame = frame
    }
}

private enum UniformIndex: Int {
    case Y = 0
    case UV
    case RotationAngle
    case ColorConversionMatrix
}

private enum AttributeIndex: GLuint {
    case Vertex = 0
    case TextureCoordinates
    case NumAttributes
}

private let colorConversion601: [GLfloat] = [
    1.164, 1.164, 1.164,
    0.0, -0.392, 2.017,
    1.596, -0.813, 0.0
]

private let colorConversion709: [GLfloat] = [
    1.164, 1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533, 0.0
]

private let fragmentShaderSource: Data = {
    return try! Data(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "VTPlayer/VTPlayer_Shader", ofType: "fsh")!))
}()

private let vertexShaderSource: Data = {
    return try! Data(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "VTPlayer/VTPlayer_Shader", ofType: "vsh")!))
}()

private final class SoftwareVideoFrames {
    var frames: [MediaId: MediaTrackFrame] = [:]
}

final class MultiplexedSoftwareVideoNode: UIView {
    override class var layerClass: AnyClass {
        return CAEAGLLayer.self
    }
    
    private var eglLayer: CAEAGLLayer {
        return self.layer as! CAEAGLLayer
    }
    
    private let account: Account
    private let scrollView: UIScrollView
    private let trackingNode: MultiplexedSoftwareVideoTrackingNode
    
    private let context: EAGLContext
    private var uniforms: [GLint]
    private var program: GLuint = 0
    private var videoTextureCache: CVOpenGLESTextureCache?
    
    private var drawableSize: CGSize?
    
    private var frameBufferHandle: GLuint?
    private var colorBufferHandle: GLuint?
    
    private var displayLink: CADisplayLink!
    
    var files: [TelegramMediaFile] = [] {
        didSet {
            self.updateVisibleItems()
        }
    }
    private var displayItems: [VisibleVideoItem] = []
    private let sourceManager: MultiplexedSoftwareVideoSourceManager
    
    private let videoSourceQueue = Queue()
    
    init(account: Account, scrollView: UIScrollView) {
        self.account = account
        self.scrollView = scrollView
        self.trackingNode = MultiplexedSoftwareVideoTrackingNode()
        self.sourceManager = MultiplexedSoftwareVideoSourceManager(queue: self.videoSourceQueue, account: account)
        
        self.context = EAGLContext(api: .openGLES2)
        
        var videoTextureCache: CVOpenGLESTextureCache?
        CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, self.context, nil, &videoTextureCache)
        self.videoTextureCache = videoTextureCache
        
        self.uniforms = Array(repeating: 0, count: 4)
        
        super.init(frame: CGRect())
        
        self.isUserInteractionEnabled = false
        self.layer.contentsScale = 2.0
        self.isOpaque = true
        
        self.addSubnode(self.trackingNode)
        
        self.eglLayer.drawableProperties = [
            kEAGLDrawablePropertyRetainedBacking: false as NSNumber,
            kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
        ]
        
        EAGLContext.setCurrent(self.context)
        
        glDisable(GLenum(GL_DEPTH_TEST))
        
        glEnableVertexAttribArray(AttributeIndex.Vertex.rawValue)
        glVertexAttribPointer(AttributeIndex.Vertex.rawValue, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(2 * MemoryLayout<GLfloat>.size), nil)
        
        glEnableVertexAttribArray(AttributeIndex.TextureCoordinates.rawValue)
        
        glVertexAttribPointer(AttributeIndex.TextureCoordinates.rawValue, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), GLsizei(2 * MemoryLayout<GLfloat>.size), nil)
        
        self.loadShaders()
        
        glUseProgram(self.program)
        
        // 0 and 1 are the texture IDs of lumaTexture and chromaTexture respectively.
        glUniform1i(self.uniforms[UniformIndex.Y.rawValue], 0)
        glUniform1i(self.uniforms[UniformIndex.UV.rawValue], 1)
        
        glUniform1f(self.uniforms[UniformIndex.RotationAngle.rawValue], 0.0)
        
        glUniformMatrix3fv(self.uniforms[UniformIndex.ColorConversionMatrix.rawValue], 1, GLboolean(GL_FALSE), colorConversion709)
        
        class DisplayLinkProxy: NSObject {
            weak var target: MultiplexedSoftwareVideoNode?
            init(target: MultiplexedSoftwareVideoNode) {
                self.target = target
            }
            
            @objc func displayLinkEvent() {
                self.target?.displayLinkEvent()
            }
        }
        
        self.displayLink = CADisplayLink(target: DisplayLinkProxy(target: self), selector: #selector(DisplayLinkProxy.displayLinkEvent))
        self.displayLink.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
        if #available(iOS 10.0, *) {
            self.displayLink.preferredFramesPerSecond = 60
        }
        self.displayLink.isPaused = true
        
        self.trackingNode.inHierarchyUpdated = { [weak self] value in
            if let strongSelf = self {
                strongSelf.displayLink.isPaused = !value
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        
        if var frameBufferHandle = self.frameBufferHandle {
            glDeleteFramebuffers(1, &frameBufferHandle)
        }
        
        if var colorBufferHandle = self.colorBufferHandle {
            glDeleteFramebuffers(1, &colorBufferHandle)
        }
    }
    
    private func compileShaderWithType(shaderType: GLuint) -> GLuint? {
        let source = shaderType == UInt32(GL_FRAGMENT_SHADER) ? fragmentShaderSource : vertexShaderSource
        
        let shader = glCreateShader(shaderType)
        source.withUnsafeBytes { (bytes: UnsafePointer<GLchar>) -> Void in
            var bytes: UnsafePointer<GLchar>? = bytes
            var length = GLint(source.count)
            withUnsafePointer(to: &bytes, { (bytesRef: UnsafePointer<UnsafePointer<GLchar>?>) -> Void in
                glShaderSource(shader, 1, bytesRef, &length)
            })
        }
        
        glCompileShader(shader)
        
        var logLength: GLsizei = 0
        glGetShaderInfoLog(shader, 0, &logLength, nil)
        if logLength != 0 {
            var log = Data(count: Int(logLength))
            
            log.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<GLchar>) -> Void in
                glGetShaderInfoLog(shader, logLength, &logLength, bytes)
            }
            
            if let logString = String(data: log, encoding: .utf8) {
                print("Shader log: \(logString)")
            }
        }
        
        return shader
    }
    
    private func loadShaders() {
        self.program = glCreateProgram()
        
        guard let vertShader = self.compileShaderWithType(shaderType: GLuint(GL_VERTEX_SHADER)) else {
            return
        }
        
        guard let fragShader = self.compileShaderWithType(shaderType: GLuint(GL_FRAGMENT_SHADER)) else {
            return
        }
        
        glAttachShader(self.program, vertShader)
        glAttachShader(self.program, fragShader)
        
        glBindAttribLocation(self.program, AttributeIndex.Vertex.rawValue, "position")
        glBindAttribLocation(self.program, AttributeIndex.TextureCoordinates.rawValue, "texCoord")
        
        glLinkProgram(self.program)
        
        var status: GLint = 0
        glGetProgramiv(self.program, GLenum(GL_LINK_STATUS), &status)
        let ok = (status != 0)
        if (ok) {
            self.uniforms[UniformIndex.Y.rawValue] = glGetUniformLocation(self.program, "SamplerY")
            self.uniforms[UniformIndex.UV.rawValue] = glGetUniformLocation(self.program, "SamplerUV")
            self.uniforms[UniformIndex.RotationAngle.rawValue] = glGetUniformLocation(self.program, "preferredRotation")
            self.uniforms[UniformIndex.ColorConversionMatrix.rawValue] = glGetUniformLocation(self.program, "colorConversionMatrix")
        }
        
        glDetachShader(self.program, vertShader)
        glDeleteShader(vertShader)
    
        glDetachShader(self.program, fragShader)
        glDeleteShader(fragShader)
    
        if (!ok) {
            glDeleteProgram(self.program)
            self.program = 0
        }
        
        assert(ok)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.updateDrawable()
    }
    
    private func displayLinkEvent() {
        self.draw()
    }
    
    private var validVisibleItemsOffset: CGFloat?
    private func updateImmediatelyVisibleItems() {
        let visibleBounds = self.scrollView.bounds
        if let validVisibleItemsOffset = self.validVisibleItemsOffset, validVisibleItemsOffset.isEqual(to: visibleBounds.origin.y) {
            return
        }
        self.validVisibleItemsOffset = visibleBounds.origin.y
        let minVisibleY = visibleBounds.minY
        let maxVisibleY = visibleBounds.maxY
        
        var visibleItems: [TelegramMediaFile] = []
        for item in self.displayItems {
            if item.frame.maxY < minVisibleY {
                continue;
            }
            if item.frame.minY > maxVisibleY {
                break;
            }
            visibleItems.append(item.file)
        }
        
        self.sourceManager.updateVisibleItems(visibleItems)
    }
    
    private func draw() {
        EAGLContext.setCurrent(self.context)
        
        let timestamp = CACurrentMediaTime()
        
        self.updateImmediatelyVisibleItems()
        self.sourceManager.update(at: timestamp)
        
        if let drawableSize = self.drawableSize, let frameBufferHandle = self.frameBufferHandle, let colorBufferHandle = self.colorBufferHandle {
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBufferHandle)
            
            let backingWidth = GLint(drawableSize.width * 2.0)
            let backingHeight = GLint(drawableSize.height * 2.0)
            
            glViewport(0, 0, backingWidth, backingHeight)
            
            glClearColor(1.0, 1.0, 1.0, 1.0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            
            glUseProgram(self.program)
            glUniform1f(self.uniforms[UniformIndex.RotationAngle.rawValue], 0.0)
            glUniformMatrix3fv(self.uniforms[UniformIndex.ColorConversionMatrix.rawValue], 1, GLboolean(GL_FALSE), colorConversion709)
            
            glEnableVertexAttribArray(AttributeIndex.Vertex.rawValue)
            glEnableVertexAttribArray(AttributeIndex.TextureCoordinates.rawValue)
            
            let visibleBounds = self.scrollView.bounds
            let minVisibleY = visibleBounds.minY
            let maxVisibleY = visibleBounds.maxY
            let verticalOffset = visibleBounds.origin.y
            for item in self.displayItems {
                if item.frame.maxY < minVisibleY {
                    continue;
                }
                if item.frame.minY > maxVisibleY {
                    break;
                }
                
                if let videoFrame = self.sourceManager.immediateVideoFrames[item.file.fileId], let imageBuffer = CMSampleBufferGetImageBuffer(videoFrame.sampleBuffer) {
                    
                    let frameSize = CVImageBufferGetEncodedSize(imageBuffer)
                    let frameWidth = GLsizei(frameSize.width)
                    let frameHeight = GLsizei(frameSize.height)
                    
                    var lumaTextureRef: CVOpenGLESTexture?
                    var chromaTextureRef: CVOpenGLESTexture?
                    
                    glActiveTexture(GLenum(GL_TEXTURE0))
                    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.videoTextureCache!, imageBuffer, nil, GLenum(GL_TEXTURE_2D), GL_RED_EXT, frameWidth, frameHeight, GLenum(GL_RED_EXT), GLenum(GL_UNSIGNED_BYTE), 0, &lumaTextureRef);
                    guard let lumaTexture = lumaTextureRef else {
                        print("error creating lumaTexture")
                        continue
                    }
                    
                    glBindTexture(CVOpenGLESTextureGetTarget(lumaTexture), CVOpenGLESTextureGetName(lumaTexture))
                    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
                    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
                    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
                    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
                    
                    glActiveTexture(GLenum(GL_TEXTURE1))
                    
                    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.videoTextureCache!, imageBuffer, nil, GLenum(GL_TEXTURE_2D), GL_RG_EXT, frameWidth / 2, frameHeight / 2, GLenum(GL_RG_EXT), GLenum(GL_UNSIGNED_BYTE), 1, &chromaTextureRef)
                    
                    guard let chromaTexture = chromaTextureRef else {
                        print("error creating chromaTexture")
                        continue
                    }
                    
                    glBindTexture(CVOpenGLESTextureGetTarget(chromaTexture), CVOpenGLESTextureGetName(chromaTexture))
                    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
                    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
                    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
                    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
                }
            
                let normalSize = item.frame.size
                let normalOrigin = CGPoint(x: item.frame.origin.x, y: drawableSize.height - (item.frame.origin.y - verticalOffset) - normalSize.height)
                
                //let normalOrigin = CGPoint(x: 375.0 - 10.0, y: drawableSize.height - 100.0 - 10.0)
                //let normalSize = CGSize(width: 10.0, height: 10.0)
                
                let normalizedSamplingSize = CGSize(width: normalSize.width / drawableSize.width, height: normalSize.height / drawableSize.height)
                let normalizedOffset = CGPoint(x: -1.0 + normalOrigin.x * 2.0 / drawableSize.width + normalizedSamplingSize.width, y: -1.0 + normalOrigin.y * 2.0 / drawableSize.height + normalizedSamplingSize.height)
                
                let quadVertexData: [GLfloat] = [
                    Float(normalizedOffset.x - 1.0 * normalizedSamplingSize.width), Float(normalizedOffset.y - 1.0 * normalizedSamplingSize.height),
                    Float(normalizedOffset.x + normalizedSamplingSize.width), Float(normalizedOffset.y - 1.0 * normalizedSamplingSize.height),
                    Float(normalizedOffset.x - 1.0 * normalizedSamplingSize.width), Float(normalizedOffset.y + normalizedSamplingSize.height),
                    Float(normalizedOffset.x + normalizedSamplingSize.width), Float(normalizedOffset.y + normalizedSamplingSize.height)
                ]
                
                glVertexAttribPointer(AttributeIndex.Vertex.rawValue, 2, GLenum(GL_FLOAT), 0, 0, quadVertexData)
                
                let textureSamplingRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
                let quadTextureData: [GLfloat] = [
                    Float(textureSamplingRect.minX), Float(textureSamplingRect.maxY),
                    Float(textureSamplingRect.maxX), Float(textureSamplingRect.maxY),
                    Float(textureSamplingRect.minX), Float(textureSamplingRect.minY),
                    Float(textureSamplingRect.maxX), Float(textureSamplingRect.minY)
                ]
                glVertexAttribPointer(AttributeIndex.TextureCoordinates.rawValue, 2, GLenum(GL_FLOAT), 0, 0, quadTextureData);
                
                glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
            }
            
            glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorBufferHandle)
            self.context.presentRenderbuffer(Int(GL_RENDERBUFFER))
        }
    }
    
    private func updateDrawable() {
        if !self.bounds.size.width.isZero {
            if self.drawableSize == nil || self.drawableSize! != self.bounds.size {
                self.drawableSize = self.bounds.size
                
                if var frameBufferHandle = self.frameBufferHandle {
                    glDeleteFramebuffers(1, &frameBufferHandle)
                    self.frameBufferHandle = nil
                }
                
                if var colorBufferHandle = self.colorBufferHandle {
                    glDeleteFramebuffers(1, &colorBufferHandle)
                    self.colorBufferHandle = nil
                }
                
                var frameBufferHandle: GLuint = 0
                glGenFramebuffers(1, &frameBufferHandle);
                glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBufferHandle)
                
                var colorBufferHandle: GLuint = 0
                glGenRenderbuffers(1, &colorBufferHandle)
                glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorBufferHandle)
                self.context.renderbufferStorage(Int(GL_RENDERBUFFER), from: self.eglLayer)
                
                var backingWidth = GLint(self.bounds.size.width * 2.0)
                var backingHeight = GLint(self.bounds.size.height * 2.0)
                glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_WIDTH), &backingWidth)
                glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_HEIGHT), &backingHeight)
                
                glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), colorBufferHandle)
                
                if glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) != UInt32(GL_FRAMEBUFFER_COMPLETE) {
                    assertionFailure()
                }
                
                self.frameBufferHandle = frameBufferHandle
                self.colorBufferHandle = colorBufferHandle
                
                self.updateVisibleItems()
            }
        }
    }
    
    private func updateVisibleItems() {
        if let drawableSize = self.drawableSize {
            var displayItems: [VisibleVideoItem] = []
            
            let idealHeight: CGFloat = 93.0
            
            var weights: [Int] = []
            var totalItemSize: CGFloat = 0.0
            for item in self.files {
                let aspectRatio: CGFloat
                if let dimensions = item.dimensions {
                    aspectRatio = dimensions.width / dimensions.height
                } else {
                    aspectRatio = 1.0
                }
                weights.append(Int(aspectRatio * 100))
                totalItemSize += aspectRatio * idealHeight
            }
            
            let numberOfRows = max(Int(round(totalItemSize / drawableSize.width)), 1)
            
            let partition = linearPartitionForWeights(weights, numberOfPartitions:numberOfRows)
            
            var i = 0
            var offset = CGPoint(x: 0.0, y: 0.0)
            var previousItemSize: CGFloat = 0.0
            var contentMaxValueInScrollDirection: CGFloat = 0.0
            let maxWidth = drawableSize.width
            
            let minimumInteritemSpacing: CGFloat = 1.0
            let minimumLineSpacing: CGFloat = 1.0
            
            let viewportWidth: CGFloat = drawableSize.width
            
            let preferredRowSize = idealHeight
            
            var rowIndex = -1
            for row in partition {
                rowIndex += 1
                
                var summedRatios: CGFloat = 0.0
                
                var j = i
                var n = i + row.count
                
                while j < n {
                    let aspectRatio: CGFloat
                    if let dimensions = self.files[j].dimensions {
                        aspectRatio = dimensions.width / dimensions.height
                    } else {
                        aspectRatio = 1.0
                    }
                    
                    summedRatios += aspectRatio
                    
                    j += 1
                }
                
                var rowSize = drawableSize.width - (CGFloat(row.count - 1) * minimumInteritemSpacing)
                
                if rowIndex == partition.count - 1 {
                    if row.count < 2 {
                        rowSize = floor(viewportWidth / 3.0) - (CGFloat(row.count - 1) * minimumInteritemSpacing)
                    } else if row.count < 3 {
                        rowSize = floor(viewportWidth * 2.0 / 3.0) - (CGFloat(row.count - 1) * minimumInteritemSpacing)
                    }
                }
                
                j = i
                n = i + row.count
                
                while j < n {
                    let aspectRatio: CGFloat
                    if let dimensions = self.files[j].dimensions {
                        aspectRatio = dimensions.width / dimensions.height
                    } else {
                        aspectRatio = 1.0
                    }
                    let preferredAspectRatio = aspectRatio
                    
                    let actualSize = CGSize(width: round(rowSize / summedRatios * (preferredAspectRatio)), height: preferredRowSize)
                    
                    var frame = CGRect(x: offset.x, y: offset.y, width: actualSize.width, height: actualSize.height)
                    if frame.origin.x + frame.size.width >= maxWidth - 2.0 {
                        frame.size.width = max(1.0, maxWidth - frame.origin.x)
                    }
                    
                    displayItems.append(VisibleVideoItem(file: self.files[j], frame: frame))
                    
                    offset.x += actualSize.width + minimumInteritemSpacing
                    previousItemSize = actualSize.height
                    contentMaxValueInScrollDirection = frame.maxY
                    
                    j += 1
                }
                
                if row.count > 0 {
                    offset = CGPoint(x: 0.0, y: offset.y + previousItemSize + minimumLineSpacing)
                }
                
                i += row.count
            }
            let contentSize = CGSize(width: drawableSize.width, height: contentMaxValueInScrollDirection)
            self.scrollView.contentSize = contentSize
            
            self.displayItems = displayItems
            
            self.validVisibleItemsOffset = nil
            self.updateImmediatelyVisibleItems()
        }
    }
    
}

private func NH_LP_TABLE_LOOKUP(_ table: inout [Int], _ i: Int, _ j: Int, _ rowsize: Int) -> Int {
    return table[i * rowsize + j]
}

private func NH_LP_TABLE_LOOKUP_SET(_ table: inout [Int], _ i: Int, _ j: Int, _ rowsize: Int, _ value: Int) {
    table[i * rowsize + j] = value
}

private func linearPartitionTable(_ weights: [Int], numberOfPartitions: Int) -> [Int] {
    let n = weights.count
    let k = numberOfPartitions
    
    let tableSize = n * k;
    var tmpTable = Array<Int>(repeatElement(0, count: tableSize))
    
    let solutionSize = (n - 1) * (k - 1)
    var solution = Array<Int>(repeatElement(0, count: solutionSize))
    
    for i in 0 ..< n {
        let offset = i != 0 ? NH_LP_TABLE_LOOKUP(&tmpTable, i - 1, 0, k) : 0
        NH_LP_TABLE_LOOKUP_SET(&tmpTable, i, 0, k, Int(weights[i]) + offset)
    }
    
    for j in 0 ..< k {
        NH_LP_TABLE_LOOKUP_SET(&tmpTable, 0, j, k, Int(weights[0]))
    }
    
    for i in 1 ..< n {
        for j in 1 ..< k {
            var currentMin = 0
            var minX = Int.max
            
            for x in 0 ..< i {
                let c1 = NH_LP_TABLE_LOOKUP(&tmpTable, x, j - 1, k)
                let c2 = NH_LP_TABLE_LOOKUP(&tmpTable, i, 0, k) - NH_LP_TABLE_LOOKUP(&tmpTable, x, 0, k)
                let cost = max(c1, c2)
                
                if x == 0 || cost < currentMin {
                    currentMin = cost;
                    minX = x
                }
            }
            
            NH_LP_TABLE_LOOKUP_SET(&tmpTable, i, j, k, currentMin)
            NH_LP_TABLE_LOOKUP_SET(&solution, i - 1, j - 1, k - 1, minX)
        }
    }
    
    return solution
}

private func linearPartitionForWeights(_ weights: [Int], numberOfPartitions: Int) -> [[Int]] {
    var n = weights.count
    var k = numberOfPartitions
    
    if k <= 0 {
        return []
    }
    
    if k >= n {
        var partition: [[Int]] = []
        for weight in weights {
            partition.append([weight])
        }
        return partition
    }
    
    if n == 1 {
        return [weights]
    }
    
    var solution = linearPartitionTable(weights, numberOfPartitions: numberOfPartitions)
    let solutionRowSize = numberOfPartitions - 1
    
    k = k - 2;
    n = n - 1;
    
    var answer: [[Int]] = []
    
    while k >= 0 {
        if n < 1 {
            answer.insert([], at: 0)
        } else {
            var currentAnswer: [Int] = []
            
            var i = NH_LP_TABLE_LOOKUP(&solution, n - 1, k, solutionRowSize) + 1
            let range = n + 1
            while i < range {
                currentAnswer.append(weights[i])
                i += 1
            }
            
            answer.insert(currentAnswer, at: 0)
            
            n = NH_LP_TABLE_LOOKUP(&solution, n - 1, k, solutionRowSize)
        }
        
        k = k - 1
    }
    
    var currentAnswer: [Int] = []
    var i = 0
    let range = n + 1
    while i < range {
        currentAnswer.append(weights[i])
        i += 1
    }
    
    answer.insert(currentAnswer, at: 0)
    
    return answer
}
