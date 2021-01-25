import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import PresentationDataUtils
import RadialStatusNode
import AnimatedStickerNode
import AppBundle
import ZIPFoundation
import MimeTypes
import ConfettiEffect
import TelegramUniversalVideoContent
import SolidRoundedButtonNode

public final class ChatImportActivityScreen: ViewController {
    enum ImportError {
        case generic
        case chatAdminRequired
        case invalidChatType
    }
    
    private enum State {
        case progress(CGFloat)
        case error(ImportError)
        case done
    }
    
    private final class Node: ViewControllerTracingNode {
        private weak var controller: ChatImportActivityScreen?
        
        private let context: AccountContext
        private var presentationData: PresentationData
        
        private let animationNode: AnimatedStickerNode
        private let doneAnimationNode: AnimatedStickerNode
        private let radialStatus: RadialStatusNode
        private let radialCheck: RadialStatusNode
        private let radialStatusBackground: ASImageNode
        private let radialStatusText: ImmediateTextNode
        private let progressText: ImmediateTextNode
        private let statusText: ImmediateTextNode
        
        private let statusButtonText: ImmediateTextNode
        private let statusButton: HighlightableButtonNode
        private let doneButton: SolidRoundedButtonNode
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        
        private let totalBytes: Int
        private var state: State = .progress(0.0)
        
        private var videoNode: UniversalVideoNode?
        private var feedback: HapticFeedback?
        
