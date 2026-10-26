// VERBATIM COPY of TelegramCore/Sources/State/Serialization.swift lines 5–27 and 70–246
// (apiPrefix, redactChildrenOfType, recursiveDescription), renamed to loggerDescription.
// The golden tests pin the logger's output, including redaction, against generated
// TelegramApi values. If Serialization.swift changes, re-copy it here.
import Foundation
@testable import TelegramApi

private let apiPrefix: String = {
    let type = _typeName(Api.User.self)
    let userType = "User"
    if type.hasSuffix(userType) {
        return String(type[type.startIndex ..< type.index(type.endIndex, offsetBy: -userType.count)])
    } else {
        return "TelegramApi.Api."
    }
}()

private let apiPrefixLength = apiPrefix.count

private let redactChildrenOfType: [String: Set<String>] = [
    "Message.message": Set(["message"]),
    "Updates.updateShortMessage": Set(["message"]),
    "Updates.updateShortChatMessage": Set(["message"]),
    "BotInlineMessage.botInlineMessageText": Set(["message"]),
    "DraftMessage.draftMessage": Set(["message"]),
    "InputSingleMedia.inputSingleMedia": Set(["message"]),
    "InputContact.inputPhoneContact": Set(["phone"]),
    "User.user": Set(["phone"]),
    "Update.updateUserPhone": Set(["phone"])
]

func loggerDescription(redact: Bool, of value: Any) -> String {
    let mirror = Mirror(reflecting: value)
    var result = ""
    if let displayStyle = mirror.displayStyle {
        switch displayStyle {
            case .enum:
                result.append(_typeName(mirror.subjectType))
                if result.hasPrefix(apiPrefix) {
                    result.removeSubrange(result.startIndex ..< result.index(result.startIndex, offsetBy: apiPrefixLength))
                }
                
                if let value = value as? TypeConstructorDescription {
                    let (consName, fields) = value.descriptionFields()
                    result.append(".")
                    result.append(consName)
                    
                    let redactChildren: Set<String>?
                    if redact {
                        redactChildren = redactChildrenOfType[result]
                    } else {
                        redactChildren = nil
                    }
                    
                    if !fields.isEmpty {
                        result.append("(")
                        var first = true
                        for (fieldName, fieldValue) in fields {
                            if first {
                                first = false
                            } else {
                                result.append(", ")
                            }
                            var redactValue: Bool = false
                            if let redactChildren = redactChildren, redactChildren.contains("*") {
                                redactValue = true
                            }
                            
                            result.append(fieldName)
                            result.append(": ")
                            if let redactChildren = redactChildren, redactChildren.contains(fieldName) {
                                redactValue = true
                            }
                            
                            if redactValue {
                                result.append("[[redacted]]")
                            } else {
                                result.append(loggerDescription(redact: redact, of: fieldValue))
                            }
                        }
                        result.append(")")
                    }
                } else {
                    inner: for child in mirror.children {
                        if let label = child.label {
                            result.append(".")
                            result.append(label)
                        }
                        let redactChildren: Set<String>?
                        if redact {
                            redactChildren = redactChildrenOfType[result]
                        } else {
                            redactChildren = nil
                        }
                        let valueMirror = Mirror(reflecting: child.value)
                        if let displayStyle = valueMirror.displayStyle {
                            switch displayStyle {
                            case .tuple:
                                var hadChildren = false
                                for child in valueMirror.children {
                                    if !hadChildren {
                                        hadChildren = true
                                        result.append("(")
                                    } else {
                                        result.append(", ")
                                    }
                                    var redactValue: Bool = false
                                    if let redactChildren = redactChildren, redactChildren.contains("*") {
                                        redactValue = true
                                    }
                                    if let label = child.label {
                                        result.append(label)
                                        result.append(": ")
                                        if let redactChildren = redactChildren, redactChildren.contains(label) {
                                            redactValue = true
                                        }
                                    }
                                    
                                    if redactValue {
                                        result.append("[[redacted]]")
                                    } else {
                                        result.append(loggerDescription(redact: redact, of: child.value))
                                    }
                                }
                                if hadChildren {
                                    result.append(")")
                                }
                            default:
                                break
                            }
                        } else {
                            result.append("(")
                            result.append(String(describing: child.value))
                            result.append(")")
                        }
                        break
                    }
                }
            case .collection:
                result.append("[")
                var isFirst = true
                for child in mirror.children {
                    if isFirst {
                        isFirst = false
                    } else {
                        result.append(", ")
                    }
                    result.append(loggerDescription(redact: redact, of: child.value))
                }
                result.append("]")
            case .class:
                if let value = value as? ConstructorParameterDescription {
                    if let v = value.value {
                        result.append(loggerDescription(redact: redact, of: v))
                    } else {
                        result.append("nil")
                    }
                } else if let value = value as? TypeConstructorDescription {
                    let (consName, fields) = value.descriptionFields()
                    result.append(".")
                    result.append(consName)
                    
                    let redactChildren: Set<String>?
                    if redact {
                        redactChildren = redactChildrenOfType[result]
                    } else {
                        redactChildren = nil
                    }
                    
                    if !fields.isEmpty {
                        result.append("(")
                        var first = true
                        for (fieldName, fieldValue) in fields {
                            if first {
                                first = false
                            } else {
                                result.append(", ")
                            }
                            var redactValue: Bool = false
                            if let redactChildren = redactChildren, redactChildren.contains("*") {
                                redactValue = true
                            }
                            
                            result.append(fieldName)
                            result.append(": ")
                            if let redactChildren = redactChildren, redactChildren.contains(fieldName) {
                                redactValue = true
                            }
                            
                            if redactValue {
                                result.append("[[redacted]]")
                            } else {
                                result.append(loggerDescription(redact: redact, of: fieldValue))
                            }
                        }
                        result.append(")")
                    }
                } else {
                    result.append("\(value)")
                }
            default:
                result.append("\(value)")
        }
    } else {
        result.append("\(value)")
    }
    return result
}

// VERBATIM COPY of TelegramCore/Sources/State/Serialization.swift lines 29–64 (redactFunctionParameters,
// apiFunctionDescription), renamed to loggerFunctionDescription with the redaction flag as a parameter.
private let redactFunctionParameters: [String: Set<String>] = [
    "messages.sendMessage": Set(["message"]),
    "messages.sendMedia": Set(["message"]),
    "messages.saveDraft": Set(["message"]),
    "messages.getWebPagePreview": Set(["message"])
]

func loggerFunctionDescription(redact: Bool, of desc: FunctionDescription) -> String {
    var result = desc.name
    if !desc.parameters.isEmpty {
        result.append("(")
        var first = true
        for param in desc.parameters {
            if first {
                first = false
            } else {
                result.append(", ")
            }
            result.append(param.0)
            result.append(": ")
            
            var redactParam = false
            if let redactParams = redactFunctionParameters[desc.name] {
                redactParam = redactParams.contains(param.0)
            }
            
            if redactParam, redact {
                result.append("[[redacted]]")
            } else {
                result.append(loggerDescription(redact: redact, of: param.1))
            }
        }
        result.append(")")
    }
    return result
}
