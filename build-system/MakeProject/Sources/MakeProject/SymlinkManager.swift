import Foundation
import PathKit

class SymlinkManager {
    let outputDir: Path
    let projectRoot: Path
    private var previousFiles: Set<Path> = []
    private var currentFiles: Set<Path> = []

    init(outputDir: Path, projectRoot: Path) {
        self.outputDir = outputDir
        self.projectRoot = projectRoot
    }

    func scanExistingFiles() {
        previousFiles = []
        scanDirectory(outputDir)
    }

    private func scanDirectory(_ path: Path) {
        guard path.exists else { return }
        do {
            for item in try path.children() {
                let name = item.lastComponent
                // Skip build artifacts and xcodeproj bundles
                if name == ".build" || name.hasSuffix(".xcodeproj") { continue }
                previousFiles.insert(item)
                if item.isDirectory && !item.isSymlink {
                    scanDirectory(item)
                }
            }
        } catch {
            print("Warning: Could not scan \(path): \(error)")
        }
    }

    func createDirectory(_ path: Path) throws {
        currentFiles.insert(path)
        var parent = path.parent()
        while parent != outputDir && parent.string.count > outputDir.string.count {
            currentFiles.insert(parent)
            parent = parent.parent()
        }
        if !path.exists {
            try path.mkpath()
        }
    }

    func createSymlink(from source: Path, to target: Path) throws {
        currentFiles.insert(target)
        var parent = target.parent()
        while parent != outputDir && parent.string.count > outputDir.string.count {
            currentFiles.insert(parent)
            parent = parent.parent()
        }

        // Calculate relative path from target back to source
        let targetDir = target.parent()
        let depth = targetDir.components.count - outputDir.components.count + 1
        let relativePrefix = Array(repeating: "..", count: depth).joined(separator: "/")
        let relativePath = Path(relativePrefix) + source

        if target.isSymlink {
            let existingTarget = try? target.symlinkDestination()
            if existingTarget == relativePath {
                return // Already correct
            }
            try target.delete()
        } else if target.exists {
            try target.delete()
        }

        try targetDir.mkpath()
        try FileManager.default.createSymbolicLink(
            atPath: target.string,
            withDestinationPath: relativePath.string
        )
    }

    func cleanupStaleFiles() {
        let staleFiles = previousFiles.subtracting(currentFiles)
        let sortedStale = staleFiles.sorted { $0.components.count > $1.components.count }

        for path in sortedStale {
            do {
                if path.isSymlink || path.isFile {
                    try path.delete()
                } else if path.isDirectory {
                    if (try? path.children().isEmpty) == true {
                        try path.delete()
                    }
                }
            } catch {
                print("Warning: Could not remove \(path): \(error)")
            }
        }
    }

    func markFile(_ path: Path) {
        currentFiles.insert(path)
    }
}

extension Path {
    var isSymlink: Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: self.string, isDirectory: &isDir)
        guard exists else { return false }
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: self.string)
            return attrs[.type] as? FileAttributeType == .typeSymbolicLink
        } catch {
            return false
        }
    }
}
