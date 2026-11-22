#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Maps a keyboard primary-language code ("ar", "he", "fa", "en", …) to a writing direction, or nil
    /// when unknown/absent. Used as the empty-paragraph fallback so the caret opens on the correct side.
    static func writingDirection(forPrimaryLanguage code: String?) -> NSWritingDirection? {
        guard let code, !code.isEmpty else { return nil }
        switch Locale.characterDirection(forLanguage: code) {
        case .rightToLeft: return .rightToLeft
        case .leftToRight: return .leftToRight
        default: return nil
        }
    }

    /// Applies the whole-document override: stores the model and pushes the resolved base direction onto
    /// the mapper (so every box rebuilt afterward bakes it in). Caller reloads content to take effect.
    func applyWritingDirectionOverride(_ mode: DocumentLayoutDirection) {
        self.layoutDirectionModel = mode
        switch mode {
        case .auto:        self.mapper.baseWritingDirection = .natural
        case .leftToRight: self.mapper.baseWritingDirection = .leftToRight
        case .rightToLeft: self.mapper.baseWritingDirection = .rightToLeft
        }
    }

    /// The direction the next typed character / an empty paragraph should use: a forced override, else the
    /// live keyboard's language, else the app's layout direction.
    var typingWritingDirection: NSWritingDirection {
        switch layoutDirectionModel {
        case .leftToRight: return .leftToRight
        case .rightToLeft: return .rightToLeft
        case .auto:
            if let dir = DocumentCanvasView.writingDirection(forPrimaryLanguage: keyboardPrimaryLanguage()) {
                return dir
            }
            return effectiveUserInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
        }
    }

    /// The resolved writing direction at a global position: a forced override, else the paragraph's
    /// content-detected direction, else the typing direction (empty paragraph).
    func resolvedDirection(forGlobal pos: Int) -> NSWritingDirection {
        switch layoutDirectionModel {
        case .leftToRight: return .leftToRight
        case .rightToLeft: return .rightToLeft
        case .auto:
            if let (region, local) = leafRegion(containingGlobal: clampGlobal(pos)),
               let detected = region.layout.baseDirection(atOffset: local) {
                return detected
            }
            return typingWritingDirection
        }
    }

    /// The live keyboard language (overridable in tests). Default reads the input mode.
    func keyboardPrimaryLanguage() -> String? { keyboardLanguageProviderForTesting?() ?? textInputMode?.primaryLanguage }
}

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Sets each EMPTY top-level paragraph's per-box direction to the current typing direction so its
    /// caret opens on the correct side before the first keystroke. Non-empty boxes clear the override
    /// (content drives them). Works in all modes: in forced mode `typingWritingDirection` is the forced
    /// direction, so empty boxes get the right hint; in auto mode it is the keyboard/app direction.
    func refreshEmptyBoxWritingDirections() {
        let typing = typingWritingDirection
        for case let b as BlockBox in boxes {
            let desired: NSWritingDirection? = (b.textLength == 0) ? typing : nil
            if b.writingDirectionOverride != desired {
                b.writingDirectionOverride = desired
                restyle(b)
            }
        }
    }
}
#endif
