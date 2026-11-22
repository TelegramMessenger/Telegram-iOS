import Foundation
import Metal

/// GPU code for pipeline states, kept on disk across launches.
///
/// Libraries ship compiled, but turning a library function into code for this GPU still happens the first time a
/// pipeline is made in each process, and the system's own shader cache does not reliably spare it, so every first use
/// stalls. Pipelines made here are compiled into a binary archive once per app version, OS build and GPU, saved in
/// Caches, and made from the archive afterwards.
///
/// The archive can never serve a stale pipeline. Metal finds a pipeline in it by the pipeline's whole descriptor and
/// the code of its functions, so a changed shader, function constant or pipeline state is a miss: it is compiled and
/// added. Whatever compiles that code into GPU code is covered by the archive's file name, which changes with the
/// app version, the OS build and the GPU, and starts a fresh archive.
///
/// Apple advises against updating archives at runtime in shipping apps because that needs resilience to corruption
/// and bounded storage: a file that fails to load is never trusted (the next save replaces it), saves replace the file
/// atomically, and the archive is version-scoped and capped in size.
///
/// Saving goes through Metal's own code, which has crashed the app (see `MetalBinaryArchiveSerialization`, which turns
/// the known case into an error). A save is marked on disk while it runs, so a process that dies inside one leaves
/// the mark behind; from then on the archive is still used but never saved again, until the app or OS version
/// changes and a new archive starts.
///
/// The archive can be switched off remotely (`setArchiveDisabled`, driven by the
/// `ios_killswitch_disable_metal_pipeline_cache` app configuration key); pipelines are then compiled as they were before
/// this cache existed.
///
/// **Currently switched off in the app** (`isSwitchedOff`): a save still crashed inside Metal on iOS 26.3 with the
/// guard in place (2026-10-02), so the guard does not cover every path there.
///
/// Thread-safe, and never makes a caller wait for another thread's compile or save.
public final class MetalPipelineCache {
    private static let maxArchiveSize = 16 * 1024 * 1024
    /// Remembers the killswitch across launches: the archive is opened at launch, before any app configuration is
    /// loaded.
    private static let isArchiveDisabledKey = "MetalPipelineCache.isArchiveDisabled"
    /// Keeps the app's cache from using an archive at all, as the killswitch does, until saving is understood.
    private static let isSwitchedOff = true

    private let device: MTLDevice
    /// Guards every use of the archive, whose thread safety is not documented. A caller that finds it held (another
    /// thread is compiling into the archive or saving it) compiles its pipeline directly rather than waiting.
    private let lock = NSLock()
    private let saveQueue = DispatchQueue(label: "org.telegram.MetalPipelineCache", qos: .utility)

    /// Where archives are kept.
    private let directoryUrl: URL?
    /// Where the archive is saved; nil when it must not be written this launch.
    private let url: URL?
    /// An `MTLBinaryArchive`, which needs macOS 11 or iOS 14 (the package also builds for older macOS).
    private let archiveStorage: AnyObject?
    private var isSaveScheduled = false
    /// Guarded by `lock`.
    private var isArchiveDisabled: Bool

    /// True when this launch found no usable archive: the first start after an install or update, or after an OS
    /// update. A good moment to make the pipelines a user is likely to need, in the background.
    public let isFresh: Bool

    convenience init(device: MTLDevice) {
        // Namespaced by app: on macOS, Caches can be shared between builds of the app.
        let directoryUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first.flatMap { cachesUrl in
            return cachesUrl
                .appendingPathComponent("MetalPipelineCache", isDirectory: true)
                .appendingPathComponent(Bundle.main.bundleIdentifier ?? "default", isDirectory: true)
        }
        self.init(device: device, directoryUrl: directoryUrl, isSwitchedOff: MetalPipelineCache.isSwitchedOff)
    }

    /// `isSwitchedOff` behaves like the killswitch for this instance: no archive, and the directory is deleted.
    init(device: MTLDevice, directoryUrl: URL?, isSwitchedOff: Bool = false) {
        self.device = device

        let isArchiveDisabled = isSwitchedOff || UserDefaults.standard.bool(forKey: MetalPipelineCache.isArchiveDisabledKey)

        var url: URL?
        var archive: AnyObject?
        // Without an archive there is nothing to fill on a first start.
        var isFresh = false
        if isArchiveDisabled {
            if let directoryUrl {
                let _ = try? FileManager.default.removeItem(at: directoryUrl)
            }
        } else {
            // The simulator's Metal accepts pipelines into an archive but fails an assertion when serializing it
            // ("Target device architecture is nil"): it has no GPU architecture to target. Compile as usual there.
            #if !targetEnvironment(simulator)
            if #available(macOS 11.0, iOS 14.0, *) {
                (url, archive, isFresh) = MetalPipelineCache.openArchive(device: device, directoryUrl: directoryUrl)
            }
            #endif
        }