        init(controller: ChatImportActivityScreen, context: AccountContext, totalBytes: Int) {
            self.controller = controller
            self.context = context
            self.totalBytes = totalBytes
            
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.animationNode = AnimatedStickerNode()
            self.doneAnimationNode = AnimatedStickerNode()
            self.doneAnimationNode.isHidden = true
            
            self.radialStatus = RadialStatusNode(backgroundNodeColor: .clear)
            self.radialCheck = RadialStatusNode(backgroundNodeColor: .clear)
            self.radialStatusBackground = ASImageNode()
            self.radialStatusBackground.isUserInteractionEnabled = false
            self.radialStatusBackground.displaysAsynchronously = false
            self.radialStatusBackground.image = generateCircleImage(diameter: 180.0, lineWidth: 6.0, color: self.presentationData.theme.list.itemAccentColor.withMultipliedAlpha(0.2))
            
            self.radialStatusText = ImmediateTextNode()
            self.radialStatusText.isUserInteractionEnabled = false
            self.radialStatusText.displaysAsynchronously = false
            self.radialStatusText.maximumNumberOfLines = 1
            self.radialStatusText.isAccessibilityElement = false
            
            self.progressText = ImmediateTextNode()
            self.progressText.isUserInteractionEnabled = false
            self.progressText.displaysAsynchronously = false
            self.progressText.maximumNumberOfLines = 1
            self.progressText.isAccessibilityElement = false
            
            self.statusText = ImmediateTextNode()
            self.statusText.textAlignment = .center
            self.statusText.isUserInteractionEnabled = false
            self.statusText.displaysAsynchronously = false
            self.statusText.maximumNumberOfLines = 0
            self.statusText.isAccessibilityElement = false
            
            self.statusButtonText = ImmediateTextNode()
            self.statusButtonText.isUserInteractionEnabled = false
            self.statusButtonText.displaysAsynchronously = false
            self.statusButtonText.maximumNumberOfLines = 1
            self.statusButtonText.isAccessibilityElement = false
            
            self.statusButton = HighlightableButtonNode()
            
            self.doneButton = SolidRoundedButtonNode(title: self.presentationData.strings.ChatImportActivity_OpenApp, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.list.itemCheckColors.fillColor, foregroundColor: self.presentationData.theme.list.itemCheckColors.foregroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
            
            super.init()
            
            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            if let path = getAppBundle().path(forResource: "HistoryImport", ofType: "tgs") {
                self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 170 * 2, height: 170 * 2, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
                self.animationNode.visibility = true
            }
            if let path = getAppBundle().path(forResource: "HistoryImportDone", ofType: "tgs") {
                self.doneAnimationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 170 * 2, height: 170 * 2, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                self.doneAnimationNode.started = { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.animationNode.isHidden = true
                }
                self.doneAnimationNode.visibility = false
            }
            
            self.addSubnode(self.animationNode)
            self.addSubnode(self.doneAnimationNode)
            self.addSubnode(self.radialStatusBackground)
            self.addSubnode(self.radialStatus)
            self.addSubnode(self.radialCheck)
            self.addSubnode(self.radialStatusText)
            self.addSubnode(self.progressText)
            self.addSubnode(self.statusText)
            self.addSubnode(self.statusButtonText)
            self.addSubnode(self.statusButton)
            self.addSubnode(self.doneButton)
            
            self.statusButton.addTarget(self, action: #selector(self.statusButtonPressed), forControlEvents: .touchUpInside)
            self.statusButton.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self {
                    if highlighted {
                        strongSelf.statusButtonText.layer.removeAnimation(forKey: "opacity")
                        strongSelf.statusButtonText.alpha = 0.4
                    } else {
                        strongSelf.statusButtonText.alpha = 1.0
                        strongSelf.statusButtonText.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                }
            }
            
            self.animationNode.completed = { [weak self] stopped in
                guard let strongSelf = self, stopped else {
                    return
                }
                strongSelf.animationNode.visibility = false
                strongSelf.doneAnimationNode.visibility = true
                strongSelf.doneAnimationNode.isHidden = false
            }
            
            if let path = getAppBundle().path(forResource: "BlankVideo", ofType: "m4v"), let size = fileSize(path) {
                let decoration = ChatBubbleVideoDecoration(corners: ImageCorners(), nativeSize: CGSize(width: 100.0, height: 100.0), contentMode: .aspectFit, backgroundColor: .black)
                
                let dummyFile = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 1), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: 12345), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: size, attributes: [.Video(duration: 1, size: PixelDimensions(width: 100, height: 100), flags: [])])
                
                let videoContent = NativeVideoContent(id: .message(1, MediaId(namespace: 0, id: 1)), fileReference: .standalone(media: dummyFile), streamVideo: .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .black)
                
                let videoNode = UniversalVideoNode(postbox: context.account.postbox, audioSession: context.sharedContext.mediaManager.audioSession, manager: context.sharedContext.mediaManager.universalVideoManager, decoration: decoration, content: videoContent, priority: .embedded)
                videoNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 2.0, height: 2.0))
                videoNode.alpha = 0.01
                self.videoNode = videoNode
                
                self.addSubnode(videoNode)
                videoNode.canAttachContent = true
                videoNode.play()
                
