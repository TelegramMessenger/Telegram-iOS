import Foundation
import UIKit
import LottieMetal
import LottieCpp
import RLottieBinding
import MetalEngine
import Display
import LottieSwift
import SoftwareLottieRenderer

@available(iOS 13.0, *)
private final class ReferenceCompareTest {
    private let view: UIView
    private let imageView = UIImageView()
    private let referenceImageView = UIImageView()
    private let deltaImageView = UIImageView()
    
    init(view: UIView, testNonReference: Bool) {
        lottieSwift_getPathNativeBoundingBox = { path in
            return getPathNativeBoundingBox(path)
        }
        
        self.view = view
        
        self.view.backgroundColor = .white
        
        let topInset: CGFloat = 50.0
        
        self.view.addSubview(self.imageView)
        self.imageView.layer.magnificationFilter = .nearest
        self.imageView.frame = CGRect(origin: CGPoint(x: 10.0, y: topInset), size: CGSize(width: 256.0, height: 256.0))
        self.imageView.backgroundColor = self.view.backgroundColor
        self.imageView.transform = CGAffineTransform.init(scaleX: 1.0, y: -1.0)
        
        self.view.addSubview(self.referenceImageView)
        self.referenceImageView.layer.magnificationFilter = .nearest
        self.referenceImageView.frame = CGRect(origin: CGPoint(x: 10.0, y: topInset + 256.0 + 1.0), size: CGSize(width: 256.0, height: 256.0))
        self.referenceImageView.backgroundColor = self.view.backgroundColor
        self.referenceImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: -1.0)
        
        self.view.addSubview(self.deltaImageView)
        self.deltaImageView.layer.magnificationFilter = .nearest
        self.deltaImageView.frame = CGRect(origin: CGPoint(x: 10.0, y: topInset + 256.0 + 1.0 + 256.0 + 1.0), size: CGSize(width: 256.0, height: 256.0))
        self.deltaImageView.backgroundColor = self.view.backgroundColor
        self.deltaImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: -1.0)
        
        let bundlePath = Bundle.main.path(forResource: "TestDataBundle", ofType: "bundle")!
        
        Task.detached {
            let sizeMapping: [String: Int] = [
                "5170488605398795246.json": 512,
                "35707580709863506.json": 512,
                "35707580709863507.json": 512,
                "1258816259754246.json": 512,
                "1258816259754248.json": 512,
                "35707580709863489.json": 512,
                "1258816259754150.json": 512,
                "35707580709863494.json": 512,
                "5021586753580958116.json": 512,
                "35707580709863509.json": 512,
                "5282957555314728059.json": 512,
                "fireworks.json": 512,
                "750766425144033565.json": 512,
                "1258816259754276.json": 1024,
                "1471004892762996753.json": 1024,
                "4985886809322947159.json": 1024,
                "35707580709863490.json": 1024,
                "4986037051573928320.json": 512,
                "1258816259754029.json": 1024,
                "4987794066860147124.json": 1024,
                "1258816259754212.json": 1024,
                "750766425144033464.json": 1024,
                "750766425144033567.json": 1024,
                "1391391008142393350.json": 1024
            ]
            
            let allowedDifferences: [String: Double] = [
                "1258816259754165.json": 0.04
            ]
            let defaultSize = 128
            
            let baseCachePath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).path + "/frame-cache"
            let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: baseCachePath), withIntermediateDirectories: true, attributes: nil)
            print("Frame cache: \(baseCachePath)")
            
            for (filePath, fileName) in buildAnimationFolderItems(basePath: bundlePath, path: "") {
                let _ = await cacheReferenceAnimation(baseCachePath: baseCachePath, width: sizeMapping[fileName] ?? defaultSize, path: filePath, name: fileName)
            }
            
            var continueFromName: String?
            //continueFromName = "562563904580878375.json"
            
            let _ = await processAnimationFolderAsync(basePath: bundlePath, path: "", stopOnFailure: !testNonReference, process: { path, name, alwaysDraw in
                if let continueFromNameValue = continueFromName {
                    if continueFromNameValue == name {
                        continueFromName = nil
                    } else {
                        return true
                    }
                }
                
                let size = sizeMapping[name] ?? defaultSize
                
                let result = await processDrawAnimation(baseCachePath: baseCachePath, path: path, name: name, size: CGSize(width: size, height: size), allowedDifference: allowedDifferences[name] ?? 0.01, alwaysDraw: alwaysDraw, useNonReferenceRendering: testNonReference, updateImage: { image, referenceImage, differenceImage in
                    DispatchQueue.main.async {
                        self.imageView.image = image
                        self.referenceImageView.image = referenceImage
                        self.deltaImageView.image = differenceImage
                    }
                })
                return result
            })
        }
    }
}

