#import <UIKit/UIKit.h>

//! Project version number for LegacyComponents.
FOUNDATION_EXPORT double LegacyComponentsVersionNumber;

//! Project version string for LegacyComponents.
FOUNDATION_EXPORT const unsigned char LegacyComponentsVersionString[];


#import <LegacyComponents/LegacyComponentsGlobals.h>
#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/TGLocalization.h>
#import <LegacyComponents/TGPluralization.h>
#import <LegacyComponents/TGStringUtils.h>
#import <LegacyComponents/TGPhoneUtils.h>
#import <LegacyComponents/NSObject+TGLock.h>
#import <LegacyComponents/RMPhoneFormat.h>
#import <LegacyComponents/NSInputStream+TL.h>
#import <LegacyComponents/TGFont.h>
#import <LegacyComponents/TGImageUtils.h>
#import <LegacyComponents/TGDateUtils.h>
#import <LegacyComponents/Freedom.h>
#import <LegacyComponents/FreedomUIKit.h>
#import <LegacyComponents/TGHacks.h>
#import <LegacyComponents/TGImageBlur.h>
#import <LegacyComponents/UIDevice+PlatformInfo.h>
#import <LegacyComponents/TGObserverProxy.h>
#import <LegacyComponents/TGModernCache.h>
#import <LegacyComponents/TGMemoryImageCache.h>
#import <LegacyComponents/LegacyComponentsAccessChecker.h>
#import <LegacyComponents/TGTimerTarget.h>
#import <LegacyComponents/TGKeyCommand.h>
#import <LegacyComponents/TGKeyCommandController.h>
#import <LegacyComponents/TGWeakDelegate.h>
#import <LegacyComponents/TGCache.h>
#import <LegacyComponents/TGLiveUploadInterface.h>

#import <LegacyComponents/JNWSpringAnimation.h>
#import <LegacyComponents/POPAnimationEvent.h>
#import <LegacyComponents/POPAnimationTracer.h>
#import <LegacyComponents/POPAnimation.h>
#import <LegacyComponents/POPBasicAnimation.h>
#import <LegacyComponents/POPCustomAnimation.h>
#import <LegacyComponents/POPDecayAnimation.h>
#import <LegacyComponents/POPPropertyAnimation.h>
#import <LegacyComponents/POPSpringAnimation.h>

#import <LegacyComponents/lmdb.h>
#import <LegacyComponents/PSLMDBTable.h>
#import <LegacyComponents/PSLMDBKeyValueStore.h>
#import <LegacyComponents/PSLMDBKeyValueReaderWriter.h>
#import <LegacyComponents/PSLMDBKeyValueCursor.h>

#import <LegacyComponents/PSCoding.h>
#import <LegacyComponents/PSData.h>
#import <LegacyComponents/PSKeyValueCoder.h>
#import <LegacyComponents/PSKeyValueDecoder.h>
#import <LegacyComponents/PSKeyValueEncoder.h>
#import <LegacyComponents/PSKeyValueReader.h>
#import <LegacyComponents/PSKeyValueStore.h>
#import <LegacyComponents/PSKeyValueWriter.h>

#import <LegacyComponents/TGPeerIdAdapter.h>
#import <LegacyComponents/TGUser.h>
#import <LegacyComponents/TGBotInfo.h>
#import <LegacyComponents/TGBotComandInfo.h>
#import <LegacyComponents/TGConversation.h>

#import <LegacyComponents/TGModernConversationAssociatedInputPanel.h>
#import <LegacyComponents/TGModernConversationHashtagsAssociatedPanel.h>
#import <LegacyComponents/TGModernConversationMentionsAssociatedPanel.h>
#import <LegacyComponents/TGModernConversationAlphacodeAssociatedPanel.h>
#import <LegacyComponents/TGSuggestionContext.h>
#import <LegacyComponents/TGAlphacode.h>

