import Foundation
import WidgetIDLCore

// WidgetIDL --impl-namespace NS --table-namespace NS --header-name NAME.h [--include HEADER]... --output-header PATH --output-source PATH a.webidl...
var arguments = Array(CommandLine.arguments.dropFirst())
var includes: [String] = []
while let i = arguments.firstIndex(of: "--include"), i + 1 < arguments.count {
    includes.append(arguments[i + 1])
    arguments.removeSubrange(i...(i + 1))
}
func take(_ flag: String) -> String {
    guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else {
        FileHandle.standardError.write("WidgetIDL: missing \(flag)\n".data(using: .utf8)!)
        exit(2)
    }
    let value = arguments[i + 1]
    arguments.removeSubrange(i...(i + 1))
    return value
}
let implNamespace = take("--impl-namespace")
let tableNamespace = take("--table-namespace")
let headerName = take("--header-name")
let headerPath = take("--output-header")
let sourcePath = take("--output-source")
do {
    let files = try arguments.map { path in
        try parseIDL(try String(contentsOfFile: path, encoding: .utf8), file: path)
    }
    let output = try emitCpp(try resolve(files), options: EmitterOptions(implNamespace: implNamespace, tableNamespace: tableNamespace, headerName: headerName, sourceIncludes: includes))
    try output.header.write(toFile: headerPath, atomically: true, encoding: .utf8)
    try output.source.write(toFile: sourcePath, atomically: true, encoding: .utf8)
} catch {
    FileHandle.standardError.write("WidgetIDL: \(error)\n".data(using: .utf8)!)
    exit(1)
}
