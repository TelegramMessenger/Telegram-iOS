import UIKit
import Photos

final class PhotoLibraryBenchmark {
    private struct Case {
        var name: String
        var deliveryMode: PHImageRequestOptionsDeliveryMode
        var isSynchronous: Bool
        var cached: Bool
    }

    private let fetchResult: PHFetchResult<PHAsset>
    private let manager = PHCachingImageManager()
    private var cursor = 0
    private var lines: [String] = []

    init(fetchResult: PHFetchResult<PHAsset>) {
        self.fetchResult = fetchResult
    }

    func run(completion: @escaping () -> Void) {
        let sizes: [(String, CGSize)] = [("L3", CGSize(width: 402, height: 402)), ("L5", CGSize(width: 240, height: 240)), ("L15", CGSize(width: 78, height: 78)), ("L31", CGSize(width: 36, height: 36))]
        var cases: [Case] = []
        for cached in [false, true] {
            for (mode, sync) in [(PHImageRequestOptionsDeliveryMode.opportunistic, false), (.fastFormat, false), (.highQualityFormat, false), (.fastFormat, true)] {
                let modeName = mode == .opportunistic ? "opportunistic" : (mode == .fastFormat ? "fastFormat" : "highQuality")
                cases.append(Case(name: "\(modeName) \(sync ? "sync" : "async") \(cached ? "cached" : "miss")", deliveryMode: mode, isSynchronous: sync, cached: cached))
            }
        }
        var work: [(Case, String, CGSize)] = []
        for (label, size) in sizes {
            for item in cases {
                work.append((item, label, size))
            }
        }
        self.next(work: work[...], completion: completion)
    }

    private func next(work: ArraySlice<(Case, String, CGSize)>, completion: @escaping () -> Void) {
        guard let (item, label, size) = work.first else {
            for line in self.lines {
                print(line)
            }
            fflush(stdout)
            completion()
            return
        }
        let count = 24
        let assets = (0 ..< count).compactMap { _ -> PHAsset? in
            guard self.fetchResult.count > 0 else {
                return nil
            }
            let index = self.cursor % self.fetchResult.count
            self.cursor += 1
            return self.fetchResult.object(at: self.fetchResult.count - 1 - index)
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = item.deliveryMode
        options.resizeMode = .fast
        options.isSynchronous = item.isSynchronous
        options.isNetworkAccessAllowed = true
        let proceed = {
            self.measure(item: item, label: label, size: size, assets: assets, options: options) {
                self.next(work: work.dropFirst(), completion: completion)
            }
        }
        if item.cached {
            let cacheOptions = PHImageRequestOptions()
            cacheOptions.deliveryMode = item.deliveryMode
            cacheOptions.resizeMode = .fast
            self.manager.startCachingImages(for: assets, targetSize: size, contentMode: .aspectFill, options: cacheOptions)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: proceed)
        } else {
            proceed()
        }
    }

    private func measure(item: Case, label: String, size: CGSize, assets: [PHAsset], options: PHImageRequestOptions, completion: @escaping () -> Void) {
        var callCost: [Double] = []
        var firstLatency: [Double] = []
        var finalLatency: [Double] = []
        var firstDegraded = 0
        var firstSize: [CGFloat] = []
        var pending = assets.count
        let finish = {
            pending -= 1
            if pending == 0 {
                let line = String(format: "BENCH %@ %@: call med %.2f max %.2f ms | first med %.2f max %.2f ms (degraded %d/%d, px %.0f) | final med %.2f max %.2f ms", label, item.name, PhotoLibraryBenchmark.median(callCost), callCost.max() ?? 0.0, PhotoLibraryBenchmark.median(firstLatency), firstLatency.max() ?? 0.0, firstDegraded, assets.count, PhotoLibraryBenchmark.median(firstSize.map(Double.init)), PhotoLibraryBenchmark.median(finalLatency), finalLatency.max() ?? 0.0)
                self.lines.append(line)
                print(line)
                fflush(stdout)
                DispatchQueue.main.async(execute: completion)
            }
        }
        if assets.isEmpty {
            completion()
            return
        }
        for asset in assets {
            let start = CACurrentMediaTime()
            var gotFirst = false
            var done = false
            self.manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options, resultHandler: { image, info in
                let now = CACurrentMediaTime()
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !gotFirst {
                    gotFirst = true
                    firstLatency.append((now - start) * 1000.0)
                    if isDegraded {
                        firstDegraded += 1
                    }
                    if let image {
                        firstSize.append(max(image.size.width * image.scale, image.size.height * image.scale))
                    } else if firstLatency.count == 1 {
                        print("BENCH nil info \(info ?? [:])")
                    }
                }
                if !isDegraded && !done {
                    done = true
                    finalLatency.append((now - start) * 1000.0)
                    if Thread.isMainThread {
                        finish()
                    } else {
                        DispatchQueue.main.async(execute: finish)
                    }
                }
            })
            callCost.append((CACurrentMediaTime() - start) * 1000.0)
        }
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else {
            return 0.0
        }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    func runThroughput(completion: @escaping () -> Void) {
        var variants: [(String, CGSize, PHImageRequestOptionsDeliveryMode, PHImageRequestOptionsResizeMode, Bool)] = [
            ("L31 opportunistic fast", CGSize(width: 36, height: 36), .opportunistic, .fast, false),
            ("L31 highQuality exact", CGSize(width: 36, height: 36), .highQualityFormat, .exact, false),
            ("L15 opportunistic fast", CGSize(width: 78, height: 78), .opportunistic, .fast, false),
            ("L5 opportunistic fast", CGSize(width: 240, height: 240), .opportunistic, .fast, false),
            ("L3 opportunistic fast", CGSize(width: 402, height: 402), .opportunistic, .fast, false),
            ("L5 opportunistic fast precached", CGSize(width: 240, height: 240), .opportunistic, .fast, true),
            ("L31 opportunistic fast precached", CGSize(width: 36, height: 36), .opportunistic, .fast, true)
        ]
        if ProcessInfo.processInfo.arguments.contains("-fastVariants") {
            variants = [
                ("fast none 36", CGSize(width: 36, height: 36), .fastFormat, .none, false),
                ("fast exact 36", CGSize(width: 36, height: 36), .fastFormat, .exact, false),
                ("fast fast 120", CGSize(width: 120, height: 120), .fastFormat, .fast, false),
                ("fast none 480", CGSize(width: 480, height: 480), .fastFormat, .none, false),
                ("fast none max", PHImageManagerMaximumSize, .fastFormat, .none, false)
            ]
        }
        self.throughput(variants: variants[...], completion: completion)
    }

