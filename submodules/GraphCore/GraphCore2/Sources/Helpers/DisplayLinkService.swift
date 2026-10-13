//
//  DisplayLinkService.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/7/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Foundation
#if os(macOS)
import Cocoa
import CoreVideo
#else
import UIKit
#endif
import CoreGraphics

public protocol DisplayLinkListner: AnyObject {
    func update(delta: TimeInterval)
}

#if os(macOS)

private final class DisplayLinkTarget: NSObject {
    weak var service: DisplayLinkService?

    init(service: DisplayLinkService) {
        self.service = service
    }

    @available(macOS 14.0, *)
    @objc func tick(_ link: CADisplayLink) {
        self.service?.fire(frameTime: link.targetTimestamp)
    }
}

class DisplayLinkService {
    let listners = NSHashTable<AnyObject>.weakObjects()
    static let shared = DisplayLinkService()

    private var isRunning = false
    private var previousTickTime: CFTimeInterval = 0
    private var lastFireTime: CFTimeInterval = 0
    private let staleInterval: CFTimeInterval = 0.5
    private var displayLink: AnyObject?
    private var coreVideoLink: CVDisplayLink?
    private var fallbackTimer: Timer?
    private let coreVideoTickPending = PendingFlag()
    private lazy var target = DisplayLinkTarget(service: self)

    private init() {
    }

    public func add(listner: DisplayLinkListner) {
        self.listners.add(listner)
        if self.isRunning, CACurrentMediaTime() - self.lastFireTime > self.staleInterval {
            self.stopDisplayLink()
            self.coreVideoLink = nil
        }
        self.startDisplayLink()
    }

    public func remove(listner: DisplayLinkListner) {
        self.listners.remove(listner)

        if self.listners.count == 0 {
            self.stopDisplayLink()
        }
    }

    private func startDisplayLink() {
        guard !self.isRunning else {
            return
        }
        self.isRunning = true
        self.previousTickTime = CACurrentMediaTime()
        self.lastFireTime = self.previousTickTime

        if #available(macOS 14.0, *), let screen = NSScreen.main ?? NSScreen.screens.first {
            let link = screen.displayLink(target: self.target, selector: #selector(DisplayLinkTarget.tick(_:)))
            link.add(to: .main, forMode: .common)
            self.displayLink = link
            return
        }

        if self.coreVideoLink == nil {
            var link: CVDisplayLink?
            CVDisplayLinkCreateWithActiveCGDisplays(&link)
            if let link = link {
                let pending = self.coreVideoTickPending
                CVDisplayLinkSetOutputHandler(link, { _, _, outputTime, _, _ in
                    let frameTime = CFTimeInterval(outputTime.pointee.hostTime) / CFTimeInterval(NSEC_PER_SEC) * CFTimeInterval(machTimebaseRatio)
                    if pending.begin() {
                        DispatchQueue.main.async {
                            pending.end()
                            DisplayLinkService.shared.fire(frameTime: frameTime)
                        }
                    }
                    return kCVReturnSuccess
                })
            }
            self.coreVideoLink = link
        }
        if let link = self.coreVideoLink, CVDisplayLinkStart(link) == kCVReturnSuccess {
            return
        }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true, block: { _ in
            DisplayLinkService.shared.fire()
        })
        RunLoop.main.add(timer, forMode: .common)
        self.fallbackTimer = timer
    }

    private func stopDisplayLink() {
        guard self.isRunning else {
            return
        }
        self.isRunning = false
        if #available(macOS 14.0, *), let link = self.displayLink as? CADisplayLink {
            link.invalidate()
        }
        self.displayLink = nil
        if let link = self.coreVideoLink {
            CVDisplayLinkStop(link)
        }
        self.fallbackTimer?.invalidate()
        self.fallbackTimer = nil
    }

    func fire(frameTime: CFTimeInterval) {
        guard self.isRunning else {
            return
        }
        self.lastFireTime = CACurrentMediaTime()
        let currentTime = max(frameTime, self.previousTickTime)
        let delta = currentTime - self.previousTickTime
        self.previousTickTime = currentTime

        let allListners = self.listners.allObjects
        var hasListners = false
        for listner in allListners {
            (listner as! DisplayLinkListner).update(delta: delta)
            hasListners = true
        }

        if !hasListners {
            self.stopDisplayLink()
        }
    }

    public func fire() {
        self.fire(frameTime: CACurrentMediaTime())
    }
}

private let machTimebaseRatio: Double = {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    return Double(info.numer) / Double(info.denom)
}()

private final class PendingFlag {
    private var lock = os_unfair_lock()
    private var pending = false

    func begin() -> Bool {
        os_unfair_lock_lock(&self.lock)
        defer {
            os_unfair_lock_unlock(&self.lock)
        }
        if self.pending {
            return false
        }
        self.pending = true
        return true
    }

    func end() {
        os_unfair_lock_lock(&self.lock)
        self.pending = false
        os_unfair_lock_unlock(&self.lock)
    }
}

#else

class DisplayLinkService {
    let listners = NSHashTable<AnyObject>.weakObjects()
    static let shared = DisplayLinkService()

    public func add(listner: DisplayLinkListner) {
        listners.add(listner)
        startDisplayLink()
    }

    public func remove(listner: DisplayLinkListner) {
        listners.remove(listner)

        if listners.count == 0 {
            stopDisplayLink()
        }
    }

    private init() {
        dispatchSourceTimer.schedule(deadline: .now() + 1.0 / 60, repeating: 1.0 / 60)
        dispatchSourceTimer.setEventHandler {
            DispatchQueue.main.sync {
                self.fire()
            }
        }
    }

    private var dispatchSourceTimer = DispatchSource.makeTimerSource(flags: [], queue: .global(qos: .userInteractive))
    private var dispatchSourceTimerStarted: Bool = false
    private var previousTickTime = 0.0

    private func startDisplayLink() {
        guard !dispatchSourceTimerStarted else { return }
        dispatchSourceTimerStarted = true
        previousTickTime = CACurrentMediaTime()
        dispatchSourceTimer.resume()
    }

    private func stopDisplayLink() {
        guard dispatchSourceTimerStarted else { return }
        dispatchSourceTimerStarted = false
        dispatchSourceTimer.suspend()
    }

    public func fire() {
        let currentTime = CACurrentMediaTime()

        let delta = currentTime - previousTickTime
        previousTickTime = currentTime
        let allListners = listners.allObjects
        var hasListners = false
        for listner in allListners {
            (listner as! DisplayLinkListner).update(delta: delta)
            hasListners = true
        }

        if !hasListners {
            stopDisplayLink()
        }
    }
}

#endif
