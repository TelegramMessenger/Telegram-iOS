import Foundation
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

private struct FetchControls {
    let fetch: () -> Void
    let cancel: () -> Void
}

private let titleFont = Font.regular(16.0)
private let descriptionFont = Font.regular(13.0)
private let durationFont = Font.regular(11.0)

private let incomingTitleColor = UIColor(0x0b8bed)
private let outgoingTitleColor = UIColor(0x3faa3c)
private let incomingDescriptionColor = UIColor(0x999999)
private let outgoingDescriptionColor = UIColor(0x6fb26a)
private let incomingDurationColor = UIColor(0x525252, 0.6)
private let outgoingDurationColor = UIColor(0x008c09, 0.8)

private let fileIconIncomingImage = UIImage(bundleImageName: "Chat/Message/RadialProgressIconDocumentIncoming")?.precomposed()
private let fileIconOutgoingImage = UIImage(bundleImageName: "Chat/Message/RadialProgressIconDocumentOutgoing")?.precomposed()

final class ChatMessageInteractiveFileNode: ASTransformNode {
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let waveformNode: AudioWaveformNode
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    
    private var iconNode: TransformImageNode?
    private var progressNode: RadialProgressNode?
    private var tapRecognizer: UITapGestureRecognizer?
    
    private let statusDisposable = MetaDisposable()
    private let fetchControls = Atomic<FetchControls?>(value: nil)
    private var resourceStatus: FileMediaResourceStatus?
    private let fetchDisposable = MetaDisposable()
    
    var activateLocalContent: () -> Void = { }
    
    private var account: Account?
    private var message: Message?
    private var file: TelegramMediaFile?
    
    init() {
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = true
        self.titleNode.isLayerBacked = true
        
        self.descriptionNode = TextNode()
        self.descriptionNode.displaysAsynchronously = true
        self.descriptionNode.isLayerBacked = true
        
        self.waveformNode = AudioWaveformNode()
        
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
    }
    
    deinit {
        self.statusDisposable.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.fileTap(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
        self.tapRecognizer = tapRecognizer
    }
    
    @objc func progressPressed() {
        if let resourceStatus = self.resourceStatus {
            switch resourceStatus {
                case let .fetchStatus(fetchStatus):
                    switch fetchStatus {
                        case .Fetching:
                            if let cancel = self.fetchControls.with({ return $0?.cancel }) {
                                cancel()
                            }
                        case .Remote:
                            if let fetch = self.fetchControls.with({ return $0?.fetch }) {
                                fetch()
                            }
                        case .Local:
                            self.activateLocalContent()
                    }
                case .playbackStatus:
                    if let account = self.account, let applicationContext = account.applicationContext as? TelegramApplicationContext {
                        applicationContext.mediaManager.playlistPlayerControl(.playback(.togglePlayPause))
                    }
            }
        }
    }
    
    @objc func fileTap(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.progressPressed()
        }
    }
    