#import <LegacyComponents/TGTextCheckingResult.h>
#import <LegacyComponents/TGChannelBannedRights.h>
#import <LegacyComponents/TGChannelAdminRights.h>
#import <LegacyComponents/TGDatabaseMessageDraft.h>
#import <LegacyComponents/TGMessageGroup.h>
#import <LegacyComponents/TGMessageHole.h>
#import <LegacyComponents/TGMessageViewCountContentProperty.h>
#import <LegacyComponents/TGAuthorSignatureMediaAttachment.h>
#import <LegacyComponents/TGWebDocument.h>
#import <LegacyComponents/TGInvoiceMediaAttachment.h>
#import <LegacyComponents/TGGameMediaAttachment.h>
#import <LegacyComponents/TGViaUserAttachment.h>
#import <LegacyComponents/TGBotContextResultAttachment.h>
#import <LegacyComponents/TGMessageEntity.h>
#import <LegacyComponents/TGMessageEntityBold.h>
#import <LegacyComponents/TGMessageEntityBotCommand.h>
#import <LegacyComponents/TGMessageEntityCode.h>
#import <LegacyComponents/TGMessageEntityEmail.h>
#import <LegacyComponents/TGMessageEntityHashtag.h>
#import <LegacyComponents/TGMessageEntityItalic.h>
#import <LegacyComponents/TGMessageEntityMention.h>
#import <LegacyComponents/TGMessageEntityMentionName.h>
#import <LegacyComponents/TGMessageEntityPre.h>
#import <LegacyComponents/TGMessageEntityTextUrl.h>
#import <LegacyComponents/TGMessageEntityUrl.h>
#import <LegacyComponents/TGMessageEntitiesAttachment.h>
#import <LegacyComponents/TGBotReplyMarkup.h>
#import <LegacyComponents/TGBotReplyMarkupButton.h>
#import <LegacyComponents/TGBotReplyMarkupRow.h>
#import <LegacyComponents/TGReplyMarkupAttachment.h>
#import <LegacyComponents/TGInstantPage.h>
#import <LegacyComponents/TGWebPageMediaAttachment.h>
#import <LegacyComponents/TGAudioMediaAttachment.h>
#import <LegacyComponents/TGAudioWaveform.h>
#import <LegacyComponents/TGStickerPackReference.h>
#import <LegacyComponents/TGDocumentAttributeFilename.h>
#import <LegacyComponents/TGDocumentAttributeImageSize.h>
#import <LegacyComponents/TGDocumentAttributeSticker.h>
#import <LegacyComponents/TGDocumentAttributeVideo.h>
#import <LegacyComponents/TGDocumentAttributeAnimated.h>
#import <LegacyComponents/TGDocumentAttributeAudio.h>
#import <LegacyComponents/TGDocumentMediaAttachment.h>
#import <LegacyComponents/TGUnsupportedMediaAttachment.h>
#import <LegacyComponents/TGForwardedMessageMediaAttachment.h>
#import <LegacyComponents/TGContactMediaAttachment.h>
#import <LegacyComponents/TGVideoInfo.h>
#import <LegacyComponents/TGVideoMediaAttachment.h>
#import <LegacyComponents/TGLocalMessageMetaMediaAttachment.h>
#import <LegacyComponents/TGLocationMediaAttachment.h>
#import <LegacyComponents/TGImageMediaAttachment.h>
#import <LegacyComponents/TGMediaAttachment.h>
#import <LegacyComponents/TGImageInfo.h>
#import <LegacyComponents/TGMessage.h>
#import <LegacyComponents/TGStickerPack.h>
#import <LegacyComponents/TGStickerAssociation.h>
#import <LegacyComponents/TGPhotoMaskPosition.h>

#import <LegacyComponents/ActionStage.h>
#import <LegacyComponents/ASActor.h>
#import <LegacyComponents/ASHandle.h>
#import <LegacyComponents/ASQueue.h>
#import <LegacyComponents/ASWatcher.h>
#import <LegacyComponents/SGraphListNode.h>
#import <LegacyComponents/SGraphNode.h>
#import <LegacyComponents/SGraphObjectNode.h>

#import <LegacyComponents/TGLabel.h>
#import <LegacyComponents/TGToolbarButton.h>
#import <LegacyComponents/UIScrollView+TGHacks.h>
#import <LegacyComponents/TGAnimationBlockDelegate.h>
#import <LegacyComponents/TGBackdropView.h>
#import <LegacyComponents/UIImage+TG.h>
#import <LegacyComponents/TGStaticBackdropAreaData.h>
#import <LegacyComponents/TGStaticBackdropImageData.h>
#import <LegacyComponents/TGImageLuminanceMap.h>
#import <LegacyComponents/TGFullscreenContainerView.h>
#import <LegacyComponents/TGDoubleTapGestureRecognizer.h>
#import <LegacyComponents/TGModernButton.h>
#import <LegacyComponents/TGModernToolbarButton.h>
#import <LegacyComponents/TGModernBackToolbarButton.h>
#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>
#import <LegacyComponents/TGMenuView.h>
#import <LegacyComponents/TGImageView.h>
#import <LegacyComponents/UICollectionView+Utils.h>
#import <LegacyComponents/TGMessageImageViewOverlayView.h>
#import <LegacyComponents/TGLetteredAvatarView.h>
#import <LegacyComponents/TGGradientLabel.h>
#import <LegacyComponents/TGRemoteImageView.h>

