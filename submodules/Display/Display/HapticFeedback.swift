import Foundation
import UIKit
import AudioToolbox

public enum ImpactHapticFeedbackStyle: Hashable {
    case light
    case medium
    case heavy
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
private final class HapticFeedbackImpl {
    private lazy var impactGenerator: [ImpactHapticFeedbackStyle : UIImpactFeedbackGenerator] = {
        [.light: UIImpactFeedbackGenerator(style: .light),
         .medium: UIImpactFeedbackGenerator(style: .medium),
         .heavy: UIImpactFeedbackGenerator(style: .heavy)] }()
   
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
            impactGenerator.impactOccurred()
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
}

