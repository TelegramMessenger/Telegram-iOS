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
    
    init(view: UIView) {
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
            
            let defaultSize = 128
            
            let baseCachePath = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).path + "/frame-cache"
            let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: baseCachePath), withIntermediateDirectories: true, attributes: nil)
            print("Frame cache: \(baseCachePath)")
            
            for (filePath, fileName) in buildAnimationFolderItems(basePath: bundlePath, path: "") {
                let _ = await cacheReferenceAnimation(baseCachePath: baseCachePath, width: sizeMapping[fileName] ?? defaultSize, path: filePath, name: fileName)
            }
            
            var continueFromName: String?
            //continueFromName = "35707580709863498.json"
            
            let _ = await processAnimationFolderAsync(basePath: bundlePath, path: "", stopOnFailure: true, process: { path, name, alwaysDraw in
                if let continueFromNameValue = continueFromName {
                    if continueFromNameValue == name {
                        continueFromName = nil
                    } else {
                        return true
                    }
                }
                
                let size = sizeMapping[name] ?? defaultSize
                
                let result = await processDrawAnimation(baseCachePath: baseCachePath, path: path, name: name, size: CGSize(width: size, height: size), alwaysDraw: alwaysDraw, updateImage: { image, referenceImage in
                    DispatchQueue.main.async {
                        self.imageView.image = image
                        self.referenceImageView.image = referenceImage
                    }
                })
                return result
            })
        }
    }
}

public final class ViewController: UIViewController {
    private var link: SharedDisplayLinkDriver.Link?
    private var test: AnyObject?
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        SharedDisplayLinkDriver.shared.updateForegroundState(true)
        
        let bundlePath = Bundle.main.path(forResource: "TestDataBundle", ofType: "bundle")!
        let filePath = bundlePath + "/fireworks.json"
        
        let performanceFrameSize = 8
        
        self.view.layer.addSublayer(MetalEngine.shared.rootLayer)
        
        if "".isEmpty {
            if #available(iOS 13.0, *) {
                self.test = ReferenceCompareTest(view: self.view)
            }
        } else if !"".isEmpty {
            let cachedAnimation = cacheLottieMetalAnimation(path: filePath)!
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
            })
        } else if "".isEmpty {
            Thread {
                let animationData = try! Data(contentsOf: URL(fileURLWithPath: filePath))
                
                var startTime = CFAbsoluteTimeGetCurrent()
                let animation = LottieAnimation(data: animationData)!
                print("Load time: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                startTime = CFAbsoluteTimeGetCurrent()
                let animationContainer = LottieAnimationContainer(animation: animation)
                animationContainer.update(0)
                print("Build time: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                let animationRenderer = SoftwareLottieRenderer(animationContainer: animationContainer)
                
                startTime = CFAbsoluteTimeGetCurrent()
                var numUpdates: Int = 0
                var frameIndex = 0
                while true {
                    animationContainer.update(frameIndex)
                    let _ = animationRenderer.render(for: CGSize(width: CGFloat(performanceFrameSize), height: CGFloat(performanceFrameSize)), useReferenceRendering: false)
                    frameIndex = (frameIndex + 1) % animationContainer.animation.frameCount
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
