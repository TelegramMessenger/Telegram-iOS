import Foundation
import UIKit
import Display
import SwiftSignalKit

final class TodoChecksView: UIView, PhoneDemoDecorationView {
    private struct Particle {
        var trackIndex: Int
        var position: CGPoint
        var scale: CGFloat
        var alpha: CGFloat
        var direction: CGPoint
        var velocity: CGFloat
        var color: UIColor
        var currentTime: CGFloat
        var lifeTime: CGFloat
        
        init(
            trackIndex: Int,
            position: CGPoint,
            scale: CGFloat,
            alpha: CGFloat,
            direction: CGPoint,
            velocity: CGFloat,
            color: UIColor,
            currentTime: CGFloat,
            lifeTime: CGFloat
        ) {
            self.trackIndex = trackIndex
            self.position = position
            self.scale = scale
            self.alpha = alpha
            self.direction = direction
            self.velocity = velocity
            self.color = color
            self.currentTime = currentTime
            self.lifeTime = lifeTime
        }
        
        mutating func update(deltaTime: CGFloat) {
            var position = self.position
            position.x += self.direction.x * self.velocity * deltaTime
            position.y += self.direction.y * self.velocity * deltaTime
            self.position = position
            self.currentTime += deltaTime
        }
    }
    
    private final class ParticleSet {
        private let size: CGSize
        private(set) var particles: [Particle] = []
        
        init(size: CGSize, preAdvance: Bool) {
            self.size = size
            
            self.generateParticles(preAdvance: preAdvance)
        }
        
        private func generateParticles(preAdvance: Bool) {
            let maxDirections = 16
            
            if self.particles.count < maxDirections {
                var allTrackIndices: [Int] = Array(repeating: 0, count: maxDirections)
                for i in 0 ..< maxDirections {
                    allTrackIndices[i] = i
                }
                var takenIndexCount = 0
                for particle in self.particles {
                    allTrackIndices[particle.trackIndex] = -1
                    takenIndexCount += 1
                }
                var availableTrackIndices: [Int] = []
                availableTrackIndices.reserveCapacity(maxDirections - takenIndexCount)
                for index in allTrackIndices {
                    if index != -1 {
                        availableTrackIndices.append(index)
                    }
                }
                
                if !availableTrackIndices.isEmpty {
                    availableTrackIndices.shuffle()
                    
                    for takeIndex in availableTrackIndices {
                        let directionIndex = takeIndex
                        var angle = (CGFloat(directionIndex % maxDirections) / CGFloat(maxDirections)) * CGFloat.pi * 2.0
                        var lifeTimeMultiplier = 1.0
                        
                        var isUpOrDownSemisphere = false
                        if angle > CGFloat.pi / 7.0 && angle < CGFloat.pi - CGFloat.pi / 7.0 {
                            isUpOrDownSemisphere = true
                        } else if !"".isEmpty, angle > CGFloat.pi + CGFloat.pi / 7.0 && angle < 2.0 * CGFloat.pi - CGFloat.pi / 7.0 {
                            isUpOrDownSemisphere = true
                        }
                        
                        if isUpOrDownSemisphere {
                            if CGFloat.random(in: 0.0 ... 1.0) < 0.2 {
                                lifeTimeMultiplier = 0.3
                            } else {
                                angle += CGFloat.random(in: 0.0 ... 1.0) > 0.5 ? CGFloat.pi / 1.6 : -CGFloat.pi / 1.6
                                angle += CGFloat.random(in: -0.2 ... 0.2)
                                lifeTimeMultiplier = 0.5
                            }
                        }
//                        if self.large {
//                            angle += CGFloat.random(in: -0.5 ... 0.5)
//                        }
                        
                        let direction = CGPoint(x: cos(angle), y: sin(angle))
                        let velocity = CGFloat.random(in: 15.0 ..< 20.0)
                        let scale = 1.0
                        let lifeTime = CGFloat.random(in: 2.0 ... 3.5)
                        
                        var position = CGPoint(x: self.size.width / 2.0, y: self.size.height / 2.0)
                        var initialOffset: CGFloat = 0.5
                        if preAdvance {
                            initialOffset = CGFloat.random(in: 0.5 ... 1.0)
                        } else {
                            let p = CGFloat.random(in: 0.0 ... 1.0)
                            if p < 0.5 {
                                initialOffset = CGFloat.random(in: 0.65 ... 1.0)
                            } else {
                                initialOffset = 0.5
                            }
                        }
                        position.x += direction.x * initialOffset * 225.0
                        position.y += direction.y * initialOffset * 225.0
                                           
                        let particle = Particle(
                            trackIndex: directionIndex,
                            position: position,
                            scale: scale,
                            alpha: 1.0,
                            direction: direction,
                            velocity: velocity,
                            color: .white,
                            currentTime: 0.0,
                            lifeTime: lifeTime * lifeTimeMultiplier
                        )
                        self.particles.append(particle)
                    }
                }
            }
        }
        
