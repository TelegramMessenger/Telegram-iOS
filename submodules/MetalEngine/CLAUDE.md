# MetalEngine — agent notes

## `MetalPipelineCacheTests`

`//submodules/MetalEngine:MetalPipelineCacheTests` is a host `swift_test`
(`./build-input/bazel-9.2.0-darwin-arm64 test //submodules/MetalEngine:MetalPipelineCacheTests`; one test via
`--test_filter=MetalPipelineCacheTests/<name>`, comma lists are not supported). It compiles only
`MetalPipelineCache.swift` + `MetalBinaryArchiveSerialization.swift` and runs on the Mac's GPU, because the simulator
has no binary archives (serializing fails an assertion there).

It pins an **Apple bug** (iOS 26.3, macOS 27): a `MTLBinaryArchive.serialize(to:)` whose final file move fails does not
throw — Metal frees the error on the compiler's reply thread and the caller crashes retaining it.
`MetalBinaryArchiveSerialization` hooks that one `NSFileManager` call to keep the error alive; the target sets
`NSZombieEnabled` so a regression fails deterministically.
