import Foundation
import UIKit
import AVFoundation
import Display
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import BundleIconComponent
import ListSectionComponent
import ListActionItemComponent
import ListTextFieldItemComponent
import AlertComponent
import ItemListUI
import PeerInfoUI
import AvatarNode
import MapResourceToAvatarSizes
import PlainButtonComponent
import RadialStatusNode
import PeerListItemComponent
import PeerSelectionScreen
import AvatarEditorScreen
import CameraScreen
import MediaEditor
import MediaEditorScreen
import Photos

private enum CommunityAddChatsMode: Equatable {
    case allMembers
    case onlyAdmins

    init(defaultBannedRights: TelegramChatBannedRights?) {
        if defaultBannedRights?.flags.contains(.banManageLinkedPeers) == true {
            self = .onlyAdmins
        } else {
            self = .allMembers
        }
    }
}

private enum CommunityEditSaveError {
    case generic
}

private struct CommunityPendingPeerAvatar {
    let previewRepresentation: TelegramMediaImageRepresentation
    let isLoadingPreview: Bool
    let uploadedPhoto: Signal<UploadedPeerPhotoData, NoError>
    let uploadedVideo: Signal<UploadedPeerPhotoData?, NoError>?
    let videoStartTimestamp: Double?
    let markup: UploadPeerPhotoMarkup?
}

private enum CommunityCreateAvatarSetup {
    private static func makePhotoRepresentation(context: AccountContext, image: UIImage) -> (LocalFileMediaResource, TelegramMediaImageRepresentation)? {
        guard let data = image.jpegData(compressionQuality: 0.6) else {
            return nil
        }
        
        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data)
        let representation = TelegramMediaImageRepresentation(
            dimensions: PixelDimensions(width: 640, height: 640),
            resource: resource,
            progressiveSizes: [],
            immediateThumbnailData: nil,
            hasVideo: false,
            isPersonal: false
        )
        return (resource, representation)
    }
    
    static func photo(context: AccountContext, image: UIImage) -> CommunityPendingPeerAvatar? {
        guard let (resource, representation) = self.makePhotoRepresentation(context: context, image: image) else {
            return nil
        }
        
        return CommunityPendingPeerAvatar(
            previewRepresentation: representation,
            isLoadingPreview: false,
            uploadedPhoto: context.engine.peers.uploadedPeerPhoto(resource: EngineMediaResource(resource)),
            uploadedVideo: nil,
            videoStartTimestamp: nil,
            markup: nil
        )
    }
    
    static func video(
        context: AccountContext,
        image: UIImage,
        video: MediaEditorScreenImpl.MediaResult.VideoResult?,
        values: MediaEditorValues?,
        markup: UploadPeerPhotoMarkup?,
        didCompleteLoadingPreview: @escaping (CommunityPendingPeerAvatar) -> Void
    ) -> CommunityPendingPeerAvatar? {
        var shouldUploadVideo = true
        if markup != nil {
            if let data = context.currentAppConfiguration.with({ $0 }).data, let uploadVideoValue = data["upload_markup_video"] as? Bool, uploadVideoValue {
                shouldUploadVideo = true
            } else {
                shouldUploadVideo = false
            }
        }
        
        guard let (photoResource, representation) = self.makePhotoRepresentation(context: context, image: image) else {
            return nil
        }
        
        let uploadedPhoto = context.engine.peers.uploadedPeerPhoto(resource: EngineMediaResource(photoResource))
        
        var videoStartTimestamp: Double?
        if let values, let coverImageTimestamp = values.coverImageTimestamp, coverImageTimestamp > 0.0 {
            videoStartTimestamp = coverImageTimestamp - (values.videoTrimRange?.lowerBound ?? 0.0)
        }
        
        let hasVideoUpload = shouldUploadVideo && video != nil && values != nil
        guard hasVideoUpload, let video, let values else {
            return CommunityPendingPeerAvatar(
                previewRepresentation: representation,
                isLoadingPreview: false,
                uploadedPhoto: uploadedPhoto,
                uploadedVideo: nil,
                videoStartTimestamp: videoStartTimestamp,
                markup: markup
            )
        }
        
        let account = context.account
        var exportSubject: Signal<(MediaEditorVideoExport.Subject, Double), NoError>?
        switch video {
        case let .imageFile(path):
            if let image = UIImage(contentsOfFile: path) {
                exportSubject = .single((.image(image: image), 3.0))
            }
        case let .videoFile(path):
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            exportSubject = .single((.video(asset: asset, isStory: false), asset.duration.seconds))
        case let .asset(localIdentifier):
            exportSubject = Signal { subscriber in
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
                if fetchResult.count != 0 {
                    let asset = fetchResult.object(at: 0)
                    if asset.mediaType == .video {
                        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                            if let avAsset {
                                subscriber.putNext((.video(asset: avAsset, isStory: true), avAsset.duration.seconds))
                                subscriber.putCompletion()
                            }
                        }
                    } else {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                            if let image {
                                subscriber.putNext((.image(image: image), 3.0))
                                subscriber.putCompletion()
                            }
                        }
                    }
                }
                return EmptyDisposable
            }
        }
        
        guard let exportSubject else {
            return CommunityPendingPeerAvatar(
                previewRepresentation: representation,
                isLoadingPreview: false,
                uploadedPhoto: uploadedPhoto,
                uploadedVideo: nil,
                videoStartTimestamp: videoStartTimestamp,
                markup: markup
            )
        }
        
        let videoResource = exportSubject
        |> castError(UploadPeerPhotoError.self)
        |> mapToSignal { exportSubject, duration -> Signal<TelegramMediaResource?, UploadPeerPhotoError> in
            return Signal { subscriber in
                let configuration = recommendedVideoExportConfiguration(values: values, duration: duration, forceFullHd: true, frameRate: 60.0, isAvatar: true)
                let tempFile = EngineTempBox.shared.tempFile(fileName: "video.mp4")
                let videoExport = MediaEditorVideoExport(postbox: context.account.postbox, subject: exportSubject, configuration: configuration, outputPath: tempFile.path, textScale: 2.0)
                let disposable = (videoExport.status
                |> deliverOnMainQueue).startStrict(next: { status in
                    switch status {
                    case .completed:
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: tempFile.path), options: .mappedIfSafe) {
                            let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                            TelegramEngine(account: account).resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data, synchronous: true)
                            subscriber.putNext(resource)
                            subscriber.putCompletion()
                        }
                        EngineTempBox.shared.dispose(tempFile)
                    case .progress:
                        break
                    default:
                        break
                    }
                })
                return ActionDisposable {
                    disposable.dispose()
                }
            }
        }
        
        var completedAvatar: CommunityPendingPeerAvatar?
        let uploadedVideo = (videoResource
        |> `catch` { _ -> Signal<TelegramMediaResource?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { resource -> Signal<UploadedPeerPhotoData?, NoError> in
            if let resource {
                return context.engine.peers.uploadedPeerVideo(resource: EngineMediaResource(resource))
                |> map(Optional.init)
            } else {
                return .single(nil)
            }
        }
        |> afterNext { next in
            if let next, next.isCompleted, let completedAvatar {
                didCompleteLoadingPreview(completedAvatar)
            }
        })
        
        let pendingAvatar = CommunityPendingPeerAvatar(
            previewRepresentation: representation,
            isLoadingPreview: true,
            uploadedPhoto: uploadedPhoto,
            uploadedVideo: uploadedVideo,
            videoStartTimestamp: videoStartTimestamp,
            markup: markup
        )
        completedAvatar = CommunityPendingPeerAvatar(
            previewRepresentation: representation,
            isLoadingPreview: false,
            uploadedPhoto: uploadedPhoto,
            uploadedVideo: uploadedVideo,
            videoStartTimestamp: videoStartTimestamp,
            markup: markup
        )
        return pendingAvatar
    }
}

private let navigationCheckImage: UIImage = {
    return generateImage(CGSize(width: 20.0, height: 20.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.6)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: CGPoint(x: 4.0, y: 10.5))
        context.addLine(to: CGPoint(x: 8.0, y: 14.5))
        context.addLine(to: CGPoint(x: 16.5, y: 5.5))
        context.strokePath()
    })!.withRenderingMode(.alwaysTemplate)
}()

private final class CommunityAvatarComponent: Component {
    typealias EnvironmentType = Empty

    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: EnginePeer
    let isEnabled: Bool
    let uploadingImage: UIImage?
    let uploadProgress: CGFloat?
    let action: () -> Void

