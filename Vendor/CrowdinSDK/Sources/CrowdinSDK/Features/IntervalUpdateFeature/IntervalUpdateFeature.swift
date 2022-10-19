//
//  IntervalUpdateFeature.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 4/8/19.
//

import Foundation

protocol IntervalUpdateFeatureProtocol {
    static var shared: IntervalUpdateFeatureProtocol? { get set }
    var interval: TimeInterval { get set }
    var enabled: Bool { get set }
    
    init(interval: TimeInterval)
    
    func start()
    func stop()
}

final class IntervalUpdateFeature: IntervalUpdateFeatureProtocol {
    var enabled: Bool {
        set {
            if newValue {
                start()
            } else {
                stop()
            }
        }
        get {
            return timer != nil
        }
    }
    
    private static var minimumTimeInterval: TimeInterval = 60 * 15 // 15 minutes
    static var shared: IntervalUpdateFeatureProtocol?
    
    var interval: TimeInterval
    var timer: Timer? = nil
    
    convenience init() {
        self.init(interval: IntervalUpdateFeature.minimumTimeInterval)
    }
    
    required init(interval: TimeInterval) {
        let minimumTimeInterval = IntervalUpdateFeature.minimumTimeInterval
        self.interval = minimumTimeInterval < interval ? interval : minimumTimeInterval
    }
    
    func start() {
        if timer != nil {
            self.stop()
        }
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(update(sender:)), userInfo: nil, repeats: true)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func update(sender: Any) {
        Localization.current.provider.refreshLocalization()
    }
}
