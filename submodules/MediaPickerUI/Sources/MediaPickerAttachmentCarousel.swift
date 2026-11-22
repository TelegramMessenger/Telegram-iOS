import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Photos
import AVFoundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import LegacyComponents
import Camera
import CameraLegacy
import MediaAssetsContext
import ChatMediaSend
import AppBundle

private final class MediaPickerAttachmentCarouselCell: UICollectionViewCell {
    let itemNode = MediaPickerGridItemNode()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.contentView.clipsToBounds = true
        self.contentView.layer.cornerRadius = 6.0
        self.contentView.addSubview(self.itemNode.view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.itemNode.frame = self.contentView.bounds
    }
}

public final class MediaPickerAttachmentCarouselView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public let policy: PassportCarouselPolicy
    public let selectionContext: TGMediaSelectionContext
    public let editingContext: TGMediaEditingContext
    public let itemStore: ChatMediaEditorItemStore

    private let context: AccountContext
    private let theme: PresentationTheme
    private let mediaAssetsContext: MediaAssetsContext
    private let downloadManager = AssetDownloadManager()
    private var interaction: MediaPickerInteraction?

    private let collectionLayout: UICollectionViewFlowLayout
    private let collectionView: UICollectionView
    private let cameraContainerView: UIView
    private var cameraPreviewView: CameraSimplePreviewView?
    private var cameraIconView: UIImageView?
    private var camera: CameraProtocol?
    private var cameraState: PassportCarouselCameraState = .placeholder
    private var isCameraHandedOff = false
    private var isCameraStopped = false

    private var fetchResult: PHFetchResult<PHAsset>?
    private var assetIndices: [Int] = []
    private var assetsDisposable: Disposable?
    private var selectionDisposable: Disposable?

    public private(set) var isZoomed = false

    public var openCamera: ((CameraHolder) -> Void)?
    public var openAsset: ((PHFetchResult<PHAsset>, Int, UIImage?) -> Void)?
    public var zoomUpdated: ((Bool) -> Void)?
    public var cameraAccessDenied: (() -> Void)?

    public init(context: AccountContext, policy: PassportCarouselPolicy, selfPortrait: Bool) {
        self.context = context
        self.policy = policy
        self.theme = context.sharedContext.currentPresentationData.with { $0 }.theme
        self.selectionContext = TGMediaSelectionContext(groupingAllowed: false, selectionLimit: Int32(policy.allowsSelection ? policy.selectionLimit : 1))!
        self.editingContext = TGMediaEditingContext()
        self.itemStore = ChatMediaEditorItemStore()
        self.mediaAssetsContext = MediaAssetsContext(assetType: policy.photoOnly ? .image : nil)

        self.collectionLayout = UICollectionViewFlowLayout()
        self.collectionLayout.scrollDirection = .horizontal
        self.collectionLayout.minimumLineSpacing = passportCarouselEdgeInset
        self.collectionLayout.minimumInteritemSpacing = passportCarouselEdgeInset

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: self.collectionLayout)
        self.collectionView.backgroundColor = .clear
        self.collectionView.showsHorizontalScrollIndicator = false
        self.collectionView.showsVerticalScrollIndicator = false
        self.collectionView.alwaysBounceHorizontal = true
        self.collectionView.contentInsetAdjustmentBehavior = .never
        self.collectionView.semanticContentAttribute = .forceLeftToRight
        self.collectionView.register(MediaPickerAttachmentCarouselCell.self, forCellWithReuseIdentifier: "cell")

        self.cameraContainerView = UIView()
        self.cameraContainerView.clipsToBounds = true
        self.cameraContainerView.layer.cornerRadius = 6.0
        self.cameraContainerView.backgroundColor = .black

        super.init(frame: .zero)

        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        self.addSubview(self.collectionView)

        let selectionContext = self.selectionContext
        let allowsSelection = policy.allowsSelection
        self.interaction = MediaPickerInteraction(
            downloadManager: self.downloadManager,
            openMedia: { [weak self] fetchResult, index, image in
                self?.openAsset?(fetchResult, index, image)
            },
            openSelectedMedia: { _, _ in
            },
            openDraft: { _, _ in
            },
            toggleSelection: { item, value, _ in
                return selectionContext.setItem(item, selected: value)
            },
            sendSelected: { _, _, _, _, _, _ in
            },
            schedule: { _ in
            },
            dismissInput: {
            },
            selectionState: allowsSelection ? selectionContext : nil,
            editingState: self.editingContext
        )

        if policy.hasCameraCell {
            self.collectionView.addSubview(self.cameraContainerView)
            self.setupCamera(selfPortrait: selfPortrait)
        }

        self.selectionDisposable = (Signal<Void, NoError> { subscriber in
            let disposable = selectionContext.selectionChangedSignal().start(next: { _ in
                subscriber.putNext(Void())
            }, error: { _ in
            }, completed: {
            })
            return ActionDisposable {
                disposable?.dispose()
            }
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
            self?.selectionUpdated()
        })

        let mediaAssetsContext = self.mediaAssetsContext
        self.assetsDisposable = (mediaAssetsContext.mediaAccess()
        |> mapToSignal { status -> Signal<PHFetchResult<PHAsset>?, NoError> in
            switch status {
            case .authorized, .limited:
                return mediaAssetsContext.recentAssets()
            case .notDetermined:
                mediaAssetsContext.requestMediaAccess()
                return .single(nil)
            default:
                return .single(nil)
            }
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] fetchResult in
            guard let self else {
                return
            }
            self.fetchResult = fetchResult
            self.assetIndices = passportCarouselAssetIndices(fetchCount: fetchResult?.count ?? 0)
            self.collectionView.reloadData()
        })
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.assetsDisposable?.dispose()
        self.selectionDisposable?.dispose()
        if !self.isCameraHandedOff && !self.isCameraStopped {
            self.camera?.stopCapture(invalidate: true)
        }
    }

    public func stopCamera() {
        guard !self.isCameraStopped else {
            return
        }
        self.isCameraStopped = true
        if !self.isCameraHandedOff {
            self.camera?.stopCapture(invalidate: true)
        }
    }

    private func setupCamera(selfPortrait: Bool) {
        let cameraImpl = LegacyCameraImpl.shared
        let previewView = cameraImpl.makeCameraSimplePreviewView(frame: .zero, main: true, roundVideo: false)
        previewView.resetPlaceholder(front: selfPortrait)
        self.cameraPreviewView = previewView
        self.cameraContainerView.addSubview(previewView)
        self.cameraContainerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.cameraTapped)))

        self.cameraState = passportCarouselCameraState(authorization: AVCaptureDevice.authorizationStatus(for: .video))
        switch self.cameraState {
        case .live:
            self.startCamera(previewView: previewView, selfPortrait: selfPortrait)
        case .requestAccess:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Queue.mainQueue().async {
                    guard let self, let previewView = self.cameraPreviewView else {
                        return
                    }
                    self.cameraState = granted ? .live : .placeholder
                    if granted {
                        if !self.isCameraStopped {
                            self.startCamera(previewView: previewView, selfPortrait: selfPortrait)
                        }
                    } else {
                        self.showCameraPlaceholder()
                    }
                }
            }
        case .placeholder:
            self.showCameraPlaceholder()
        }
    }

    private func showCameraPlaceholder() {
        guard self.cameraIconView == nil else {
            return
        }
        let iconView = UIImageView(image: UIImage(bundleImageName: "Chat/Attach Menu/Camera"))
        self.cameraContainerView.addSubview(iconView)
        self.cameraIconView = iconView
        self.setNeedsLayout()
    }

    private func startCamera(previewView: CameraSimplePreviewView, selfPortrait: Bool) {
        let cameraImpl = LegacyCameraImpl.shared
        let _ = (previewView.isPreviewing
        |> filter { $0 }
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [weak previewView] _ in
            previewView?.removePlaceholder(delay: 0.35)
        })

        let camera = cameraImpl.makeCamera(
            configuration: Camera.Configuration(
                preset: .hd1920x1080,
                position: selfPortrait ? .front : .back,
                isDualEnabled: false,
                audio: false,
                photo: true,
                metadata: false,
                captureMode: .photo
            ),
            previewView: previewView,
            secondaryPreviewView: nil
        )
        self.camera = camera
        camera.startCapture()
    }

    @objc private func cameraTapped() {
        if self.cameraState == .placeholder {
            self.cameraAccessDenied?()
            return
        }
        guard !self.isCameraHandedOff, !self.isCameraStopped, let camera = self.camera, let previewView = self.cameraPreviewView, let openCamera = self.openCamera else {
            return
        }
        self.isCameraHandedOff = true
        let parentView = self.cameraContainerView
        openCamera(CameraHolder(
            camera: camera,
            previewView: previewView,
            parentView: parentView,
            restore: { [weak self, weak previewView] in
                guard let self else {
                    camera.stopCapture(invalidate: true)
                    return
                }
                self.isCameraHandedOff = false
                if self.isCameraStopped {
                    camera.stopCapture(invalidate: true)
                    return
                }
                if let previewView {
                    self.cameraContainerView.addSubview(previewView)
                    previewView.frame = self.cameraContainerView.bounds
                    previewView.layer.removeAllAnimations()
                }
                let _ = camera.setCaptureMode(.photo).startStandalone()
            }
        ))
    }

    public var selectedCount: Int {
        return Int(self.selectionContext.count())
    }

    private func selectionUpdated() {
        for case let cell as MediaPickerAttachmentCarouselCell in self.collectionView.visibleCells {
            cell.itemNode.updateSelectionState(animated: true)
        }
        let isZoomed = self.policy.allowsSelection && self.selectedCount > 0
        if self.isZoomed != isZoomed {
            self.isZoomed = isZoomed
            self.setNeedsLayout()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.zoomUpdated?(isZoomed)
        }
    }

    public func updateHiddenAsset(_ identifier: String?) {
        self.interaction?.hiddenMediaId = identifier
        for case let cell as MediaPickerAttachmentCarouselCell in self.collectionView.visibleCells {
            cell.itemNode.updateHiddenMedia()
        }
    }

    public func transitionView(for identifier: String) -> UIView? {
        for case let cell as MediaPickerAttachmentCarouselCell in self.collectionView.visibleCells {
            if cell.itemNode.identifier == identifier {
                return cell.itemNode.view
            }
        }
        return nil
    }

    public var preferredHeight: CGFloat {
        return passportCarouselHeight(zoomed: self.isZoomed)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        self.collectionView.frame = self.bounds
        self.cameraContainerView.frame = passportCarouselCameraFrame
        self.cameraContainerView.isHidden = self.isZoomed
        self.cameraPreviewView?.frame = self.cameraContainerView.bounds
        if let cameraIconView = self.cameraIconView, let image = cameraIconView.image {
            cameraIconView.frame = CGRect(origin: CGPoint(x: self.cameraContainerView.bounds.width - image.size.width - 3.0, y: 3.0 - UIScreenPixel), size: image.size)
        }
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.assetIndices.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! MediaPickerAttachmentCarouselCell
        if let fetchResult = self.fetchResult, let interaction = self.interaction, indexPath.item < self.assetIndices.count {
            cell.itemNode.setup(interaction: interaction, fetchResult: fetchResult, index: self.assetIndices[indexPath.item], theme: self.theme, selectable: self.policy.allowsSelection, enableAnimations: true, stories: false)
            cell.itemNode.updateSelectionState()
            cell.itemNode.updateHiddenMedia()
        }
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var assetPixelSize = CGSize()
        if let fetchResult = self.fetchResult, indexPath.item < self.assetIndices.count {
            let asset = fetchResult.object(at: self.assetIndices[indexPath.item])
            assetPixelSize = CGSize(width: CGFloat(asset.pixelWidth), height: CGFloat(asset.pixelHeight))
        }
        return passportCarouselItemSize(zoomed: self.isZoomed, assetPixelSize: assetPixelSize)
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: passportCarouselEdgeInset, left: passportCarouselLeadingInset(zoomed: self.isZoomed, hasCamera: self.policy.hasCameraCell), bottom: passportCarouselEdgeInset, right: passportCarouselEdgeInset)
    }
}
