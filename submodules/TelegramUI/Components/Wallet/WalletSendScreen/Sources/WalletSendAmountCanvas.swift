import UIKit
import CoreText
import Display
import Metal
import MetalEngine
import QuartzCore

private final class WalletSendAmountMetal {
    static let shared = WalletSendAmountMetal()

    struct Quad {
        var rect: SIMD4<Float>
        var color: SIMD4<Float>
        var uv: SIMD4<Float>
        var viewport: SIMD2<Float>
        var effect: SIMD2<Float>
        var reveal: SIMD2<Float>
    }
    struct Blur {
        var radius: UInt32
        var horizontal: UInt32
    }
    let device: MTLDevice
    let paint: MTLRenderPipelineState
    let maskPaint: MTLRenderPipelineState
    let blur: MTLComputePipelineState
    private var cachedAtlas: (key: WalletSendAmountGlyphAtlas.Key, atlas: WalletSendAmountGlyphAtlas)?

    private init?() {
        let device = MetalEngine.shared.device
        guard let url = Bundle(for: WalletSendAmountCanvas.self).url(forResource: "WalletSendAmountMetalSourcesBundle", withExtension: "bundle"),
              let bundle = Bundle(url: url), let library = try? device.makeDefaultLibrary(bundle: bundle),
              let vertex = library.makeFunction(name: "walletAmountVertex"),
              let layerVertex = library.makeFunction(name: "walletAmountLayerVertex"),
              let fragment = library.makeFunction(name: "walletAmountFragment"),
              let blurFunction = library.makeFunction(name: "walletAmountBlur"),
              let blur = MetalEngine.shared.pipelineCache.makeComputePipelineState(function: blurFunction) else { return nil }
        func pipeline(_ format: MTLPixelFormat) -> MTLRenderPipelineState? {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = format == .r16Float ? vertex : layerVertex
            descriptor.fragmentFunction = fragment
            let attachment = descriptor.colorAttachments[0]!
            attachment.pixelFormat = format
            attachment.isBlendingEnabled = true
            attachment.sourceRGBBlendFactor = .one
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return MetalEngine.shared.pipelineCache.makeRenderPipelineState(descriptor: descriptor)
        }
        guard let paint = pipeline(.bgra8Unorm), let maskPaint = pipeline(.r16Float) else { return nil }
        self.device = device
        self.paint = paint
        self.maskPaint = maskPaint
        self.blur = blur
    }

    func atlas(for key: WalletSendAmountGlyphAtlas.Key) -> WalletSendAmountGlyphAtlas? {
        if let cachedAtlas, cachedAtlas.key == key { return cachedAtlas.atlas }
        guard let atlas = WalletSendAmountGlyphAtlas(device: device, key: key) else { return nil }
        cachedAtlas = (key, atlas)
        return atlas
    }

    func quad(rect: CGRect, uv: SIMD4<Float>, color: SIMD4<Float>, viewport: CGSize, threshold: Float = -1, reveal: SIMD2<Float> = .zero) -> Quad {
        return Quad(rect: SIMD4(Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height)),
                    color: color, uv: uv, viewport: SIMD2(Float(viewport.width), Float(viewport.height)), effect: SIMD2(threshold, 0), reveal: reveal)
    }

    func draw(_ texture: MTLTexture, rect: CGRect, uv: SIMD4<Float>, color: SIMD4<Float>, viewport: CGSize,
              encoder: MTLRenderCommandEncoder) {
        draw(texture, quads: [quad(rect: rect, uv: uv, color: color, viewport: viewport)], encoder: encoder)
    }

    func draw(_ texture: MTLTexture, quads: [Quad], encoder: MTLRenderCommandEncoder) {
        guard !quads.isEmpty else { return }
        quads.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            encoder.setVertexBytes(base, length: buffer.count * MemoryLayout<Quad>.stride, index: 0)
        }
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: quads.count)
    }
}