@available(iOS 13.0, *)
private final class ManualReferenceCompareTest {
    private final class Item {
        let renderer: SoftwareLottieRenderer
        let referenceRenderer: ReferenceLottieAnimationItem
        
        init(renderer: SoftwareLottieRenderer, referenceRenderer: ReferenceLottieAnimationItem) {
            self.renderer = renderer
            self.referenceRenderer = referenceRenderer
        }
    }
    
    private let view: UIView
    private let imageView = UIImageView()
    private let referenceImageView = UIImageView()
    private let labelView = UILabel()
    
    private let renderSize: CGSize
    private let testNonReference: Bool
    
    private let fileList: [(filePath: String, fileName: String)]
    private var currentFileIndex: Int = 0
    private var currentItem: Item?
    
    private var frameDisplayLink: SharedDisplayLinkDriver.Link?
    
    init(view: UIView) {
        self.testNonReference = true
        
        self.currentFileIndex = 0
        
        lottieSwift_getPathNativeBoundingBox = { path in
            return getPathNativeBoundingBox(path)
        }
        
        let bundlePath = Bundle.main.path(forResource: "TestDataBundle", ofType: "bundle")!
        self.fileList = buildAnimationFolderItems(basePath: bundlePath, path: "")
        
        if let index = self.fileList.firstIndex(where: { $0.fileName == "shit.json" }) {
            self.currentFileIndex = index
        }
        
        self.renderSize = CGSize(width: 256.0, height: 256.0)
        
        self.view = view
        self.view.backgroundColor = .white
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        
        let topInset: CGFloat = 50.0
        
        self.view.addSubview(self.imageView)
        self.imageView.layer.magnificationFilter = .nearest
        self.imageView.frame = CGRect(origin: CGPoint(x: 10.0, y: topInset), size: CGSize(width: 256.0, height: 256.0))
        self.imageView.backgroundColor = self.view.backgroundColor
        self.imageView.transform = CGAffineTransform.init(scaleX: 1.0, y: -1.0)
        
        self.view.addSubview(self.referenceImageView)
        self.referenceImageView.layer.magnificationFilter = .nearest
        self.referenceImageView.frame = CGRect(origin: CGPoint(x: 10.0, y: topInset + 256.0 + 1.0), size: CGSize(width: 256.0, height: 256.0))
        self.referenceImageView.backgroundColor = self.view.backgroundColor
        self.referenceImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: -1.0)
        
        self.view.addSubview(self.labelView)
        
        self.updateCurrentAnimation()
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if recognizer.location(in: self.view).x <= self.view.bounds.width * 0.5 {
                if self.currentFileIndex != 0 {
                    self.currentFileIndex = self.currentFileIndex - 1
                }
            } else {
                self.currentFileIndex = (self.currentFileIndex + 1) % self.fileList.count
            }
            self.updateCurrentAnimation()
        }
    }
    
    private func updateCurrentAnimation() {
        self.imageView.image = nil
        self.referenceImageView.image = nil
        self.currentItem = nil
        
        self.labelView.text = "\(self.currentFileIndex + 1) / \(self.fileList.count)"
        self.labelView.sizeToFit()
        self.labelView.center = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.height - 10.0 - self.labelView.bounds.height)
        
        self.frameDisplayLink?.invalidate()
        self.frameDisplayLink = nil
        
        let (filePath, _) = self.fileList[self.currentFileIndex]
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            print("Could not load \(filePath)")
            return
        }
        guard let renderer = SoftwareLottieRenderer(data: data) else {
            print("Could not load animation at \(filePath)")
            return
        }
        guard let referenceRenderer = ReferenceLottieAnimationItem(path: filePath) else {
            print("Could not load reference animation at \(filePath)")
            return
        }
        
        let currentItem = Item(renderer: renderer, referenceRenderer: referenceRenderer)
        self.currentItem = currentItem
        
        var animationTime = 0.0
        let secondsPerFrame = 1.0 / Double(renderer.framesPerSecond)
        
        let frameDisplayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
            guard let self, let currentItem = self.currentItem else {
                return
            }
            
            var frameIndex = animationTime / secondsPerFrame
            frameIndex = frameIndex.truncatingRemainder(dividingBy: Double(currentItem.renderer.frameCount))
            
            currentItem.renderer.setFrame(frameIndex)
            let image = currentItem.renderer.render(for: self.renderSize, useReferenceRendering: !self.testNonReference, canUseMoreMemory: false, skipImageGeneration: false)!
            self.imageView.image = image
            
            currentItem.referenceRenderer.setFrame(index: Int(frameIndex))
            let referenceImage = currentItem.referenceRenderer.makeImage(width: Int(self.renderSize.width), height: Int(self.renderSize.height))!
            self.referenceImageView.image = referenceImage
            
            animationTime += deltaTime
        })
        self.frameDisplayLink = frameDisplayLink
        frameDisplayLink.isPaused = false
    }
}

