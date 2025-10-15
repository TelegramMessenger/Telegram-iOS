import Foundation
import MetalKit
import UIKit
import MetalEngine
import ComponentFlow
import Display

private func shiftArray(array: [SIMD2<Float>], offset: Int) -> [SIMD2<Float>] {
    var newArray = array
    var offset = offset
    while offset > 0 {
        let element = newArray.removeFirst()
        newArray.append(element)
        offset -= 1
    }
    return newArray
}

private func gatherPositions(_ list: [SIMD2<Float>]) -> [SIMD2<Float>] {
    var result: [SIMD2<Float>] = []
    for i in 0 ..< list.count / 2 {
        result.append(list[i * 2])
    }
    return result
}

private func hexToFloat(_ hex: Int) -> SIMD4<Float> {
    let red = Float((hex >> 16) & 0xFF) / 255.0
    let green = Float((hex >> 8) & 0xFF) / 255.0
    let blue = Float((hex >> 0) & 0xFF) / 255.0
    return SIMD4<Float>(x: red, y: green, z: blue, w: 1.0)
}

private struct ColorSet: Equatable, AnimationInterpolatable {
    static let animationInterpolator = AnimationInterpolator<ColorSet> { from, to, fraction in
        var result: [SIMD4<Float>] = []
        for i in 0 ..< min(from.colors.count, to.colors.count) {
            result.append(from.colors[i] * Float(1.0 - fraction) + to.colors[i] * Float(fraction))
        }
        return ColorSet(colors: result)
    }
    
    var colors: [SIMD4<Float>]
}

