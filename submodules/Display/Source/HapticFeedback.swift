import Foundation
import UIKit
import AudioToolbox
import CoreHaptics

public enum ImpactHapticFeedbackStyle: Hashable {
    case light
    case medium
    case heavy
    case soft
    case rigid
    case veryLight
    case click05
    case click06
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
private final class HapticFeedbackImpl {
    private lazy var impactGenerator: [ImpactHapticFeedbackStyle : UIImpactFeedbackGenerator] = {
        if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
            return [.light: UIImpactFeedbackGenerator(style: .light),
                    .medium: UIImpactFeedbackGenerator(style: .medium),
                    .heavy: UIImpactFeedbackGenerator(style: .heavy),
                    .soft: UIImpactFeedbackGenerator(style: .soft),
                    .rigid: UIImpactFeedbackGenerator(style: .rigid),
                    .veryLight: UIImpactFeedbackGenerator(),
                    .click05: UIImpactFeedbackGenerator(),
                    .click06: UIImpactFeedbackGenerator()]
        } else {
            return [.light: UIImpactFeedbackGenerator(style: .light),
                    .medium: UIImpactFeedbackGenerator(style: .medium),
                    .heavy: UIImpactFeedbackGenerator(style: .heavy)]
        }
    }()
   
    private lazy var selectionGenerator: UISelectionFeedbackGenerator? = {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        var string = generator.debugDescription
        string.removeLast()
        let number = string.suffix(1)
        if number == "1" {
            return generator
        } else {
            if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
                return generator
            }
            return nil
        }
    }()
    
    private lazy var notificationGenerator: UINotificationFeedbackGenerator? = {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        var string = generator.debugDescription
        string.removeLast()
        let number = string.suffix(1)
        if number == "1" {
            return generator
        } else {
            return nil
        }
    }()
    
    func prepareTap() {
        if let selectionGenerator = self.selectionGenerator {
            selectionGenerator.prepare()
        }
    }
    
    func tap() {
        if let selectionGenerator = self.selectionGenerator {
            selectionGenerator.selectionChanged()
        }
    }
    
    func prepareImpact(_ style: ImpactHapticFeedbackStyle) {
        if let impactGenerator = self.impactGenerator[style] {
            impactGenerator.prepare()
        }
    }
    
    func impact(_ style: ImpactHapticFeedbackStyle) {
        if let impactGenerator = self.impactGenerator[style] {
            if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
                switch style {
                    case .click05:
                        impactGenerator.impactOccurred(intensity: 0.3)
                    case .click06:
                        impactGenerator.impactOccurred(intensity: 0.4)
                    case .veryLight:
                        impactGenerator.impactOccurred(intensity: 0.3)
                    default:
                        impactGenerator.impactOccurred()
                }
            } else {
                impactGenerator.impactOccurred()
            }
        }
    }
    
    func success() {
        if let notificationGenerator = self.notificationGenerator {
            notificationGenerator.notificationOccurred(.success)
        } else {
            AudioServicesPlaySystemSound(1520)
        }
    }
    
    func prepareError() {
        if let notificationGenerator = self.notificationGenerator {
            notificationGenerator.prepare()
        }
    }
    
    func error() {
        if let notificationGenerator = self.notificationGenerator {
            notificationGenerator.notificationOccurred(.error)
        } else {
            AudioServicesPlaySystemSound(1521)
        }
    }
    
    func warning() {
        if let notificationGenerator = self.notificationGenerator {
            notificationGenerator.notificationOccurred(.warning)
        } else {

        }
    }
    
    @objc dynamic func f() {
    }
}

public final class HapticFeedback {
    private var impl: AnyObject?
    
    public init() {
    }
    
    deinit {
        let impl = self.impl
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                if let impl = impl as? HapticFeedbackImpl {
                    impl.f()
                }
            }
        })
    }
    
    @available(iOSApplicationExtension 10.0, iOS 10.0, *)
    private func withImpl(_ f: (HapticFeedbackImpl) -> Void) {
        if self.impl == nil {
            self.impl = HapticFeedbackImpl()
        }
        f(self.impl as! HapticFeedbackImpl)
    }
    
    public func prepareTap() {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.withImpl { impl in
                impl.prepareTap()
            }
        }
    }
    
    public func tap() {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.withImpl { impl in
                impl.tap()
            }
        }
    }
    
    public func prepareImpact(_ style: ImpactHapticFeedbackStyle = .medium) {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.withImpl { impl in
                impl.prepareImpact(style)
            }
        }
    }
    
    public func impact(_ style: ImpactHapticFeedbackStyle = .medium) {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.withImpl { impl in
                impl.impact(style)
            }
        }
    }
    
    public func success() {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.withImpl { impl in
                impl.success()
            }
        }
    }
    
    public func prepareError() {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.withImpl { impl in
                impl.prepareError()
            }
        }
    }
    
    public func error() {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.withImpl { impl in
                impl.error()
            }
        }
    }
    
    public func warning() {
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.withImpl { impl in
                impl.warning()
            }
        }
    }
}

@available(iOS 13.0, *)
public final class ContinuousHaptic {
    private let engine: CHHapticEngine
    private let player: CHHapticPatternPlayer
    
    public init(duration: Double) throws {
        self.engine = try CHHapticEngine()
        
        var events: [CHHapticEvent] = []
        for i in 0 ... 10 {
            let t = CGFloat(i) / 10.0
            
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float((1.0 - t) * 0.1 + t * 1.0))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            let eventDuration: Double
            if i == 10 {
                eventDuration = 100.0
            } else {
                eventDuration = duration
            }
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: Double(i) / 10.0 * duration, duration: eventDuration)
            events.append(event)
        }

        let pattern = try CHHapticPattern(events: events, parameters: [])
        self.player = try self.engine.makePlayer(with: pattern)

        try self.engine.start()
        try self.player.start(atTime: 0)
    }
    
    deinit {
        self.engine.stop(completionHandler: nil)
    }
}
