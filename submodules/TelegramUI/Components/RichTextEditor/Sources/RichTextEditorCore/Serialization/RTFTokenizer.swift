import Foundation

public enum RTFToken: Equatable {
    case groupStart
    case groupEnd
    case controlWord(String, Int?)
    case controlSymbol(Character)
    case text(String)
}

public enum RTFTokenizer {
    public static func tokenize(_ data: Data) -> [RTFToken] {
        let bytes = [UInt8](data)
        var i = 0
        var tokens: [RTFToken] = []
        var ucStack: [Int] = [1]                 // \uc skip-count, group-scoped
        var pendingHighSurrogate: UInt16? = nil

        func flushText(_ s: String) { if !s.isEmpty { tokens.append(.text(s)) } }
        func appendScalar(_ v: UInt32) {
            // Recombine a high surrogate held from a previous \u with this low surrogate.
            if let hi = pendingHighSurrogate {
                pendingHighSurrogate = nil
                if (0xDC00...0xDFFF).contains(v) {
                    let scalar = 0x10000 + (UInt32(hi) - 0xD800) * 0x400 + (v - 0xDC00)
                    if let s = Unicode.Scalar(scalar) { tokens.append(.text(String(s))) }
                    return
                } else if let s = Unicode.Scalar(hi) { tokens.append(.text(String(s))) }   // lone hi: emit it
            }
            if (0xD800...0xDBFF).contains(v) { pendingHighSurrogate = UInt16(v); return }   // hold high surrogate
            if let s = Unicode.Scalar(v) { tokens.append(.text(String(s))) }
        }
        func skipFallback(_ n: Int) {            // skip n chars / \'XX bytes after a \u
            var skipped = 0
            while skipped < n && i < bytes.count {
                if bytes[i] == 0x5C, i + 1 < bytes.count, bytes[i+1] == UInt8(ascii: "'") {
                    i += 4; skipped += 1          // \'XX = one fallback unit
                } else { i += 1; skipped += 1 }
            }
        }

        var textBuf = ""
        while i < bytes.count {
            let b = bytes[i]
            if b == 0x7B { flushText(textBuf); textBuf = ""; tokens.append(.groupStart); ucStack.append(ucStack.last ?? 1); i += 1; continue }
            if b == 0x7D { flushText(textBuf); textBuf = ""; tokens.append(.groupEnd); if ucStack.count > 1 { ucStack.removeLast() }; i += 1; continue }
            if b == 0x0D || b == 0x0A { flushText(textBuf); textBuf = ""; i += 1; continue }   // ignore raw CR/LF
            if b != 0x5C {                                   // ordinary text byte (treat as Latin-1/ASCII)
                textBuf += String(Unicode.Scalar(b)); i += 1; continue
            }
            // backslash
            flushText(textBuf); textBuf = ""
            i += 1
            guard i < bytes.count else { break }
            let c = bytes[i]
            if c == 0x5C || c == 0x7B || c == 0x7D {         // \\ \{ \}
                tokens.append(.text(String(Unicode.Scalar(c)))); i += 1; continue
            }
            if c == 0x0D || c == 0x0A {                       // backslash + CR/LF == \par (RTF spec)
                // Cocoa/AppKit (TextEdit, Notes, Safari, Mail, Pages) serializes paragraph breaks this
                // way, not as a literal `\par`. Without this, every cross-app paste glues all paragraphs
                // into one (the "pasting removes newlines" bug).
                tokens.append(.controlWord("par", nil)); i += 1
                if c == 0x0D, i < bytes.count, bytes[i] == 0x0A { i += 1 }   // swallow the LF of a CRLF
                continue
            }
            if c == UInt8(ascii: "'") {                       // \'XX
                if i + 2 < bytes.count, let hi = hexVal(bytes[i+1]), let lo = hexVal(bytes[i+2]) {
                    appendScalar(cp1252(UInt8(hi * 16 + lo))); i += 3
                } else { i += 1 }
                continue
            }
            if !isLetter(c) {                                 // control symbol (\*, \~, \-, \_, …)
                let ch = Character(Unicode.Scalar(c))
                switch ch {
                case "~": appendScalar(0x00A0)
                case "_": appendScalar(0x2D)                  // non-breaking hyphen → "-"
                case "-": break                               // optional hyphen → nothing
                default: tokens.append(.controlSymbol(ch))
                }
                i += 1; continue
            }
            // control word: letters, optional -?digits, optional single space delimiter
            var name = ""
            while i < bytes.count, isLetter(bytes[i]) { name.append(Character(Unicode.Scalar(bytes[i]))); i += 1 }
            var param: Int? = nil
            if i < bytes.count, bytes[i] == UInt8(ascii: "-") || isDigit(bytes[i]) {
                var numStr = ""
                if bytes[i] == UInt8(ascii: "-") { numStr = "-"; i += 1 }
                while i < bytes.count, isDigit(bytes[i]) { numStr.append(Character(Unicode.Scalar(bytes[i]))); i += 1 }
                param = Int(numStr)
            }
            if i < bytes.count, bytes[i] == 0x20 { i += 1 }    // consume one trailing space delimiter
            if name == "uc" { ucStack[ucStack.count - 1] = param ?? 1; continue }
            if name == "u", let v = param {                   // \uN signed-16 unicode
                let scalar = v < 0 ? UInt32(v + 0x10000) : UInt32(v)
                appendScalar(scalar)
                skipFallback(ucStack.last ?? 1)
                continue
            }
            tokens.append(.controlWord(name, param))
        }
        flushText(textBuf)
        if let hi = pendingHighSurrogate, let s = Unicode.Scalar(hi) { tokens.append(.text(String(s))) }
        return tokens
    }

    private static func isLetter(_ b: UInt8) -> Bool { (0x41...0x5A).contains(b) || (0x61...0x7A).contains(b) }
    private static func isDigit(_ b: UInt8) -> Bool { (0x30...0x39).contains(b) }
    private static func hexVal(_ b: UInt8) -> Int? {
        if (0x30...0x39).contains(b) { return Int(b - 0x30) }
        if (0x61...0x66).contains(b) { return Int(b - 0x61 + 10) }
        if (0x41...0x46).contains(b) { return Int(b - 0x41 + 10) }
        return nil
    }
    /// cp1252 → Unicode (only the slots that differ from Latin-1; others map 1:1).
    private static func cp1252(_ b: UInt8) -> UInt32 {
        let map: [UInt8: UInt32] = [0x80:0x20AC,0x82:0x201A,0x83:0x0192,0x84:0x201E,0x85:0x2026,0x86:0x2020,0x87:0x2021,0x88:0x02C6,0x89:0x2030,0x8A:0x0160,0x8B:0x2039,0x8C:0x0152,0x8E:0x017D,0x91:0x2018,0x92:0x2019,0x93:0x201C,0x94:0x201D,0x95:0x2022,0x96:0x2013,0x97:0x2014,0x98:0x02DC,0x99:0x2122,0x9A:0x0161,0x9B:0x203A,0x9C:0x0153,0x9E:0x017E,0x9F:0x0178]
        return map[b] ?? UInt32(b)
    }
}
