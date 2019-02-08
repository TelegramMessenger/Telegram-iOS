import Foundation
import AsyncDisplayKit
import UIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import Display

private let textFont = Font.regular(13.0)

final class ChatVideoGalleryItemScrubberView: UIView {
    private let leftTimestampNode: MediaPlayerTimeTextNode
    private let rightTimestampNode: MediaPlayerTimeTextNode
    private let fileSizeNode: ASTextNode
    private let scrubberNode: MediaPlayerScrubbingNode
    
    private var playbackStatus: MediaPlayerStatus?
    
    private var fetchStatusDisposable = MetaDisposable()
    
    var hideWhenDurationIsUnknown = false {
        didSet {
            if self.hideWhenDurationIsUnknown {
                if let playbackStatus = self.playbackStatus, !playbackStatus.duration.isZero {
                    self.scrubberNode.isHidden = false
                    self.leftTimestampNode.isHidden = false
                    self.rightTimestampNode.isHidden = false
                } else {
                    self.scrubberNode.isHidden = true
                    self.leftTimestampNode.isHidden = true
                    self.rightTimestampNode.isHidden = true
                }
            } else {
                self.scrubberNode.isHidden = false
                self.leftTimestampNode.isHidden = false
                self.rightTimestampNode.isHidden = false
            }
        }
    }
    
    var seek: (Double) -> Void = { _ in }
    
    override init(frame: CGRect) {
        self.scrubberNode = MediaPlayerScrubbingNode(content: .standard(lineHeight: 4.0, lineCap: .round, scrubberHandle: .circle, backgroundColor: UIColor(white: 1.0, alpha: 0.42), foregroundColor: .white))
        
        self.leftTimestampNode = MediaPlayerTimeTextNode(textColor: .white)
        self.rightTimestampNode = MediaPlayerTimeTextNode(textColor: .white)
        self.rightTimestampNode.alignment = .right
        self.rightTimestampNode.mode = .reversed
        
        self.fileSizeNode = ASTextNode()
        self.fileSizeNode.maximumNumberOfLines = 1
        self.fileSizeNode.isUserInteractionEnabled = false
        self.fileSizeNode.displaysAsynchronously = false
        
        super.init(frame: frame)
        
        self.scrubberNode.seek = { [weak self] timestamp in
            self?.seek(timestamp)
        }
        
        self.scrubberNode.playerStatusUpdated = { [weak self] status in
            if let strongSelf = self {
                strongSelf.playbackStatus = status
                if strongSelf.hideWhenDurationIsUnknown {
                    if let playbackStatus = status, !playbackStatus.duration.isZero {
                        strongSelf.scrubberNode.isHidden = false
                        strongSelf.leftTimestampNode.isHidden = false
                        strongSelf.rightTimestampNode.isHidden = false
                    } else {
                        strongSelf.scrubberNode.isHidden = true
                        strongSelf.leftTimestampNode.isHidden = true
                        strongSelf.rightTimestampNode.isHidden = true
                    }
                } else {
                    strongSelf.scrubberNode.isHidden = false
                    strongSelf.leftTimestampNode.isHidden = false
                    strongSelf.rightTimestampNode.isHidden = false
                }
            }
        }
        
        self.addSubnode(self.scrubberNode)
        self.addSubnode(self.leftTimestampNode)
        self.addSubnode(self.rightTimestampNode)
        self.addSubnode(self.fileSizeNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setStatusSignal(_ status: Signal<MediaPlayerStatus, NoError>?) {
        let mappedStatus: Signal<MediaPlayerStatus, NoError>?
        if let status = status {
            mappedStatus = combineLatest(status, self.scrubberNode.scrubbingTimestamp) |> map { status, scrubbingTimestamp -> MediaPlayerStatus in
                return MediaPlayerStatus(generationTimestamp: status.generationTimestamp, duration: status.duration, dimensions: status.dimensions, timestamp: scrubbingTimestamp ?? status.timestamp, baseRate: status.baseRate, seekId: status.seekId, status: status.status, soundEnabled: status.soundEnabled)
            }
        } else {
            mappedStatus = nil
        }
        self.scrubberNode.status = mappedStatus
        self.leftTimestampNode.status = mappedStatus
        self.rightTimestampNode.status = mappedStatus
    }
    
    func setBufferingStatusSignal(_ status: Signal<(IndexSet, Int)?, NoError>?) {
        self.scrubberNode.bufferingStatus = status
    }
    
    func setFetchStatusSignal(_ fetchStatus: Signal<MediaResourceStatus, NoError>?, strings: PresentationStrings, fileSize: Int?) {
        if let fileSize = fileSize {
            if let fetchStatus = fetchStatus {
                self.fetchStatusDisposable.set((fetchStatus
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self {
                        var text: String
                        switch status {
                            case .Remote:
                                text = dataSizeString(fileSize, forceDecimal: true)
                            case let .Fetching(_, progress):
                                text = strings.DownloadingStatus(dataSizeString(Int64(Float(fileSize) * progress), forceDecimal: true), dataSizeString(fileSize, forceDecimal: true)).0
                            default:
                                text = ""
                        }
                        strongSelf.fileSizeNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: .white)
                        strongSelf.layoutSubviews()
                    }
                }))
            } else {
                self.fileSizeNode.attributedText = NSAttributedString(string: dataSizeString(fileSize, forceDecimal: true), font: textFont, textColor: .white)
            }
        } else {
            self.fileSizeNode.attributedText = nil
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        guard !size.equalTo(CGSize.zero) else {
            return
        }
        
        let scrubberHeight: CGFloat = 14.0
        
        self.leftTimestampNode.frame = CGRect(origin: CGPoint(x: 6.0, y: 22.0), size: CGSize(width: 60.0, height: 20.0))
        self.rightTimestampNode.frame = CGRect(origin: CGPoint(x: size.width - 60.0 - 6.0, y: 22.0), size: CGSize(width: 60.0, height: 20.0))
        
        let fileSize = self.fileSizeNode.measure(size)
        self.fileSizeNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - fileSize.width) / 2.0), y: 22.0), size: fileSize)
        self.scrubberNode.frame = CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: size.width - 6.0 * 2.0, height: scrubberHeight))
    }
}
