import Foundation

private let reservedIdentifiers: [String] = [
    "protocol",
    "private"
]

extension String {
    var camelCased: String {
        var result = ""

        var capitalizeNext = false
        for c in self {
            if c == "_" {
                capitalizeNext = true
            } else {
                if capitalizeNext {
                    capitalizeNext = false
                    result.append(c.uppercased())
                } else {
                    result.append(c)
                }
            }
        }

        return result
    }

    var camelCasedAndEscaped: String {
        var result = self.camelCased

        if reservedIdentifiers.contains(result) {
            result = "`\(result)`"
        }

        return result
    }
}

private let objcReservedNames: Set<String> = [
    // C and Objective-C keywords and reserved identifiers
    "auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else",
    "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long", "register",
    "restrict", "return", "short", "signed", "sizeof", "static", "struct", "switch",
    "typedef", "union", "unsigned", "void", "volatile", "while",
    "id", "Class", "SEL", "IMP", "BOOL", "YES", "NO", "nil", "Nil", "NULL", "bool", "true", "false",
    "self", "super", "_cmd", "in", "out", "inout", "bycopy", "byref", "oneway",
    // selectors the ObjC runtime, Foundation or the TLObject root send or implement
    "description", "debugDescription", "hash", "isEqual", "class", "superclass", "retain",
    "release", "autorelease", "retainCount", "zone", "isProxy", "copy", "mutableCopy",
    "dealloc", "init", "new", "alloc", "initialize", "load", "version", "finalize",
    "methodSignatureForSelector", "doesNotRecognizeSelector", "respondsToSelector",
    "conformsToProtocol", "isKindOfClass", "isMemberOfClass", "allowsWeakReference",
    "retainWeakReference", "performSelector", "forwardingTargetForSelector", "copyWithZone",
    // generated initializers take a trailing `present:` argument
    "present",
]

private let arcMethodFamilies = ["alloc", "copy", "mutableCopy", "new", "init"]

/// The ObjC spelling (property, `_ivar`, selector piece) of a Swift field name. A
/// property named `hash` or `description` would override the root's runtime methods, and
/// a getter in an ARC method family (`newMessage`) would be treated as returning +1 by
/// clang and by Swift. A suffix cannot leave a family (`newMessage_` still starts with
/// `new` + uppercase), so family names get a `tl` prefix instead. `NS_SWIFT_NAME`
/// restores the Swift name.
func objcFieldName(for swiftName: String) -> String {
    for family in arcMethodFamilies where swiftName.hasPrefix(family) {
        let rest = swiftName.dropFirst(family.count)
        if rest.isEmpty || !rest.first!.isLowercase {
            return "tl" + swiftName.prefix(1).uppercased() + swiftName.dropFirst()
        }
    }
    if objcReservedNames.contains(swiftName) || swiftName.hasPrefix("tl_") {
        return swiftName + "_"
    }
    return swiftName
}
