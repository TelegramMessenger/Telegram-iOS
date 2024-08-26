import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import BundleIconComponent
import MetalEngine
import CallScreen
import TelegramCore
import AccountContext
import SwiftSignalKit

final class VideoChatParticipantVideoComponent: Component {
    let call: PresentationGroupCall
    let participant: GroupCallParticipantsContext.Participant
    let isPresentation: Bool
    
    init(
        call: PresentationGroupCall,
        participant: GroupCallParticipantsContext.Participant,
        isPresentation: Bool
    ) {
        self.call = call
        self.participant = participant
        self.isPresentation = isPresentation
    }
    
    static func ==(lhs: VideoChatParticipantVideoComponent, rhs: VideoChatParticipantVideoComponent) -> Bool {
        if lhs.participant != rhs.participant {
            return false
        }
        if lhs.isPresentation != rhs.isPresentation {
            return false
        }
        return true
    }
    
    private struct VideoSpec: Equatable {
        var resolution: CGSize
        var rotationAngle: Float
        
        init(resolution: CGSize, rotationAngle: Float) {
            self.resolution = resolution
            self.rotationAngle = rotationAngle
        }
    }
    
    final class View: UIView {
        private var component: VideoChatParticipantVideoComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private let title = ComponentView<Empty>()
        
        private var videoSource: AdaptedCallVideoSource?
        private var videoDisposable: Disposable?
        private var videoBackgroundLayer: SimpleLayer?
        private var videoLayer: PrivateCallVideoLayer?
        private var videoSpec: VideoSpec?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.clipsToBounds = true
            self.layer.cornerRadius = 10.0
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.videoDisposable?.dispose()
        }
        