        func update(deltaTime: CGFloat) {
            for i in (0 ..< self.particles.count).reversed() {
                self.particles[i].update(deltaTime: deltaTime)
                if self.particles[i].currentTime > self.particles[i].lifeTime {
                    self.particles.remove(at: i)
                }
            }
            
            self.generateParticles(preAdvance: false)
        }
    }
    
    private var displayLink: SharedDisplayLinkDriver.Link?
    
    private var particleSet: ParticleSet?
    private let particleImage: UIImage
    private var particleLayers: [SimpleLayer] = []
    
    private var size: CGSize?
    private let large: Bool = false
        
    override init(frame: CGRect) {
//        if large {
//            self.particleImage = generateTintedImage(image: UIImage(bundleImageName: "Peer Info/PremiumIcon"), color: .white)!.withRenderingMode(.alwaysTemplate)
//        } else {
        self.particleImage = generateTintedImage(image: UIImage(bundleImageName: "Premium/Stars/Particle"), color: .white)!.withRenderingMode(.alwaysTemplate)
//        }
                
        super.init(frame: frame)
        
        self.particleSet = ParticleSet(size: frame.size, preAdvance: true)
        
        self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] delta in
            self?.update(deltaTime: CGFloat(delta))
        })
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    fileprivate func update(size: CGSize) {
        self.size = size
    }
    
    private func update(deltaTime: CGFloat) {
        guard let particleSet = self.particleSet else {
            return
        }
        particleSet.update(deltaTime: deltaTime)
        
        for i in 0 ..< particleSet.particles.count {
            let particle = particleSet.particles[i]
            
            let particleLayer: SimpleLayer
            if i < self.particleLayers.count {
                particleLayer = self.particleLayers[i]
                particleLayer.isHidden = false
            } else {
                particleLayer = SimpleLayer()
                particleLayer.contents = self.particleImage.cgImage
                particleLayer.bounds = CGRect(origin: CGPoint(), size: self.particleImage.size)
                self.particleLayers.append(particleLayer)
                self.layer.addSublayer(particleLayer)
            }
            
            particleLayer.layerTintColor = particle.color.cgColor
            
            particleLayer.position = particle.position
            particleLayer.opacity = Float(particle.alpha)
            
            let particleScale = min(1.0, particle.currentTime / 0.3) * min(1.0, (particle.lifeTime - particle.currentTime) / 0.2) * particle.scale
            particleLayer.transform = CATransform3DMakeScale(particleScale, particleScale, 1.0)
        }
        if particleSet.particles.count < self.particleLayers.count {
            for i in particleSet.particles.count ..< self.particleLayers.count {
                self.particleLayers[i].isHidden = true
            }
        }
    }
    
    private var visible = false
    func setVisible(_ visible: Bool) {
        guard self.visible != visible else {
            return
        }
        self.visible = visible
        
        self.displayLink?.isPaused = !visible
    
//        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .linear)
//        transition.updateAlpha(layer: self.containerView.layer, alpha: visible ? 1.0 : 0.0, completion: { [weak self] finished in
//            if let strongSelf = self, finished && !visible && !strongSelf.visible {
//                for view in strongSelf.containerView.subviews {
//                    view.removeFromSuperview()
//                }
//            }
//        })
    }
    
    func resetAnimation() {
        
    }
}