#import <LegacyComponents/TGProgressSpinnerView.h>
#import <LegacyComponents/TGProgressWindow.h>

#import <LegacyComponents/TGMenuSheetController.h>
#import <LegacyComponents/TGMenuSheetButtonItemView.h>
#import <LegacyComponents/TGMenuSheetCollectionView.h>
#import <LegacyComponents/TGMenuSheetItemView.h>
#import <LegacyComponents/TGMenuSheetTitleItemView.h>
#import <LegacyComponents/TGMenuSheetView.h>

#import <LegacyComponents/HPGrowingTextView.h>
#import <LegacyComponents/HPTextViewInternal.h>
#import <LegacyComponents/TGInputTextTag.h>

#import <LegacyComponents/TGStickerKeyboardTabPanel.h>

#import <LegacyComponents/TGItemPreviewController.h>
#import <LegacyComponents/TGItemPreviewView.h>
#import <LegacyComponents/TGItemMenuSheetPreviewView.h>

#import <LegacyComponents/TGImageManager.h>
#import <LegacyComponents/TGDataResource.h>
#import <LegacyComponents/TGImageDataSource.h>
#import <LegacyComponents/TGImageManagerTask.h>

#import <LegacyComponents/TGRTLScreenEdgePanGestureRecognizer.h>
#import <LegacyComponents/TGPopoverController.h>
#import <LegacyComponents/TGNavigationController.h>
#import <LegacyComponents/TGNavigationBar.h>
#import <LegacyComponents/TGViewController.h>
#import <LegacyComponents/TGViewController+TGRecursiveEnumeration.h>
#import <LegacyComponents/TGOverlayController.h>
#import <LegacyComponents/TGOverlayControllerWindow.h>

#import <LegacyComponents/TGMediaAssetsLibrary.h>
#import <LegacyComponents/TGMediaAssetsModernLibrary.h>
#import <LegacyComponents/TGMediaAsset.h>
#import <LegacyComponents/TGMediaAssetFetchResult.h>
#import <LegacyComponents/TGMediaAssetFetchResultChange.h>
#import <LegacyComponents/TGMediaAssetGroup.h>
#import <LegacyComponents/TGMediaAssetMoment.h>
#import <LegacyComponents/TGMediaAssetMomentList.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>
#import <LegacyComponents/TGMediaSelectionContext.h>
#import <LegacyComponents/TGMediaEditingContext.h>

#import <LegacyComponents/TGModernGalleryZoomableItemViewContent.h>
#import <LegacyComponents/TGModernGalleryZoomableScrollView.h>
#import <LegacyComponents/TGModernGalleryZoomableScrollViewSwipeGestureRecognizer.h>
#import <LegacyComponents/TGModernGalleryVideoView.h>
#import <LegacyComponents/TGModernGalleryScrollView.h>
#import <LegacyComponents/TGModernGalleryItem.h>
#import <LegacyComponents/TGModernGalleryItemView.h>
#import <LegacyComponents/TGModernGalleryDefaultFooterAccessoryView.h>
#import <LegacyComponents/TGModernGalleryDefaultFooterView.h>
#import <LegacyComponents/TGModernGalleryDefaultHeaderView.h>
#import <LegacyComponents/TGModernGalleryDefaultInterfaceView.h>
#import <LegacyComponents/TGModernGalleryInterfaceView.h>
#import <LegacyComponents/TGModernGalleryImageItemContainerView.h>
#import <LegacyComponents/TGModernGalleryZoomableItemView.h>
#import <LegacyComponents/TGModernGalleryModel.h>
#import <LegacyComponents/TGModernGalleryTransitionView.h>
#import <LegacyComponents/TGModernGalleryView.h>
#import <LegacyComponents/TGModernGalleryContainerView.h>
#import <LegacyComponents/TGModernGalleryEmbeddedStickersHeaderView.h>
#import <LegacyComponents/TGModernGalleryController.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/PGPhotoEditorValues.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>
#import <LegacyComponents/AVURLAsset+TGMediaItem.h>
#import <LegacyComponents/UIImage+TGMediaEditableItem.h>
#import <LegacyComponents/TGMediaVideoConverter.h>

