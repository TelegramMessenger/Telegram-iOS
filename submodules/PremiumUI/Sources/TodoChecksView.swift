import Foundation
import UIKit
import Display
import SwiftSignalKit
import CheckNode

final class TodoChecksView: UIView, PhoneDemoDecorationView {
    private struct Particle {
        var id: Int64
        var trackIndex: Int
        var position: CGPoint
        var scale: CGFloat
        var alpha: CGFloat
        var direction: CGPoint
        var velocity: CGFloat
        var rotation: CGFloat
        var currentTime: CGFloat
        var lifeTime: CGFloat
        var checkTime: CGFloat?
        var didSetup: Bool = false
        
        init(
            trackIndex: Int,
            position: CGPoint,
            scale: CGFloat,
            alpha: CGFloat,
            direction: CGPoint,
            velocity: CGFloat,
            rotation: CGFloat,
            currentTime: CGFloat,
            lifeTime: CGFloat,
            checkTime: CGFloat?
        ) {
            self.id = Int64.random(in: 0 ..< .max)
            self.trackIndex = trackIndex
            self.position = position
            self.scale = scale
            self.alpha = alpha
            self.direction = direction
            self.velocity = velocity
            self.rotation = rotation
            self.currentTime = currentTime
            self.lifeTime = lifeTime
            self.checkTime = checkTime
        }
        
        mutating func update(deltaTime: CGFloat) {
            var position = self.position
            position.x += self.direction.x * self.velocity * deltaTime
            position.y += self.direction.y * self.velocity * deltaTime
            self.position = position
            self.currentTime += deltaTime
        }
        
        mutating func setup() {
            self.didSetup = true
        }
    }
    
    private final class ParticleSet {
        private let size: CGSize
        var particles: [Particle] = []
        
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
                        let angle: CGFloat
                       if directionIndex < 8 {
                           angle = (CGFloat(directionIndex) / 5.0 - 0.5) * 2.0 * (CGFloat.pi / 4.0)
                       } else {
                           angle = CGFloat.pi + (CGFloat(directionIndex - 6) / 5.0 - 0.5) * 2.0 * (CGFloat.pi / 4.0)
                       }
                        
                        let lifeTimeMultiplier = 1.0
                        
                        let scale = 1.0
                                           
                        let direction = CGPoint(x: cos(angle), y: sin(angle))
                        let velocity = CGFloat.random(in: 18.0 ..< 22.0)
                        
                        let lifeTime = CGFloat.random(in: 3.2 ... 4.2)
                        
                        var position = CGPoint(x: self.size.width / 2.0, y: self.size.height / 2.0 + 40.0)
                        var initialOffset: CGFloat = 0.5
                        if preAdvance {
                            initialOffset = CGFloat.random(in: 0.7 ... 0.7)
                        } else {
                            initialOffset = CGFloat.random(in: 0.60 ... 0.72)
                        }
                        position.x += direction.x * initialOffset * 250.0
                        position.y += direction.y * initialOffset * 330.0
                        
                        var checkTime: CGFloat?
                        let p = CGFloat.random(in: 0.0 ... 1.0)
                        if p < 0.2 {
                            checkTime = 0.0
                        } else if p < 0.6 {
                            checkTime = 1.2 + CGFloat.random(in: 0.1 ... 0.6)
                        }
                        
                        let particle = Particle(
                            trackIndex: directionIndex,
                            position: position,
                            scale: scale,
                            alpha: 0.3,
                            direction: direction,
                            velocity: velocity,
                            rotation: CGFloat.random(in: -0.18 ... 0.2),
                            currentTime: 0.0,
                            lifeTime: lifeTime * lifeTimeMultiplier,
                            checkTime: checkTime
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
    private var particleLayers: [CheckLayer] = []
    private var particleMap: [Int64: CheckLayer] = [:]
    
    private var size: CGSize?
    private let large: Bool = false
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.particleSet = ParticleSet(size: frame.size, preAdvance: false)
        
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
        
        var validIds = Set<Int64>()
        for i in 0 ..< particleSet.particles.count {
            validIds.insert(particleSet.particles[i].id)
        }
        
        for id in self.particleMap.keys {
            if !validIds.contains(id) {
                self.particleMap[id]?.isHidden = true
                self.particleMap.removeValue(forKey: id)
            }
        }
        
        for i in 0 ..< particleSet.particles.count {
            let particle = particleSet.particles[i]
            
            let particleLayer: CheckLayer
            if let assignedLayer = self.particleMap[particle.id] {
                particleLayer = assignedLayer
            } else {
                if i < self.particleLayers.count, let availableLayer = self.particleLayers.first(where: { $0.isHidden }) {
                    particleLayer = availableLayer
                    particleLayer.isHidden = false
                } else {
                    particleLayer = CheckLayer()
                    particleLayer.animateScale = false
                    particleLayer.theme = CheckNodeTheme(backgroundColor: .white, strokeColor: .clear, borderColor: .white, overlayBorder: false, hasInset: false, hasShadow: false)
                    particleLayer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 22.0, height: 22.0))
                    self.particleLayers.append(particleLayer)
                    self.layer.addSublayer(particleLayer)
                }
                self.particleMap[particle.id] = particleLayer
            }
            
            if !particle.didSetup {
                particleLayer.setSelected(false, animated: false)
                particleSet.particles[i].setup()
            }
                        
            particleLayer.position = particle.position
            particleLayer.opacity = Float(particle.alpha)
            
            let particleScale = min(1.0, particle.currentTime / 0.3) * min(1.0, (particle.lifeTime - particle.currentTime) / 0.2) * particle.scale
            var transform = CATransform3DMakeScale(particleScale, particleScale, 1.0)
            transform = CATransform3DRotate(transform, particle.rotation, 0.0, 0.0, 1.0)
            particleLayer.transform = transform
            
            if let checkTime = particle.checkTime, particle.currentTime >= checkTime, !particleLayer.selected {
                particleLayer.setSelected(true, animated: true)
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
