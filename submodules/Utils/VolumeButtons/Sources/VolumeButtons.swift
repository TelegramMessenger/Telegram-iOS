import Foundation
import UIKit
import AVKit
import SwiftSignalKit
import MediaPlayer
import LegacyComponents
import AccountContext

private protocol VolumeButtonHandlerImpl {
}

private final class LegacyHandlerImpl: VolumeButtonHandlerImpl {
    private let handler: PGCameraVolumeButtonHandler
    
    init(
        context: SharedAccountContext,
        performAction: @escaping (VolumeButtonsListener.Action) -> Void
    ) {
        self.handler = PGCameraVolumeButtonHandler(
            isCameraSpecific: false,
            eventView: context.mainWindow?.viewController?.view,
            upButtonPressedBlock: {
                performAction(.up)
            }, upButtonReleasedBlock: {
                performAction(.upRelease)
            }, downButtonPressedBlock: {
                performAction(.down)
            }, downButtonReleasedBlock: {
                performAction(.downRelease)
            }
        )
        self.handler.enabled = true
    }
    
    deinit {
        self.handler.enabled = false
    }
}

@available(iOS 17.2, *)
private final class AVCaptureEventHandlerImpl: VolumeButtonHandlerImpl {
    private weak var context: SharedAccountContext?
    private let interaction: AVCaptureEventInteraction
    
    init(
        context: SharedAccountContext,
        performAction: @escaping (VolumeButtonsListener.Action) -> Void
    ) {
        self.context = context
        self.interaction = AVCaptureEventInteraction(
            primary: { event in
                switch event.phase {
                case .began:
                    performAction(.down)
                case .ended:
                    performAction(.downRelease)
                case .cancelled:
                    performAction(.downRelease)
                @unknown default:
                    break
                }
            },
            secondary: { event in
                switch event.phase {
                case .began:
                    performAction(.up)
                case .ended:
                    performAction(.upRelease)
                case .cancelled:
                    performAction(.upRelease)
                @unknown default:
                    break
                }
            }
        )
        self.interaction.isEnabled = true
        context.mainWindow?.viewController?.view.addInteraction(self.interaction)
    }
    
    deinit {
        self.interaction.isEnabled = false
        self.context?.mainWindow?.viewController?.view.removeInteraction(self.interaction)
    }
}

public class VolumeButtonsListener {
    private final class ListenerReference {
        let id: Int
        weak var listener: VolumeButtonsListener?
        
        init(id: Int, listener: VolumeButtonsListener) {
            self.id = id
            self.listener = listener
        }
    }
    
    fileprivate enum Action {
        case up
        case upRelease
        case down
        case downRelease
    }
        
    private final class SharedContext: NSObject {
        private var handler: VolumeButtonHandlerImpl?
        private var cameraSpecificHandler: VolumeButtonHandlerImpl?
        
        private weak var sharedAccountContext: SharedAccountContext?
        
        private var nextListenerId: Int = 0
        private var listeners: [ListenerReference] = []
        
        override init() {
            super.init()
        }
        
        func add(listener: VolumeButtonsListener) -> Int {
            self.sharedAccountContext = listener.sharedAccountContext
            
            let id = self.nextListenerId
            self.nextListenerId += 1
            
            self.listeners.append(ListenerReference(id: id, listener: listener))
            self.updateListeners()
            
            return id
        }
        
        func update(id: Int) {
            self.updateListeners()
        }
        
        func remove(id: Int) {
            if let index = self.listeners.firstIndex(where: { $0.id == id }) {
                self.listeners.remove(at: index)
                self.updateListeners()
            }
        }
        
        private func performAction(_ action: Action, isCameraSpecific: Bool) {
            for i in (0 ..< self.listeners.count).reversed() {
                if let listener = self.listeners[i].listener, listener.isActive, listener.isCameraSpecific == isCameraSpecific {
                    switch action {
                    case .up:
                        listener.upPressed()
                    case .upRelease:
                        listener.upReleased()
                    case .down:
                        listener.downPressed()
                    case .downRelease:
                        listener.downReleased()
                    }
                }
            }
        }
        
        private func updateListeners() {
            var isGeneralActive = false
            var isCameraSpecificActive = false
            
            for i in (0 ..< self.listeners.count).reversed() {
                if let listener = self.listeners[i].listener {
                    if listener.isActive {
                        if #available(iOS 17.2, *) {
                            if listener.isCameraSpecific {
                                isCameraSpecificActive = true
                            } else {
                                isGeneralActive = true
                            }
                        } else {
                            isGeneralActive = true
                        }
                    }
                } else {
                    self.listeners.remove(at: i)
                }
            }
            
            if isGeneralActive {
                if self.handler == nil {
                    if let sharedAccountContext = self.sharedAccountContext {
                        let performAction: (VolumeButtonsListener.Action) -> Void = { [weak self] action in
                            self?.performAction(action, isCameraSpecific: false)
                        }
                        self.handler = LegacyHandlerImpl(
                            context: sharedAccountContext,
                            performAction: performAction
                        )
                    }
                }
            } else {
                self.handler = nil
            }
            
            if isCameraSpecificActive {
                if self.cameraSpecificHandler == nil {
                    if let sharedAccountContext = self.sharedAccountContext {
                        let performAction: (VolumeButtonsListener.Action) -> Void = { [weak self] action in
                            self?.performAction(action, isCameraSpecific: true)
                        }
                        if #available(iOS 17.2, *) {
                            self.cameraSpecificHandler = AVCaptureEventHandlerImpl(
                                context: sharedAccountContext,
                                performAction: performAction
                            )
                        } else {
                            self.cameraSpecificHandler = nil
                        }
                    }
                }
            } else {
                self.cameraSpecificHandler = nil
            }
        }
    }
    
    fileprivate let sharedAccountContext: SharedAccountContext
    fileprivate let isCameraSpecific: Bool
    
    private static var sharedContext: SharedContext = {
        return SharedContext()
    }()
    
    fileprivate let upPressed: () -> Void
    fileprivate let upReleased: () -> Void
    fileprivate let downPressed: () -> Void
    fileprivate let downReleased: () -> Void
    
    private var index: Int?
    
    fileprivate var isActive: Bool = false
    private var disposable: Disposable?
    
    public init(
        sharedContext: SharedAccountContext,
        isCameraSpecific: Bool,
        shouldBeActive: Signal<Bool, NoError>,
        upPressed: @escaping () -> Void,
        upReleased: @escaping () -> Void = {},
        downPressed: @escaping () -> Void,
        downReleased: @escaping () -> Void = {}
    ) {
        self.sharedAccountContext = sharedContext
        self.isCameraSpecific = isCameraSpecific
        self.upPressed = upPressed
        self.upReleased = upReleased
        self.downPressed = downPressed
        self.downReleased = downReleased
        
        self.index = VolumeButtonsListener.sharedContext.add(listener: self)
                
        self.disposable = (shouldBeActive
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self, let index = self.index else {
                return
            }
            self.isActive = value
            VolumeButtonsListener.sharedContext.update(id: index)
        })
    }
    
    deinit {
        if let index = self.index {
            VolumeButtonsListener.sharedContext.remove(id: index)
        }
        self.disposable?.dispose()
    }
}