    private func throughput(variants: ArraySlice<(String, CGSize, PHImageRequestOptionsDeliveryMode, PHImageRequestOptionsResizeMode, Bool)>, completion: @escaping () -> Void) {
        guard let (name, size, mode, resize, precache) = variants.first else {
            completion()
            return
        }
        let count = Int(ProcessInfo.processInfo.environment["TP_COUNT"] ?? "") ?? 400
        var assets: [PHAsset] = []
        for _ in 0 ..< count {
            let index = self.cursor % self.fetchResult.count
            self.cursor += 1
            assets.append(self.fetchResult.object(at: self.fetchResult.count - 1 - index))
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = mode
        options.resizeMode = resize
        options.isNetworkAccessAllowed = true
        let run = {
            let start = CACurrentMediaTime()
            var remaining = assets.count
            var nilCount = 0
            var syncCount = 0
            for asset in assets {
                var calling = true
                var done = false
                self.manager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options, resultHandler: { image, info in
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if isDegraded || done {
                        return
                    }
                    done = true
                    if calling {
                        syncCount += 1
                    }
                    if image == nil {
                        nilCount += 1
                    }
                    remaining -= 1
                    if remaining == 0 {
                        let elapsed = CACurrentMediaTime() - start
                        print(String(format: "THROUGHPUT %@: %d images in %.0f ms = %.0f/s (nil %d, sync %d)", name, assets.count, elapsed * 1000.0, Double(assets.count) / elapsed, nilCount, syncCount))
                        fflush(stdout)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.throughput(variants: variants.dropFirst(), completion: completion)
                        }
                    }
                })
                calling = false
            }
        }
        if precache {
            let start = CACurrentMediaTime()
            self.manager.startCachingImages(for: assets, targetSize: size, contentMode: .aspectFill, options: options)
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                print(String(format: "THROUGHPUT %@ precache waited %.0f ms", name, (CACurrentMediaTime() - start) * 1000.0))
                run()
            }
        } else {
            run()
        }
    }

    func runBatchCaching(completion: @escaping () -> Void) {
        let caching = PHCachingImageManager()
        caching.allowsCachingHighQualityImages = false
        let sizes: [CGFloat] = [240.0, 128.0, 96.0]
        var remaining = sizes[...]
        func next() {
            guard let side = remaining.first else {
                completion()
                return
            }
            remaining = remaining.dropFirst()
            let size = CGSize(width: side, height: side)
            var assets: [PHAsset] = []
            for _ in 0 ..< 2000 {
                let index = self.cursor % self.fetchResult.count
                self.cursor += 1
                assets.append(self.fetchResult.object(at: self.fetchResult.count - 1 - (index % 4000)))
            }
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            let start = CACurrentMediaTime()
            caching.startCachingImages(for: assets, targetSize: size, contentMode: .aspectFill, options: options)
            print(String(format: "BATCH %.0f startCaching call %.1f ms", side, (CACurrentMediaTime() - start) * 1000.0))
            var probes = [0.5, 1.0, 2.0, 4.0, 8.0][...]
            func probe() {
                guard let delay = probes.first else {
                    caching.stopCachingImagesForAllAssets()
                    next()
                    return
                }
                probes = probes.dropFirst()
                DispatchQueue.main.asyncAfter(deadline: .now() + delay - (CACurrentMediaTime() - start)) {
                    var hits = 0
                    let sample = stride(from: 0, to: assets.count, by: 40).map { assets[$0] }
                    for asset in sample {
                        var sync = true
                        caching.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options, resultHandler: { image, info in
                            if sync && image != nil && !((info?[PHImageResultIsDegradedKey] as? Bool) ?? false) {
                                hits += 1
                            }
                        })
                        sync = false
                    }
                    print(String(format: "BATCH %.0f after %.1fs: sync hits %d/%d", side, delay, hits, sample.count))
                    fflush(stdout)
                    probe()
                }
            }
            probe()
        }
        next()
    }
}
