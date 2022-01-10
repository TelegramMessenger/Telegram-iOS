import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import PresentationDataUtils
import RadialStatusNode
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import AppBundle
import ZipArchive
import MimeTypes
import ConfettiEffect
import TelegramUniversalVideoContent
import SolidRoundedButtonNode

private final class ProgressEstimator {
    private var averageProgressPerSecond: Double = 0.0
    private var lastMeasurement: (Double, Float)?
    
    init() {
    }
    
    func update(progress: Float) -> Double? {
        let timestamp = CACurrentMediaTime()
        if let (lastTimestamp, lastProgress) = self.lastMeasurement {
            if abs(lastProgress - progress) >= 0.01 || abs(lastTimestamp - timestamp) > 1.0 {
                let immediateProgressPerSecond = Double(progress - lastProgress) / (timestamp - lastTimestamp)
                let alpha: Double = 0.01
                self.averageProgressPerSecond = alpha * immediateProgressPerSecond + (1.0 - alpha) * self.averageProgressPerSecond
                self.lastMeasurement = (timestamp, progress)
            }
        } else {
            self.lastMeasurement = (timestamp, progress)
        }
        
        //print("progress = \(progress)")
        //print("averageProgressPerSecond = \(self.averageProgressPerSecond)")
        
        if self.averageProgressPerSecond < 0.0001 {
            return nil
        } else {
            let remainingProgress = Double(1.0 - progress)
            let remainingTime = remainingProgress / self.averageProgressPerSecond
            //print("remainingTime \(remainingTime)")
            return remainingTime
        }
    }
}

private final class ImportManager {
    enum ImportError {
        case generic
        case chatAdminRequired
        case invalidChatType
        case userBlocked
        case limitExceeded
    }
    
    enum State {
        case progress(totalBytes: Int, totalUploadedBytes: Int, totalMediaBytes: Int, totalUploadedMediaBytes: Int)
        case error(ImportError)
        case done
    }
    
    private let account: Account
    private let archivePath: String?
    private let entries: [(SSZipEntry, String, TelegramEngine.HistoryImport.MediaType)]
    
    private var session: TelegramEngine.HistoryImport.Session?
    
    private let disposable = MetaDisposable()
    
    private let totalBytes: Int
    private let totalMediaBytes: Int
    private let mainFileSize: Int
    private var pendingEntries: [(SSZipEntry, String, TelegramEngine.HistoryImport.MediaType)]
    private var entryProgress: [String: (Int, Int)] = [:]
    private var activeEntries: [String: Disposable] = [:]
    
    private var stateValue: State {
        didSet {
            self.statePromise.set(.single(self.stateValue))
        }
    }
    private let statePromise = Promise<State>()
    var state: Signal<State, NoError> {
        return self.statePromise.get()
    }
    
    init(account: Account, peerId: PeerId, mainFile: TempBoxFile, archivePath: String?, entries: [(SSZipEntry, String, TelegramEngine.HistoryImport.MediaType)]) {
        self.account = account
        self.archivePath = archivePath
        self.entries = entries
        self.pendingEntries = entries
        
        self.mainFileSize = fileSize(mainFile.path) ?? 0
        
        var totalMediaBytes = 0
        for entry in self.entries {
            self.entryProgress[entry.1] = (Int(entry.0.uncompressedSize), 0)
            totalMediaBytes += Int(entry.0.uncompressedSize)
        }
        self.totalBytes = self.mainFileSize + totalMediaBytes
        self.totalMediaBytes = totalMediaBytes
        
        self.stateValue = .progress(totalBytes: self.totalBytes, totalUploadedBytes: 0, totalMediaBytes: self.totalMediaBytes, totalUploadedMediaBytes: 0)
        
        Logger.shared.log("ChatImportScreen", "Requesting import session for \(peerId), media count: \(entries.count) with pending entries:")
        for entry in entries {
            Logger.shared.log("ChatImportScreen", "    \(entry.1)")
        }
        
        self.disposable.set((TelegramEngine(account: self.account).historyImport.initSession(peerId: peerId, file: mainFile, mediaCount: Int32(entries.count))
        |> mapError { error -> ImportError in
            switch error {
            case .chatAdminRequired:
                return .chatAdminRequired
            case .invalidChatType:
                return .invalidChatType
            case .generic:
                return .generic
            case .userBlocked:
                return .userBlocked
            case .limitExceeded:
                return .limitExceeded
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] session in
            guard let strongSelf = self else {
                return
            }
            strongSelf.session = session
            strongSelf.updateState()
        }, error: { [weak self] error in
            guard let strongSelf = self else {
                return
            }
            strongSelf.failWithError(error)
        }))
    }
    
