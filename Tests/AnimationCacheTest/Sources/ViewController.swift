import Foundation
import UIKit

import Display
import AnimationCache
import SwiftSignalKit
import VideoAnimationCache
import LottieAnimationCache

public final class ViewController: UIViewController {
    private var imageView: UIImageView?
    private var imageViewLarge: UIImageView?
    
    private var cache: AnimationCache?
    private var animationCacheItem: AnimationCacheItem?
    
    //private let playbackSize = CGSize(width: 512, height: 512)
    //private let playbackSize = CGSize(width: 256, height: 256)
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
        
        let path = Bundle.main.path(forResource: "sticker", ofType: "webm")!
        
        let scaledSize = CGSize(width: self.playbackSize.width * 2.0, height: self.playbackSize.height * 2.0)
        let _ = (self.cache!.get(sourceId: "Item\(Int64.random(in: 0 ... Int64.max))", size: scaledSize, fetch: { options in
            options.writer.queue.async {
                if path.hasSuffix(".webm") {
                    cacheVideoAnimation(path: path, width: Int(options.size.width), height: Int(options.size.height), writer: options.writer, firstFrameOnly: options.firstFrameOnly)
                } else {
                    let data = try! Data(contentsOf: URL(fileURLWithPath: path))
                    cacheLottieAnimation(data: data, width: Int(options.size.width), height: Int(options.size.height), keyframeOnly: false, writer: options.writer, firstFrameOnly: options.firstFrameOnly)
                }
                
                options.writer.finish()
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
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0 / 30.0, execute: { [weak self] in
                    self?.updateImage()
                })
                /*DispatchQueue.main.async {
                    self.updateImage()
                }*/
            default:
                break
            }
        } else {
            self.loadItem()
        }
    }
}