    func asyncLayout() -> (_ account: Account, _ message: Message, _ file: TelegramMediaFile, _ incoming: Bool, _ dateAndStatusType: ChatMessageDateAndStatusType?, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void))) {
        let currentFile = self.file
        
        let titleAsyncLayout = TextNode.asyncLayout(self.titleNode)
        let descriptionAsyncLayout = TextNode.asyncLayout(self.descriptionNode)
        let currentMessage = self.message
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        
        return { account, message, file, incoming, dateAndStatusType, constrainedSize in
            return (CGFloat.greatestFiniteMagnitude, { constrainedSize in
                //var updateImageSignal: Signal<TransformImageArguments -> DrawingContext, NoError>?
                var updatedStatusSignal: Signal<FileMediaResourceStatus, NoError>?
                var updatedFetchControls: FetchControls?
                
                var mediaUpdated = false
                if let currentFile = currentFile {
                    mediaUpdated = file != currentFile
                } else {
                    mediaUpdated = true
                }
                
                var statusUpdated = mediaUpdated
                if currentMessage?.id != message.id || currentMessage?.flags != message.flags {
                    statusUpdated = true
                }
                
                if mediaUpdated {
                    updatedFetchControls = FetchControls(fetch: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.fetchDisposable.set(chatMessageFileInteractiveFetched(account: account, file: file).start())
                        }
                    }, cancel: {
                        chatMessageFileCancelInteractiveFetch(account: account, file: file)
                    })
                }
                
                if statusUpdated {
                    updatedStatusSignal = fileMediaResourceStatus(account: account, file: file, message: message)
                }
                
                var statusSize: CGSize?
                var statusApply: ((Bool) -> Void)?
                
                if let statusType = dateAndStatusType {
                    var t = Int(message.timestamp)
                    var timeinfo = tm()
                    localtime_r(&t, &timeinfo)
                    
                    var edited = false
                    var viewCount: Int?
                    for attribute in message.attributes {
                        if let attribute = attribute as? EditedMessageAttribute {
                            edited = true
                        } else if let attribute = attribute as? ViewCountMessageAttribute {
                            viewCount = attribute.count
                        }
                    }
                    var dateText = String(format: "%02d:%02d", arguments: [Int(timeinfo.tm_hour), Int(timeinfo.tm_min)])
                    if let viewCount = viewCount {
                        dateText = "\(viewCount) " + dateText
                    }
                    if edited {
                        dateText = "edited " + dateText
                    }
                    
                    let (size, apply) = statusLayout(dateText, statusType, constrainedSize)
                    statusSize = size
                    statusApply = apply
                }
                
                var candidateTitleString: NSAttributedString?
                var candidateDescriptionString: NSAttributedString?
                
                var isAudio = false
                var audioWaveform: AudioWaveform?
                var isVoice = false
                var audioDuration: Int32 = 0
                
                for attribute in file.attributes {
                    if case let .Audio(voice, duration, title, performer, waveform) = attribute {
                        isAudio = true
                        if let currentUpdatedStatusSignal = updatedStatusSignal {
                            updatedStatusSignal = currentUpdatedStatusSignal |> map { status in
                                switch status {
                                    case .fetchStatus:
                                        return .fetchStatus(.Local)
                                    case .playbackStatus:
                                        return status
                                }
                            }
                        }
                        
                        audioDuration = Int32(duration)
                        if voice {
                            isVoice = true
                            candidateDescriptionString = NSAttributedString(string: String(format: "%d:%02d", duration / 60, duration % 60), font: durationFont, textColor:incoming ? incomingDurationColor : outgoingDurationColor)
                            if let waveform = waveform {
                                waveform.withDataNoCopy { data in
                                    audioWaveform = AudioWaveform(bitstream: data, bitsPerSample: 5)
                                }
                            }
                        } else {
                            candidateTitleString = NSAttributedString(string: title ?? "Unknown Track", font: titleFont, textColor: incoming ? incomingTitleColor : outgoingTitleColor)
                            let descriptionText: String
                            if let performer = performer {
                                descriptionText = performer
                            } else if let size = file.size {
                                descriptionText = dataSizeString(size)
                            } else {
                                descriptionText = ""
                            }
                            candidateDescriptionString = NSAttributedString(string: descriptionText, font: descriptionFont, textColor:incoming ? incomingDescriptionColor : outgoingDescriptionColor)
                        }
                        break
                    }
                }
                
                var titleString: NSAttributedString?
                var descriptionString: NSAttributedString?
                
                if let candidateTitleString = candidateTitleString {
                    titleString = candidateTitleString
                } else if !isVoice {
                    titleString = NSAttributedString(string: file.fileName ?? "File", font: titleFont, textColor: incoming ? incomingTitleColor : outgoingTitleColor)
                }
                
                if let candidateDescriptionString = candidateDescriptionString {
                    descriptionString = candidateDescriptionString
                } else if !isVoice {
                    let descriptionText: String
                    if let size = file.size {
                        descriptionText = dataSizeString(size)
                    } else {
                        descriptionText = ""
                    }
                    descriptionString = NSAttributedString(string: descriptionText, font: descriptionFont, textColor:incoming ? incomingDescriptionColor : outgoingDescriptionColor)
                }
                
                let textConstrainedSize = CGSize(width: constrainedSize.width - 44.0 - 8.0, height: constrainedSize.height)
                
                let (titleLayout, titleApply) = titleAsyncLayout(titleString, nil, 1, .middle, textConstrainedSize, nil)
                let (descriptionLayout, descriptionApply) = descriptionAsyncLayout(descriptionString, nil, 1, .middle, textConstrainedSize, nil)
                
                var voiceWidth: CGFloat = 0.0
                let minVoiceWidth: CGFloat = 120.0
                let maxVoiceWidth = constrainedSize.width
                let maxVoiceLength: CGFloat = 30.0
                
                let minLayoutWidth: CGFloat
                if isVoice {
                    //y = a exp bx
                    //b = log (y1/y2) / (x1-x2)
                    //a = y1 / exp bx1
                    
                    let b = log(maxVoiceWidth / minVoiceWidth) / (maxVoiceLength - 0.0)
                    let a = minVoiceWidth / exp(CGFloat(0.0))
                    
                    let y = a * exp(b * min(maxVoiceLength, CGFloat(audioDuration)))
                    
                    minLayoutWidth = floor(y)
                } else {
                    minLayoutWidth = max(titleLayout.size.width, descriptionLayout.size.width) + 44.0 + 8.0
                }
                
                return (minLayoutWidth, { boundingWidth in
                    let progressDiameter: CGFloat = isVoice ? 37.0 : 44.0
                    let progressFrame = CGRect(origin: CGPoint(x: 0.0, y: isVoice ? -5.0 : 0.0), size: CGSize(width: progressDiameter, height: progressDiameter))
                    
                    let titleAndDescriptionHeight = titleLayout.size.height - 1.0 + descriptionLayout.size.height
                    
                    let titleFrame = CGRect(origin: CGPoint(x: progressFrame.maxX + 8.0, y: floor((44.0 - titleAndDescriptionHeight) / 2.0)), size: titleLayout.size)
                    
                    let descriptionFrame: CGRect
                    if isVoice {
                        descriptionFrame = CGRect(origin: CGPoint(x: 43.0, y: 19.0), size: descriptionLayout.size)
                    } else {
                        descriptionFrame = CGRect(origin: CGPoint(x: titleFrame.minX, y: titleFrame.maxY - 1.0), size: descriptionLayout.size)
                    }
                    
                    let fittedLayoutSize: CGSize
                    if isVoice {
                        fittedLayoutSize = CGSize(width: minLayoutWidth, height: 27.0)
                    } else {
                        fittedLayoutSize = titleFrame.union(descriptionFrame).union(progressFrame).size
                    }
                    
                    return (fittedLayoutSize, { [weak self] in
                        if let strongSelf = self {
                            strongSelf.account = account
                            strongSelf.message = message
                            strongSelf.file = file
                            
                            let _ = titleApply()
                            let _ = descriptionApply()
                            
                            strongSelf.titleNode.frame = titleFrame
                            strongSelf.descriptionNode.frame = descriptionFrame
                            
                            if let statusApply = statusApply, let statusSize = statusSize {
                                if strongSelf.dateAndStatusNode.supernode == nil {
                                   strongSelf.addSubnode(strongSelf.dateAndStatusNode)
                                }
                                
                                strongSelf.dateAndStatusNode.frame = CGRect(origin: CGPoint(x: fittedLayoutSize.width - statusSize.width, y: fittedLayoutSize.height - statusSize.height + 10.0), size: statusSize)
                                statusApply(false)
                            } else if strongSelf.dateAndStatusNode.supernode != nil {
                                strongSelf.dateAndStatusNode.removeFromSupernode()
                            }
                            
                            if isVoice {
                                if strongSelf.waveformNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.waveformNode)
                                }
                                strongSelf.waveformNode.frame = CGRect(origin: CGPoint(x: 43.0, y: -1.0), size: CGSize(width: fittedLayoutSize.width - 41.0, height: 12.0))
                                strongSelf.waveformNode.setup(color: UIColor(incoming ? 0x007ee5 : 0x3fc33b), waveform: audioWaveform)
                            } else if strongSelf.waveformNode.supernode != nil {
                                strongSelf.waveformNode.removeFromSupernode()
                            }
                            
                            /*if let updateImageSignal = updateImageSignal {
                                strongSelf.imageNode.setSignal(account, signal: updateImageSignal)
                            }*/
                            
                            if let updatedStatusSignal = updatedStatusSignal {
                                strongSelf.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak strongSelf] status in
                                    displayLinkDispatcher.dispatch {
                                        if let strongSelf = strongSelf {
                                            strongSelf.resourceStatus = status
                                            
                                            if strongSelf.progressNode == nil {
                                                let progressNode = RadialProgressNode(theme: RadialProgressTheme(backgroundColor: UIColor(incoming ? 0x007ee5 : 0x3fc33b), foregroundColor: incoming ? UIColor.white : UIColor(0xe1ffc7), icon: incoming ? fileIconIncomingImage : fileIconOutgoingImage))
                                                strongSelf.progressNode = progressNode
                                                progressNode.frame = progressFrame
                                                strongSelf.addSubnode(progressNode)
                                            }
                                            
                                            switch status {
                                                case let .fetchStatus(fetchStatus):
                                                    switch fetchStatus {
                                                        case let .Fetching(progress):
                                                            strongSelf.progressNode?.state = .Fetching(progress: progress)
                                                        case .Local:
                                                            if isAudio {
                                                                strongSelf.progressNode?.state = .Play
                                                            } else {
                                                                strongSelf.progressNode?.state = .Icon
                                                            }
                                                        case .Remote:
                                                            if isAudio {
                                                                strongSelf.progressNode?.state = .Play
                                                            } else {
                                                                strongSelf.progressNode?.state = .Remote
                                                            }
                                                    }
                                                case let .playbackStatus(playbackStatus):
                                                    switch playbackStatus {
                                                        case .playing:
                                                            strongSelf.progressNode?.state = .Pause
                                                        case .paused:
                                                            strongSelf.progressNode?.state = .Play
                                                    }
                                            }
                                        }
                                    }
                                }))
                            }
                            
                            strongSelf.progressNode?.frame = progressFrame
                            
                            if let updatedFetchControls = updatedFetchControls {
                                let _ = strongSelf.fetchControls.swap(updatedFetchControls)
                            }
                        }
                    })
                })
            })
        }
    }
    
    static func asyncLayout(_ node: ChatMessageInteractiveFileNode?) -> (_ account: Account, _ message: Message, _ file: TelegramMediaFile, _ incoming: Bool, _ dateAndStatusType: ChatMessageDateAndStatusType?, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageInteractiveFileNode))) {
        let currentAsyncLayout = node?.asyncLayout()
        
        return { account, message, file, incoming, dateAndStatusType, constrainedSize in
            var fileNode: ChatMessageInteractiveFileNode
            var fileLayout: (_ account: Account, _ message: Message, _ file: TelegramMediaFile, _ incoming: Bool, _ dateAnsStatusType: ChatMessageDateAndStatusType?, _ constrainedSize: CGSize) -> (CGFloat, (CGSize) -> (CGFloat, (CGFloat) -> (CGSize, () -> Void)))
            
            if let node = node, let currentAsyncLayout = currentAsyncLayout {
                fileNode = node
                fileLayout = currentAsyncLayout
            } else {
                fileNode = ChatMessageInteractiveFileNode()
                fileLayout = fileNode.asyncLayout()
            }
            
            let (initialWidth, continueLayout) = fileLayout(account, message, file, incoming, dateAndStatusType, constrainedSize)
            
            return (initialWidth, { constrainedSize in
                let (finalWidth, finalLayout) = continueLayout(constrainedSize)
                
                return (finalWidth, { boundingWidth in
                    let (finalSize, apply) = finalLayout(boundingWidth)
                    
                    return (finalSize, {
                        apply()
                        return fileNode
                    })
                })
            })
        }
    }
}