final class CallBackgroundLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    var internalData: MetalEngineSubjectInternalData?
    
    final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "callBackgroundVertex"), let fragmentFunction = library.makeFunction(name: "callBackgroundFragment") else {
                return nil
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }
    
    private static var basePositions: [SIMD2<Float>] = [
        SIMD2<Float>(x: 0.80, y: 0.10),
        SIMD2<Float>(x: 0.60, y: 0.20),
        SIMD2<Float>(x: 0.35, y: 0.25),
        SIMD2<Float>(x: 0.25, y: 0.60),
        SIMD2<Float>(x: 0.20, y: 0.90),
        SIMD2<Float>(x: 0.40, y: 0.80),
        SIMD2<Float>(x: 0.65, y: 0.75),
        SIMD2<Float>(x: 0.75, y: 0.40)
    ]
    
    let blurredLayer: MetalEngineSubjectLayer
    let externalBlurredLayer: MetalEngineSubjectLayer
    
    private var phase: Float = 0.0
    
    private var displayLinkSubscription: SharedDisplayLinkDriver.Link?
    
    var renderSpec: RenderLayerSpec? {
        didSet {
            if self.renderSpec != oldValue {
                self.setNeedsUpdate()
            }
        }
    }
    
    private let colorSets: [ColorSet]
    private let colorTransition: AnimatedProperty<ColorSet>
    private var stateIndex: Int = 0
    private var isEnergySavingEnabled: Bool = false
    private let phaseAcceleration = AnimatedProperty<CGFloat>(0.0)
    
    override init() {
        self.blurredLayer = MetalEngineSubjectLayer()
        self.externalBlurredLayer = MetalEngineSubjectLayer()
        
        self.colorSets = [
            ColorSet(colors: [
                hexToFloat(0x568FD6),
                hexToFloat(0x626ED5),
                hexToFloat(0xA667D5),
                hexToFloat(0x7664DA)
            ]),
            ColorSet(colors: [
                hexToFloat(0xACBD65),
                hexToFloat(0x459F8D),
                hexToFloat(0x53A4D1),
                hexToFloat(0x3E917A)
            ]),
            ColorSet(colors: [
                hexToFloat(0xC0508D),
                hexToFloat(0xF09536),
                hexToFloat(0xCE5081),
                hexToFloat(0xFC7C4C)
            ])
        ]
        self.colorTransition = AnimatedProperty<ColorSet>(colorSets[0])
        
        super.init()
        
        self.blurredLayer.cloneLayers.append(self.externalBlurredLayer)
        
        self.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.displayLinkSubscription = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(30), { [weak self] timeDelta in
                guard let self else {
                    return
                }
                self.colorTransition.update()
                self.phaseAcceleration.update()
                
                let stepCount = 8
                var phaseStep: CGFloat = 0.5 * timeDelta
                phaseStep += phaseStep * self.phaseAcceleration.value * 0.5
                self.phase = (self.phase + Float(phaseStep)).truncatingRemainder(dividingBy: Float(stepCount))
                
                self.setNeedsUpdate()
            })
        }
        self.didExitHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.displayLinkSubscription = nil
        }
    }
    
    override init(layer: Any) {
        self.blurredLayer = MetalEngineSubjectLayer()
        self.externalBlurredLayer = MetalEngineSubjectLayer()
        self.colorSets = []
        self.colorTransition = AnimatedProperty<ColorSet>(ColorSet(colors: []))
        
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(stateIndex: Int, isEnergySavingEnabled: Bool, transition: ComponentTransition) {
        self.isEnergySavingEnabled = isEnergySavingEnabled
        
        if self.stateIndex != stateIndex {
            self.stateIndex = stateIndex
            if !transition.animation.isImmediate {
                self.phaseAcceleration.animate(from: 1.0, to: 0.0, duration: 2.0, curve: .easeInOut)
                self.colorTransition.animate(to: self.colorSets[stateIndex % self.colorSets.count], duration: 0.3, curve: .easeInOut)
            } else {
                self.colorTransition.set(to: self.colorSets[stateIndex % self.colorSets.count])
            }
            self.setNeedsUpdate()
        }
    }
    
    func update(context: MetalEngineSubjectContext) {
        guard let renderSpec = self.renderSpec else {
            return
        }
        
        let phase = self.isEnergySavingEnabled ? 0.0 : self.phase
        
        for i in 0 ..< 2 {
            let isBlur = i == 1
            context.renderToLayer(spec: renderSpec, state: RenderState.self, layer: i == 0 ? self : self.blurredLayer, commands: { encoder, placement in
                var effectiveRect = placement.effectiveRect
                effectiveRect = effectiveRect.insetBy(dx: -effectiveRect.width * 0.1, dy: -effectiveRect.height * 0.1)
                
                var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width), Float(effectiveRect.height))
                encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
                
                let baseStep = floor(phase)
                let nextStepInterpolation = phase - floor(phase)
                
                let positions0 = gatherPositions(shiftArray(array: CallBackgroundLayer.basePositions, offset: Int(baseStep)))
                let positions1 = gatherPositions(shiftArray(array: CallBackgroundLayer.basePositions, offset: Int(baseStep) + 1))
                var positions = Array<SIMD2<Float>>(repeating: SIMD2<Float>(), count: 4)
                for i in 0 ..< 4 {
                    positions[i] = interpolatePoints(positions0[i], positions1[i], at: nextStepInterpolation)
                }
                encoder.setFragmentBytes(&positions, length: 4 * MemoryLayout<SIMD2<Float>>.size, index: 0)
                
                var colors: [SIMD4<Float>] = self.colorTransition.value.colors
                
                encoder.setFragmentBytes(&colors, length: 4 * MemoryLayout<SIMD4<Float>>.size, index: 1)
                var brightness: Float = isBlur ? 0.9 : 1.0
                var saturation: Float = isBlur ? 1.1 : 1.0
                var overlay: SIMD4<Float> = isBlur ? SIMD4<Float>(1.0, 1.0, 1.0, 0.2) : SIMD4<Float>()
                encoder.setFragmentBytes(&brightness, length: 4, index: 2)
                encoder.setFragmentBytes(&saturation, length: 4, index: 3)
                encoder.setFragmentBytes(&overlay, length: 4 * 4, index: 4)
                
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            })
        }
    }
}
