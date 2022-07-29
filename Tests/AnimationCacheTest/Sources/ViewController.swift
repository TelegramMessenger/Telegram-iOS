import Foundation
import UIKit

import Display
import RLottieBinding
import AnimationCache
import SwiftSignalKit

public final class ViewController: UIViewController {
    private var imageView: UIImageView?
    private var imageViewLarge: UIImageView?
    
    private var cache: AnimationCache?
    private var animationCacheItem: AnimationCacheItem?
    
    //private let playbackSize = CGSize(width: 512, height: 512)
    private let playbackSize = CGSize(width: 48.0, height: 48.0)
    //private let playbackSize = CGSize(width: 16, height: 16)
    
    private var fpsCount: Int = 0
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        
        let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 0.0, y: 20.0), size: CGSize(width: 48.0, height: 48.0)))
        self.imageView = imageView
        self.view.addSubview(imageView)
        
        let imageViewLarge = UIImageView(frame: CGRect(origin: CGPoint(x: 0.0, y: 20.0 + 48.0 + 10.0), size: CGSize(width: 256.0, height: 256.0)))
        //imageViewLarge.layer.magnificationFilter = .nearest
        self.imageViewLarge = imageViewLarge
        self.view.addSubview(imageViewLarge)
        
        self.loadItem()
        
        if #available(iOS 10.0, *) {
            let timer = Foundation.Timer(timeInterval: 1.0, repeats: true, block: { _ in
                print(self.fpsCount)
                self.fpsCount = 0
            })
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func loadItem() {
        let basePath = NSTemporaryDirectory() + "/animation-cache"
        let _ = try? FileManager.default.removeItem(atPath: basePath)
        let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: basePath), withIntermediateDirectories: true)
        self.cache = AnimationCacheImpl(basePath: basePath, allocateTempFile: {
            return basePath + "/\(Int64.random(in: 0 ... Int64.max))"
        })
        
        let path = Bundle.main.path(forResource: "Test2", ofType: "json")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: path))
        
        let scaledSize = CGSize(width: self.playbackSize.width * 2.0, height: self.playbackSize.height * 2.0)
        let _ = (self.cache!.get(sourceId: "Item\(Int64.random(in: 0 ... Int64.max))", size: scaledSize, fetch: { size, writer in
            writer.queue.async {
                let lottieInstance = LottieInstance(data: data, fitzModifier: .none, colorReplacements: nil, cacheKey: "")!
                
                for i in 0 ..< min(600, Int(lottieInstance.frameCount)) {
                    //for _ in 0 ..< 10 {
                    writer.add(with: { surface in
                        let _ = i
                        lottieInstance.renderFrame(with: Int32(i), into: surface.argb, width: Int32(surface.width), height: Int32(surface.height), bytesPerRow: Int32(surface.bytesPerRow))
                    
                        return 1.0 / 60.0
                    }, proposedWidth: Int(scaledSize.width), proposedHeight: Int(scaledSize.height), insertKeyframe: false)
                    //}
                }
                
                writer.finish()
            }
            
            return EmptyDisposable
        })
        |> deliverOnMainQueue).start(next: { result in
            if !result.isFinal {
                return
            }
            
            self.animationCacheItem = result.item
            
            self.updateImage()
        })
    }
    
    private func updateImage() {
        guard let animationCacheItem = self.animationCacheItem else {
            self.loadItem()
            return
        }
        
        if let frame = animationCacheItem.advance(advance: .frames(1), requestedFormat: .rgba) {
            switch frame.format {
            case let .rgba(data, width, height, bytesPerRow):
                let context = DrawingContext(size: CGSize(width: CGFloat(width), height: CGFloat(height)), scale: 1.0, opaque: false, bytesPerRow: bytesPerRow)
                    
                data.withUnsafeBytes { bytes -> Void in
                    memcpy(context.bytes, bytes.baseAddress!, height * bytesPerRow)
                }
                
                self.imageView?.image = context.generateImage()
                self.imageViewLarge?.image = self.imageView?.image
                
                self.fpsCount += 1
                
                /*DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0 / 60.0, execute: { [weak self] in
                    self?.updateImage()
                })*/
                DispatchQueue.main.async {
                    self.updateImage()
                }
            default:
                break
            }
        } else {
            self.loadItem()
        }
    }
}
