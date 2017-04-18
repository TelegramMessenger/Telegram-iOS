import Foundation
import AsyncDisplayKit

open class SwitchNode: ASDisplayNode {
    public var valueUpdated: ((Bool) -> Void)?
    
    private var _isOn: Bool = false
    public var isOn: Bool {
        get {
            return self._isOn
        } set(value) {
            if (value != self._isOn) {
                self._isOn = value
                if self.isNodeLoaded {
                    (self.view as! UISwitch).setOn(value, animated: false)
                }
            }
        }
    }
    
    override public init() {
        super.init(viewBlock: {
            return UISwitch()
        }, didLoad: nil)
    }
    
    override open func didLoad() {
        super.didLoad()
        
        (self.view as! UISwitch).backgroundColor = .white
        
        (self.view as! UISwitch).setOn(self._isOn, animated: false)
        
        (self.view as! UISwitch).addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
    }
    
    public func setOn(_ value: Bool, animated: Bool) {
        self._isOn = value
        if self.isNodeLoaded {
            (self.view as! UISwitch).setOn(value, animated: animated)
        }
    }
    
    override open func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 51.0, height: 31.0)
    }
    
    @objc func switchValueChanged(_ view: UISwitch) {
        self.valueUpdated?(view.isOn)
    }
}