private final class WalletSendAmountLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    private final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        required init?(device: MTLDevice) {
            guard let renderer = WalletSendAmountMetal.shared else { return nil }
            pipelineState = renderer.paint
        }
    }

    private final class PrepareState: ComputeState {
        required init?(device: MTLDevice) {
            guard WalletSendAmountMetal.shared != nil else { return nil }
        }
    }

    var internalData: MetalEngineSubjectInternalData?
    var onFrameReady: (() -> Void)?
    private(set) var hasFrame = false
    var isRenderingEnabled = false
    var frameDuration: Double = 1.0 / 120.0
    var sprites: [WalletSendAmountSprite] = []
    var reveal: SIMD2<Float> = .zero
    var displayScale: CGFloat = 1
    var glyphAtlas: WalletSendAmountGlyphAtlas?
    var previousGlyphAtlases: [WalletSendAmountGlyphAtlas] = []

    private struct Batch {
        let texture: MTLTexture
        var quads: [WalletSendAmountMetal.Quad]
    }
    private struct TexturePair {
        let mask: MTLTexture
        let temporary: MTLTexture
    }
    private struct Draw {
        let texture: MTLTexture
        let rect: CGRect
        let color: SIMD4<Float>
        var uv: SIMD4<Float> = SIMD4(0, 0, 1, 1)
        var threshold: Float = -1
    }
    private let renderer = WalletSendAmountMetal.shared
    private var texturePool: [String: [TexturePair]] = [:]
    private var textureUses: [String: Int] = [:]
    override init() {
        super.init()
        isOpaque = false
        contentsGravity = .resize
        masksToBounds = false
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func releaseScratchTextures() {
        texturePool.removeAll()
    }

    private func textures(width: Int, height: Int) -> TexturePair? {
        guard let renderer else { return nil }
        let key = "\(width)x\(height)"
        let index = textureUses[key, default: 0]
        textureUses[key] = index + 1
        if let pool = texturePool[key], index < pool.count { return pool[index] }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        guard let mask = renderer.device.makeTexture(descriptor: descriptor),
              let temporary = renderer.device.makeTexture(descriptor: descriptor) else { return nil }
        let pair = TexturePair(mask: mask, temporary: temporary)
        texturePool[key, default: []].append(pair)
        return pair
    }

    private func color(_ color: UIColor, alpha: CGFloat) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4(Float(r), Float(g), Float(b), Float(a * alpha))
    }

    private func mask(for glyph: WalletSendAmountGlyph, atlases: [WalletSendAmountGlyphAtlas]) -> WalletSendAmountGlyphAtlas.Mask? {
        for atlas in atlases {
            if let mask = atlas.mask(for: glyph) { return mask }
        }
        return nil
    }

    private func melt(_ sprite: WalletSendAmountSprite, morph: WalletSendAmountMorph,
                      atlases: [WalletSendAmountGlyphAtlas], scale: CGFloat, command: MTLCommandBuffer) -> Draw? {
        guard let renderer,
              let old = mask(for: morph.from, atlases: atlases),
              let new = mask(for: sprite.glyph, atlases: atlases) else { return nil }
        let p = min(1, max(0, morph.progress))
        let radius = morph.from.font.capHeight * 0.19 * pow(max(0, sin(.pi * p)), 0.55)
        let sxOld = 1 + 0.08 * p, syOld = 1 - 0.22 * p
        let sxNew = 1.08 - 0.08 * p, syNew = 0.78 + 0.22 * p
        let oldRect = old.rect.applying(CGAffineTransform(scaleX: sxOld, y: syOld))
        let newRect = new.rect.applying(CGAffineTransform(scaleX: sxNew, y: syNew))
        let padding = max(morph.from.font.capHeight, sprite.glyph.font.capHeight)
        let union = old.rect.union(new.rect).insetBy(dx: -padding, dy: -padding)
        let width = max(1, Int(ceil(union.width * scale)))
        let height = max(1, Int(ceil(union.height * scale)))
        let size = CGSize(width: CGFloat(width) / scale, height: CGFloat(height) / scale)
        guard let pair = textures(width: width, height: height) else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = pair.mask
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encoder.setRenderPipelineState(renderer.maskPaint)
        renderer.draw(old.texture, rect: oldRect.offsetBy(dx: -union.minX, dy: -union.minY), uv: old.uv,
            color: SIMD4(1, 1, 1, Float(pow(1 - p, 0.55))), viewport: size, encoder: encoder)
        renderer.draw(new.texture, rect: newRect.offsetBy(dx: -union.minX, dy: -union.minY), uv: new.uv,
            color: SIMD4(1, 1, 1, Float(pow(p, 0.55))), viewport: size, encoder: encoder)
        encoder.endEncoding()
        
        let sigma = max(Float(radius * scale), 0.01)
        let kernelRadius = Int(ceil(sigma * 3))
        var weights = (-kernelRadius ... kernelRadius).map { offset in
            exp(-Float(offset * offset) / (2 * sigma * sigma))
        }
        let weightSum = weights.reduce(0, +)
        for i in weights.indices { weights[i] /= weightSum }
        for horizontal in [true, false] {
            guard let compute = command.makeComputeCommandEncoder() else { return nil }
            compute.setComputePipelineState(renderer.blur)
            compute.setTexture(horizontal ? pair.mask : pair.temporary, index: 0)
            compute.setTexture(horizontal ? pair.temporary : pair.mask, index: 1)
            var blur = WalletSendAmountMetal.Blur(radius: UInt32(kernelRadius), horizontal: horizontal ? 1 : 0)
            compute.setBytes(&blur, length: MemoryLayout<WalletSendAmountMetal.Blur>.stride, index: 0)
            weights.withUnsafeBufferPointer { buffer in
                if let base = buffer.baseAddress {
                    compute.setBytes(base, length: buffer.count * MemoryLayout<Float>.stride, index: 1)
                }
            }
            compute.dispatchThreadgroups(MTLSize(width: (width + 7) / 8, height: (height + 7) / 8, depth: 1),
                                         threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
            compute.endEncoding()
        }
        return Draw(texture: pair.mask,
                    rect: CGRect(origin: CGPoint(x: sprite.glyph.position.x + union.minX, y: sprite.glyph.position.y + union.minY), size: size),
                    color: color(sprite.glyph.color, alpha: sprite.alpha), threshold: 0.42)
    }

    private func draws(_ sprite: WalletSendAmountSprite, atlases: [WalletSendAmountGlyphAtlas], frameDuration: Double) -> [Draw] {
        guard let mask = mask(for: sprite.glyph, atlases: atlases) else { return [] }
        let glyph = sprite.glyph
        let pitch = glyph.font.capHeight * 0.8
        let vertical = min(abs(sprite.travel.y), pitch * 1.4)
        let travel = max(vertical, abs(sprite.travel.x))
        let haze = max(sprite.spread, sprite.spread - sprite.spreadTravel)
        let moving = travel > 0.01
        let span = max(travel, haze, moving ? sprite.soft : 0)
        let density = min(1, (1.0 / 90) / max(frameDuration, 1.0 / 120))
        let samples = span > 1 ? max(3, Int(Double(min(2 + Int(span), 18)) * density)) : 1
        let weights = (0 ..< samples).map { i -> CGFloat in
            let k = samples > 1 ? CGFloat(i) / CGFloat(samples - 1) * 2 - 1 : 0
            return 1 - 0.55 * k * k
        }
        let total = weights.reduce(0, +)
        let stretch = moving ? max(min(span, pitch * 1.4) / travel, 1) : 1
        let zoom = moving ? 0 : span / max(glyph.width, 1)
        var result: [Draw] = []
        for sample in 0 ..< samples {
            let alpha = sprite.alpha * weights[sample] / total
            guard alpha > 0.008 else { continue }
            let k = samples > 1 ? CGFloat(sample) / CGFloat(samples - 1) : 1
            let dx = sprite.travel.x * (k - 1) * stretch
                + (k - 0.5) * (sprite.spread + (k - 1) * sprite.spreadTravel)
            let dy = sprite.travel.y * (k - 1) * stretch
            let s = sprite.scale + (k - 1) * sprite.scaleTravel + (k - 0.5) * zoom
            let cap = glyph.font.capHeight / 2
            let rect = CGRect(x: glyph.position.x + dx + mask.rect.minX * s,
                              y: glyph.position.y + dy - cap + (mask.rect.minY + cap) * s,
                              width: mask.rect.width * s, height: mask.rect.height * s)
            result.append(Draw(texture: mask.texture, rect: rect, color: color(glyph.color, alpha: alpha), uv: mask.uv))
        }
        return result
    }

    func update(context: MetalEngineSubjectContext) {
        guard let renderer, let glyphAtlas, isRenderingEnabled, !bounds.isEmpty,
              UIApplication.shared.applicationState != .background else { return }
        let scale = displayScale
        let viewport = bounds.size
        let sprites = self.sprites
        let frameDuration = self.frameDuration
        let reveal = self.reveal
        let atlases = [glyphAtlas] + previousGlyphAtlases
        contentsScale = scale
    
        let batches = context.compute(state: PrepareState.self, commands: { [self] command, _ -> [Batch] in
            textureUses.removeAll(keepingCapacity: true)
            if texturePool.count > 64 { texturePool.removeAll(keepingCapacity: true) }
            var batches: [Batch] = []
            func append(_ draw: Draw) {
                let quad = renderer.quad(rect: draw.rect, uv: draw.uv, color: draw.color, viewport: viewport, threshold: draw.threshold, reveal: reveal)
                if let last = batches.indices.last, batches[last].texture === draw.texture,
                   (batches[last].quads.count + 1) * MemoryLayout<WalletSendAmountMetal.Quad>.stride <= 4096 {
                    batches[last].quads.append(quad)
                } else {
                    batches.append(Batch(texture: draw.texture, quads: [quad]))
                }
            }
            for sprite in sprites where sprite.alpha > 0.006 {
                if let morph = sprite.morph, let draw = melt(sprite, morph: morph, atlases: atlases, scale: scale, command: command) {
                    append(draw)
                } else {
                    for draw in draws(sprite, atlases: atlases, frameDuration: frameDuration) { append(draw) }
                }
            }
            return batches
        })
        context.renderToLayer(
            spec: RenderLayerSpec(size: RenderSize(width: max(1, Int(ceil(viewport.width * scale))),
                                                   height: max(1, Int(ceil(viewport.height * scale))))),
            state: RenderState.self, layer: self, inputs: batches,
            commands: { [weak self] encoder, placement, batches in
                let rect = placement.effectiveRect
                var placement = SIMD4<Float>(Float(rect.minX), Float(rect.minY), Float(rect.width), Float(rect.height))
                encoder.setVertexBytes(&placement, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
                for batch in batches {
                    renderer.draw(batch.texture, quads: batch.quads, encoder: encoder)
                }
                if let self, !self.hasFrame {
                    self.hasFrame = true
                    self.onFrameReady?()
                }
            }
        )
    }
}

final class WalletSendAmountCanvas: UIView {
    override class var layerClass: AnyClass { WalletSendAmountLayer.self }
    private var metalLayer: WalletSendAmountLayer { layer as! WalletSendAmountLayer }
    private var glyphFonts: [WalletSendAmountGlyphAtlas.FontCharacters] = []
    private var atlasKey: WalletSendAmountGlyphAtlas.Key?
    var onFrameReady: (() -> Void)?
    var isAvailable: Bool { metalLayer.glyphAtlas != nil }
    var hasFrame: Bool { metalLayer.hasFrame }
    var isRenderingEnabled = true {
        didSet {
            if isRenderingEnabled != oldValue { requestFrame() }
        }
    }
    var frameDuration: Double = 1.0 / 120.0
    private var sprites: [WalletSendAmountSprite] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        metalLayer.onFrameReady = { [weak self] in self?.onFrameReady?() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func prepareGlyphs(separators: String, currencyCode: String) {
        prepareGlyphs(WalletSendAmountGlyphAtlas.Key(scale: 1.0, separators: separators, currencyCode: currencyCode).fonts)
    }

    func prepareGlyphs(text: String, font: UIFont, separators: String) {
        // Keep digits and previously seen letters ready for rolling and interrupted
        // transitions without rebuilding the atlas on every keystroke.
        var characters = "0123456789" + separators + text
        if glyphFonts.count == 1, let previous = glyphFonts.first, previous.font == font {
            characters += previous.characters
        }
        prepareGlyphs([WalletSendAmountGlyphAtlas.FontCharacters(font: font, characters: characters)])
    }

    private func prepareGlyphs(_ fonts: [WalletSendAmountGlyphAtlas.FontCharacters]) {
        guard self.glyphFonts != fonts || atlasKey == nil else { return }
        self.glyphFonts = fonts
        atlasKey = nil
        updateAtlas(scale: window?.screen.scale ?? UIScreen.main.scale)
    }

    func glyphMask(for glyph: WalletSendAmountGlyph) -> WalletSendAmountGlyphAtlas.Mask? {
        return self.metalLayer.glyphAtlas?.mask(for: glyph)
    }

    private func updateAtlas(scale: CGFloat) {
        if atlasKey?.scale == scale, metalLayer.glyphAtlas != nil { return }
        guard !glyphFonts.isEmpty else { return }
        let key = WalletSendAmountGlyphAtlas.Key(scale: scale, fonts: glyphFonts)
        let atlas = WalletSendAmountMetal.shared?.atlas(for: key)
        if let previous = metalLayer.glyphAtlas, previous !== atlas,
           !metalLayer.previousGlyphAtlases.contains(where: { $0 === previous }) {
            metalLayer.previousGlyphAtlases.append(previous)
        }
        metalLayer.glyphAtlas = atlas
        atlasKey = key
    }

    func update(sprites: [WalletSendAmountSprite], isAnimating: Bool, reveal: SIMD2<Float> = .zero) {
        self.metalLayer.reveal = reveal
        self.sprites = sprites
        if !isAnimating, !metalLayer.previousGlyphAtlases.isEmpty, let atlas = metalLayer.glyphAtlas {
            let missing = (sprites.map { $0.glyph } + sprites.compactMap { $0.morph?.from }).filter { atlas.mask(for: $0) == nil }
            metalLayer.previousGlyphAtlases.removeAll { previous in
                !missing.contains(where: { previous.mask(for: $0) != nil })
            }
        }
        requestFrame()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        requestFrame()
        if window == nil { metalLayer.releaseScratchTextures() }
    }

    private func requestFrame() {
        metalLayer.isRenderingEnabled = isRenderingEnabled && window != nil && UIApplication.shared.applicationState != .background
        guard metalLayer.isRenderingEnabled else { return }
        metalLayer.sprites = sprites
        metalLayer.frameDuration = frameDuration
        metalLayer.displayScale = window?.screen.scale ?? UIScreen.main.scale
        updateAtlas(scale: metalLayer.displayScale)
        metalLayer.setNeedsUpdate()
    }
}

enum WalletSendAmountFonts {
    static let integral = Font.with(size: 48.0, design: .round, weight: .bold, traits: [])
    static let fractional = Font.with(size: 32.0, design: .round, weight: .bold)
    static let rate = Font.with(size: 13.0, design: .round, weight: .semibold)
}

final class WalletSendAmountGlyphAtlas {
    struct FontCharacters: Hashable {
        let font: UIFont
        let characters: String

        init(font: UIFont, characters: String) {
            self.font = font
            self.characters = String(Set(characters).sorted())
        }
    }

    struct Key: Hashable {
        let scale: CGFloat
        let fonts: [FontCharacters]

        init(scale: CGFloat, fonts: [FontCharacters]) {
            self.scale = scale
            self.fonts = fonts
        }

        init(scale: CGFloat, separators: String, currencyCode: String) {
            self.scale = scale
            let numericCharacters = "0123456789" + separators
            let suffixCharacters = numericCharacters + "GRAM" + currencyCode
            self.fonts = [
                FontCharacters(font: WalletSendAmountFonts.integral, characters: numericCharacters),
                FontCharacters(font: WalletSendAmountFonts.fractional, characters: suffixCharacters),
                FontCharacters(font: WalletSendAmountFonts.rate, characters: suffixCharacters + "~")
            ]
        }
    }

    struct Mask {
        let texture: MTLTexture
        let rect: CGRect
        let uv: SIMD4<Float>
    }

    private struct GlyphKey: Hashable {
        let text: String
        let font: UIFont
    }

    private struct Outline {
        let key: GlyphKey
        let path: CGPath
        let rect: CGRect
        let width: Int
        let height: Int
        var x: Int = 0
        var y: Int = 0
    }

    private let masks: [GlyphKey: Mask]

    init?(device: MTLDevice, key: Key) {
        let scale = key.scale
        var outlines: [Outline] = []
        for fontCharacters in key.fonts {
            let font = fontCharacters.font
            for character in fontCharacters.characters {
                let text = String(character)
                let width = WalletSendAmountGlyphMetrics.width(text, font: font)
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
                let path = CGMutablePath()
                for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                    let count = CTRunGetGlyphCount(run)
                    let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
                    var indices = [CGGlyph](repeating: 0, count: count)
                    var positions = [CGPoint](repeating: .zero, count: count)
                    CTRunGetGlyphs(run, CFRangeMake(0, count), &indices)
                    CTRunGetPositions(run, CFRangeMake(0, count), &positions)
                    for i in 0 ..< count {
                        if let outline = CTFontCreatePathForGlyph(runFont, indices[i], nil) {
                            path.addPath(outline, transform: CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
                                tx: positions[i].x - width / 2, ty: -positions[i].y))
                        }
                    }
                }
                guard !path.isEmpty else { continue }
                let ink = path.boundingBoxOfPath.insetBy(dx: -2 / scale, dy: -2 / scale)
                let rect = CGRect(x: floor(ink.minX * scale) / scale, y: floor(ink.minY * scale) / scale,
                                  width: ceil(ink.width * scale + 1) / scale, height: ceil(ink.height * scale + 1) / scale)
                outlines.append(Outline(key: GlyphKey(text: text, font: font), path: path, rect: rect,
                    width: max(1, Int(round(rect.width * scale))), height: max(1, Int(round(rect.height * scale)))))
            }
        }

        outlines.sort { $0.height > $1.height }
        let gutter = 2
        let area = outlines.reduce(0) { $0 + ($1.width + gutter) * ($1.height + gutter) }
        let widest = outlines.map { $0.width + 2 * gutter }.max() ?? 1
        var width = 256
        while width * width < area || width < widest { width *= 2 }
        var x = gutter, y = gutter, rowHeight = 0
        for i in outlines.indices {
            if x + outlines[i].width + gutter > width {
                x = gutter
                y += rowHeight + gutter
                rowHeight = 0
            }
            outlines[i].x = x
            outlines[i].y = y
            x += outlines[i].width + gutter
            rowHeight = max(rowHeight, outlines[i].height)
        }
        let height = ((y + rowHeight + gutter + 15) / 16) * 16
        var bytes = [UInt8](repeating: 0, count: width * height)
        let drawn = bytes.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(data: storage.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.setFillColor(gray: 1, alpha: 1)
            for outline in outlines {
                context.saveGState()
                context.translateBy(x: CGFloat(outline.x), y: CGFloat(outline.y))
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: -outline.rect.minX, y: -outline.rect.minY)
                context.addPath(outline.path)
                context.fillPath()
                context.restoreGState()
            }
            return true
        }
        guard drawn else { return nil }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.label = "Wallet send glyph atlas"
        bytes.withUnsafeBytes { storage in
            if let base = storage.baseAddress {
                texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: base, bytesPerRow: width)
            }
        }
        var masks: [GlyphKey: Mask] = [:]
        for outline in outlines {
            masks[outline.key] = Mask(texture: texture, rect: outline.rect, uv: SIMD4(
                Float(outline.x) / Float(width), Float(outline.y) / Float(height),
                Float(outline.width) / Float(width), Float(outline.height) / Float(height)))
        }
        self.masks = masks
    }

    func mask(for glyph: WalletSendAmountGlyph) -> Mask? {
        return masks[GlyphKey(text: glyph.text, font: glyph.font)]
    }
}