#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import <LegacyComponents/TGPhotoToolbarView.h>

#import <LegacyComponents/TGPaintingData.h>
#import <LegacyComponents/TGPaintUtils.h>
#import <LegacyComponents/TGPhotoPaintEntity.h>
#import <LegacyComponents/TGPhotoPaintStickerEntity.h>
#import <LegacyComponents/TGPaintUndoManager.h>

#import <LegacyComponents/PGCamera.h>
#import <LegacyComponents/PGCameraCaptureSession.h>
#import <LegacyComponents/PGCameraDeviceAngleSampler.h>
#import <LegacyComponents/PGCameraMomentSegment.h>
#import <LegacyComponents/PGCameraMomentSession.h>
#import <LegacyComponents/PGCameraMovieWriter.h>
#import <LegacyComponents/PGCameraShotMetadata.h>
#import <LegacyComponents/PGCameraVolumeButtonHandler.h>
#import <LegacyComponents/TGCameraPreviewView.h>
#import <LegacyComponents/TGCameraMainPhoneView.h>
#import <LegacyComponents/TGCameraMainTabletView.h>
#import <LegacyComponents/TGCameraMainView.h>
#import <LegacyComponents/TGCameraFlashActiveView.h>
#import <LegacyComponents/TGCameraFlashControl.h>
#import <LegacyComponents/TGCameraFlipButton.h>
#import <LegacyComponents/TGCameraInterfaceAssets.h>
#import <LegacyComponents/TGCameraModeControl.h>
#import <LegacyComponents/TGCameraSegmentsView.h>
#import <LegacyComponents/TGCameraShutterButton.h>
#import <LegacyComponents/TGCameraTimeCodeView.h>
#import <LegacyComponents/TGCameraZoomView.h>
#import <LegacyComponents/TGCameraPhotoPreviewController.h>
#import <LegacyComponents/TGCameraController.h>

#import <LegacyComponents/TGModernConversationTitleActivityIndicator.h>
#import <LegacyComponents/TGEmbedPIPButton.h>
#import <LegacyComponents/TGEmbedPIPPullArrowView.h>
#import <LegacyComponents/TGEmbedPlayerState.h>
#import <LegacyComponents/TGAttachmentCameraView.h>
#import <LegacyComponents/TGMediaAvatarMenuMixin.h>
#import <LegacyComponents/TGPasscodeEntryController.h>
#import <LegacyComponents/TGEmbedPlayerView.h>
#import <LegacyComponents/TGWallpaperInfo.h>
#import <LegacyComponents/TGMemoryImageCache.h>
#import <LegacyComponents/LegacyHTTPRequestOperation.h>
#import <LegacyComponents/LegacyComponentsAccessChecker.h>

#import <LegacyComponents/TGAttachmentCarouselItemView.h>
#import <LegacyComponents/TGMediaAssetsController.h>

#import <LegacyComponents/TGLocationMapViewController.h>
#import <LegacyComponents/TGLocationPickerController.h>
#import <LegacyComponents/TGLocationViewController.h>
#import <LegacyComponents/TGListsTableView.h>
#import <LegacyComponents/TGSearchBar.h>
#import <LegacyComponents/TGSearchDisplayMixin.h>

#import <LegacyComponents/TGPhotoEditorSliderView.h>

#import <LegacyComponents/TGClipboardGalleryMixin.h>
#import <LegacyComponents/TGClipboardGalleryPhotoItem.h>
#import <LegacyComponents/TGVideoMessageCaptureController.h>
#import <LegacyComponents/TGModernConversationInputMicButton.h>

#import <LegacyComponents/TGLocationPulseView.h>
#import <LegacyComponents/TGLocationWavesView.h>
#import <LegacyComponents/TGLocationLiveElapsedView.h>
#import <LegacyComponents/TGLocationLiveSessionItemView.h>

#import <LegacyComponents/TGTooltipView.h>