    deinit {
        self.disposable.dispose()
        for (_, disposable) in self.activeEntries {
            disposable.dispose()
        }
    }
    
    private func updateProgress() {
        if case .error = self.stateValue {
            return
        }
        
        var totalUploadedMediaBytes = 0
        for (_, entrySizes) in self.entryProgress {
            totalUploadedMediaBytes += entrySizes.1
        }
        
        var totalUploadedBytes = totalUploadedMediaBytes
        if let _ = self.session {
            totalUploadedBytes += self.mainFileSize
        }
        
        self.stateValue = .progress(totalBytes: self.totalBytes, totalUploadedBytes: totalUploadedBytes, totalMediaBytes: self.totalMediaBytes, totalUploadedMediaBytes: totalUploadedMediaBytes)
    }
    
    private func failWithError(_ error: ImportError) {
        self.stateValue = .error(error)
        for (_, disposable) in self.activeEntries {
            disposable.dispose()
        }
    }
    
    private func complete() {
        guard let session = self.session else {
            self.failWithError(.generic)
            return
        }
        self.disposable.set((TelegramEngine(account: self.account).historyImport.startImport(session: session)
        |> deliverOnMainQueue).start(error: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.failWithError(.generic)
        }, completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.stateValue = .done
        }))
    }
    
    private func updateState() {
        guard let session = self.session else {
            Logger.shared.log("ChatImportScreen", "updateState called with no session, ignoring")
            return
        }
        if self.pendingEntries.isEmpty && self.activeEntries.isEmpty {
            Logger.shared.log("ChatImportScreen", "updateState called with no pending and no active entries, completing")
            self.complete()
            return
        }
        if case .error = self.stateValue {
            Logger.shared.log("ChatImportScreen", "updateState called after error, ignoring")
            return
        }
        guard let archivePath = self.archivePath else {
            Logger.shared.log("ChatImportScreen", "updateState called with empty arhivePath, ignoring")
            return
        }
        
        while true {
            if self.activeEntries.count >= 3 {
                Logger.shared.log("ChatImportScreen", "updateState concurrent processing limit reached, stop searching")
                break
            }
            if self.pendingEntries.isEmpty {
                Logger.shared.log("ChatImportScreen", "updateState no more pending entries, stop searching (active entries: \(self.activeEntries.keys))")
                
                if self.activeEntries.isEmpty {
                    Logger.shared.log("ChatImportScreen", "no active entries, completing")
                    self.complete()
                    return
                }
                
                break
            }
            
            let entry = self.pendingEntries.removeFirst()
            
            Logger.shared.log("ChatImportScreen", "updateState take pending entry \(entry.1)")
            
            let unpackedFile = Signal<TempBoxFile, ImportError> { subscriber in
                let tempFile = TempBox.shared.tempFile(fileName: entry.0.path)
                Logger.shared.log("ChatImportScreen", "Extracting \(entry.0.path) to \(tempFile.path)...")
                let startTime = CACurrentMediaTime()
                if SSZipArchive.extractFileFromArchive(atPath: archivePath, filePath: entry.0.path, toPath: tempFile.path) {
                    Logger.shared.log("ChatImportScreen", "[Done in \(CACurrentMediaTime() - startTime) s] Extract \(entry.0.path) to \(tempFile.path)")
                    subscriber.putNext(tempFile)
                    subscriber.putCompletion()
                } else {
                    subscriber.putError(.generic)
                }
                
                return EmptyDisposable
            }
            
            let account = self.account
            
            let uploadedEntrySignal: Signal<Float, ImportError> = unpackedFile
            |> mapToSignal { tempFile -> Signal<Float, ImportError> in
                let pathExtension = (entry.1 as NSString).pathExtension
                var mimeType = "application/octet-stream"
                if !pathExtension.isEmpty, let value = TGMimeTypeMap.mimeType(forExtension: pathExtension) {
                    mimeType = value
                }
                return TelegramEngine(account: account).historyImport.uploadMedia(session: session, file: tempFile, disposeFileAfterDone: true, fileName: entry.0.path, mimeType: mimeType, type: entry.2)
                |> mapError { error -> ImportError in
                    switch error {
                    case .chatAdminRequired:
                        return .chatAdminRequired
                    case .generic:
                        return .generic
                    }
                }
            }
            
            let disposable = MetaDisposable()
            self.activeEntries[entry.1] = disposable
            
            disposable.set((uploadedEntrySignal
            |> deliverOnMainQueue).start(next: { [weak self] progress in
                guard let strongSelf = self else {
                    return
                }
                if let (size, _) = strongSelf.entryProgress[entry.1] {
                    strongSelf.entryProgress[entry.1] = (size, Int(progress * Float(entry.0.uncompressedSize)))
                    strongSelf.updateProgress()
                }
            }, error: { [weak self] error in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.failWithError(error)
            }, completed: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                Logger.shared.log("ChatImportScreen", "updateState entry \(entry.1) has completed upload, previous active entries: \(strongSelf.activeEntries.keys)")
                strongSelf.activeEntries.removeValue(forKey: entry.1)
                Logger.shared.log("ChatImportScreen", "removed active entry \(entry.1), current active entries: \(strongSelf.activeEntries.keys)")
                strongSelf.updateState()
            }))
        }
    }
}

