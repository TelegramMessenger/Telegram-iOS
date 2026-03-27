import Foundation

struct QualifiedName: Hashable, Comparable, CustomStringConvertible {
    var namespace: String?
    var value: String
    
    var description: String {
        if let namespace = self.namespace {
            return "\(namespace).\(self.value)"
        } else {
            return self.value
        }
    }
    
    static func <(lhs: QualifiedName, rhs: QualifiedName) -> Bool {
        return lhs.description < rhs.description
    }
}

extension QualifiedName {
    init(string: String) {
        if let dotRange = string.range(of: ".") {
            self.init(namespace: String(string[string.startIndex ..< dotRange.lowerBound]), value: String(string[dotRange.upperBound...]))
        } else {
            self.init(namespace: nil, value: string)
        }
    }
}

enum Resolver {
    struct ResolutionError: Error, CustomStringConvertible {
        var text: String
        
        var description: String {
            return self.text
        }
    }
    
    indirect enum TypeReference {
        case int32
        case int64
        case int256
        case double
        case bytes
        case string
        case bool
        case boolTrue
        case bareVector(TypeReference)
        case boxedVector(TypeReference)
        case bareConstructor(typeName: QualifiedName, name: QualifiedName)
        case boxedType(QualifiedName)
    }

    struct Argument {
        struct Condition {
            var fieldName: String
            var bitIndex: Int
        }
        
        var name: String
        var type: TypeReference
        var condition: Condition?
    }

    final class SumType {
        struct Constructor {
            var name: QualifiedName
            var id: UInt32
            var arguments: [Argument]
        }
        
        let name: QualifiedName
        var constructors: [QualifiedName: Constructor] = [:]
        
        init(name: QualifiedName) {
            self.name = name
        }
    }

    struct Function {
        var name: QualifiedName
        var id: UInt32
        var arguments: [Argument]
        var result: TypeReference
    }
    
    static func resolveBuiltinType(name: QualifiedName) -> TypeReference? {
        if name.namespace == nil {
            if name.value == "int" {
                return .int32
            } else if name.value == "long" {
                return .int64
            } else if name.value == "int256" {
                return .int256
            } else if name.value == "double" {
                return .double
            } else if name.value == "string" {
                return .string
            } else if name.value == "bytes" {
                return .bytes
            } else if name.value == "true" {
                return .boolTrue
            }
        }
        return nil
    }
    
    static func resolveTypes(constructors: [DescriptionParser.ConstructorDescription]) throws -> [SumType] {
        var constructedTypes: [QualifiedName: [DescriptionParser.ConstructorDescription]] = [:]
        var constructorNameToType: [QualifiedName: QualifiedName] = [:]
        
        for constructorDescription in constructors {
            switch constructorDescription.type {
            case let .type(name):
                if !name.value[name.value.startIndex].isUppercase {
                    throw ResolutionError(text: "Type constructor \(constructorDescription.name) -> \(name): the resulting type name should begin with a capital letter")
                }
                
                constructedTypes[name, default: []].append(constructorDescription)
                
                if let _ = constructorNameToType[constructorDescription.name] {
                    throw ResolutionError(text: "Duplicate type constructor \(constructorDescription.name) found")
                }
                constructorNameToType[constructorDescription.name] = name
            case let .generic(name, argumentType):
                throw ResolutionError(text: "Type constructor \(constructorDescription.name) can not be used to construct a generic type \(name)<\(argumentType)>")
            }
        }
        
        func resolveTypeReference(description: DescriptionParser.TypeReferenceDescription) throws -> TypeReference {
            switch description {
            case let .type(name):
                if let resolvedBuiltinType = resolveBuiltinType(name: name) {
                    return resolvedBuiltinType
                }
                
                if name.value[name.value.startIndex].isUppercase {
                    if let _ = constructedTypes[name] {
                        return .boxedType(name)
                    } else {
                        throw ResolutionError(text: "Unresolved type \(name)")
                    }
                } else {
                    if let typeName = constructorNameToType[name] {
                        return .bareConstructor(typeName: typeName, name: name)
                    } else {
                        throw ResolutionError(text: "Unresolved type constructor \(name)")
                    }
                }
            case let .generic(name, argumentType):
                if name == "vector" {
                    return .bareVector(try resolveTypeReference(description: .type(name: argumentType)))
                } else if name == "Vector" {
                    return .boxedVector(try resolveTypeReference(description: .type(name: argumentType)))
                } else {
                    throw ResolutionError(text: "Unresolved generic type \(name)")
                }
            }
        }
        
        func resolveArgument(existingArguments: [Argument], description: DescriptionParser.ArgumentDescription) throws -> Argument {
            return Argument(
                name: description.name,
                type: try resolveTypeReference(description: description.type),
                condition: try description.condition.flatMap { condition -> Argument.Condition in
                    if !existingArguments.contains(where: { $0.name == condition.fieldName }) {
                        throw ResolutionError(text: "Unresolved conditional field reference to \(condition.fieldName)")
                    }
                    return Argument.Condition(fieldName: condition.fieldName, bitIndex: condition.bitIndex)
                }
            )
        }
        
        var types: [QualifiedName: SumType] = [:]
        
        for (typeName, constructorDescriptions) in constructedTypes {
            let type = SumType(name: typeName)
            
            for constructorDescription in constructorDescriptions {
                var arguments: [Argument] = []
                
                for argumentDescription in constructorDescription.arguments {
                    arguments.append(try resolveArgument(existingArguments: arguments, description: argumentDescription))
                }
                
                guard let id = constructorDescription.explicitId else {
                    throw ResolutionError(text: "Constructor \(constructorDescription.name) does not have an id")
                }
                
                type.constructors[constructorDescription.name] = SumType.Constructor(
                    name: constructorDescription.name,
                    id: id,
                    arguments: arguments
                )
            }
            
            types[type.name] = type
        }
        
        return types.values.sorted(by: { $0.name < $1.name })
    }
    
