import UIKit

public protocol KeyShortcutResponder {
    var keyShortcuts: [KeyShortcut] { get };
}

public protocol UnclaimedKeyPressResponder {
    func handleUnclaimedKeyPress(_ key: UIKey) -> Bool
}

public class KeyShortcutsController: UIResponder {
    private var effectiveShortcuts: [KeyShortcut]?
    private var viewControllerEnumerator: (@escaping (ContainableController) -> Bool) -> Void
    
    public static var isAvailable: Bool {
        return true
    }
    
    public static var isSuspended: Bool = false
    
    public init(enumerator: @escaping (@escaping (ContainableController) -> Bool) -> Void) {
        self.viewControllerEnumerator = enumerator
        super.init()
    }
    
    public override var keyCommands: [UIKeyCommand]? {
        if KeyShortcutsController.isSuspended {
            return []
        }
        var convertedCommands: [UIKeyCommand] = []
        var shortcuts: [KeyShortcut] = []
        
        self.viewControllerEnumerator({ viewController -> Bool in
            guard let viewController = viewController as? KeyShortcutResponder else {
                return true
            }
            // `keyShortcuts` is an EXPENSIVE computed property (a controller rebuilds its whole shortcut
            // array — closures and all — on every access). UIKit queries `keyCommands` on every hardware
            // key-down, so this getter is hot. Read it ONCE per controller: the old
            // `removeAll(where: { viewController.keyShortcuts.contains($0) })` re-invoked the getter once
            // per already-accumulated shortcut (quadratic rebuilds), then `append` invoked it again.
            let viewControllerShortcuts = viewController.keyShortcuts
            shortcuts.removeAll(where: { viewControllerShortcuts.contains($0) })
            shortcuts.append(contentsOf: viewControllerShortcuts)
            return true
        })
        
        convertedCommands.append(contentsOf: shortcuts.map { $0.uiKeyCommand })
        
        self.effectiveShortcuts = shortcuts
        
        return convertedCommands
    }
    
    public func handleUnclaimedPresses(_ presses: Set<UIPress>) -> Bool {
        guard !KeyShortcutsController.isSuspended, presses.count == 1, let press = presses.first, let key = press.key, !(press.responder is UITextInput) else {
            return false
        }
        let modifiers = key.modifierFlags.intersection([.shift, .control, .alternate, .command])
        let input = key.charactersIgnoringModifiers.lowercased()
        if let shortcuts = self.effectiveShortcuts, shortcuts.contains(where: { $0.modifiers == modifiers && $0.input.lowercased() == input }) {
            return false
        }
        var handled = false
        self.viewControllerEnumerator({ viewController -> Bool in
            if handled {
                return false
            }
            if let viewController = viewController as? UnclaimedKeyPressResponder, viewController.handleUnclaimedKeyPress(key) {
                handled = true
                return false
            }
            return true
        })
        return handled
    }

    public override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if !self.handleUnclaimedPresses(presses) {
            super.pressesBegan(presses, with: event)
        }
    }

    @objc func handleKeyCommand(_ command: UIKeyCommand) {
        if let shortcut = findShortcut(for: command) {
            shortcut.action()
        }
    }
    
    private func findShortcut(for command: UIKeyCommand) -> KeyShortcut? {
        if let shortcuts = self.effectiveShortcuts {
            for shortcut in shortcuts {
                if shortcut.isEqual(to: command) {
                    return shortcut
                }
            }
        }
        return nil
    }
    
    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if let keyCommand = sender as? UIKeyCommand, let _ = findShortcut(for: keyCommand) {
            return true
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    public override func target(forAction action: Selector, withSender sender: Any?) -> Any? {
        if let keyCommand = sender as? UIKeyCommand, let _ = findShortcut(for: keyCommand) {
            return self
        } else {
            return super.target(forAction: action, withSender: sender)
        }
    }
    
    public override var canBecomeFirstResponder: Bool {
        return true
    }
}
