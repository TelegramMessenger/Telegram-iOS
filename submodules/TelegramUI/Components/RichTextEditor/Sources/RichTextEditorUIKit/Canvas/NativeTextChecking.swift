#if canImport(UIKit)
import UIKit

/// Runtime-assembled private symbol strings (XOR 0x5A) so no plaintext private
/// class/selector appears in the binary. Values are the XOR of each UTF-8 byte.
enum ObfuscatedStrings {
    static let key: UInt8 = 0x5A
    static func decode(_ bytes: [UInt8]) -> String { String(decoding: bytes.map { $0 ^ key }, as: UTF8.self) }
    static let classNameBytes: [UInt8] = [15, 19, 14, 63, 34, 46, 25, 50, 63, 57, 49, 51, 52, 61, 25, 53, 52, 46, 40, 53, 54, 54, 63, 40]
    static let selInitWithClient: [UInt8] = [51, 52, 51, 46, 13, 51, 46, 50, 25, 54, 51, 63, 52, 46, 96]
    static let selPreheat: [UInt8] = [42, 40, 63, 50, 63, 59, 46, 14, 63, 34, 46, 25, 50, 63, 57, 49, 63, 40]
    static let selInvalidate: [UInt8] = [51, 52, 44, 59, 54, 51, 62, 59, 46, 63]
    // The `didChange*`/`consider*`/`inserted*` notify selectors are omitted: those controller methods are
    // no-op stubs on modern iOS (verified by disassembly). Checking is driven synchronously per word.
    static let selCheckSpelling: [UInt8] = [57, 50, 63, 57, 49, 9, 42, 63, 54, 54, 51, 52, 61, 28, 53, 40, 13, 53, 40, 62, 19, 52, 8, 59, 52, 61, 63, 96]
    static let selCheckGrammar: [UInt8] = [57, 50, 63, 57, 49, 29, 40, 59, 55, 55, 59, 40, 28, 53, 40, 9, 63, 52, 46, 63, 52, 57, 63, 19, 52, 8, 59, 52, 61, 63, 96, 53, 52, 10, 59, 47, 41, 63, 96]
    // Attribute keys the private controller stamps on a delivered annotation + the KVC accessors on the
    // (private) `NSTextAlternatives` object — kept obfuscated + confined here too, so no plaintext of the
    // private text-checking surface appears in the binary.
    static let attrDisplayStyle: [UInt8] = [20, 9, 14, 63, 34, 46, 27, 54, 46, 63, 40, 52, 59, 46, 51, 44, 63, 41, 30, 51, 41, 42, 54, 59, 35, 9, 46, 35, 54, 63]
    static let attrAlternatives: [UInt8] = [20, 9, 14, 63, 34, 46, 27, 54, 46, 63, 40, 52, 59, 46, 51, 44, 63, 41]
    static let kvcAlternativeStrings: [UInt8] = [59, 54, 46, 63, 40, 52, 59, 46, 51, 44, 63, 9, 46, 40, 51, 52, 61, 41]
    static let kvcPrimaryString: [UInt8] = [42, 40, 51, 55, 59, 40, 35, 9, 46, 40, 51, 52, 61]
}

/// Drives a private text-checking controller (resolved via `ObfuscatedStrings`) against a duck-typed
/// client. All private-API access is confined here. If the class can't resolve, `init?` returns nil and
/// there is NO fallback (checking off).
@available(iOS 13.0, *)
final class NativeTextChecker {
    private let controller: NSObject
    private weak var client: NSObject?

    static var nativeCheckingControllerClassIsAvailable: Bool {
        NSClassFromString(ObfuscatedStrings.decode(ObfuscatedStrings.classNameBytes)) != nil
    }

    init?(client: NSObject) {
        guard let cls = NSClassFromString(ObfuscatedStrings.decode(ObfuscatedStrings.classNameBytes)) as? NSObject.Type
        else { return nil }
        let sel = NSSelectorFromString(ObfuscatedStrings.decode(ObfuscatedStrings.selInitWithClient))
        guard let allocated = (cls as AnyObject).perform(NSSelectorFromString("alloc"))?.takeRetainedValue() as? NSObject,
              allocated.responds(to: sel),
              let inited = allocated.perform(sel, with: client)?.takeUnretainedValue() as? NSObject
        else { return nil }
        self.controller = inited
        self.client = client
    }

    func preheat() { call(ObfuscatedStrings.selPreheat) }
    func invalidate() { call(ObfuscatedStrings.selInvalidate) }
    /// The actual spelling check: synchronous per-word (reads the word via the client, runs the checker, and
    /// calls back `replaceRange:withAnnotatedString:`/`removeAnnotation:forRange:`). `range` is one word's span.
    func checkSpellingForWord(inGlobal range: NSRange) { drive(ObfuscatedStrings.selCheckSpelling, range) }

    /// Grammar check over one sentence's span. The selector takes a trailing scalar `BOOL onPause:` (passed
    /// true = a settled/final check), so it goes through an IMP cast rather than `perform`.
    func checkGrammarForSentence(inGlobal range: NSRange) {
        guard let client = client, let textRange = clientTextRange(client, range) else { return }
        let sel = NSSelectorFromString(ObfuscatedStrings.decode(ObfuscatedStrings.selCheckGrammar))
        guard controller.responds(to: sel) else { return }
        typealias GrammarFn = @convention(c) (AnyObject, Selector, AnyObject, Bool) -> Void
        let fn = unsafeBitCast(controller.method(for: sel), to: GrammarFn.self)
        fn(controller, sel, textRange, true)
    }

    private func call(_ selBytes: [UInt8]) {
        let sel = NSSelectorFromString(ObfuscatedStrings.decode(selBytes))
        if controller.responds(to: sel) { controller.perform(sel) }
    }
    /// Convert a global NSRange to the client's UITextRange and send it to the controller.
    private func drive(_ selBytes: [UInt8], _ range: NSRange) {
        guard let client = client else { return }
        let sel = NSSelectorFromString(ObfuscatedStrings.decode(selBytes))
        guard controller.responds(to: sel), let textRange = clientTextRange(client, range) else { return }
        controller.perform(sel, with: textRange)
    }
    /// Build a client UITextRange from a raw GLOBAL position range. The client provides an exact converter
    /// (`nativeTextRangeForGlobalLocation:length:`) that wraps its own position type directly — avoiding the
    /// `positionFromPosition:offset:` arithmetic, which is relative to `beginningOfDocument` (not at global 0
    /// on the editor's 1-based axis). Two scalar `NSInteger` args → called through an IMP cast (`perform`
    /// would pass them as object pointers).
    private func clientTextRange(_ client: NSObject, _ r: NSRange) -> AnyObject? {
        let sel = NSSelectorFromString("nativeTextRangeForGlobalLocation:length:")
        guard client.responds(to: sel) else { return nil }
        typealias RangeForGlobalFn = @convention(c) (AnyObject, Selector, Int, Int) -> Unmanaged<AnyObject>?
        let make = unsafeBitCast(client.method(for: sel), to: RangeForGlobalFn.self)
        return make(client, sel, r.location, r.length)?.takeUnretainedValue()
    }
}
#endif