public final class ViewController: UIViewController {
    private var link: SharedDisplayLinkDriver.Link?
    private var test: AnyObject?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        SharedDisplayLinkDriver.shared.updateForegroundState(true)
        
        let bundlePath = Bundle.main.path(forResource: "TestDataBundle", ofType: "bundle")!
        let filePath = bundlePath + "/fire.json"
        
        let performanceFrameSize = 128
        
        self.view.layer.addSublayer(MetalEngine.shared.rootLayer)
        
        if !"".isEmpty {
            if #available(iOS 13.0, *) {
                self.test = ReferenceCompareTest(view: self.view, testNonReference: false)
            }
        } else if "".isEmpty {
            if #available(iOS 13.0, *) {
                self.test = ManualReferenceCompareTest(view: self.view)
            }
        } else if !"".isEmpty {
            /*let cachedAnimation = cacheLottieMetalAnimation(path: filePath)!
            let animation = parseCachedLottieMetalAnimation(data: cachedAnimation)!
            
            /*let animationData = try! Data(contentsOf: URL(fileURLWithPath: filePath))
            
            var startTime = CFAbsoluteTimeGetCurrent()
            let animation = LottieAnimation(data: animationData)!
            print("Load time: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
            
            startTime = CFAbsoluteTimeGetCurrent()
            let animationContainer = LottieAnimationContainer(animation: animation)
            animationContainer.update(0)
            print("Build time: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")*/
            
            let lottieLayer = LottieContentLayer(content: animation)
            lottieLayer.frame = CGRect(origin: CGPoint(x: 10.0, y: 50.0), size: CGSize(width: 256.0, height: 256.0))
            self.view.layer.addSublayer(lottieLayer)
            lottieLayer.setNeedsUpdate()
            
            self.link = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { _ in
                lottieLayer.frameIndex = (lottieLayer.frameIndex + 1) % animation.frameCount
                lottieLayer.setNeedsUpdate()
            })*/
        } else if "".isEmpty {
            Thread {
                let animationData = try! Data(contentsOf: URL(fileURLWithPath: filePath))
                
                var startTime = CFAbsoluteTimeGetCurrent()
                
                let animationRenderer = SoftwareLottieRenderer(data: animationData)!
                print("Load time: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                startTime = CFAbsoluteTimeGetCurrent()
                var numUpdates: Int = 0
                var frameIndex = 0
                while true {
                    animationRenderer.setFrame(CGFloat(frameIndex))
                    let _ = animationRenderer.render(for: CGSize(width: CGFloat(performanceFrameSize), height: CGFloat(performanceFrameSize)), useReferenceRendering: false, canUseMoreMemory: true, skipImageGeneration: true)
                    frameIndex = (frameIndex + 1) % animationRenderer.frameCount
                    numUpdates += 1
                    let timestamp = CFAbsoluteTimeGetCurrent()
                    let deltaTime = timestamp - startTime
                    if deltaTime > 2.0 {
                        let updatesPerSecond = Double(numUpdates) / deltaTime
                        startTime = timestamp
                        numUpdates = 0
                        print("Ours: updatesPerSecond: \(updatesPerSecond)")
                    }
                }
            }.start()
        } else {
            Thread {
                var startTime = CFAbsoluteTimeGetCurrent()
                let animationInstance = LottieInstance(data: try! Data(contentsOf: URL(fileURLWithPath: filePath)), fitzModifier: .none, colorReplacements: nil, cacheKey: "")!
                print("Load time: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                let frameBuffer = malloc(performanceFrameSize * 4 * performanceFrameSize)!
                defer {
                    free(frameBuffer)
                }
                
                startTime = CFAbsoluteTimeGetCurrent()
                var numUpdates: Int = 0
                var frameIndex = 0
                while true {
                    animationInstance.renderFrame(with: Int32(frameIndex), into: frameBuffer, width: Int32(performanceFrameSize), height: Int32(performanceFrameSize), bytesPerRow: Int32(performanceFrameSize * 4))
                    
                    frameIndex = (frameIndex + 1) % Int(animationInstance.frameCount)
                    numUpdates += 1
                    let timestamp = CFAbsoluteTimeGetCurrent()
                    let deltaTime = timestamp - startTime
                    if deltaTime > 2.0 {
                        let updatesPerSecond = Double(numUpdates) / deltaTime
                        startTime = timestamp
                        numUpdates = 0
                        print("Rlottie: updatesPerSecond: \(updatesPerSecond)")
                    }
                }
            }.start()
        }
    }
}