    static func resolveFunctions(types: [SumType], functionDescriptions: [DescriptionParser.ConstructorDescription]) throws -> [Function] {
        var functions: [QualifiedName: Function] = [:]
        
        var typeMap: [QualifiedName: SumType] = [:]
        var constructorMap: [QualifiedName: SumType] = [:]
        
        for type in types {
            typeMap[type.name] = type
            
            for (_, constructor) in type.constructors {
                constructorMap[constructor.name] = type
            }
        }
        
        func resolveTypeReference(description: DescriptionParser.TypeReferenceDescription) throws -> TypeReference {
            switch description {
            case let .type(name):
                if let resolvedBuiltinType = resolveBuiltinType(name: name) {
                    return resolvedBuiltinType
                }
                
                if name.value[name.value.startIndex].isUppercase {
                    if let _ = typeMap[name] {
                        return .boxedType(name)
                    } else {
                        throw ResolutionError(text: "Unresolved type \(name)")
                    }
                } else {
                    if let type = constructorMap[name] {
                        return .bareConstructor(typeName: type.name, name: name)
                    } else {
                        throw ResolutionError(text: "Unresolved type constructor \(name)")
                    }
                }
            case let .generic(name, argumentType):
                if name == "vector" {
                    return .bareVector(try resolveTypeReference(description: .type(name: argumentType)))
                } else if name == "Vector" {
                    return .boxedVector(try resolveTypeReference(description: .type(name: argumentType)))
                } else {
                    throw ResolutionError(text: "Unresolved generic type \(name)")
                }
            }
        }
        
        func resolveArgument(existingArguments: [Argument], description: DescriptionParser.ArgumentDescription) throws -> Argument {
            return Argument(
                name: description.name,
                type: try resolveTypeReference(description: description.type),
                condition: try description.condition.flatMap { condition -> Argument.Condition in
                    if !existingArguments.contains(where: { $0.name == condition.fieldName }) {
                        throw ResolutionError(text: "Unresolved conditional field reference to \(condition.fieldName)")
                    }
                    return Argument.Condition(fieldName: condition.fieldName, bitIndex: condition.bitIndex)
                }
            )
        }
        
        for functionDescription in functionDescriptions {
            var arguments: [Argument] = []
            
            for argumentDescription in functionDescription.arguments {
                arguments.append(try resolveArgument(existingArguments: arguments, description: argumentDescription))
            }
            
            let result = try resolveTypeReference(description: functionDescription.type)
            
            guard let id = functionDescription.explicitId else {
                throw ResolutionError(text: "Function \(functionDescription.name) does not have an id")
            }
            
            functions[functionDescription.name] = Function(
                name: functionDescription.name,
                id: id,
                arguments: arguments,
                result: result
            )
        }
        
        return functions.values.sorted(by: { $0.name < $1.name })
    }
}
