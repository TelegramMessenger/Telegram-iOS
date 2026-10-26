import Foundation

/// Which types go into which generated Swift file. The file count is fixed so that a build system
/// can declare the outputs before the generator runs (the Bazel genrule in
/// submodules/TelegramApi/BUILD): `Api0` holds the registry and the schema hash, the last file the
/// function builders, and the files in between the types, in sorted order, contiguous and balanced
/// by constructor count. A file left without types (more files than types) is still written.
enum SwiftFileSplit {
    typealias FileContents = (types: [(typeName: QualifiedName, constructorNames: [String])], functions: [QualifiedName])

    static let defaultFileCount = 44

    struct SplitError: Error, CustomStringConvertible {
        var description: String
    }

    /// The contents of `Api1` ... `Api{fileCount - 1}`.
    static func typeOrder(types: [Resolver.SumType], functions: [Resolver.Function], fileCount: Int) throws -> [FileContents] {
        guard fileCount >= 3 else {
            throw SplitError(description: "--swift-file-count must be at least 3 (the registry, one type file, the functions), got \(fileCount)")
        }
        let typeFileCount = fileCount - 2
        let sortedTypes = types.sorted(by: { $0.name < $1.name })
        let totalConstructors = sortedTypes.reduce(0) { $0 + $1.constructors.count }

        var files: [FileContents] = Array(repeating: ([], []), count: typeFileCount)
        var constructorsBefore = 0
        for type in sortedTypes {
            let count = type.constructors.count
            // The file whose share of the constructors contains this type's midpoint.
            let file = totalConstructors == 0 ? 0 : min(typeFileCount - 1, (2 * constructorsBefore + count) * typeFileCount / (2 * totalConstructors))
            files[file].types.append((type.name, type.constructors.values.sorted(by: { $0.name < $1.name }).map(\.name.value)))
            constructorsBefore += count
        }
        files.append(([], functions.map(\.name).sorted()))
        return files
    }
}