        self.directoryUrl = directoryUrl
        self.url = url
        self.archiveStorage = archive
        self.isFresh = isFresh
        self.isArchiveDisabled = isArchiveDisabled
    }

    /// Switches the archive off, now and on later launches, or back on from the next launch. Switching it off deletes
    /// it; from then on pipelines are compiled as they were before this cache existed.
    public func setArchiveDisabled(_ isDisabled: Bool) {
        if UserDefaults.standard.bool(forKey: MetalPipelineCache.isArchiveDisabledKey) != isDisabled {
            UserDefaults.standard.set(isDisabled, forKey: MetalPipelineCache.isArchiveDisabledKey)
        }
        if !isDisabled {
            return
        }
        // The lock may be held by a compile; take it on the save queue rather than on the caller's thread.
        self.saveQueue.async { [weak self] in
            guard let self else {
                return
            }
            self.lock.lock()
            let wasDisabled = self.isArchiveDisabled
            self.isArchiveDisabled = true
            self.lock.unlock()

            if !wasDisabled, let directoryUrl = self.directoryUrl {
                let _ = try? FileManager.default.removeItem(at: directoryUrl)
            }
        }
    }

    @available(macOS 11.0, iOS 14.0, *)
    private static func openArchive(device: MTLDevice, directoryUrl: URL?) -> (url: URL?, archive: MTLBinaryArchive?, isFresh: Bool) {
        let emptyArchive = try? device.makeBinaryArchive(descriptor: MTLBinaryArchiveDescriptor())

        let fileManager = FileManager.default
        guard let directoryUrl else {
            return (nil, emptyArchive, true)
        }
        let _ = try? fileManager.createDirectory(at: directoryUrl, withIntermediateDirectories: true)

        let fileName = MetalPipelineCache.archiveFileName(device: device)
        let fileUrl = directoryUrl.appendingPathComponent(fileName)

        let saveMarkerUrl = MetalPipelineCache.saveMarkerUrl(archiveUrl: fileUrl)

        // Archives of previous versions are never valid again, and neither are their saves' marks.
        for item in (try? fileManager.contentsOfDirectory(atPath: directoryUrl.path)) ?? [] where item != fileName && item != saveMarkerUrl.lastPathComponent {
            let _ = try? fileManager.removeItem(at: directoryUrl.appendingPathComponent(item))
        }

        // A mark means a save of this archive never finished: the process died in it. The file it was replacing is
        // untouched (saves are renamed into place), so keep using it, but do not risk saving it again.
        let saveUrl: URL? = fileManager.fileExists(atPath: saveMarkerUrl.path) ? nil : fileUrl

        // Changed pipelines are added next to their old versions, which are never used again. Within one app version
        // that only happens in development builds; start over if it ever adds up.
        if let size = (try? fileManager.attributesOfItem(atPath: fileUrl.path))?[.size] as? Int, size > MetalPipelineCache.maxArchiveSize {
            let _ = try? fileManager.removeItem(at: fileUrl)
        }

        guard fileManager.fileExists(atPath: fileUrl.path) else {
            return (saveUrl, emptyArchive, true)
        }
        let descriptor = MTLBinaryArchiveDescriptor()
        descriptor.url = fileUrl
        if let archive = try? device.makeBinaryArchive(descriptor: descriptor) {
            return (saveUrl, archive, false)
        }
        if (try? FileHandle(forReadingFrom: fileUrl)) == nil {
            // Not readable yet: Caches stays protected until the first unlock after a reboot, and a background launch
            // can come before it. The archive is most likely fine, so leave it alone this launch.
            return (nil, emptyArchive, true)
        }
        // Readable but not an archive; the next save replaces it.
        return (saveUrl, emptyArchive, true)
    }

    public func makeRenderPipelineState(descriptor: MTLRenderPipelineDescriptor) -> MTLRenderPipelineState? {
        // An archive only serves its own device; functions from another device are compiled on theirs.
        let functionDevice = descriptor.vertexFunction?.device ?? self.device
        let isArchivable = functionDevice === self.device && (descriptor.fragmentFunction.flatMap({ $0.device === self.device }) ?? true)

        if #available(macOS 11.0, iOS 14.0, *), isArchivable, let archive = self.archiveStorage as? MTLBinaryArchive, self.lock.try() {
            defer {
                self.lock.unlock()
            }
            if self.isArchiveDisabled {
                return try? functionDevice.makeRenderPipelineState(descriptor: descriptor)
            }
            guard let descriptor = descriptor.copy() as? MTLRenderPipelineDescriptor else {
                return nil
            }
            descriptor.binaryArchives = [archive]
            if let pipelineState = try? self.device.makeRenderPipelineState(descriptor: descriptor, options: [.failOnBinaryArchiveMiss], reflection: nil) {
                return pipelineState
            }
            // Compile it into the archive, then make it from there, so it is compiled once.
            if (try? archive.addRenderPipelineFunctions(descriptor: descriptor)) != nil {
                self.scheduleSave()
            }
            return try? self.device.makeRenderPipelineState(descriptor: descriptor)
        }
        return try? functionDevice.makeRenderPipelineState(descriptor: descriptor)
    }

    public func makeComputePipelineState(descriptor: MTLComputePipelineDescriptor) -> MTLComputePipelineState? {
        let functionDevice = descriptor.computeFunction?.device ?? self.device

        if #available(macOS 11.0, iOS 14.0, *), functionDevice === self.device, let archive = self.archiveStorage as? MTLBinaryArchive, self.lock.try() {
            defer {
                self.lock.unlock()
            }
            if self.isArchiveDisabled {
                return try? functionDevice.makeComputePipelineState(descriptor: descriptor, options: [], reflection: nil)
            }
            guard let descriptor = descriptor.copy() as? MTLComputePipelineDescriptor else {
                return nil
            }
            descriptor.binaryArchives = [archive]
            if let pipelineState = try? self.device.makeComputePipelineState(descriptor: descriptor, options: [.failOnBinaryArchiveMiss], reflection: nil) {
                return pipelineState
            }
            if (try? archive.addComputePipelineFunctions(descriptor: descriptor)) != nil {
                self.scheduleSave()
            }
            return try? self.device.makeComputePipelineState(descriptor: descriptor, options: [], reflection: nil)
        }
        return try? functionDevice.makeComputePipelineState(descriptor: descriptor, options: [], reflection: nil)
    }

    public func makeComputePipelineState(function: MTLFunction) -> MTLComputePipelineState? {
        let descriptor = MTLComputePipelineDescriptor()
        descriptor.computeFunction = function
        return self.makeComputePipelineState(descriptor: descriptor)
    }

    /// Called with `lock` held.
    private func scheduleSave() {
        if self.isSaveScheduled || self.url == nil {
            return
        }
        self.isSaveScheduled = true
        // Pipelines tend to be made in bursts; save once after one.
        self.saveQueue.asyncAfter(deadline: .now() + 1.0, execute: { [weak self] in
            self?.save()
        })
    }

    private func save() {
        guard #available(macOS 11.0, iOS 14.0, *) else {
            return
        }
        // On the save queue, so waiting here holds up no one; callers skip the archive while it is held.
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        self.isSaveScheduled = false

        guard !self.isArchiveDisabled, let archive = self.archiveStorage as? MTLBinaryArchive, let url = self.url else {
            return
        }
        // Created before serializing and removed after it returns, so it is only left behind by a process that died
        // in between. Without it, a save that crashes would crash again on every launch.
        let saveMarkerUrl = MetalPipelineCache.saveMarkerUrl(archiveUrl: url)
        guard FileManager.default.createFile(atPath: saveMarkerUrl.path, contents: nil) else {
            return
        }
        defer {
            let _ = try? FileManager.default.removeItem(at: saveMarkerUrl)
        }

        let temporaryUrl = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try MetalBinaryArchiveSerialization.serialize(archive, to: temporaryUrl)
            // rename(2) replaces the previous archive atomically: there is always either the old file or the new one.
            if rename(temporaryUrl.path, url.path) != 0 {
                let _ = try? FileManager.default.removeItem(at: temporaryUrl)
            }
        } catch {
            let _ = try? FileManager.default.removeItem(at: temporaryUrl)
        }
    }

    /// Whether this launch saves the archive (for tests).
    var isSaveEnabled: Bool {
        return self.url != nil
    }

    static func archiveFileName(device: MTLDevice) -> String {
        return "pipelines-\(MetalPipelineCache.archiveKey(device: device)).metallib"
    }

    /// Exists while the archive at `archiveUrl` is being saved.
    static func saveMarkerUrl(archiveUrl: URL) -> URL {
        return archiveUrl.deletingPathExtension().appendingPathExtension("saving")
    }

    /// Identifies the app version, OS build and GPU the archived code was compiled for.
    private static func archiveKey(device: MTLDevice) -> String {
        let info = Bundle.main.infoDictionary
        let appVersion = info?["CFBundleShortVersionString"] as? String ?? ""
        let buildNumber = info?["CFBundleVersion"] as? String ?? ""
        let components = [appVersion, buildNumber, ProcessInfo.processInfo.operatingSystemVersionString, device.name]

        // FNV-1a: stable across launches, unlike `hashValue`.
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in components.joined(separator: "|").utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
