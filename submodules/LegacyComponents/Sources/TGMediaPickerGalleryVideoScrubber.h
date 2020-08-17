#import <UIKit/UIKit.h>

@protocol TGMediaPickerGalleryVideoScrubberDelegate;
@protocol TGMediaPickerGalleryVideoScrubberDataSource;

@interface TGMediaPickerGalleryVideoScrubber : UIControl

@property (nonatomic, weak) id<TGMediaPickerGalleryVideoScrubberDelegate> delegate;
@property (nonatomic, weak) id<TGMediaPickerGalleryVideoScrubberDataSource> dataSource;

@property (nonatomic, readonly) NSTimeInterval duration;

@property (nonatomic, assign) bool allowsTrimming;
@property (nonatomic, readonly) bool hasTrimming;
@property (nonatomic, assign) NSTimeInterval trimStartValue;
@property (nonatomic, assign) NSTimeInterval trimEndValue;

@property (nonatomic, assign) bool hasDotPicker;
- (void)setDotVideoView:(UIView *)dotVideoView;
- (void)setDotImage:(UIImage *)dotImage;

@property (nonatomic, assign) NSTimeInterval minimumLength;
@property (nonatomic, assign) NSTimeInterval maximumLength;

@property (nonatomic, assign) bool disableZoom;
@property (nonatomic, assign) bool disableTimeDisplay;

@property (nonatomic, readonly) bool isScrubbing;
@property (nonatomic, assign) bool isPlaying;
@property (nonatomic, assign) NSTimeInterval value;
- (void)setValue:(NSTimeInterval)value resetPosition:(bool)resetPosition;

- (void)setTrimApplied:(bool)trimApplied;

- (void)resetToStart;

- (void)reloadData;
- (void)reloadDataAndReset:(bool)reset;

- (void)reloadThumbnails;
- (void)ignoreThumbnails;
- (void)resetThumbnails;

- (void)updateThumbnails;

- (void)setThumbnailImage:(UIImage *)image forTimestamp:(NSTimeInterval)timestamp index:(NSInteger)index isSummaryThubmnail:(bool)isSummaryThumbnail;

- (CGPoint)scrubberPositionForPosition:(NSTimeInterval)position;

- (void)_updateScrubberAnimationsAndResetCurrentPosition:(bool)resetCurrentPosition;

@end

@protocol TGMediaPickerGalleryVideoScrubberDelegate <NSObject>

- (void)videoScrubberDidBeginScrubbing:(TGMediaPickerGalleryVideoScrubber *)videoScrubber;
- (void)videoScrubberDidEndScrubbing:(TGMediaPickerGalleryVideoScrubber *)videoScrubber;
- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)videoScrubber valueDidChange:(NSTimeInterval)position;

- (void)videoScrubberDidBeginEditing:(TGMediaPickerGalleryVideoScrubber *)videoScrubber;
- (void)videoScrubberDidEndEditing:(TGMediaPickerGalleryVideoScrubber *)videoScrubber;
- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)videoScrubber editingStartValueDidChange:(NSTimeInterval)startValue;
- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)videoScrubber editingEndValueDidChange:(NSTimeInterval)endValue;

- (void)videoScrubberDidFinishRequestingThumbnails:(TGMediaPickerGalleryVideoScrubber *)videoScrubber;
- (void)videoScrubberDidCancelRequestingThumbnails:(TGMediaPickerGalleryVideoScrubber *)videoScrubber;

@end

@protocol TGMediaPickerGalleryVideoScrubberDataSource <NSObject>

- (NSTimeInterval)videoScrubberDuration:(TGMediaPickerGalleryVideoScrubber *)videoScrubber;

- (NSArray *)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)videoScrubber evenlySpacedTimestamps:(NSInteger)count startingAt:(NSTimeInterval)startTimestamp endingAt:(NSTimeInterval)endTimestamp;

- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)videoScrubber requestThumbnailImagesForTimestamps:(NSArray *)timestamps size:(CGSize)size isSummaryThumbnails:(bool)isSummaryThumbnails;

- (CGFloat)videoScrubberThumbnailAspectRatio:(TGMediaPickerGalleryVideoScrubber *)videoScrubber;

- (CGSize)videoScrubberOriginalSize:(TGMediaPickerGalleryVideoScrubber *)videoScrubber cropRect:(CGRect *)cropRect cropOrientation:(UIImageOrientation *)cropOrientation cropMirrored:(bool *)cropMirrored;

@end
