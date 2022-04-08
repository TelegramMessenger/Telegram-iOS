import Foundation
import UIKit
import Display

private struct Vector2 {
    var x: Float
    var y: Float
}

private final class ParticleLayer: CALayer {
    let mass: Float
    var velocity: Vector2
    var angularVelocity: Float
    var rotationAngle: Float = 0.0
    var localTime: Float = 0.0
    var type: Int
    
    init(image: CGImage, size: CGSize, position: CGPoint, mass: Float, velocity: Vector2, angularVelocity: Float, type: Int) {
        self.mass = mass
        self.velocity = velocity
        self.angularVelocity = angularVelocity
        self.type = type
        
        super.init()
        
        self.contents = image
        self.bounds = CGRect(origin: CGPoint(), size: size)
        self.position = position
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }
}

public final class ConfettiView: UIView {
    private var particles: [ParticleLayer] = []
    private var displayLink: ConstantDisplayLinkAnimator?
    
    private var localTime: Float = 0.0
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = false
        
        let colors: [UIColor] = ([
            0x56CE6B,
            0xCD89D0,
            0x1E9AFF,
            0xFF8724
        ] as [UInt32]).map(UIColor.init(rgb:))
        let imageSize = CGSize(width: 8.0, height: 8.0)
        var images: [(CGImage, CGSize)] = []
        for imageType in 0 ..< 2 {
            for color in colors {
                if imageType == 0 {
                    images.append((generateFilledCircleImage(diameter: imageSize.width, color: color)!.cgImage!, imageSize))
                } else {
                    let spriteSize = CGSize(width: 2.0, height: 6.0)
                    images.append((generateImage(spriteSize, opaque: false, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(color.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.width)))
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: size.height - size.width), size: CGSize(width: size.width, height: size.width)))
                        context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.width / 2.0), size: CGSize(width: size.width, height: size.height - size.width)))
                    })!.cgImage!, spriteSize))
                }
            }
        }
        let imageCount = images.count
        
        let originXRange = 0 ..< Int(frame.width)
        let originYRange = Int(-frame.height) ..< Int(0)
        let topMassRange: Range<Float> = 40.0 ..< 50.0
        let velocityYRange = Float(3.0) ..< Float(5.0)
        let angularVelocityRange = Float(1.0) ..< Float(6.0)
        let sizeVariation = Float(0.8) ..< Float(1.6)
        
        for i in 0 ..< 70 {
            let (image, size) = images[i % imageCount]
            let sizeScale = CGFloat(Float.random(in: sizeVariation))
            let particle = ParticleLayer(image: image, size: CGSize(width: size.width * sizeScale, height: size.height * sizeScale), position: CGPoint(x: CGFloat(Int.random(in: originXRange)), y: CGFloat(Int.random(in: originYRange))), mass: Float.random(in: topMassRange), velocity: Vector2(x: 0.0, y: Float.random(in: velocityYRange)), angularVelocity: Float.random(in: angularVelocityRange), type: 0)
            self.particles.append(particle)
            self.layer.addSublayer(particle)
        }
        
        let sideMassRange: Range<Float> = 110.0 ..< 120.0
        let sideOriginYBase: Float = Float(frame.size.height * 9.0 / 10.0)
        let sideOriginVelocityValueRange = Float(1.1) ..< Float(1.3)
        let sideOriginVelocityValueScaling: Float = 2400.0 * Float(frame.height) / 896.0
        let sideOriginVelocityBase: Float = Float.pi / 2.0 + atanf(Float(CGFloat(sideOriginYBase) / (frame.size.width * 0.8)))
        let sideOriginVelocityVariation: Float = 0.09
        let sideOriginVelocityAngleRange = Float(sideOriginVelocityBase - sideOriginVelocityVariation) ..< Float(sideOriginVelocityBase + sideOriginVelocityVariation)
        let originAngleRange = Float(0.0) ..< (Float.pi * 2.0)
        let originAmplitudeDiameter: CGFloat = 230.0
        let originAmplitudeRange = Float(0.0) ..< Float(originAmplitudeDiameter / 2.0)
        
        let sideTypes: [Int] = [0, 1, 2]
        
        for sideIndex in 0 ..< 2 {
            let sideSign: Float = sideIndex == 0 ? 1.0 : -1.0
            let baseOriginX: CGFloat = sideIndex == 0 ? -originAmplitudeDiameter / 2.0 : (frame.width + originAmplitudeDiameter / 2.0)
            
            for i in 0 ..< 40 {
                let originAngle = Float.random(in: originAngleRange)
                let originAmplitude = Float.random(in: originAmplitudeRange)
                let originX = baseOriginX + CGFloat(cosf(originAngle) * originAmplitude)
                let originY = CGFloat(sideOriginYBase + sinf(originAngle) * originAmplitude)
                
                let velocityValue = Float.random(in: sideOriginVelocityValueRange) * sideOriginVelocityValueScaling
                let velocityAngle = Float.random(in: sideOriginVelocityAngleRange)
                let velocityX = sideSign * velocityValue * sinf(velocityAngle)
                let velocityY = velocityValue * cosf(velocityAngle)
                let (image, size) = images[i % imageCount]
                let sizeScale = CGFloat(Float.random(in: sizeVariation))
                let particle = ParticleLayer(image: image, size: CGSize(width: size.width * sizeScale, height: size.height * sizeScale), position: CGPoint(x: originX, y: originY), mass: Float.random(in: sideMassRange), velocity: Vector2(x: velocityX, y: velocityY), angularVelocity: Float.random(in: angularVelocityRange), type: sideTypes[i % 3])
                self.particles.append(particle)
                self.layer.addSublayer(particle)
            }
        }
        
        self.displayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
            self?.step()
        })
        
        self.displayLink?.isPaused = false
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var slowdownStartTimestamps: [Float?] = [nil, nil, nil]
    
    private func step() {
        self.slowdownStartTimestamps[0] = 0.33
        
        var haveParticlesAboveGround = false
        let maxPositionY = self.bounds.height + 30.0
        let dt: Float = 1.0 * 1.0 / 60.0
        
        let typeDelays: [Float] = [0.0, 0.01, 0.08]
        var dtAndDamping: [(Float, Float)] = []
        
        for i in 0 ..< 3 {
            let typeDelay = typeDelays[i]
            let currentTime = self.localTime - typeDelay
            if currentTime < 0.0 {
                dtAndDamping.append((0.0, 1.0))
            } else if let slowdownStart = self.slowdownStartTimestamps[i] {
                let slowdownDt: Float
                let slowdownDuration: Float = 0.5
                let damping: Float
                if currentTime >= slowdownStart && currentTime <= slowdownStart + slowdownDuration {
                    let slowdownTimestamp: Float = currentTime - slowdownStart
                    
                    let slowdownRampInDuration: Float = 0.05
                    let slowdownRampOutDuration: Float = 0.2
                    let rawSlowdownT: Float
                    if slowdownTimestamp < slowdownRampInDuration {
                        rawSlowdownT = slowdownTimestamp / slowdownRampInDuration
                    } else if slowdownTimestamp >= slowdownDuration - slowdownRampOutDuration {
                        let reverseTransition = (slowdownTimestamp - (slowdownDuration - slowdownRampOutDuration)) / slowdownRampOutDuration
                        rawSlowdownT = 1.0 - reverseTransition
                    } else {
                        rawSlowdownT = 1.0
                    }
                    
                    let slowdownTransition = rawSlowdownT * rawSlowdownT
                    
                    let slowdownFactor: Float = 0.8 * slowdownTransition + 1.0 * (1.0 - slowdownTransition)
                    slowdownDt = dt * slowdownFactor
                    let dampingFactor: Float = 0.937 * slowdownTransition + 1.0 * (1.0 - slowdownTransition)
                    
                    damping = dampingFactor
                } else {
                    slowdownDt = dt
                    damping = 1.0
                }
                if i == 1 {
                    //print("type 1 dt = \(slowdownDt), slowdownStart = \(slowdownStart), currentTime = \(currentTime)")
                }
                dtAndDamping.append((slowdownDt, damping))
            } else {
                dtAndDamping.append((dt, 1.0))
            }
        }
        self.localTime += dt
        
        let g: Vector2 = Vector2(x: 0.0, y: 9.8)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var turbulenceVariation: [Float] = []
        for _ in 0 ..< 20 {
            turbulenceVariation.append(Float.random(in: -16.0 ..< 16.0) * 60.0)
        }
        let turbulenceVariationCount = turbulenceVariation.count
        var index = 0
        
        var typesWithPositiveVelocity: [Bool] = [false, false, false]
        
        for particle in self.particles {
            let (localDt, _) = dtAndDamping[particle.type]
            if localDt.isZero {
                continue
            }
            let damping: Float = 0.93
            
            particle.localTime += localDt
            
            var position = particle.position
            
            position.x += CGFloat(particle.velocity.x * localDt)
            position.y += CGFloat(particle.velocity.y * localDt)
            particle.position = position
            
            particle.rotationAngle += particle.angularVelocity * localDt
            particle.transform = CATransform3DMakeRotation(CGFloat(particle.rotationAngle), 0.0, 0.0, 1.0)
            
            let acceleration = g
            
            var velocity = particle.velocity
            velocity.x += acceleration.x * particle.mass * localDt
            velocity.y += acceleration.y * particle.mass * localDt
            if velocity.y < 0.0 {
                velocity.x *= damping
                velocity.y *= damping
            } else {
                velocity.x += turbulenceVariation[index % turbulenceVariationCount] * localDt
                typesWithPositiveVelocity[particle.type] = true
            }
            particle.velocity = velocity
            
            index += 1
            
            if position.y < maxPositionY {
                haveParticlesAboveGround = true
            }
        }
        for i in 0 ..< 3 {
            if typesWithPositiveVelocity[i] && self.slowdownStartTimestamps[i] == nil {
                self.slowdownStartTimestamps[i] = max(0.0, self.localTime - typeDelays[i])
            }
        }
        CATransaction.commit()
        if !haveParticlesAboveGround {
            self.displayLink?.isPaused = true
            self.removeFromSuperview()
        }
    }
}
