import Foundation
import UIKit

final class ChatVideoGalleryItemScrubberView: UIView {
    private let backgroundView: UIView
    private let foregroundView: UIView
    private let handleView: UIView
    
    private var status: MediaPlayerStatus?
    
    private var scrubbing = false
    private var scrubbingLocation: CGFloat = 0.0
    private var initialScrubbingPosition: CGFloat = 0.0
    private var scrubbingPosition: CGFloat = 0.0
    
    var seek: (Double) -> Void = { _ in }
    
    override init(frame: CGRect) {
        self.backgroundView = UIView()
        self.backgroundView.backgroundColor = UIColor.gray
        self.backgroundView.clipsToBounds = true
        self.foregroundView = UIView()
        self.foregroundView.backgroundColor = UIColor.white
        self.handleView = UIView()
        self.handleView.backgroundColor = UIColor.white
        
        super.init(frame: frame)
        
        self.backgroundView.addSubview(self.foregroundView)
        self.addSubview(self.backgroundView)
        self.addSubview(self.handleView)
        
        self.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setStatus(_ status: MediaPlayerStatus) {
        self.status = status
        self.layoutSubviews()
        
        if status.status == .playing {
            
        }
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        guard let status = self.status, status.duration > 0.0 else {
            return
        }
        
        switch recognizer.state {
            case .began:
                self.scrubbing = true
                self.scrubbingLocation = recognizer.location(in: self).x
                self.initialScrubbingPosition = CGFloat(status.timestamp / status.duration)
                self.scrubbingPosition = 0.0
            case .changed:
                let distance = recognizer.location(in: self).x - self.scrubbingLocation
                self.scrubbingPosition = self.initialScrubbingPosition + (distance / self.bounds.size.width)
                self.layoutSubviews()
            case .ended:
                self.scrubbing = false
                self.seek(Double(self.scrubbingPosition) * status.duration)
            default:
                break
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        let barHeight: CGFloat = 2.0
        let handleHeight: CGFloat = 14.0
        
        self.backgroundView.frame = CGRect(origin: CGPoint(x: 0.0, y: floor(size.height - barHeight) / 2.0), size: CGSize(width: size.width, height: barHeight))
        
        var position: CGFloat = 0.0
        if self.scrubbing {
            position = self.scrubbingPosition
        } else {
            if let status = self.status, status.duration > 0.0 {
                position = CGFloat(status.timestamp / status.duration)
            }
        }
        
        self.foregroundView.frame = CGRect(origin: CGPoint(x: -size.width + floor(position * size.width), y: 0.0), size: CGSize(width: size.width, height: barHeight))
        self.handleView.frame = CGRect(origin: CGPoint(x: floor(position * size.width), y: floor(size.height - handleHeight) / 2.0), size: CGSize(width: 1.5, height: handleHeight))
    }
}
