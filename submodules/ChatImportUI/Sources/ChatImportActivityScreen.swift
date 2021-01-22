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

public final class ChatImportActivityScreen: ViewController {
    private final class Node: ViewControllerTracingNode {
        private weak var controller: ChatImportActivityScreen?
        
        private let context: AccountContext
        private var presentationData: PresentationData
        
        private let animationNode: AnimatedStickerNode
        private let radialStatus: RadialStatusNode
        private let radialCheck: RadialStatusNode
        private let radialStatusBackground: ASImageNode
        private let radialStatusText: ImmediateTextNode
        private let progressText: ImmediateTextNode
        private let statusText: ImmediateTextNode
        
        private let statusButtonText: ImmediateTextNode
        private let statusButton: HighlightableButtonNode
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        
        private var totalProgress: CGFloat = 0.0
        private let totalBytes: Int
        private var isDone: Bool = false
        
        init(controller: ChatImportActivityScreen, context: AccountContext, totalBytes: Int) {
            self.controller = controller
            self.context = context
            self.totalBytes = totalBytes
            
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.animationNode = AnimatedStickerNode()
            
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
            
            super.init()
            
            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            if let path = getAppBundle().path(forResource: "HistoryImport", ofType: "tgs") {
                self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 170 * 2, height: 170 * 2, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
                self.animationNode.visibility = true
            }
            
            self.addSubnode(self.animationNode)
            self.addSubnode(self.radialStatusBackground)
            self.addSubnode(self.radialStatus)
            self.addSubnode(self.radialCheck)
            self.addSubnode(self.radialStatusText)
            self.addSubnode(self.progressText)
            self.addSubnode(self.statusText)
            self.addSubnode(self.statusButtonText)
            self.addSubnode(self.statusButton)
            
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
        }
        
        @objc private func statusButtonPressed() {
            self.controller?.cancel()
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            self.validLayout = (layout, navigationHeight)
            
            //TODO:localize
            
            let iconSize = CGSize(width: 170.0, height: 170.0)
            let radialStatusSize = CGSize(width: 186.0, height: 186.0)
            let maxIconStatusSpacing: CGFloat = 62.0
            let maxProgressTextSpacing: CGFloat = 33.0
            let progressStatusSpacing: CGFloat = 14.0
            let statusButtonSpacing: CGFloat = 19.0
            
            self.radialStatusText.attributedText = NSAttributedString(string: "\(Int(self.totalProgress * 100.0))%", font: Font.with(size: 42.0, design: .round, weight: .semibold), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            let radialStatusTextSize = self.radialStatusText.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
            
            self.progressText.attributedText = NSAttributedString(string: "\(dataSizeString(Int(self.totalProgress * CGFloat(self.totalBytes)))) of \(dataSizeString(Int(1.0 * CGFloat(self.totalBytes))))", font: Font.semibold(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            let progressTextSize = self.progressText.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: .greatestFiniteMagnitude))
            
            self.statusButtonText.attributedText = NSAttributedString(string: "Done", font: Font.semibold(17.0), textColor: self.presentationData.theme.list.itemAccentColor)
            let statusButtonTextSize = self.statusButtonText.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: .greatestFiniteMagnitude))
            