                self.doneButton.pressed = { [weak self] in
                    guard let strongSelf = self, let controller = strongSelf.controller else {
                        return
                    }
                    
                    if let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication {
                        let selector = NSSelectorFromString("openURL:")
                        let url = URL(string: "tg://localpeer?id=\(controller.peerId.toInt64())")!
                        application.perform(selector, with: url)
                    }
                }
            }
        }
        
        @objc private func statusButtonPressed() {
            switch self.state {
            case .done, .progress:
                self.controller?.cancel()
            case .error:
                self.controller?.beginImport()
            }
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let isFirstLayout = self.validLayout == nil
            self.validLayout = (layout, navigationHeight)
            
            let iconSize = CGSize(width: 170.0, height: 170.0)
            let radialStatusSize = CGSize(width: 186.0, height: 186.0)
            let maxIconStatusSpacing: CGFloat = 62.0
            let maxProgressTextSpacing: CGFloat = 33.0
            let progressStatusSpacing: CGFloat = 14.0
            let statusButtonSpacing: CGFloat = 19.0
            
            let effectiveProgress: CGFloat
            switch state {
            case let .progress(value):
                effectiveProgress = value
            case .error:
                effectiveProgress = 0.0
            case .done:
                effectiveProgress = 1.0
            }
            
            self.radialStatusText.attributedText = NSAttributedString(string: "\(Int(effectiveProgress * 100.0))%", font: Font.with(size: 42.0, design: .round, weight: .semibold), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            let radialStatusTextSize = self.radialStatusText.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
            
            self.progressText.attributedText = NSAttributedString(string: "\(dataSizeString(Int(effectiveProgress * CGFloat(self.totalBytes)))) of \(dataSizeString(Int(1.0 * CGFloat(self.totalBytes))))", font: Font.semibold(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            let progressTextSize = self.progressText.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: .greatestFiniteMagnitude))
            
            switch self.state {
            case .progress, .done:
                self.statusButtonText.attributedText = NSAttributedString(string: self.presentationData.strings.Common_Done, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.itemAccentColor)
            case .error:
                self.statusButtonText.attributedText = NSAttributedString(string: self.presentationData.strings.ChatImportActivity_Retry, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.itemAccentColor)
            }
            let statusButtonTextSize = self.statusButtonText.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: .greatestFiniteMagnitude))
            
            switch self.state {
            case .progress:
                self.statusText.attributedText = NSAttributedString(string: self.presentationData.strings.ChatImportActivity_InProgress, font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
            case let .error(error):
                let errorText: String
                switch error {
                case .chatAdminRequired:
                    errorText = self.presentationData.strings.ChatImportActivity_ErrorNotAdmin
                case .invalidChatType:
                    errorText = self.presentationData.strings.ChatImportActivity_ErrorGeneric
                case .generic:
                    errorText = self.presentationData.strings.ChatImportActivity_ErrorInvalidChatType
                }
                self.statusText.attributedText = NSAttributedString(string: errorText, font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemDestructiveColor)
            case .done:
                self.statusText.attributedText = NSAttributedString(string: self.presentationData.strings.ChatImportActivity_Success, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            }
            
            let statusTextSize = self.statusText.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: .greatestFiniteMagnitude))
            
            let contentHeight: CGFloat
            var hideIcon = false
            if case .compact = layout.metrics.heightClass, layout.size.width > layout.size.height {
                hideIcon = true
                contentHeight = progressTextSize.height + progressStatusSpacing + 160.0
            } else {
                contentHeight = iconSize.height + maxIconStatusSpacing + radialStatusSize.height + maxProgressTextSpacing + progressTextSize.height + progressStatusSpacing + 100.0
            }
            
            transition.updateAlpha(node: self.radialStatus, alpha: hideIcon ? 0.0 : 1.0)
            transition.updateAlpha(node: self.radialStatusBackground, alpha: hideIcon ? 0.0 : 1.0)
            switch self.state {
            case .done:
                break
            default:
                transition.updateAlpha(node: self.radialStatusText, alpha: hideIcon ? 0.0 : 1.0)
            }
            transition.updateAlpha(node: self.radialCheck, alpha: hideIcon ? 0.0 : 1.0)
            transition.updateAlpha(node: self.animationNode, alpha: hideIcon ? 0.0 : 1.0)
            transition.updateAlpha(node: self.doneAnimationNode, alpha: hideIcon ? 0.0 : 1.0)
            
            let contentOriginY = navigationHeight + floor((layout.size.height - contentHeight) / 2.0)
            
            self.animationNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: contentOriginY), size: iconSize)
            self.animationNode.updateLayout(size: iconSize)
            self.doneAnimationNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: contentOriginY), size: iconSize)
            self.doneAnimationNode.updateLayout(size: iconSize)
            
            self.radialStatus.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - radialStatusSize.width) / 2.0), y: contentOriginY + iconSize.height + maxIconStatusSpacing), size: radialStatusSize)
            let checkSize: CGFloat = 130.0
            self.radialCheck.frame = CGRect(origin: CGPoint(x: self.radialStatus.frame.minX + floor((self.radialStatus.frame.width - checkSize) / 2.0), y: self.radialStatus.frame.minY + floor((self.radialStatus.frame.height - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize))
            self.radialStatusBackground.frame = self.radialStatus.frame
            
            self.radialStatusText.frame = CGRect(origin: CGPoint(x: self.radialStatus.frame.minX + floor((self.radialStatus.frame.width - radialStatusTextSize.width) / 2.0), y: self.radialStatus.frame.minY + floor((self.radialStatus.frame.height - radialStatusTextSize.height) / 2.0)), size: radialStatusTextSize)
            
            self.progressText.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - progressTextSize.width) / 2.0), y: hideIcon ? contentOriginY : (self.radialStatus.frame.maxY + maxProgressTextSpacing)), size: progressTextSize)
            
            if case .progress = self.state {
                self.statusText.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusTextSize.width) / 2.0), y: self.progressText.frame.maxY + progressStatusSpacing), size: statusTextSize)
                self.statusButtonText.isHidden = true
                self.statusButton.isHidden = true
                self.doneButton.isHidden = true
                self.progressText.isHidden = false
            } else if case .error = self.state {
                self.statusText.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusTextSize.width) / 2.0), y: self.progressText.frame.minY), size: statusTextSize)
                self.statusButtonText.isHidden = false
                self.statusButton.isHidden = false
                self.doneButton.isHidden = true
                self.progressText.isHidden = true
            } else {
                self.statusText.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusTextSize.width) / 2.0), y: self.progressText.frame.minY), size: statusTextSize)
                self.statusButtonText.isHidden = false
                self.statusButton.isHidden = false
                self.doneButton.isHidden = true
                self.progressText.isHidden = true
            }/* else {
                self.statusText.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusTextSize.width) / 2.0), y: self.progressText.frame.minY), size: statusTextSize)
                self.statusButtonText.isHidden = true
                self.statusButton.isHidden = true
                self.doneButton.isHidden = false
                self.progressText.isHidden = true
            }*/
            
            let buttonSideInset: CGFloat = 75.0
            let buttonWidth = max(240.0, min(layout.size.width - buttonSideInset * 2.0, horizontalContainerFillingSizeForLayout(layout: layout, sideInset: buttonSideInset)))
            
            let buttonHeight = self.doneButton.updateLayout(width: buttonWidth, transition: .immediate)
            
            let doneButtonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: self.statusText.frame.maxY + statusButtonSpacing + 10.0), size: CGSize(width: buttonWidth, height: buttonHeight))
            self.doneButton.frame = doneButtonFrame
            
            let statusButtonTextFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusButtonTextSize.width) / 2.0), y: self.statusText.frame.maxY + statusButtonSpacing), size: statusButtonTextSize)
            self.statusButtonText.frame = statusButtonTextFrame
            self.statusButton.frame = statusButtonTextFrame.insetBy(dx: -10.0, dy: -10.0)
            
            if isFirstLayout {
                self.updateState(state: self.state, animated: false)
            }
        }
        
        func updateState(state: State, animated: Bool) {
            var wasDone = false
            if case .done = self.state {
                wasDone = true
            }
            self.state = state
            
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                
                let effectiveProgress: CGFloat
                switch state {
                case let .progress(value):
                    effectiveProgress = value
                case .error:
                    effectiveProgress = 0.0
                case .done:
                    effectiveProgress = 1.0
                }
                self.radialStatus.transitionToState(.progress(color: self.presentationData.theme.list.itemAccentColor, lineWidth: 6.0, value: max(0.01, effectiveProgress), cancelEnabled: false, animateRotation: false), animated: animated, synchronous: true, completion: {})
                if case .done = state {
                    self.radialCheck.transitionToState(.progress(color: .clear, lineWidth: 6.0, value: 1.0, cancelEnabled: false, animateRotation: false), animated: false, synchronous: true, completion: {})
                    self.radialCheck.transitionToState(.check(self.presentationData.theme.list.itemAccentColor), animated: animated, synchronous: true, completion: {})
                    self.radialStatus.layer.animateScale(from: 1.0, to: 1.05, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, additive: false, completion: { [weak self] _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.radialStatus.layer.animateScale(from: 1.05, to: 1.0, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, additive: false)
                    })
                    self.radialCheck.layer.animateScale(from: 1.0, to: 1.05, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, additive: false, completion: { [weak self] _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.radialCheck.layer.animateScale(from: 1.05, to: 1.0, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, additive: false)
                    })
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = .animated(duration: 0.2, curve: .easeInOut)
                    } else {
                        transition = .immediate
                    }
                    transition.updateAlpha(node: self.radialStatusText, alpha: 0.0)
                    
                    if !wasDone {
                        self.view.addSubview(ConfettiView(frame: self.view.bounds))
                        
                        if self.feedback == nil {
                            self.feedback = HapticFeedback()
                        }
                        self.feedback?.success()
                        
                        self.animationNode.stopAtNearestLoop = true
                    }
                }
            }
        }
    }
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private var presentationData: PresentationData
    fileprivate let cancel: () -> Void
    fileprivate var peerId: PeerId
    private let archive: Archive
    private let mainEntry: TempBoxFile
    private let mainEntrySize: Int
    private let otherEntries: [(Entry, String, ChatHistoryImport.MediaType, Promise<TempBoxFile?>)]
    private let totalBytes: Int
    
    private var pendingEntries: [String: (Int, Float)] = [:]
    
    private let disposable = MetaDisposable()
    
    override public var _presentedInModal: Bool {
        get {
            return true
        } set(value) {
        }
    }
    
    public init(context: AccountContext, cancel: @escaping () -> Void, peerId: PeerId, archive: Archive, mainEntry: TempBoxFile, otherEntries: [(Entry, String, ChatHistoryImport.MediaType)]) {
        self.context = context
        self.cancel = cancel
        self.peerId = peerId
        self.archive = archive
        self.mainEntry = mainEntry
        
        self.otherEntries = otherEntries.map { entry -> (Entry, String, ChatHistoryImport.MediaType, Promise<TempBoxFile?>) in
            let signal = Signal<TempBoxFile?, NoError> { subscriber in
                let tempFile = TempBox.shared.tempFile(fileName: entry.1)
                do {
                    let _ = try archive.extract(entry.0, to: URL(fileURLWithPath: tempFile.path))
                    subscriber.putNext(tempFile)
                    subscriber.putCompletion()
                } catch {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                }
                
                return EmptyDisposable
            }
            let promise = Promise<TempBoxFile?>()
            promise.set(signal)
            return (entry.0, entry.1, entry.2, promise)
        }
        
        if let size = fileSize(self.mainEntry.path) {
            self.mainEntrySize = size
        } else {
            self.mainEntrySize = 0
        }
        
        for (entry, fileName, _) in otherEntries {
            self.pendingEntries[fileName] = (entry.uncompressedSize, 0.0)
        }
        
        var totalBytes: Int = self.mainEntrySize
        for entry in self.otherEntries {
            totalBytes += entry.0.uncompressedSize
        }
        self.totalBytes = totalBytes
        
        self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData, hideBackground: true, hideBadge: true))
        
        self.title = self.presentationData.strings.ChatImportActivity_Title
        
        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
        
        self.attemptNavigation = { _ in
            return false
        }
        
        self.beginImport()
        
        if let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication {
            application.isIdleTimerDisabled = true
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        
        if let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication {
            application.isIdleTimerDisabled = false
        }
    }
    
    @objc private func cancelPressed() {
        self.cancel()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self, context: self.context, totalBytes: self.totalBytes)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationHeight, transition: transition)
    }
    
    private func beginImport() {
        for (key, value) in self.pendingEntries {
            self.pendingEntries[key] = (value.0, 0.0)
        }
        
        self.controllerNode.updateState(state: .progress(0.0), animated: true)
        
        let context = self.context
        let archive = self.archive
        let mainEntry = self.mainEntry
        let otherEntries = self.otherEntries
        
        let resolvedPeerId: Signal<PeerId, ImportError>
        if self.peerId.namespace == Namespaces.Peer.CloudGroup {
            resolvedPeerId = convertGroupToSupergroup(account: self.context.account, peerId: self.peerId)
            |> mapError { _ -> ImportError in
                return .generic
            }
        } else {
            resolvedPeerId = .single(self.peerId)
        }
        
        self.disposable.set((resolvedPeerId
        |> mapToSignal { [weak self] peerId -> Signal<ChatHistoryImport.Session, ImportError> in
            Queue.mainQueue().async {
                self?.peerId = peerId
            }
            
            return ChatHistoryImport.initSession(account: context.account, peerId: peerId, file: mainEntry, mediaCount: Int32(otherEntries.count))
            |> mapError { error -> ImportError in
                switch error {
                case .chatAdminRequired:
                    return .chatAdminRequired
                case .invalidChatType:
                    return .invalidChatType
                case .generic:
                    return .generic
                }
            }
        }
        |> mapToSignal { session -> Signal<(String, Float), ImportError> in
            var importSignal: Signal<(String, Float), ImportError> = .single(("", 0.0))
            
            for (_, fileName, mediaType, fileData) in otherEntries {
                let unpackedFile: Signal<TempBoxFile, ImportError> = fileData.get()
                |> take(1)
                |> castError(ImportError.self)
                |> mapToSignal { file -> Signal<TempBoxFile, ImportError> in
                    if let file = file {
                        return .single(file)
                    } else {
                        return .fail(.generic)
                    }
                }
                let uploadedMedia = unpackedFile
                |> mapToSignal { tempFile -> Signal<(String, Float), ImportError> in
                    var mimeTypeValue = "application/binary"
                    let fileExtension = (tempFile.path as NSString).pathExtension
                    if !fileExtension.isEmpty {
                        if let value = TGMimeTypeMap.mimeType(forExtension: fileExtension.lowercased()) {
                            mimeTypeValue = value
                        }
                    }
                    
                    return ChatHistoryImport.uploadMedia(account: context.account, session: session, file: tempFile, fileName: fileName, mimeType: mimeTypeValue, type: mediaType)
                    |> mapError { error -> ImportError in
                        switch error {
                        case .chatAdminRequired:
                            return .chatAdminRequired
                        case .generic:
                            return .generic
                        }
                    }
                    |> map { progress -> (String, Float) in
                        return (fileName, progress)
                    }
                }
                
                importSignal = importSignal
                |> then(uploadedMedia)
            }
            
            importSignal = importSignal
            |> then(ChatHistoryImport.startImport(account: context.account, session: session)
            |> mapError { _ -> ImportError in
                return .generic
            }
            |> map { _ -> (String, Float) in
            })
            
            return importSignal
        }
        |> deliverOnMainQueue).start(next: { [weak self] (fileName, progress) in
            guard let strongSelf = self else {
                return
            }
            
            if let (fileSize, _) = strongSelf.pendingEntries[fileName] {
                strongSelf.pendingEntries[fileName] = (fileSize, progress)
            }
            
            var totalDoneBytes = strongSelf.mainEntrySize
            for (_, sizeAndProgress) in strongSelf.pendingEntries {
                totalDoneBytes += Int(Float(sizeAndProgress.0) * sizeAndProgress.1)
            }
            
            var totalProgress: CGFloat = 1.0
            if !strongSelf.otherEntries.isEmpty {
                totalProgress = CGFloat(totalDoneBytes) / CGFloat(strongSelf.totalBytes)
            }
            strongSelf.controllerNode.updateState(state: .progress(totalProgress), animated: true)
        }, error: { [weak self] error in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState(state: .error(error), animated: true)
        }, completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState(state: .done, animated: true)
            
            if let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication {
                application.isIdleTimerDisabled = false
            }
        }))
    }
}
