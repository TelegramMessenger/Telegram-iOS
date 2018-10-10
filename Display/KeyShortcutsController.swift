import UIKit

public protocol KeyShortcutResponder {
    var keyShortcuts: [KeyShortcut] { get };
}

public class KeyShortcutsController: UIResponder {
    private var effectiveShortcuts: [KeyShortcut]?
    private var viewControllerEnumerator: ((ViewController) -> Bool) -> Void
    
    public static var isAvailable: Bool {
        if #available(iOSApplicationExtension 8.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            return true
        } else {
            return false
        }
    }
    
    public init(enumerator: @escaping ((ViewController) -> Bool) -> Void) {
        self.viewControllerEnumerator = enumerator
        super.init()
    }
    
    public override var keyCommands: [UIKeyCommand]? {
        var convertedCommands: [UIKeyCommand] = []
        var shortcuts: [KeyShortcut] = []
        
        self.viewControllerEnumerator({ viewController -> Bool in
            guard let viewController = viewController as? KeyShortcutResponder else {
                return true
            }
            shortcuts.append(contentsOf: viewController.keyShortcuts)
            return true
        })
        
        // iOS 8 fix
        convertedCommands.append(KeyShortcut(modifiers:[.command]).uiKeyCommand)
        convertedCommands.append(KeyShortcut(modifiers:[.alternate]).uiKeyCommand)
        
        convertedCommands.append(contentsOf: shortcuts.map { $0.uiKeyCommand })
        
        self.effectiveShortcuts = shortcuts
        
        return convertedCommands
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
        if sender is UIKeyCommand {
            return true
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    public override func target(forAction action: Selector, withSender sender: Any?) -> Any? {
        if sender is UIKeyCommand {
            return self
        } else {
            return super.target(forAction: action, withSender: sender)
        }
    }
    
    public override var canBecomeFirstResponder: Bool {
        return true
    }
}