        func update(component: VideoChatParticipantVideoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            let nameColor = component.participant.peer.nameColor ?? .blue
            let nameColors = component.call.accountContext.peerNameColors.get(nameColor, dark: true)
            self.backgroundColor = nameColors.main
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.participant.peer.debugDisplayTitle, font: Font.regular(14.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 8.0 * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: 8.0, y: availableSize.height - 8.0 - titleSize.height), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            if let videoDescription = component.isPresentation ? component.participant.presentationDescription : component.participant.videoDescription {
                let videoBackgroundLayer: SimpleLayer
                if let current = self.videoBackgroundLayer {
                    videoBackgroundLayer = current
                } else {
                    videoBackgroundLayer = SimpleLayer()
                    videoBackgroundLayer.backgroundColor = UIColor(white: 0.1, alpha: 1.0).cgColor
                    self.videoBackgroundLayer = videoBackgroundLayer
                    self.layer.insertSublayer(videoBackgroundLayer, at: 0)
                    videoBackgroundLayer.isHidden = true
                }
                
                let videoLayer: PrivateCallVideoLayer
                if let current = self.videoLayer {
                    videoLayer = current
                } else {
                    videoLayer = PrivateCallVideoLayer()
                    self.videoLayer = videoLayer
                    self.layer.insertSublayer(videoLayer.blurredLayer, above: videoBackgroundLayer)
                    self.layer.insertSublayer(videoLayer, above: videoLayer.blurredLayer)
                    
                    videoLayer.blurredLayer.opacity = 0.25
                    
                    if let input = (component.call as! PresentationGroupCallImpl).video(endpointId: videoDescription.endpointId) {
                        let videoSource = AdaptedCallVideoSource(videoStreamSignal: input)
                        self.videoSource = videoSource
                        
                        self.videoDisposable?.dispose()
                        self.videoDisposable = videoSource.addOnUpdated { [weak self] in
                            guard let self, let videoSource = self.videoSource, let videoLayer = self.videoLayer else {
                                return
                            }
                            
                            let videoOutput = videoSource.currentOutput
                            videoLayer.video = videoOutput
                            
                            if let videoOutput {
                                let videoSpec = VideoSpec(resolution: videoOutput.resolution, rotationAngle: videoOutput.rotationAngle)
                                if self.videoSpec != videoSpec {
                                    self.videoSpec = videoSpec
                                    if !self.isUpdating {
                                        self.state?.updated(transition: .immediate, isLocal: true)
                                    }
                                }
                            } else {
                                if self.videoSpec != nil {
                                    self.videoSpec = nil
                                    if !self.isUpdating {
                                        self.state?.updated(transition: .immediate, isLocal: true)
                                    }
                                }
                            }
                            
                            /*var notifyOrientationUpdated = false
                            var notifyIsMirroredUpdated = false
                            
                            if !self.didReportFirstFrame {
                                notifyOrientationUpdated = true
                                notifyIsMirroredUpdated = true
                            }
                            
                            if let currentOutput = videoOutput {
                                let currentAspect: CGFloat
                                if currentOutput.resolution.height > 0.0 {
                                    currentAspect = currentOutput.resolution.width / currentOutput.resolution.height
                                } else {
                                    currentAspect = 1.0
                                }
                                if self.currentAspect != currentAspect {
                                    self.currentAspect = currentAspect
                                    notifyOrientationUpdated = true
                                }
                                
                                let currentOrientation: PresentationCallVideoView.Orientation
                                if currentOutput.followsDeviceOrientation {
                                    currentOrientation = .rotation0
                                } else {
                                    if abs(currentOutput.rotationAngle - 0.0) < .ulpOfOne {
                                        currentOrientation = .rotation0
                                    } else if abs(currentOutput.rotationAngle - Float.pi * 0.5) < .ulpOfOne {
                                        currentOrientation = .rotation90
                                    } else if abs(currentOutput.rotationAngle - Float.pi) < .ulpOfOne {
                                        currentOrientation = .rotation180
                                    } else if abs(currentOutput.rotationAngle - Float.pi * 3.0 / 2.0) < .ulpOfOne {
                                        currentOrientation = .rotation270
                                    } else {
                                        currentOrientation = .rotation0
                                    }
                                }
                                if self.currentOrientation != currentOrientation {
                                    self.currentOrientation = currentOrientation
                                    notifyOrientationUpdated = true
                                }
                                
                                let currentIsMirrored = !currentOutput.mirrorDirection.isEmpty
                                if self.currentIsMirrored != currentIsMirrored {
                                    self.currentIsMirrored = currentIsMirrored
                                    notifyIsMirroredUpdated = true
                                }
                            }
                            
                            if !self.didReportFirstFrame {
                                self.didReportFirstFrame = true
                                self.onFirstFrameReceived?(Float(self.currentAspect))
                            }
                            
                            if notifyOrientationUpdated {
                                self.onOrientationUpdated?(self.currentOrientation, self.currentAspect)
                            }
                            
                            if notifyIsMirroredUpdated {
                                self.onIsMirroredUpdated?(self.currentIsMirrored)
                            }*/
                            
                            
                        }
                    }
                }
                
                transition.setFrame(layer: videoBackgroundLayer, frame: CGRect(origin: CGPoint(), size: availableSize))
                
                if let videoSpec = self.videoSpec {
                    videoBackgroundLayer.isHidden = false
                    
                    let rotatedResolution = videoSpec.resolution
                    let videoSize = rotatedResolution.aspectFitted(availableSize)
                    let videoFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - videoSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - videoSize.height) * 0.5)), size: videoSize)
                    let blurredVideoSize = rotatedResolution.aspectFilled(availableSize)
                    let blurredVideoFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - blurredVideoSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - blurredVideoSize.height) * 0.5)), size: blurredVideoSize)
                    
                    let videoResolution = rotatedResolution.aspectFitted(CGSize(width: availableSize.width * 3.0, height: availableSize.height * 3.0))
                    let rotatedVideoResolution = videoResolution
                    
                    transition.setPosition(layer: videoLayer, position: videoFrame.center)
                    transition.setBounds(layer: videoLayer, bounds: CGRect(origin: CGPoint(), size: videoFrame.size))
                    videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(rotatedVideoResolution.width), height: Int(rotatedVideoResolution.height)), edgeInset: 2)
                    
                    transition.setPosition(layer: videoLayer.blurredLayer, position: blurredVideoFrame.center)
                    transition.setBounds(layer: videoLayer.blurredLayer, bounds: CGRect(origin: CGPoint(), size: blurredVideoFrame.size))
                }
            } else {
                if let videoBackgroundLayer = self.videoBackgroundLayer {
                    self.videoBackgroundLayer = nil
                    videoBackgroundLayer.removeFromSuperlayer()
                }
                if let videoLayer = self.videoLayer {
                    self.videoLayer = nil
                    videoLayer.blurredLayer.removeFromSuperlayer()
                    videoLayer.removeFromSuperlayer()
                }
                self.videoDisposable?.dispose()
                self.videoDisposable = nil
                self.videoSource = nil
                self.videoSpec = nil
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