    init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer,
        isEnabled: Bool,
        uploadingImage: UIImage?,
        uploadProgress: CGFloat?,
        action: @escaping () -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.isEnabled = isEnabled
        self.uploadingImage = uploadingImage
        self.uploadProgress = uploadProgress
        self.action = action
    }

    static func ==(lhs: CommunityAvatarComponent, rhs: CommunityAvatarComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.isEnabled != rhs.isEnabled {
            return false
        }
        if lhs.uploadingImage !== rhs.uploadingImage {
            return false
        }
        if lhs.uploadProgress != rhs.uploadProgress {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatarShadow = UIImageView()
        private let avatarNode: AvatarNode
        private let uploadingImageView = UIImageView()
        private let uploadingOverlayView = UIView()
        private let statusNode: RadialStatusNode
        private let button = HighlightTrackingButton()
        private let actionButton = ComponentView<Empty>()

        private var component: CommunityAvatarComponent?

        override init(frame: CGRect) {
            self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: floor(100.0 * 16.0 / 37.0)))
            self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(rgb: 0x000000, alpha: 0.6))

            super.init(frame: frame)

            self.avatarShadow.image = UIImage(bundleImageName: "Components/CommunityShadow")
            self.uploadingImageView.contentMode = .scaleAspectFill
            self.uploadingImageView.clipsToBounds = true
            self.uploadingImageView.isUserInteractionEnabled = false
            self.uploadingImageView.isHidden = true
            self.uploadingOverlayView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
            self.uploadingOverlayView.isUserInteractionEnabled = false
            self.uploadingOverlayView.isHidden = true
            self.statusNode.isUserInteractionEnabled = false
            self.addSubview(self.avatarShadow)
            self.addSubnode(self.avatarNode)
            self.addSubview(self.uploadingImageView)
            self.addSubview(self.uploadingOverlayView)
            self.addSubnode(self.statusNode)
            self.addSubview(self.button)

            self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func pressed() {
            guard self.component?.isEnabled == true else {
                return
            }
            self.component?.action()
        }

        func transitionView() -> UIView {
            if self.component?.uploadingImage != nil {
                return self.uploadingImageView
            } else {
                return self.avatarNode.view
            }
        }

        func update(component: CommunityAvatarComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component

            let avatarSize = CGSize(width: 100.0, height: 100.0)
            let avatarFrame = CGRect(
                origin: CGPoint(
                    x: floorToScreenPixels((availableSize.width - avatarSize.width) / 2.0),
                    y: 0.0
                ),
                size: avatarSize
            )

            let hasAvatar = !component.peer.profileImageRepresentations.isEmpty || component.uploadingImage != nil
            let overrideImage: AvatarNodeImageOverride?
            if !hasAvatar {
                overrideImage = .editAvatarIcon(forceNone: true)
            } else {
                overrideImage = nil
            }

            self.avatarNode.font = avatarPlaceholderFont(size: floor(avatarSize.width * 16.0 / 37.0))
            self.avatarNode.setPeer(
                context: component.context,
                theme: component.theme,
                peer: component.peer,
                overrideImage: overrideImage,
                clipStyle: .roundedRect,
                synchronousLoad: false,
                displayDimensions: avatarSize
            )

            self.avatarNode.frame = avatarFrame
            self.uploadingImageView.layer.cornerRadius = floor(avatarSize.width * 0.25)
            self.uploadingOverlayView.layer.cornerRadius = floor(avatarSize.width * 0.25)
            self.button.frame = avatarFrame.insetBy(dx: -8.0, dy: -8.0)
            self.button.isUserInteractionEnabled = component.isEnabled

            if let uploadingImage = component.uploadingImage {
                self.uploadingImageView.isHidden = false
                self.uploadingOverlayView.isHidden = false
                self.uploadingImageView.image = uploadingImage
                self.uploadingImageView.frame = avatarFrame
                self.uploadingOverlayView.frame = avatarFrame

                let statusSize = CGSize(width: 50.0, height: 50.0)
                self.statusNode.frame = CGRect(
                    origin: CGPoint(
                        x: floorToScreenPixels(avatarFrame.midX - statusSize.width * 0.5),
                        y: floorToScreenPixels(avatarFrame.midY - statusSize.height * 0.5)
                    ),
                    size: statusSize
                )
                self.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: component.uploadProgress, cancelEnabled: false, animateRotation: true))
            } else {
                self.uploadingImageView.isHidden = true
                self.uploadingImageView.image = nil
                self.uploadingOverlayView.isHidden = true
                self.statusNode.transitionToState(.none)
            }

            let actionButtonText = hasAvatar ? component.strings.Settings_ChangePhoto : component.strings.Settings_SetPhoto
            let actionButtonSize = self.actionButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(Text(
                        text: actionButtonText,
                        font: Font.regular(17.0),
                        color: component.theme.list.itemAccentColor
                    )),
                    contentInsets: UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0),
                    action: { [weak self] in
                        guard self?.component?.isEnabled == true else {
                            return
                        }
                        self?.component?.action()
                    },
                    isEnabled: component.isEnabled,
                    animateScale: false,
                    animateContents: false
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: 44.0)
            )
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                let actionButtonFrame = CGRect(
                    origin: CGPoint(
                        x: floorToScreenPixels((availableSize.width - actionButtonSize.width) / 2.0),
                        y: avatarFrame.maxY + 30.0
                    ),
                    size: actionButtonSize
                )
                actionButtonView.frame = actionButtonFrame
            }

            if hasAvatar, let shadowImage = self.avatarShadow.image {
                self.avatarShadow.isHidden = false
                self.avatarShadow.tintColor = component.theme.list.freeTextColor

                let aspectRatio = shadowImage.size.width / shadowImage.size.height
                let shadowSize = CGSize(width: avatarSize.width * aspectRatio, height: avatarSize.height)
                let shadowFrame = shadowSize.centered(around: avatarFrame.center).offsetBy(dx: -13.0, dy: 0.0)
                self.avatarShadow.frame = shadowFrame
            } else {
                self.avatarShadow.isHidden = true
            }

            return CGSize(width: availableSize.width, height: avatarSize.height + 30.0 + actionButtonSize.height + 12.0)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class ItemAccessoryComponent: Component {
    enum CountStyle: Equatable {
        case plain
        case badge
    }

    let count: Int32?
    let countStyle: CountStyle
    let theme: PresentationTheme

    init(count: Int32?, countStyle: CountStyle, theme: PresentationTheme) {
        self.count = count
        self.countStyle = countStyle
        self.theme = theme
    }

    static func ==(lhs: ItemAccessoryComponent, rhs: ItemAccessoryComponent) -> Bool {
        if lhs.count != rhs.count {
            return false
        }
        if lhs.countStyle != rhs.countStyle {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }

    final class View: UIView {
        private let text = ComponentView<Empty>()
        private let badgeBackgroundView = UIView()
        private let chevronView = UIImageView()
        private var component: ItemAccessoryComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.badgeBackgroundView)
            self.addSubview(self.chevronView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: ItemAccessoryComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component

            if themeUpdated || self.chevronView.image == nil {
                self.chevronView.image = PresentationResourcesItemList.disclosureArrowImage(component.theme)
            }

            let countValue = component.count.flatMap { $0 > 0 ? Int($0) : nil }
            var textSize = CGSize()
            if let countValue {
                let textColor: UIColor
                let font: UIFont
                let backgroundColor: UIColor?
                let textConstrainedSize: CGSize
                switch component.countStyle {
                case .plain:
                    textColor = component.theme.list.itemSecondaryTextColor
                    font = Font.regular(17.0)
                    backgroundColor = nil
                    textConstrainedSize = CGSize(width: 80.0, height: 30.0)
                case .badge:
                    textColor = component.theme.list.itemCheckColors.foregroundColor
                    font = Font.medium(12.0)
                    backgroundColor = component.theme.list.itemCheckColors.fillColor
                    textConstrainedSize = CGSize(width: 80.0, height: 20.0)
                }

                let measuredSize = self.text.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "\(countValue)", font: font, textColor: textColor)),
                        horizontalAlignment: .center,
                        verticalAlignment: .middle
                    )),
                    environment: {},
                    containerSize: textConstrainedSize
                )
                textSize = measuredSize

                if let textView = self.text.view {
                    if textView.superview == nil {
                        self.insertSubview(textView, aboveSubview: self.badgeBackgroundView)
                    }
                    textView.isHidden = false
                    textView.backgroundColor = nil
                    textView.layer.cornerRadius = 0.0
                    textView.clipsToBounds = false
                }
                if let backgroundColor {
                    self.badgeBackgroundView.isHidden = false
                    self.badgeBackgroundView.backgroundColor = backgroundColor
                    self.badgeBackgroundView.layer.cornerRadius = 10.0
                    self.badgeBackgroundView.clipsToBounds = true
                } else {
                    self.badgeBackgroundView.isHidden = true
                }
            } else {
                self.text.view?.isHidden = true
                self.badgeBackgroundView.isHidden = true
            }

            let chevronSize = self.chevronView.image?.size ?? CGSize(width: 8.0, height: 13.0)
            let spacing: CGFloat = countValue == nil ? 0.0 : 4.0
            let size = CGSize(width: textSize.width + spacing + chevronSize.width - 9.0, height: max(20.0, chevronSize.height))

            var currentX: CGFloat = 0.0
            if countValue != nil {
                let badgeBackgroundSize = CGSize(width: max(20.0, textSize.width), height: 20.0)
                transition.setFrame(view: self.badgeBackgroundView, frame: CGRect(origin: CGPoint(x: currentX + textSize.width * 0.5 - badgeBackgroundSize.width * 0.5, y: floor((size.height - badgeBackgroundSize.height) * 0.5)), size: badgeBackgroundSize))
                if let textView = self.text.view {
                    transition.setFrame(view: textView, frame: CGRect(origin: CGPoint(x: currentX, y: floor((size.height - textSize.height) * 0.5)), size: textSize))
                }
                currentX += textSize.width + spacing
            }
            transition.setFrame(view: self.chevronView, frame: CGRect(origin: CGPoint(x: currentX, y: floor((size.height - chevronSize.height) * 0.5)), size: chevronSize))

            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class CommunityEditScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: CommunityEditScreenMode
    let completed: () -> Void

    init(context: AccountContext, mode: CommunityEditScreenMode, completed: @escaping () -> Void) {
        self.context = context
        self.mode = mode
        self.completed = completed
    }

    static func ==(lhs: CommunityEditScreenComponent, rhs: CommunityEditScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }

    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private struct DraftLinkedPeer: Equatable {
        let peerId: EnginePeer.Id
        var visible: Bool
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView

        private let avatarHeader = ComponentView<Empty>()
        private let titleSection = ComponentView<Empty>()
        private let permissionsSection = ComponentView<Empty>()
        private let managementSection = ComponentView<Empty>()
        private let chatsSection = ComponentView<Empty>()
        private let deleteSection = ComponentView<Empty>()

        private var component: CommunityEditScreenComponent?
        private(set) weak var state: EmptyComponentState?
        private var environment: EnvironmentType?

        private var isUpdating = false
        private var ignoreScrolling = false

        private let titleFieldTag = NSObject()
        private var resetTitleText: String?
        private var didFocusTitleField = false

        private var community: TelegramCommunity?
        private var cachedData: CachedCommunityData?
        private var linkedPeers: [EnginePeer.Id: EnginePeer] = [:]
        private var linkedPeerCachedData: [EnginePeer.Id: EngineCachedPeerData] = [:]
        private var currentLinkedPeerIds: [EnginePeer.Id] = []
        private var draftLinkedPeers: [DraftLinkedPeer] = []
        private var createdCommunityId: EnginePeer.Id?
        private var createdCommunityTitle: String?
        private var currentTitle = ""
        private var initialTitle = ""
        private var selectedMode: CommunityAddChatsMode = .allMembers
        private var initialMode: CommunityAddChatsMode = .allMembers
        private var didInitializeState = false
        private var isSaving = false
        private var isDeleting = false
        private var isAddActionInProgress = false
        private var isUpdatingAvatar = false
        private var uploadingAvatarImage: UIImage?
        private var avatarUploadProgress: CGFloat?
        private var pendingAvatar: CommunityPendingPeerAvatar?
        private var avatarPickerHolder: Any?

        private var dataDisposable: Disposable?
        private let linkedPeersDisposable = MetaDisposable()
        private let linkedPeerDataDisposable = MetaDisposable()
        private let addChatDisposable = MetaDisposable()
        private let saveDisposable = MetaDisposable()
        private let deleteDisposable = MetaDisposable()
        private let avatarDisposable = MetaDisposable()
        private let avatarUploadStatusDisposable = MetaDisposable()

        private let cachedAdminsIcon = renderSettingsIcon(name: "Item List/Icons/Admin", backgroundColors: [UIColor(rgb: 0x34C759)])
        private let cachedRequestsIcon = renderSettingsIcon(name: "Item List/Icons/Requests", backgroundColors: [UIColor(rgb: 0x0079ff)])
        private let cachedBannedIcon = renderSettingsIcon(name: "Item List/Icons/Block", backgroundColors: [UIColor(rgb: 0xFF453A)])

        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true

            super.init(frame: frame)

            self.scrollView.delegate = self
            self.addSubview(self.scrollView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.dataDisposable?.dispose()
            self.linkedPeersDisposable.dispose()
            self.linkedPeerDataDisposable.dispose()
            self.addChatDisposable.dispose()
            self.saveDisposable.dispose()
            self.deleteDisposable.dispose()
            self.avatarDisposable.dispose()
            self.avatarUploadStatusDisposable.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            self.endEditing(true)
        }

        private func updateScrolling(transition: ComponentTransition) {
            guard let environment = self.environment, let controller = environment.controller(), let navigationBar = controller.navigationBar else {
                return
            }
            let alphaDistance: CGFloat = 16.0
            let edgeEffectAlpha = max(0.0, min(1.0, self.scrollView.contentOffset.y / alphaDistance))
            navigationBar.setBackdropAlpha(edgeEffectAlpha, transition: transition.containedViewLayoutTransition)
        }
        
        private var editCommunityId: EnginePeer.Id? {
            guard let component = self.component else {
                return nil
            }
            if case let .edit(communityId) = component.mode {
                return communityId
            } else {
                return nil
            }
        }
        
        private var createSourcePeerId: EnginePeer.Id? {
            guard let component = self.component else {
                return nil
            }
            if case let .create(peerId) = component.mode {
                return peerId
            } else {
                return nil
            }
        }
        
        private var isCreateMode: Bool {
            return self.createSourcePeerId != nil
        }

        private var trimmedTitle: String {
            return self.currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private var hasChanges: Bool {
            if self.trimmedTitle != self.initialTitle {
                return true
            }
            if self.selectedMode != self.initialMode {
                return true
            }
            return false
        }

        private func ensureDataSignal(component: CommunityEditScreenComponent) {
            if case let .create(peerId) = component.mode {
                if !self.didInitializeState {
                    self.didInitializeState = true
                    self.currentTitle = ""
                    self.initialTitle = ""
                    self.selectedMode = .allMembers
                    self.initialMode = .allMembers
                    self.draftLinkedPeers = [DraftLinkedPeer(peerId: peerId, visible: true)]
                    self.updateLinkedPeerSignals(component: component, ids: [peerId])
                }
                return
            }
            
            if self.dataDisposable != nil {
                return
            }
            guard case let .edit(communityId) = component.mode else {
                return
            }
            component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: communityId)
            self.dataDisposable = (combineLatest(
                component.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: communityId)),
                component.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.CachedData(id: communityId))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] peer, cachedData in
                guard let self else {
                    return
                }

                let community: TelegramCommunity?
                if let peer {
                    switch peer {
                    case let .community(value):
                        community = value
                    default:
                        community = nil
                    }
                } else {
                    community = nil
                }
                self.community = community
                self.cachedData = cachedData as? CachedCommunityData
                let linkedPeerIds = self.cachedData?.linkedPeers.map(\.peerId) ?? []
                self.updateLinkedPeerSignals(component: component, ids: linkedPeerIds)

                if let community {
                    let mode = CommunityAddChatsMode(defaultBannedRights: community.defaultBannedRights)
                    if !self.didInitializeState || (!self.hasChanges && !self.isSaving) {
                        self.didInitializeState = true
                        self.initialTitle = community.title
                        self.currentTitle = community.title
                        self.initialMode = mode
                        self.selectedMode = mode
                        self.resetTitleText = community.title
                    }
                }

                self.state?.updated(transition: .spring(duration: 0.35))
            })
        }

        private func updateLinkedPeerSignals(component: CommunityEditScreenComponent, ids: [EnginePeer.Id]) {
            if self.currentLinkedPeerIds == ids {
                return
            }
            self.currentLinkedPeerIds = ids

            if ids.isEmpty {
                self.linkedPeers = [:]
                self.linkedPeerCachedData = [:]
                self.linkedPeersDisposable.set(nil)
                self.linkedPeerDataDisposable.set(nil)
                self.state?.updated(transition: .immediate)
                return
            }

            self.linkedPeersDisposable.set((component.context.engine.data.subscribe(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] peersById in
                guard let self else {
                    return
                }
                var peers: [EnginePeer.Id: EnginePeer] = [:]
                for id in ids {
                    if let maybePeer = peersById[id], let peer = maybePeer {
                        peers[id] = peer
                    }
                }
                self.linkedPeers = peers
                self.state?.updated(transition: .spring(duration: 0.35))
            }))

            self.linkedPeerDataDisposable.set((component.context.engine.data.subscribe(
                EngineDataMap(ids.map(TelegramEngine.EngineData.Item.Peer.CachedData.init(id:)))
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] cachedDataById in
                guard let self else {
                    return
                }
                var cachedPeerData: [EnginePeer.Id: EngineCachedPeerData] = [:]
                for id in ids {
                    if let maybeCachedData = cachedDataById[id], let cachedData = maybeCachedData {
                        cachedPeerData[id] = cachedData
                    }
                }
                self.linkedPeerCachedData = cachedPeerData
                self.state?.updated(transition: .spring(duration: 0.35))
            }))
        }

        private func dismissController() {
            self.environment?.controller()?.dismiss()
        }

        private func presentError() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            environment.controller()?.present(AlertScreen(
                context: component.context,
                title: nil,
                text: environment.strings.Login_UnknownError,
                actions: [
                    AlertScreen.Action(title: environment.strings.Common_OK, type: .default)
                ]
            ), in: .window(.root))
        }

        private func openAvatarSetup() {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            if self.isSaving || self.isDeleting || self.isUpdatingAvatar {
                return
            }
            
            if self.isCreateMode {
                self.openCreateAvatarSetup(component: component)
                return
            }
            
            guard let community = self.community else {
                return
            }

            let peer = EnginePeer(community)
            component.context.sharedContext.displaySetPhoto(
                parentController: controller,
                context: component.context,
                peer: peer,
                canDelete: !peer.profileImageRepresentations.isEmpty,
                performDelete: { [weak self] in
                    self?.confirmRemoveAvatar()
                },
                completion: { _ in },
                completedWithUploadingImage: { [weak self] image, uploadStatus in
                    guard let self else {
                        return nil
                    }
                    self.isUpdatingAvatar = true
                    self.uploadingAvatarImage = image
                    self.avatarUploadProgress = 0.027
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                    self.avatarUploadStatusDisposable.set((uploadStatus
                    |> deliverOnMainQueue).startStrict(next: { [weak self] status in
                        guard let self else {
                            return
                        }
                        switch status {
                        case let .progress(value):
                            self.avatarUploadProgress = max(0.027, CGFloat(value))
                            if !self.isUpdatingAvatar {
                                self.isUpdatingAvatar = true
                            }
                            self.state?.updated(transition: .easeInOut(duration: 0.2))
                        case .done:
                            self.isUpdatingAvatar = false
                            self.uploadingAvatarImage = nil
                            self.avatarUploadProgress = nil
                            self.state?.updated(transition: .easeInOut(duration: 0.2))
                        }
                    }, completed: { [weak self] in
                        guard let self, self.isUpdatingAvatar else {
                            return
                        }
                        self.isUpdatingAvatar = false
                        self.uploadingAvatarImage = nil
                        self.avatarUploadProgress = nil
                        self.state?.updated(transition: .easeInOut(duration: 0.2))
                    }))
                    return (self.avatarHeader.view as? CommunityAvatarComponent.View)?.transitionView()
                }
            )
        }
        
        private func applyPendingAvatar(_ avatar: CommunityPendingPeerAvatar) {
            self.pendingAvatar = avatar
            self.state?.updated(transition: .easeInOut(duration: 0.2))
        }
        
        private func updatePendingAvatarIfCurrent(_ avatar: CommunityPendingPeerAvatar) {
            if self.pendingAvatar?.previewRepresentation.resource.id == avatar.previewRepresentation.resource.id {
                self.applyPendingAvatar(avatar)
            }
        }
        
        private func clearPendingAvatar() {
            self.pendingAvatar = nil
            self.state?.updated(transition: .easeInOut(duration: 0.2))
        }
        
        private func openCreateAvatarSetup(component: CommunityEditScreenComponent) {
            self.endEditing(true)
            
            let keyboardInputData = Promise<AvatarKeyboardInputData>()
            keyboardInputData.set(AvatarEditorScreen.inputData(context: component.context, isGroup: true))
            
            var dismissPickerImpl: (() -> Void)?
            let (mainController, pickerHolder) = component.context.sharedContext.makeAvatarMediaPickerScreen(
                context: component.context,
                peerType: .community,
                getSourceRect: { return nil },
                canDelete: self.pendingAvatar != nil,
                performDelete: { [weak self] in
                    self?.clearPendingAvatar()
                },
                completion: { [weak self] result, transitionView, transitionRect, transitionImage, fromCamera, _, cancelled in
                    guard let self, let component = self.component else {
                        return
                    }
                    self.avatarPickerHolder = nil
                    
                    let applyPhoto: (UIImage) -> Void = { [weak self] image in
                        guard let self else {
                            return
                        }
                        if let avatar = CommunityCreateAvatarSetup.photo(context: component.context, image: image) {
                            self.applyPendingAvatar(avatar)
                        }
                    }
                    let applyVideo: (UIImage, MediaEditorScreenImpl.MediaResult.VideoResult?, MediaEditorValues?, UploadPeerPhotoMarkup?) -> Void = { [weak self] image, video, values, markup in
                        guard let self else {
                            return
                        }
                        if let avatar = CommunityCreateAvatarSetup.video(context: component.context, image: image, video: video, values: values, markup: markup, didCompleteLoadingPreview: { [weak self] avatar in
                            self?.updatePendingAvatarIfCurrent(avatar)
                        }) {
                            self.applyPendingAvatar(avatar)
                        }
                    }
                    
                    let subject: Signal<MediaEditorScreenImpl.Subject?, NoError>
                    if let asset = result as? PHAsset {
                        subject = .single(.asset(asset))
                    } else if let image = result as? UIImage {
                        subject = .single(.image(image: image, dimensions: PixelDimensions(image.size), additionalImage: nil, additionalImagePosition: .bottomRight, fromCamera: false))
                    } else if let result = result as? Signal<CameraScreenImpl.Result, NoError> {
                        subject = result
                        |> map { value -> MediaEditorScreenImpl.Subject? in
                            switch value {
                            case .pendingImage:
                                return nil
                            case let .image(image):
                                return .image(image: image.image, dimensions: PixelDimensions(image.image.size), additionalImage: nil, additionalImagePosition: .topLeft, fromCamera: false)
                            case let .video(video):
                                return .video(videoPath: video.videoPath, thumbnail: video.coverImage, mirror: video.mirror, additionalVideoPath: nil, additionalThumbnail: nil, dimensions: video.dimensions, duration: video.duration, videoPositionChanges: [], additionalVideoPosition: .topLeft, fromCamera: false)
                            default:
                                return nil
                            }
                        }
                    } else {
                        let controller = AvatarEditorScreen(context: component.context, inputData: keyboardInputData.get(), peerType: .community, markup: nil)
                        controller.imageCompletion = { image, commit in
                            applyPhoto(image)
                            commit()
                        }
                        controller.videoCompletion = { image, _, _, markup, commit in
                            applyVideo(image, nil, nil, markup)
                            commit()
                        }
                        self.pushController(controller)
                        return
                    }
                    
                    let editorController = MediaEditorScreenImpl(
                        context: component.context,
                        mode: .avatarEditor(clipStyle: .roundedRect),
                        subject: subject,
                        transitionIn: fromCamera ? .camera : transitionView.flatMap({ .gallery(
                            MediaEditorScreenImpl.TransitionIn.GalleryTransitionIn(
                                sourceView: $0,
                                sourceRect: transitionRect,
                                sourceImage: transitionImage
                            )
                        ) }),
                        transitionOut: { finished, _ in
                            if !finished, let transitionView {
                                return MediaEditorScreenImpl.TransitionOut(
                                    destinationView: transitionView,
                                    destinationRect: transitionView.bounds,
                                    destinationCornerRadius: 0.0
                                )
                            }
                            return nil
                        },
                        completion: { results, commit in
                            guard let result = results.first else {
                                return
                            }
                            switch result.media {
                            case let .image(image, _):
                                applyPhoto(image)
                                commit({})
                            case let .video(video, coverImage, values, _, _):
                                if let coverImage {
                                    applyVideo(coverImage, video, values, nil)
                                }
                                commit({})
                            default:
                                break
                            }
                            dismissPickerImpl?()
                        } as ([MediaEditorScreenImpl.Result], @escaping (@escaping () -> Void) -> Void) -> Void
                    )
                    editorController.cancelled = { _ in
                        cancelled()
                    }
                    self.pushController(editorController)
                },
                dismissed: { [weak self] in
                    self?.avatarPickerHolder = nil
                }
            )
            self.avatarPickerHolder = pickerHolder
            if let mainController {
                dismissPickerImpl = { [weak mainController] in
                    if let mainController, let navigationController = mainController.navigationController {
                        var viewControllers = navigationController.viewControllers
                        viewControllers = viewControllers.filter { controller in
                            return !(controller is CameraScreen) && controller !== mainController
                        }
                        navigationController.setViewControllers(viewControllers, animated: false)
                    }
                }
                if mainController is ActionSheetController {
                    self.environment?.controller()?.present(mainController, in: .window(.root))
                } else {
                    mainController.navigationPresentation = .flatModal
                    mainController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
                    self.pushController(mainController)
                }
            }
        }

        private func confirmRemoveAvatar() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            if self.isSaving || self.isDeleting || self.isUpdatingAvatar {
                return
            }

            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Settings_RemoveConfirmation, color: .destructive, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        self?.removeAvatar()
                    })
                ]),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: environment.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            environment.controller()?.present(actionSheet, in: .window(.root))
        }

        private func removeAvatar() {
            guard let component = self.component, let communityId = self.editCommunityId else {
                return
            }
            if self.isSaving || self.isDeleting || self.isUpdatingAvatar {
                return
            }

            self.isUpdatingAvatar = true
            self.uploadingAvatarImage = nil
            self.avatarUploadProgress = nil
            self.state?.updated(transition: .easeInOut(duration: 0.2))

            let signal = component.context.engine.peers.updatePeerPhoto(peerId: communityId, photo: nil, mapResourceToAvatarSizes: { resource, representations in
                return mapResourceToAvatarSizes(engine: component.context.engine, resource: resource, representations: representations)
            })
            |> mapError { _ -> CommunityEditSaveError in
                return .generic
            }

            self.avatarDisposable.set((signal
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                switch result {
                case .complete:
                    self.isUpdatingAvatar = false
                    self.uploadingAvatarImage = nil
                    self.avatarUploadProgress = nil
                    self.state?.updated(transition: .easeInOut(duration: 0.2))
                case .progress:
                    break
                }
            }, error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.isUpdatingAvatar = false
                self.uploadingAvatarImage = nil
                self.avatarUploadProgress = nil
                self.state?.updated(transition: .easeInOut(duration: 0.2))
                self.presentError()
            }, completed: { [weak self] in
                guard let self, self.isUpdatingAvatar else {
                    return
                }
                self.isUpdatingAvatar = false
                self.uploadingAvatarImage = nil
                self.avatarUploadProgress = nil
                self.state?.updated(transition: .easeInOut(duration: 0.2))
            }))
        }

        private func confirmDeleteCommunity() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            if self.isSaving || self.isDeleting {
                return
            }
            environment.controller()?.present(AlertScreen(
                context: component.context,
                title: environment.strings.Community_Edit_DeleteCommunity,
                text: environment.strings.Community_Edit_DeleteConfirmationText,
                actions: [
                    AlertScreen.Action(title: environment.strings.Common_Cancel, type: .generic),
                    AlertScreen.Action(title: environment.strings.Common_Delete, type: .defaultDestructive, action: { [weak self] in
                        self?.deleteCommunity()
                    })
                ]
            ), in: .window(.root))
        }

        private func deleteCommunity() {
            guard let component = self.component, let communityId = self.editCommunityId else {
                return
            }
            if self.isSaving || self.isDeleting {
                return
            }

            self.isDeleting = true
            self.state?.updated(transition: .easeInOut(duration: 0.2))

            let signal = component.context.engine.peers.deleteChannel(peerId: communityId)
            |> mapError { _ -> CommunityEditSaveError in
                return .generic
            }
            |> ignoreValues
            |> then(
                component.context.engine.peers.joinedCommunities()
                |> castError(CommunityEditSaveError.self)
                |> ignoreValues
            )

            self.deleteDisposable.set((signal
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.isDeleting = false
                self.state?.updated(transition: .easeInOut(duration: 0.2))
                self.presentError()
            }, completed: { [weak self] in
                guard let self else {
                    return
                }
                self.isDeleting = false
                
                if let navigationController = self.environment?.controller()?.navigationController {
                    var viewControllers = navigationController.viewControllers
                    viewControllers = viewControllers.filter { c in
                        if c is CommunityViewScreen {
                            return false
                        } else {
                            return true
                        }
                    }
                    navigationController.setViewControllers(viewControllers, animated: false)
                }
                
                self.dismissController()
            }))
        }

        private func pushController(_ controller: ViewController) {
            guard let environment = self.environment else {
                return
            }
            if let navigationController = environment.controller()?.navigationController as? NavigationController {
                navigationController.pushViewController(controller)
            } else {
                environment.controller()?.present(controller, in: .window(.root))
            }
        }

        private func openAdministrators() {
            guard let component = self.component, let communityId = self.editCommunityId else {
                return
            }
            let controller = channelAdminsController(
                context: component.context,
                updatedPresentationData: nil,
                peerId: communityId
            )
            self.pushController(controller)
        }

        private func openRemovedUsers() {
            guard let component = self.component, let communityId = self.editCommunityId else {
                return
            }
            let controller = channelBlacklistController(
                context: component.context,
                updatedPresentationData: nil,
                peerId: communityId
            )
            self.pushController(controller)
        }

        private func openPendingRequests() {
            guard let component = self.component, let communityId = self.editCommunityId else {
                return
            }
            let controller = component.context.sharedContext.makeCommunityRequestsScreen(context: component.context, communityId: communityId, existingContext: nil)
            self.pushController(controller)
        }

        private func openPeer(_ peer: EnginePeer) {
            guard let component = self.component, let environment = self.environment, let navigationController = environment.controller()?.navigationController as? NavigationController else {
                return
            }
            component.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(
                navigationController: navigationController,
                context: component.context,
                chatLocation: .peer(peer),
                keepStack: .always,
                forceOpenChat: true
            ))
        }
        
        private func openDraftPeerVisibility(peer: EnginePeer) {
            guard let component = self.component, self.isCreateMode else {
                return
            }
            if self.isSaving || self.isDeleting {
                return
            }
            let initialVisibility = self.draftLinkedPeers.first(where: { $0.peerId == peer.id })?.visible ?? true
            let controller = component.context.sharedContext.makeCommunityAddScreen(
                context: component.context,
                peerId: peer.id,
                initialVisibility: initialVisibility,
                completed: { [weak self] isVisible in
                    guard let self else {
                        return
                    }
                    if let index = self.draftLinkedPeers.firstIndex(where: { $0.peerId == peer.id }) {
                        self.draftLinkedPeers[index].visible = isVisible
                    }
                    self.state?.updated(transition: .spring(duration: 0.35))
                }
            )
            self.environment?.controller()?.present(controller, in: .window(.root))
        }

        private func openAddChat() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            if self.isSaving || self.isDeleting || self.isAddActionInProgress {
                return
            }

            let communitiesConfiguration = CommunitiesConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            let linkedPeersCount: Int32
            let excludedPeerIds: Set<EnginePeer.Id>
            if self.isCreateMode {
                linkedPeersCount = Int32(self.draftLinkedPeers.count)
                excludedPeerIds = Set(self.draftLinkedPeers.map(\.peerId))
            } else {
                linkedPeersCount = Int32(self.cachedData?.linkedPeers.count ?? 0)
                excludedPeerIds = Set((self.cachedData?.linkedPeers ?? []).map(\.peerId))
            }
            if linkedPeersCount >= communitiesConfiguration.peersLimit {
                environment.controller()?.present(AlertScreen(
                    context: component.context,
                    title: nil,
                    text: environment.strings.Community_Edit_ChatsLimitReached,
                    actions: [
                        AlertScreen.Action(title: environment.strings.Common_OK, type: .default)
                    ]
                ), in: .window(.root))
                return
            }

            self.isAddActionInProgress = true
            self.state?.updated(transition: .spring(duration: 0.35))

            self.addChatDisposable.set((component.context.engine.peers.adminedPublicChannels(scope: .forCommunity)
            |> take(1)
            |> deliverOnMainQueue).startStrict(next: { [weak self] channels in
                guard let self else {
                    return
                }
                self.isAddActionInProgress = false
                self.addChatDisposable.set(nil)
                self.state?.updated(transition: .spring(duration: 0.35))

                guard let component = self.component, let environment = self.environment else {
                    return
                }

                let channels = channels.filter { channel in
                    !excludedPeerIds.contains(channel.peer.id)
                }
                let selectionController = PeerSelectionScreen(
                    context: component.context,
                    initialData: PeerSelectionScreen.communityInitialData(channels: channels),
                    updatedPresentationData: nil,
                    completion: { [weak self] channel in
                        guard let self, let component = self.component, let channel else {
                            return
                        }
                        let controller: ViewController
                        if self.isCreateMode {
                            controller = component.context.sharedContext.makeCommunityAddScreen(
                                context: component.context,
                                peerId: channel.peer.id,
                                initialVisibility: true,
                                completed: { [weak self] isVisible in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    if let index = self.draftLinkedPeers.firstIndex(where: { $0.peerId == channel.peer.id }) {
                                        self.draftLinkedPeers[index].visible = isVisible
                                    } else {
                                        self.draftLinkedPeers.append(DraftLinkedPeer(peerId: channel.peer.id, visible: isVisible))
                                    }
                                    self.updateLinkedPeerSignals(component: component, ids: self.draftLinkedPeers.map(\.peerId))
                                    self.state?.updated(transition: .spring(duration: 0.35))
                                }
                            )
                        } else {
                            guard let communityId = self.editCommunityId else {
                                return
                            }
                            controller = component.context.sharedContext.makeCommunityAddScreen(
                                context: component.context,
                                communityId: communityId,
                                peerId: channel.peer.id,
                                completed: { [weak self] immediate in
                                    guard let self, let component = self.component, let communityId = self.editCommunityId else {
                                        return
                                    }
                                    component.context.account.viewTracker.forceUpdateCachedPeerData(peerId: communityId)
                                    self.state?.updated(transition: .spring(duration: 0.35))
                                }
                            )
                        }
                        self.environment?.controller()?.present(controller, in: .window(.root))
                    }
                )
                selectionController.navigationPresentation = .modal
                environment.controller()?.push(selectionController)
            }))
        }

        private func rightsWithUpdatedMode(_ mode: CommunityAddChatsMode, current: TelegramChatBannedRights?) -> TelegramChatBannedRights {
            var flags = current?.flags ?? TelegramChatBannedRightsFlags()
            switch mode {
            case .allMembers:
                flags.remove(.banManageLinkedPeers)
            case .onlyAdmins:
                flags.insert(.banManageLinkedPeers)
            }
            return TelegramChatBannedRights(flags: flags, untilDate: current?.untilDate ?? Int32.max)
        }
        
        private func animateTitleError() {
            if let view = self.titleSection.findTaggedView(tag: self.titleFieldTag) as? ListTextFieldItemComponent.View {
                view.animateError()
                view.activateInput()
            }
        }
        
        private func saveCreateCommunity(component: CommunityEditScreenComponent, sourcePeerId: EnginePeer.Id) {
            if self.isSaving || self.isDeleting {
                return
            }
            
            let title = self.trimmedTitle
            if title.isEmpty {
                self.animateTitleError()
                return
            }
            
            guard let sourcePeer = self.draftLinkedPeers.first(where: { $0.peerId == sourcePeerId }) else {
                return
            }
            
            self.endEditing(true)
            self.isSaving = true
            self.state?.updated(transition: .easeInOut(duration: 0.2))
            
            let createSignal: Signal<EnginePeer.Id, CommunityEditSaveError>
            let shouldApplySourcePeerLink = self.createdCommunityId != nil
            if let createdCommunityId = self.createdCommunityId {
                createSignal = .single(createdCommunityId)
            } else {
                createSignal = component.context.engine.peers.createCommunity(
                    title: title,
                    about: nil,
                    peerId: sourcePeerId,
                    visible: sourcePeer.visible
                )
                |> mapError { _ -> CommunityEditSaveError in
                    return .generic
                }
                |> afterNext { [weak self] communityId in
                    self?.createdCommunityId = communityId
                    self?.createdCommunityTitle = title
                }
            }
            
            let pendingAvatar = self.pendingAvatar
            let shouldUpdateMode = self.selectedMode != .allMembers || self.createdCommunityId != nil
            let peersToLink = shouldApplySourcePeerLink ? self.draftLinkedPeers : self.draftLinkedPeers.filter { $0.peerId != sourcePeerId }
            
            let signal = createSignal
            |> mapToSignal { communityId -> Signal<Never, CommunityEditSaveError> in
                var signal: Signal<Never, CommunityEditSaveError> = .complete()
                |> delay(0.5, queue: Queue.mainQueue())
                if let pendingAvatar {
                    signal = signal
                    |> then(component.context.engine.peers.updatePeerPhoto(
                        peerId: communityId,
                        photo: pendingAvatar.uploadedPhoto,
                        video: pendingAvatar.uploadedVideo,
                        videoStartTimestamp: pendingAvatar.videoStartTimestamp,
                        markup: pendingAvatar.markup,
                        mapResourceToAvatarSizes: { resource, representations in
                            return mapResourceToAvatarSizes(engine: component.context.engine, resource: resource, representations: representations)
                        }
                    )
                    |> mapError { _ -> CommunityEditSaveError in
                        return .generic
                    }
                    |> ignoreValues)
                }
                if shouldUpdateMode {
                    let rights = self.rightsWithUpdatedMode(self.selectedMode, current: nil)
                    signal = signal
                    |> then(component.context.engine.peers.updateDefaultChannelMemberBannedRights(peerId: communityId, rights: rights)
                    |> castError(CommunityEditSaveError.self))
                }
                for peer in peersToLink {
                    signal = signal
                    |> then(component.context.engine.peers.toggleCommunityPeerLink(
                        communityId: communityId,
                        peerId: peer.peerId,
                        action: .link(visible: peer.visible)
                    )
                    |> `catch` { error -> Signal<Never, CommunityEditSaveError> in
                        if case .requestCreated = error {
                            return .complete()
                        } else {
                            return .fail(.generic)
                        }
                    })
                }
                return signal
            }
            |> then(
                component.context.engine.peers.joinedCommunities()
                |> castError(CommunityEditSaveError.self)
                |> ignoreValues
            )
            
            self.saveDisposable.set((signal
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.isSaving = false
                self.state?.updated(transition: .easeInOut(duration: 0.2))
                self.presentError()
            }, completed: { [weak self] in
                guard let self else {
                    return
                }
                self.isSaving = false
                component.completed()
            }))
        }

        func save() {
            guard let component = self.component else {
                return
            }
            if case let .create(peerId) = component.mode {
                self.saveCreateCommunity(component: component, sourcePeerId: peerId)
                return
            }
            
            guard let component = self.component, let community = self.community else {
                return
            }
            if self.isSaving || self.isDeleting {
                return
            }

            let title = self.trimmedTitle
            if title.isEmpty {
                self.animateTitleError()
                return
            }

            if !self.hasChanges {
                self.dismissController()
                return
            }

            self.isSaving = true

            let titleChanged = title != self.initialTitle
            let modeChanged = self.selectedMode != self.initialMode

            var signal: Signal<Never, CommunityEditSaveError> = .complete()
            if titleChanged {
                signal = signal
                |> then(component.context.engine.peers.updatePeerTitle(peerId: community.id, title: title)
                |> mapError { _ -> CommunityEditSaveError in
                    return .generic
                }
                |> ignoreValues)
            }
            if modeChanged {
                let rights = self.rightsWithUpdatedMode(self.selectedMode, current: community.defaultBannedRights)
                signal = signal
                |> then(component.context.engine.peers.updateDefaultChannelMemberBannedRights(peerId: community.id, rights: rights)
                |> castError(CommunityEditSaveError.self))
            }

            self.saveDisposable.set((signal
            |> deliverOnMainQueue).startStrict(error: { [weak self] _ in
                guard let self else {
                    return
                }
                self.isSaving = false
                self.presentError()
            }, completed: { [weak self] in
                guard let self else {
                    return
                }
                self.isSaving = false
                self.dismissController()
            }))
        }

        private func selectMode(_ mode: CommunityAddChatsMode) {
            if self.isSaving || self.isDeleting {
                return
            }
            if self.selectedMode != mode {
                self.selectedMode = mode
                self.state?.updated(transition: .spring(duration: 0.35))
            }
        }

        private func permissionItem(
            id: String,
            title: String,
            subtitle: String,
            mode: CommunityAddChatsMode,
            theme: PresentationTheme,
            presentationData: PresentationData
        ) -> AnyComponentWithIdentity<Empty> {
            return AnyComponentWithIdentity(id: id, component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(VStack([
                    AnyComponentWithIdentity(id: "title", component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: title,
                            font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))),
                    AnyComponentWithIdentity(id: "subtitle", component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: subtitle,
                            font: Font.regular(13.0),
                            textColor: theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 0
                    )))
                ], alignment: .left, spacing: 4.0)),
                contentInsets: UIEdgeInsets(top: 9.0, left: 0.0, bottom: 9.0, right: 0.0),
                leftIcon: .check(ListActionItemComponent.LeftIcon.Check(
                    style: .tick,
                    isSelected: self.selectedMode == mode,
                    toggle: { [weak self] in
                        self?.selectMode(mode)
                    }
                )),
                accessory: nil,
                action: { [weak self] _ in
                    self?.selectMode(mode)
                },
                highlighting: self.isSaving ? .disabled : .default
            )))
        }

        private func managementItem(
            id: String,
            title: String,
            icon: UIImage?,
            count: Int32?,
            countStyle: ItemAccessoryComponent.CountStyle,
            theme: PresentationTheme,
            presentationData: PresentationData,
            action: (() -> Void)?
        ) -> AnyComponentWithIdentity<Empty> {
            let itemAction: ((UIView) -> Void)? = action.map { action in
                return { _ in
                    action()
                }
            }
            return AnyComponentWithIdentity(id: id, component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: title,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                leftIcon: .custom(AnyComponentWithIdentity(id: icon, component: AnyComponent(Image(image: icon, size: CGSize(width: 30.0, height: 30.0)))), false),
                accessory: .custom(ListActionItemComponent.CustomAccessory(
                    component: AnyComponentWithIdentity(id: "\(id)-accessory-\(count ?? 0)", component: AnyComponent(ItemAccessoryComponent(
                        count: count,
                        countStyle: countStyle,
                        theme: theme
                    ))),
                    insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 16.0),
                    isInteractive: false
                )),
                action: itemAction,
                highlighting: itemAction == nil ? .disabled : .default
            )))
        }

        private func chatsHeaderTitle(presentationData: PresentationData) -> String {
            let count: Int
            if self.isCreateMode {
                count = self.draftLinkedPeers.count
            } else {
                count = self.cachedData?.linkedPeers.count ?? 0
            }
            return presentationData.strings.Community_Edit_ChatsHeader(Int32(clamping: count))
        }

        private func memberCountString(peerId: EnginePeer.Id, presentationData: PresentationData) -> String? {
            guard let cachedData = self.linkedPeerCachedData[peerId] else {
                return nil
            }
            let count: Int32?
            if let cachedData = cachedData as? CachedChannelData {
                count = cachedData.participantsSummary.memberCount
            } else if let cachedData = cachedData as? CachedGroupData {
                count = Int32(cachedData.participants?.participants.count ?? 0)
            } else {
                count = nil
            }
            guard let count else {
                return nil
            }
            return presentationData.strings.Conversation_StatusMembers(count)
        }

        private func addChatItem(
            theme: PresentationTheme,
            presentationData: PresentationData
        ) -> AnyComponentWithIdentity<Empty> {
            return AnyComponentWithIdentity(id: "addChat", component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: presentationData.strings.Community_Edit_AddChat,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: theme.list.itemAccentColor
                    )),
                    maximumNumberOfLines: 1
                )),
                contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Item List/AddCommunityIcon", tintColor: theme.list.itemAccentColor))), false),
                accessory: self.isAddActionInProgress ? .activity : nil,
                action: { [weak self] _ in
                    self?.openAddChat()
                },
                highlighting: (self.isSaving || self.isDeleting || self.isAddActionInProgress) ? .disabled : .default
            )))
        }

        private func chatItem(
            context: AccountContext,
            peer: EnginePeer,
            theme: PresentationTheme,
            presentationData: PresentationData,
            isHidden: Bool = false
        ) -> AnyComponentWithIdentity<Empty> {
            let subtitle: PeerListItemComponent.Subtitle?
            if case .user = peer {
                subtitle = PeerListItemComponent.Subtitle(text: presentationData.strings.Bot_GenericBotStatus, color: .neutral)
            } else {
                subtitle = self.memberCountString(peerId: peer.id, presentationData: presentationData).flatMap {
                    PeerListItemComponent.Subtitle(text: $0, color: .neutral)
                }
            }
                
            return AnyComponentWithIdentity(id: peer.id, component: AnyComponent(PeerListItemComponent(
                context: context,
                theme: theme,
                strings: presentationData.strings,
                style: .generic,
                sideInset: 0.0,
                title: peer.compactDisplayTitle,
                titleAccessory: isHidden ? .hidden : .none,
                peer: peer,
                subtitle: subtitle,
                subtitleAccessory: .none,
                presence: nil,
                rightAccessory: .none,
                selectionState: .none,
                isEnabled: !(self.isSaving || self.isDeleting),
                hasNext: false,
                extractedTheme: PeerListItemComponent.ExtractedTheme(
                    inset: 2.0,
                    background: theme.list.itemBlocksBackgroundColor
                ),
                insets: UIEdgeInsets(top: -1.0, left: 0.0, bottom: -1.0, right: 0.0),
                action: { [weak self] peer, _, _ in
                    self?.openPeer(peer)
                }
            )))
        }
        
        private func draftChatItem(
            context: AccountContext,
            peer: EnginePeer,
            visible: Bool,
            theme: PresentationTheme,
            presentationData: PresentationData
        ) -> AnyComponentWithIdentity<Empty> {
            let subtitle = self.memberCountString(peerId: peer.id, presentationData: presentationData).flatMap {
                PeerListItemComponent.Subtitle(text: $0, color: .neutral)
            }
            return AnyComponentWithIdentity(id: peer.id, component: AnyComponent(PeerListItemComponent(
                context: context,
                theme: theme,
                strings: presentationData.strings,
                style: .generic,
                sideInset: 0.0,
                title: peer.compactDisplayTitle,
                titleAccessory: visible ? .none : .hidden,
                peer: peer,
                subtitle: subtitle,
                subtitleAccessory: .none,
                presence: nil,
                rightAccessory: .none,
                selectionState: .none,
                isEnabled: !(self.isSaving || self.isDeleting),
                hasNext: false,
                extractedTheme: PeerListItemComponent.ExtractedTheme(
                    inset: 2.0,
                    background: theme.list.itemBlocksBackgroundColor
                ),
                insets: UIEdgeInsets(top: -1.0, left: 0.0, bottom: -1.0, right: 0.0),
                action: { [weak self] peer, _, _ in
                    self?.openDraftPeerVisibility(peer: peer)
                }
            )))
        }

        private func deleteItem(
            theme: PresentationTheme,
            presentationData: PresentationData
        ) -> AnyComponentWithIdentity<Empty> {
            return AnyComponentWithIdentity(id: "delete", component: AnyComponent(ListActionItemComponent(
                theme: theme,
                style: .glass,
                title: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: presentationData.strings.Community_Edit_DeleteCommunity,
                        font: Font.regular(presentationData.listsFontSize.baseDisplaySize),
                        textColor: theme.list.itemDestructiveColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                titleAlignment: .center,
                contentInsets: UIEdgeInsets(top: 12.0, left: 0.0, bottom: 12.0, right: 0.0),
                leftIcon: nil,
                accessory: self.isDeleting ? .activity : nil,
                action: { [weak self] _ in
                    self?.confirmDeleteCommunity()
                },
                highlighting: (self.isSaving || self.isDeleting) ? .disabled : .default
            )))
        }

        func update(component: CommunityEditScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }

            let environment = environment[EnvironmentType.self].value
            self.environment = environment
            self.component = component
            self.state = state

            self.ensureDataSignal(component: component)

            let theme = environment.theme
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            // iPhone Duo: one side's safe inset is the side strip; the right margin is its own and centered
            // content is centered in the band between the insets. With equal insets these are the old values.
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let rightSideInset: CGFloat = 16.0 + environment.safeInsets.right
            let sectionSpacing: CGFloat = 24.0

            self.backgroundColor = theme.list.blocksBackgroundColor
            self.scrollView.backgroundColor = theme.list.blocksBackgroundColor

            var contentHeight = environment.navigationHeight - 36.0

            let resetTitleText = self.resetTitleText
            self.resetTitleText = nil

            let avatarPeer: EnginePeer?
            if let community = self.community {
                avatarPeer = EnginePeer(community)
            } else if self.isCreateMode {
                avatarPeer = EnginePeer(TelegramCommunity(
                    id: EnginePeer.Id(namespace: .max, id: EnginePeer.Id.Id._internalFromInt64Value(0)),
                    accessHash: nil,
                    title: self.trimmedTitle,
                    photo: self.pendingAvatar.flatMap { [$0.previewRepresentation] } ?? [],
                    creationDate: 0,
                    participationStatus: .member,
                    flags: [.isCreator],
                    collapsedInDialogs: nil,
                    adminRights: nil,
                    defaultBannedRights: nil
                ))
            } else {
                avatarPeer = nil
            }
            
            if let avatarPeer {
                var transition = transition
                if self.avatarHeader.view == nil {
                    transition = .immediate
                }
                let avatarHeaderSize = self.avatarHeader.update(
                    transition: transition,
                    component: AnyComponent(CommunityAvatarComponent(
                        context: component.context,
                        theme: theme,
                        strings: presentationData.strings,
                        peer: avatarPeer,
                        isEnabled: !(self.isSaving || self.isDeleting || self.isUpdatingAvatar),
                        uploadingImage: self.uploadingAvatarImage,
                        uploadProgress: self.avatarUploadProgress,
                        action: { [weak self] in
                            self?.openAvatarSetup()
                        }
                    )),
                    environment: {},
                    // The band between the side insets (iPhone Duo's side strip): the avatar centers in it.
                    containerSize: CGSize(width: availableSize.width - environment.safeInsets.left - environment.safeInsets.right, height: 120.0)
                )
                if let avatarHeaderView = self.avatarHeader.view {
                    if avatarHeaderView.superview == nil {
                        self.scrollView.addSubview(avatarHeaderView)
                    }
                    transition.setFrame(view: avatarHeaderView, frame: CGRect(origin: CGPoint(x: environment.safeInsets.left, y: contentHeight), size: avatarHeaderSize))
                }
            }
            contentHeight += 179.0

            let titleSectionSize = self.titleSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: nil,
                    items: [
                        AnyComponentWithIdentity(id: "title", component: AnyComponent(ListTextFieldItemComponent(
                            style: .glass,
                            theme: theme,
                            initialText: self.currentTitle,
                            resetText: resetTitleText.flatMap { ListTextFieldItemComponent.ResetText(value: $0) },
                            placeholder: self.isCreateMode ? presentationData.strings.Community_Edit_CommunityNamePlaceholder : "",
                            characterLimit: 128,
                            autocapitalizationType: .words,
                            autocorrectionType: .yes,
                            updated: { [weak self] value in
                                guard let self else {
                                    return
                                }
                                self.currentTitle = value
                            },
                            tag: self.titleFieldTag
                        )))
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset - rightSideInset, height: 1000.0)
            )
            if let titleSectionView = self.titleSection.view {
                if titleSectionView.superview == nil {
                    self.scrollView.addSubview(titleSectionView)
                }
                transition.setFrame(view: titleSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: titleSectionSize))
            }
            if self.isCreateMode && !self.didFocusTitleField {
                self.didFocusTitleField = true
                Queue.mainQueue().after(0.1, { [weak self] in
                    guard let self, let view = self.titleSection.findTaggedView(tag: self.titleFieldTag) as? ListTextFieldItemComponent.View else {
                        return
                    }
                    view.activateInput()
                })
            }
            contentHeight += titleSectionSize.height + sectionSpacing

            let permissionsSectionSize = self.permissionsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: presentationData.strings.Community_Edit_WhoCanAddChats,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    footer: nil,
                    items: [
                        self.permissionItem(
                            id: "allMembers",
                            title: presentationData.strings.Community_Edit_PermissionAllMembers,
                            subtitle: presentationData.strings.Community_Edit_PermissionAllMembersInfo,
                            mode: .allMembers,
                            theme: theme,
                            presentationData: presentationData
                        ),
                        self.permissionItem(
                            id: "onlyAdmins",
                            title: presentationData.strings.Community_Edit_PermissionOnlyAdmins,
                            subtitle: presentationData.strings.Community_Edit_PermissionOnlyAdminsInfo,
                            mode: .onlyAdmins,
                            theme: theme,
                            presentationData: presentationData
                        )
                    ]
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset - rightSideInset, height: 1000.0)
            )
            if let permissionsSectionView = self.permissionsSection.view {
                if permissionsSectionView.superview == nil {
                    self.scrollView.addSubview(permissionsSectionView)
                }
                transition.setFrame(view: permissionsSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: permissionsSectionSize))
            }
            contentHeight += permissionsSectionSize.height
            contentHeight += sectionSpacing

            let adminsCount = self.cachedData?.adminsCount
            let removedUsersCount = self.cachedData?.kickedCount
            let pendingRequests = self.cachedData?.pendingRequests
            var managementItems: [AnyComponentWithIdentity<Empty>] = [
                self.managementItem(
                    id: "administrators",
                    title: presentationData.strings.Community_Edit_Administrators,
                    icon: self.cachedAdminsIcon,
                    count: adminsCount,
                    countStyle: .plain,
                    theme: theme,
                    presentationData: presentationData,
                    action: { [weak self] in
                        self?.openAdministrators()
                    }
                )
            ]
            if let pendingRequests, pendingRequests > 0 {
                managementItems.append(self.managementItem(
                    id: "pendingRequests",
                    title: presentationData.strings.Community_Edit_PendingRequests,
                    icon: self.cachedRequestsIcon,
                    count: pendingRequests,
                    countStyle: .badge,
                    theme: theme,
                    presentationData: presentationData,
                    action: { [weak self] in
                        self?.openPendingRequests()
                    }
                ))
            }
            managementItems.append(self.managementItem(
                id: "removedUsers",
                title: presentationData.strings.Community_Edit_RemovedUsers,
                icon: self.cachedBannedIcon,
                count: removedUsersCount,
                countStyle: .plain,
                theme: theme,
                presentationData: presentationData,
                action: { [weak self] in
                    self?.openRemovedUsers()
                }
            ))

            if !self.isCreateMode && !managementItems.isEmpty {
                let managementSectionSize = self.managementSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: managementItems
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset - rightSideInset, height: 1000.0)
                )
                if let managementSectionView = self.managementSection.view {
                    if managementSectionView.superview == nil {
                        self.scrollView.addSubview(managementSectionView)
                    }
                    transition.setFrame(view: managementSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: managementSectionSize))
                }
                contentHeight += managementSectionSize.height
                contentHeight += sectionSpacing
            }

            var chatItems: [AnyComponentWithIdentity<Empty>] = []
            if self.isCreateMode {
                chatItems.append(self.addChatItem(
                    theme: theme,
                    presentationData: presentationData
                ))
                for draftPeer in self.draftLinkedPeers {
                    guard let peer = self.linkedPeers[draftPeer.peerId] else {
                        continue
                    }
                    chatItems.append(self.draftChatItem(
                        context: component.context,
                        peer: peer,
                        visible: draftPeer.visible,
                        theme: theme,
                        presentationData: presentationData
                    ))
                }
            } else {
                chatItems.append(self.addChatItem(
                    theme: theme,
                    presentationData: presentationData
                ))
                let linkedPeers = self.cachedData?.linkedPeers ?? []
                for linkedPeer in linkedPeers {
                    guard let peer = self.linkedPeers[linkedPeer.peerId] else {
                        continue
                    }
                    chatItems.append(self.chatItem(
                        context: component.context,
                        peer: peer,
                        theme: theme,
                        presentationData: presentationData,
                        isHidden: linkedPeer.visible == false
                    ))
                }
            }

            let chatsSectionSize = self.chatsSection.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: self.chatsHeaderTitle(presentationData: presentationData),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    footer: nil,
                    items: chatItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset - rightSideInset, height: 1000.0)
            )
            if let chatsSectionView = self.chatsSection.view {
                if chatsSectionView.superview == nil {
                    self.scrollView.addSubview(chatsSectionView)
                }
                transition.setFrame(view: chatsSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: chatsSectionSize))
            }
            contentHeight += chatsSectionSize.height
            
            if let community = self.community, community.flags.contains(.isCreator) {
                contentHeight += sectionSpacing
                
                var transition = transition
                if self.deleteSection.view == nil {
                    transition = .immediate
                }
                
                let deleteSectionSize = self.deleteSection.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: nil,
                        items: [
                            self.deleteItem(
                                theme: theme,
                                presentationData: presentationData
                            )
                        ]
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset - rightSideInset, height: 1000.0)
                )
                if let deleteSectionView = self.deleteSection.view {
                    if deleteSectionView.superview == nil {
                        self.scrollView.addSubview(deleteSectionView)
                    }
                    transition.setFrame(view: deleteSectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: deleteSectionSize))
                }
                contentHeight += deleteSectionSize.height
            }
            
            contentHeight += 32.0 + environment.safeInsets.bottom

            let contentSize = CGSize(width: availableSize.width, height: max(contentHeight, availableSize.height + 1.0))
            self.ignoreScrolling = true
            if self.scrollView.frame.size != availableSize {
                self.scrollView.frame = CGRect(origin: .zero, size: availableSize)
            }
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
            self.ignoreScrolling = false

            self.updateScrolling(transition: transition)

            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class CommunityEditScreen: ViewControllerComponentContainer {
    public convenience init(context: AccountContext, communityId: EnginePeer.Id) {
        self.init(context: context, mode: .edit(communityId: communityId), completed: {})
    }
    
    public init(context: AccountContext, mode: CommunityEditScreenMode, completed: @escaping () -> Void) {
        super.init(
            context: context,
            component: CommunityEditScreenComponent(context: context, mode: mode, completed: completed),
            navigationBarAppearance: .default,
            theme: .default,
            updatedPresentationData: nil
        )

        self.title = ""
        switch mode {
        case .create:
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "___close", style: .plain, target: self, action: #selector(self.closePressed))
        case .edit:
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "___done", style: .plain, target: self, action: #selector(self.savePressed))

        self.scrollToTop = { [weak self] in
            guard let self, let componentView = self.node.hostView.componentView as? CommunityEditScreenComponent.View else {
                return
            }
            componentView.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func closePressed() {
        self.dismiss()
    }
    
    @objc private func savePressed() {
        guard let componentView = self.node.hostView.componentView as? CommunityEditScreenComponent.View else {
            return
        }
        componentView.save()
    }
}
