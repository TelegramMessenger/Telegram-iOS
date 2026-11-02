import Foundation
import UIKit
import CoreMedia
import Display
import SwiftSignalKit
import ComponentFlow
import TelegramPresentationData
import MediaEditor
import MediaScrubberComponent

extension MediaEditor: ChatMediaEditorCoverFrameSource {
}

private let chatMediaEditorCoverEnterDuration: Double = 0.2
private let chatMediaEditorCoverExitDuration: Double = 0.3

extension ChatMediaEditorScreen.Node {
    func setupCover() {
        guard self.isGallery, let gallery = self.controller?.gallery, gallery.hasCoverButton, let covers = gallery.covers else {
            return
        }
        self.coverModel = ChatMediaEditorCoverModel(adapter: covers)
    }

    var isEditingCover: Bool {
        return self.activeTool == .cover
    }

    var isCoverButtonVisible: Bool {
        guard self.coverModel != nil, let gallery = self.controller?.gallery else {
            return false
        }
        return chatMediaEditorCoverButtonIsVisible(hasCoverButton: gallery.hasCoverButton, isVideo: self.subject.isVideo, isAnimation: self.pageModel.currentItem.isAnimation, duration: self.subject.duration)
    }

    private func coverHeaderFrame(layout: ContainerViewLayout, safeInsets: UIEdgeInsets) -> CGRect {
        let toolbarMinY = chatMediaEditorBottomPanelFrame(size: layout.size, safeInsets: safeInsets, toolbarHeight: chatMediaEditorToolbarHeight).minY
        return chatMediaEditorVideoHeaderFrame(size: layout.size, toolbarMinY: toolbarMinY, captionBaseHeight: self.captionPanelView?.baseHeight() ?? 0.0, safeInsets: safeInsets, toolbarSide: self.toolbarSide(layout: layout), reservedCorners: layout.reservedCorners)
    }