public final class ChatImportActivityScreen: ViewController {
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
        private var state: ImportManager.State
        
        private var videoNode: UniversalVideoNode?
        private var feedback: HapticFeedback?
        
        fileprivate var remainingAnimationSeconds: Double?
        
        init(controller: ChatImportActivityScreen, context: AccountContext, totalBytes: Int, totalMediaBytes: Int) {
            self.controller = controller
            self.context = context
            self.totalBytes = totalBytes
            self.state = .progress(totalBytes: totalBytes, totalUploadedBytes: 0, totalMediaBytes: totalMediaBytes, totalUploadedMediaBytes: 0)
            
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
            
            self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "HistoryImport"), width: 190 * 2, height: 190 * 2, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
            self.animationNode.visibility = true
            
            self.doneAnimationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "HistoryImportDone"), width: 190 * 2, height: 190 * 2, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
            self.doneAnimationNode.started = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.animationNode.isHidden = true
            }
            self.doneAnimationNode.visibility = false
            
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
            
            self.animationNode.frameUpdated = { [weak self] index, totalCount in
                guard let strongSelf = self else {
                    return
                }
                
                let remainingSeconds = Double(totalCount - index) / 60.0
                strongSelf.remainingAnimationSeconds = remainingSeconds
                strongSelf.controller?.updateProgressEstimation()
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
            
            let availableHeight = layout.size.height - navigationHeight
            
            var iconSize = CGSize(width: 190.0, height: 190.0)
            var radialStatusSize = CGSize(width: 186.0, height: 186.0)
            var maxIconStatusSpacing: CGFloat = 46.0
            var maxProgressTextSpacing: CGFloat = 33.0
            var progressStatusSpacing: CGFloat = 14.0
            var statusButtonSpacing: CGFloat = 19.0
            
            var maxK: CGFloat = availableHeight / (iconSize.height + maxIconStatusSpacing + 30.0 + maxProgressTextSpacing + 320.0)
            maxK = max(0.5, min(1.0, maxK))
            
            iconSize.width = floor(iconSize.width * maxK)
            iconSize.height = floor(iconSize.height * maxK)
            radialStatusSize.width = floor(radialStatusSize.width * maxK)
            radialStatusSize.height = floor(radialStatusSize.height * maxK)
            maxIconStatusSpacing = floor(maxIconStatusSpacing * maxK)
            maxProgressTextSpacing = floor(maxProgressTextSpacing * maxK)
            progressStatusSpacing = floor(progressStatusSpacing * maxK)
            statusButtonSpacing = floor(statusButtonSpacing * maxK)
            
            var updateRadialBackround = false
            if let width = self.radialStatusBackground.image?.size.width {
                if abs(width - radialStatusSize.width) > 0.01 {
                    updateRadialBackround = true
                }
            } else {
                updateRadialBackround = true
            }
            
            if updateRadialBackround {
                self.radialStatusBackground.image = generateCircleImage(diameter: radialStatusSize.width, lineWidth: 6.0, color: self.presentationData.theme.list.itemAccentColor.withMultipliedAlpha(0.2))
            }
            
            let effectiveProgress: CGFloat
            switch state {
            case let .progress(totalBytes, totalUploadedBytes, _, _):
                if totalBytes == 0 {
                    effectiveProgress = 1.0
                } else {
                    effectiveProgress = CGFloat(totalUploadedBytes) / CGFloat(totalBytes)
                }
            case .error:
                effectiveProgress = 0.0
            case .done:
                effectiveProgress = 1.0
            }
            
            self.radialStatusText.attributedText = NSAttributedString(string: "\(Int(effectiveProgress * 100.0))%", font: Font.with(size: floor(36.0 * maxK), design: .round, weight: .semibold), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            let radialStatusTextSize = self.radialStatusText.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
            
            self.progressText.attributedText = NSAttributedString(string: "\(dataSizeString(Int(effectiveProgress * CGFloat(self.totalBytes)), formatting: DataSizeStringFormatting(presentationData: self.presentationData))) of \(dataSizeString(Int(1.0 * CGFloat(self.totalBytes)), formatting: DataSizeStringFormatting(presentationData: self.presentationData)))", font: Font.semibold(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
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
                    errorText = self.presentationData.strings.ChatImportActivity_ErrorInvalidChatType
                case .generic:
                    errorText = self.presentationData.strings.ChatImportActivity_ErrorGeneric
                case .userBlocked:
                    errorText = self.presentationData.strings.ChatImportActivity_ErrorUserBlocked
                case .limitExceeded:
                    errorText = self.presentationData.strings.ChatImportActivity_ErrorLimitExceeded
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
                contentHeight = iconSize.height + maxIconStatusSpacing + radialStatusSize.height + maxProgressTextSpacing + progressTextSize.height + progressStatusSpacing + 140.0
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
        
        func transitionToDoneAnimation() {
            self.animationNode.stopAtNearestLoop = true
        }
        
        func updateState(state: ImportManager.State, animated: Bool) {
            var wasDone = false
            if case .done = self.state {
                wasDone = true
            }
            self.state = state
            
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                
                let effectiveProgress: CGFloat
                switch state {
                case let .progress(totalBytes, totalUploadedBytes, _, _):
                    if totalBytes == 0 {
                        effectiveProgress = 1.0
                    } else {
                        effectiveProgress = CGFloat(totalUploadedBytes) / CGFloat(totalBytes)
                    }
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
                    self.radialStatusBackground.layer.animateScale(from: 1.0, to: 1.05, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.linear.rawValue, removeOnCompletion: false, additive: false, completion: { [weak self] _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.radialStatusBackground.layer.animateScale(from: 1.05, to: 1.0, duration: 0.07, delay: 0.0, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, additive: false)
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
    private let archivePath: String?
    private let mainEntry: TempBoxFile
    private let totalBytes: Int
    private let totalMediaBytes: Int
    private let otherEntries: [(SSZipEntry, String, TelegramEngine.HistoryImport.MediaType)]
    
    private var importManager: ImportManager?
    private var progressEstimator: ProgressEstimator?
    private var totalMediaProgress: Float = 0.0
    private var beganCompletion: Bool = false
    
    private let disposable = MetaDisposable()
    private let progressDisposable = MetaDisposable()
    
    override public var _presentedInModal: Bool {
        get {
            return true
        } set(value) {
        }
    }
    
    public init(context: AccountContext, cancel: @escaping () -> Void, peerId: PeerId, archivePath: String?, mainEntry: TempBoxFile, otherEntries: [(SSZipEntry, String, TelegramEngine.HistoryImport.MediaType)]) {
        self.context = context
        self.cancel = cancel
        self.peerId = peerId
        self.archivePath = archivePath
        self.mainEntry = mainEntry
        
        self.otherEntries = otherEntries.map { entry -> (SSZipEntry, String, TelegramEngine.HistoryImport.MediaType) in
            return (entry.0, entry.1, entry.2)
        }
        
        let mainEntrySize = fileSize(self.mainEntry.path) ?? 0
        
        var totalMediaBytes = 0
        for entry in self.otherEntries {
            totalMediaBytes += Int(entry.0.uncompressedSize)
        }
        self.totalBytes = mainEntrySize + totalMediaBytes
        self.totalMediaBytes = totalMediaBytes
        
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
        self.progressDisposable.dispose()
        
        if let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication {
            application.isIdleTimerDisabled = false
        }
    }
    
    @objc private func cancelPressed() {
        self.cancel()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self, context: self.context, totalBytes: self.totalBytes, totalMediaBytes: self.totalMediaBytes)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    private func beginImport() {
        self.progressEstimator = ProgressEstimator()
        self.beganCompletion = false
        
        let resolvedPeerId: Signal<PeerId, ImportManager.ImportError>
        if self.peerId.namespace == Namespaces.Peer.CloudGroup {
            resolvedPeerId = self.context.engine.peers.convertGroupToSupergroup(peerId: self.peerId)
            |> mapError { _ -> ImportManager.ImportError in
                return .generic
            }
        } else {
            resolvedPeerId = .single(self.peerId)
        }
        
        self.disposable.set((resolvedPeerId
        |> deliverOnMainQueue).start(next: { [weak self] peerId in
            guard let strongSelf = self else {
                return
            }
            let importManager = ImportManager(account: strongSelf.context.account, peerId: peerId, mainFile: strongSelf.mainEntry, archivePath: strongSelf.archivePath, entries: strongSelf.otherEntries)
            strongSelf.importManager = importManager
            strongSelf.progressDisposable.set((importManager.state
            |> deliverOnMainQueue).start(next: { state in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.controllerNode.updateState(state: state, animated: true)
                if case let .progress(_, _, totalMediaBytes, totalUploadedMediaBytes) = state {
                    let progress = Float(totalUploadedMediaBytes) / Float(totalMediaBytes)
                    strongSelf.totalMediaProgress = progress
                }
            }))
        }, error: { [weak self] error in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateState(state: .error(error), animated: true)
        }))
    }
    
    fileprivate func updateProgressEstimation() {
        if !self.beganCompletion, let progressEstimator = self.progressEstimator, let remainingAnimationSeconds = self.controllerNode.remainingAnimationSeconds {
            if let remainingSeconds = progressEstimator.update(progress: self.totalMediaProgress) {
                //print("remainingSeconds: \(remainingSeconds)")
                //print("remainingAnimationSeconds + 1.0: \(remainingAnimationSeconds + 1.0)")
                if remainingSeconds <= remainingAnimationSeconds + 1.0 {
                    self.beganCompletion = true
                    self.controllerNode.transitionToDoneAnimation()
                }
            }
        }
    }
}
