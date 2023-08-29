import Foundation
import UIKit
import SwiftSignalKit
import MediaPlayer

import LegacyComponents


public class VolumeButtonsListener {
    private final class ListenerReference {
        let id: Int
        weak var listener: VolumeButtonsListener?
        
        init(id: Int, listener: VolumeButtonsListener) {
            self.id = id
            self.listener = listener
        }
    }
    
    private enum Action {
        case up
        case upRelease
        case down
        case downRelease
    }
    
    private final class SharedContext: NSObject {
        private var handler: PGCameraVolumeButtonHandler?
        
        private var nextListenerId: Int = 0
        private var listeners: [ListenerReference] = []
        
        override init() {
            super.init()
                    
            /*self.disposable = (shouldBeActive
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.handler.enabled = value
            })*/
        }
        
        deinit {
            if let handler = self.handler {
                handler.enabled = false
            }
        }
        
        func add(listener: VolumeButtonsListener) -> Int {
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
        
        private func performAction(action: Action) {
            for i in (0 ..< self.listeners.count).reversed() {
                if let listener = self.listeners[i].listener, listener.isActive {
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
            var isActive = false
            
            for i in (0 ..< self.listeners.count).reversed() {
                if let listener = self.listeners[i].listener {
                    if listener.isActive {
                        isActive = true
                    }
                } else {
                    self.listeners.remove(at: i)
                }
            }
            
            if isActive {
                if self.handler == nil {
                    self.handler = PGCameraVolumeButtonHandler(upButtonPressedBlock: { [weak self] in
                        self?.performAction(action: .up)
                    }, upButtonReleasedBlock: { [weak self] in
                        self?.performAction(action: .upRelease)
                    }, downButtonPressedBlock: { [weak self] in
                        self?.performAction(action: .down)
                    }, downButtonReleasedBlock: { [weak self] in
                        self?.performAction(action: .downRelease)
                    })
                }
                self.handler?.enabled = true
            } else {
                if let handler = self.handler {
                    self.handler = nil
                    
                    handler.enabled = false
                }
            }
        }
    }
    
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
        shouldBeActive: Signal<Bool, NoError>,
        upPressed: @escaping () -> Void,
        upReleased: @escaping () -> Void = {},
        downPressed: @escaping () -> Void,
        downReleased: @escaping () -> Void = {}
    ) {
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