    func updateCoverLayout(layout: ContainerViewLayout, safeInsets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        guard self.isCoverButtonVisible else {
            self.coverButton?.removeFromSuperview()
            self.coverButton = nil
            return
        }
        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
        let button: ChatMediaEditorCoverButton
        var isNew = false
        if let current = self.coverButton {
            button = current
        } else {
            button = ChatMediaEditorCoverButton(title: strings.Media_EditCover)
            button.addTarget(self, action: #selector(self.coverButtonPressed), for: .touchUpInside)
            self.coverButton = button
            self.view.insertSubview(button, aboveSubview: self.pagerView)
            isNew = true
        }
        button.setThumbnail(self.coverModel?.coverImage(for: self.pageModel.currentItem.uniqueId))
        let headerFrame = self.coverHeaderFrame(layout: layout, safeInsets: safeInsets)
        let buttonFrame = chatMediaEditorCoverButtonFrame(size: layout.size, safeInsets: safeInsets, headerFrame: headerFrame, buttonWidth: button.contentWidth, toolbarSide: self.toolbarSide(layout: layout))
        if isNew {
            button.frame = buttonFrame
        } else {
            transition.updateFrame(view: button, frame: buttonFrame)
        }
        let isHidden = self.activeTool != nil || self.isInterfaceHiddenBySwipe || self.isEditingCaption || (layout.inputHeight ?? 0.0) > 0.0 || self.isSending
        transition.updateAlpha(layer: button.layer, alpha: isHidden ? 0.0 : 1.0)
        button.isUserInteractionEnabled = !isHidden

        if let editView = self.coverEditView {
            transition.updateFrame(view: editView, frame: CGRect(origin: .zero, size: layout.size))
            let editLayout = chatMediaEditorCoverEditLayout(size: layout.size, safeInsets: safeInsets, titleSize: editView.titleLabel.bounds.size, cancelSize: editView.cancelButton.bounds.size, statusIsland: chatMediaEditorStatusIslandRow(layout: layout))
            transition.updateFrame(view: editView.titleLabel, frame: editLayout.titleFrame)
            transition.updateFrame(view: editView.cancelButton, frame: editLayout.cancelFrame)
            transition.updateFrame(view: editView.saveButton, frame: editLayout.saveFrame)
            if let galleryButton = editView.galleryButton {
                transition.updateFrame(view: galleryButton, frame: chatMediaEditorCoverGalleryButtonFrame(coverButtonFrame: buttonFrame, size: layout.size, safeInsets: safeInsets, buttonWidth: galleryButton.contentWidth))
            }
        }
        self.updateCoverScrubber(layout: layout, safeInsets: safeInsets, transition: ComponentTransition(transition))
    }

    func updateCoverScrubber(layout: ContainerViewLayout, safeInsets: UIEdgeInsets, transition: ComponentTransition) {
        guard self.isEditingCover, let playerState = self.playerState, let mainTrack = playerState.tracks.first(where: { $0.id == 0 }) else {
            return
        }
        let headerFrame = self.coverHeaderFrame(layout: layout, safeInsets: safeInsets)
        let availableWidth = chatMediaEditorScrubberFrame(size: layout.size, safeInsets: safeInsets, headerFrame: headerFrame, scrubberHeight: 0.0, toolbarSide: self.toolbarSide(layout: layout)).width
        let mediaEditor = self.mediaEditor
        let scrubberSize = self.coverScrubber.update(
            transition: transition,
            component: AnyComponent(MediaScrubberComponent(
                context: self.context,
                style: .cover,
                theme: defaultDarkColorPresentationTheme,
                generationTimestamp: playerState.generationTimestamp,
                position: self.coverPosition ?? playerState.position,
                minDuration: 1.0,
                maxDuration: max(1.0, mainTrack.duration),
                isPlaying: playerState.isPlaying,
                tracks: [MediaScrubberComponent.Track(mainTrack)],
                isCollage: false,
                positionUpdated: { [weak self, weak mediaEditor] position, _ in
                    self?.coverPosition = position
                    mediaEditor?.seek(position, andPlay: false)
                },
                coverPositionUpdated: { [weak self, weak mediaEditor] position, tap, commit in
                    self?.coverPosition = position
                    guard let mediaEditor else {
                        return
                    }
                    if tap {
                        mediaEditor.setOnNextDisplay {
                            commit()
                        }
                        mediaEditor.seek(position, andPlay: false)
                    } else {
                        mediaEditor.seek(position, andPlay: false)
                        commit()
                    }
                },
                trackTrimUpdated: { _, _, _, _, _ in
                },
                trackOffsetUpdated: { _, _, _ in
                },
                trackLongPressed: { _, _ in
                }
            )),
            environment: {},
            containerSize: CGSize(width: availableWidth, height: layout.size.height)
        )
        guard let scrubberView = self.coverScrubber.view else {
            return
        }
        let scrubberFrame = chatMediaEditorCoverScrubberFrame(trimScrubberFrame: chatMediaEditorScrubberFrame(size: layout.size, safeInsets: safeInsets, headerFrame: headerFrame, scrubberHeight: scrubberSize.height, toolbarSide: self.toolbarSide(layout: layout)))
        if scrubberView.superview == nil {
            scrubberView.alpha = 0.0
            if let editView = self.coverEditView {
                self.view.insertSubview(scrubberView, belowSubview: editView)
            } else {
                self.view.insertSubview(scrubberView, aboveSubview: self.pagerView)
            }
            scrubberView.frame = scrubberFrame
            UIView.animate(withDuration: chatMediaEditorCoverEnterDuration, animations: {
                scrubberView.alpha = 1.0
            })
        } else {
            transition.setFrame(view: scrubberView, frame: scrubberFrame)
        }
    }

    private func clampedCoverPosition(_ position: Double) -> Double {
        let duration = self.playerState?.tracks.first(where: { $0.id == 0 })?.duration ?? self.subject.duration
        return chatMediaEditorCoverClampedPosition(position, trimRange: self.mediaEditor.values.videoTrimRange, duration: duration)
    }

    @objc func coverButtonPressed() {
        guard let controller = self.controller, self.isCoverButtonVisible, let coverModel = self.coverModel, chatMediaEditorCanOpenTool(isToolActive: self.activeTool != nil, isSending: self.isSending, isDismissing: controller.isDismissing, isPagerMoving: self.isPagerMoving), !self.isInvalidated else {
            return
        }
        self.resetCurrentPageZoom()
        if self.entitiesView.hasSelection {
            self.entitiesView.selectEntity(nil)
        }
        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
        let editView = ChatMediaEditorCoverEditView(
            title: strings.Media_SelectFrame,
            cancelTitle: strings.Common_Cancel,
            saveTitle: strings.Media_SaveCover,
            galleryTitle: controller.gallery?.editCover != nil ? strings.Media_ChooseFromGallery : nil
        )
        editView.cancelButton.addTarget(self, action: #selector(self.coverCancelPressed), for: .touchUpInside)
        editView.saveButton.addTarget(self, action: #selector(self.coverSavePressed), for: .touchUpInside)
        editView.galleryButton?.addTarget(self, action: #selector(self.coverGalleryPressed), for: .touchUpInside)
        editView.alpha = 0.0
        self.view.insertSubview(editView, belowSubview: self.captionDimView)
        self.coverEditView = editView

        self.mediaEditor.stop()
        let position = self.clampedCoverPosition(chatMediaEditorCoverEditingPosition(savedPosition: coverModel.savedPosition(for: self.pageModel.currentItem.uniqueId), playerPosition: self.playerState?.position, currentPosition: self.mediaEditor.currentPosition.seconds))
        self.coverPosition = position
        self.mediaEditor.seek(position, andPlay: false)
        self.activeTool = .cover
        self.updateEntityInteraction()
        self.requestLayout(transition: .animated(duration: chatMediaEditorCoverEnterDuration, curve: .easeInOut))
        UIView.animate(withDuration: chatMediaEditorCoverEnterDuration, animations: {
            editView.alpha = 1.0
        })
    }

    @objc private func coverCancelPressed() {
        guard self.isEditingCover, !self.isCapturingCover else {
            return
        }
        self.exitCoverEditing()
    }

    @objc private func coverSavePressed() {
        guard self.isEditingCover, let coverModel = self.coverModel, !self.isInvalidated, !self.isCapturingCover else {
            return
        }
        let uniqueId = self.pageModel.currentItem.uniqueId
        let position = self.clampedCoverPosition(self.coverPosition ?? self.playerState?.position ?? self.mediaEditor.currentPosition.seconds)
        self.isCapturingCover = true
        self.coverEditView?.isUserInteractionEnabled = false
        self.coverScrubber.view?.isUserInteractionEnabled = false
        chatMediaEditorCaptureCoverFrame(source: self.mediaEditor, position: position, completion: { [weak self] image, position in
            guard let self else {
                return
            }
            self.isCapturingCover = false
            self.coverScrubber.view?.isUserInteractionEnabled = true
            guard self.isEditingCover, !self.isInvalidated, self.pageModel.currentItem.uniqueId == uniqueId else {
                self.coverEditView?.isUserInteractionEnabled = true
                return
            }
            if let image {
                coverModel.saveFrame(image, position: position, for: uniqueId)
            }
            self.exitCoverEditing()
        })
    }

    @objc private func coverGalleryPressed() {
        guard self.isEditingCover, let editCover = self.controller?.gallery?.editCover, !self.isInvalidated, !self.isCapturingCover else {
            return
        }
        let uniqueId = self.pageModel.currentItem.uniqueId
        editCover(self.subject.dimensions.cgSize, { [weak self] image in
            guard let self, !self.isInvalidated, let coverModel = self.coverModel else {
                return
            }
            coverModel.saveGalleryImage(image, for: uniqueId)
            if self.isEditingCover, self.pageModel.currentItem.uniqueId == uniqueId {
                self.exitCoverEditing()
            } else {
                self.requestLayout(transition: .immediate)
            }
        }, { [weak self] in
            self?.coverPickerDismissed(uniqueId: uniqueId)
        })
    }

    private func coverPickerDismissed(uniqueId: String) {
        guard self.isEditingCover, !self.isInvalidated, !self.isCapturingCover, self.pageModel.currentItem.uniqueId == uniqueId, let position = self.coverPosition else {
            return
        }
        self.mediaEditor.seek(position, andPlay: false)
        self.requestLayout(transition: .immediate)
    }

    func exitCoverEditing() {
        guard self.isEditingCover else {
            return
        }
        self.activeTool = nil
        self.updateEntityInteraction()
        self.removeCoverEditViews(animated: true)
        self.requestLayout(transition: .animated(duration: chatMediaEditorCoverExitDuration, curve: .easeInOut))
    }

    func removeCoverEditViews(animated: Bool) {
        let editView = self.coverEditView
        self.coverEditView = nil
        self.coverPosition = nil
        let scrubberView = self.coverScrubber.view
        self.coverScrubber = ComponentView<Empty>()
        if animated {
            UIView.animate(withDuration: chatMediaEditorCoverExitDuration, animations: {
                editView?.alpha = 0.0
                scrubberView?.alpha = 0.0
            }, completion: { _ in
                editView?.removeFromSuperview()
                scrubberView?.removeFromSuperview()
            })
        } else {
            editView?.removeFromSuperview()
            scrubberView?.removeFromSuperview()
        }
    }
}