            if !self.isDone {
                self.statusText.attributedText = NSAttributedString(string: "Please keep this window open\nduring the import.", font: Font.regular(17.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
            } else {
                self.statusText.attributedText = NSAttributedString(string: "This chat has been imported\nsuccessfully.", font: Font.semibold(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            }
            let statusTextSize = self.statusText.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: .greatestFiniteMagnitude))
            
            let contentHeight: CGFloat
            var hideIcon = false
            if case .compact = layout.metrics.heightClass, layout.size.width > layout.size.height {
                hideIcon = true
                contentHeight = radialStatusSize.height + maxProgressTextSpacing + progressTextSize.height + progressStatusSpacing + 100.0
            } else {
                contentHeight = iconSize.height + maxIconStatusSpacing + radialStatusSize.height + maxProgressTextSpacing + progressTextSize.height + progressStatusSpacing + 100.0
            }
            
            transition.updateAlpha(node: self.animationNode, alpha: hideIcon ? 0.0 : 1.0)
            
            let contentOriginY = navigationHeight + floor((layout.size.height - contentHeight) / 2.0)
            
            self.animationNode.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - iconSize.width) / 2.0), y: contentOriginY), size: iconSize)
            self.animationNode.updateLayout(size: iconSize)
            
            self.radialStatus.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - radialStatusSize.width) / 2.0), y: hideIcon ? contentOriginY : (contentOriginY + iconSize.height + maxIconStatusSpacing)), size: radialStatusSize)
            let checkSize: CGFloat = 130.0
            self.radialCheck.frame = CGRect(origin: CGPoint(x: self.radialStatus.frame.minX + floor((self.radialStatus.frame.width - checkSize) / 2.0), y: self.radialStatus.frame.minY + floor((self.radialStatus.frame.height - checkSize) / 2.0)), size: CGSize(width: checkSize, height: checkSize))
            self.radialStatusBackground.frame = self.radialStatus.frame
            
            self.radialStatusText.frame = CGRect(origin: CGPoint(x: self.radialStatus.frame.minX + floor((self.radialStatus.frame.width - radialStatusTextSize.width) / 2.0), y: self.radialStatus.frame.minY + floor((self.radialStatus.frame.height - radialStatusTextSize.height) / 2.0)), size: radialStatusTextSize)
            
            self.progressText.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - progressTextSize.width) / 2.0), y: self.radialStatus.frame.maxY + maxProgressTextSpacing), size: progressTextSize)
            
            if self.isDone {
                self.statusText.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusTextSize.width) / 2.0), y: self.progressText.frame.minY), size: statusTextSize)
            } else {
                self.statusText.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusTextSize.width) / 2.0), y: self.progressText.frame.maxY + progressStatusSpacing), size: statusTextSize)
            }
            
            let statusButtonTextFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusButtonTextSize.width) / 2.0), y: self.statusText.frame.maxY + statusButtonSpacing), size: statusButtonTextSize)
            self.statusButtonText.frame = statusButtonTextFrame
            self.statusButton.frame = statusButtonTextFrame.insetBy(dx: -10.0, dy: -10.0)
            
            self.statusButtonText.isHidden = !self.isDone
            self.statusButton.isHidden = !self.isDone
            self.progressText.isHidden = self.isDone
        }
        
        func updateProgress(totalProgress: CGFloat, isDone: Bool, animated: Bool) {
            self.totalProgress = totalProgress
            self.isDone = isDone
            
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                self.radialStatus.transitionToState(.progress(color: self.presentationData.theme.list.itemAccentColor, lineWidth: 6.0, value: max(0.02, self.totalProgress), cancelEnabled: false), animated: animated, synchronous: true, completion: {})
                if isDone {
                    self.radialCheck.transitionToState(.progress(color: .clear, lineWidth: 6.0, value: self.totalProgress, cancelEnabled: false), animated: false, synchronous: true, completion: {})
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
    private let peerId: PeerId
    private let archive: Archive
    private let mainEntry: TempBoxFile
    private let mainEntrySize: Int
    private let otherEntries: [(Entry, String, ChatHistoryImport.MediaType)]
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
        self.otherEntries = otherEntries
        
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
        
        //TODO:localize
        self.title = "Importing Chat"
        
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
        enum ImportError {
            case generic
        }
        
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
        |> mapToSignal { peerId -> Signal<ChatHistoryImport.Session, ImportError> in
            return ChatHistoryImport.initSession(account: context.account, peerId: peerId, file: mainEntry, mediaCount: Int32(otherEntries.count))
            |> mapError { _ -> ImportError in
                return .generic
            }
        }
        |> mapToSignal { session -> Signal<(String, Float), ImportError> in
            var importSignal: Signal<(String, Float), ImportError> = .single(("", 0.0))
            
            for (entry, fileName, mediaType) in otherEntries {
                let unpackedFile = Signal<TempBoxFile, ImportError> { subscriber in
                    let tempFile = TempBox.shared.tempFile(fileName: fileName)
                    do {
                        let _ = try archive.extract(entry, to: URL(fileURLWithPath: tempFile.path))
                        subscriber.putNext(tempFile)
                        subscriber.putCompletion()
                    } catch {
                        subscriber.putError(.generic)
                    }
                    
                    return EmptyDisposable
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
                    |> mapError { _ -> ImportError in
                        return .generic
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
            strongSelf.controllerNode.updateProgress(totalProgress: totalProgress, isDone: false, animated: true)
        }, error: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateProgress(totalProgress: 0.0, isDone: false, animated: true)
        }, completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateProgress(totalProgress: 1.0, isDone: true, animated: true)
            
            if let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication {
                application.isIdleTimerDisabled = false
            }
        }))
    }
}
