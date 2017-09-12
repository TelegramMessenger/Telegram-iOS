#import <UIKit/UIKit.h>

@protocol TGVideoMessageScrubberDelegate;
@protocol TGVideoMessageScrubberDataSource;

@interface TGVideoMessageScrubber : UIView

@property (nonatomic, weak) id<TGVideoMessageScrubberDelegate> delegate;
@property (nonatomic, weak) id<TGVideoMessageScrubberDataSource> dataSource;

@property (nonatomic, readonly) NSTimeInterval duration;

@property (nonatomic, assign) bool allowsTrimming;
@property (nonatomic, readonly) bool hasTrimming;
@property (nonatomic, assign) NSTimeInterval trimStartValue;
@property (nonatomic, assign) NSTimeInterval trimEndValue;

@property (nonatomic, assign) NSTimeInterval maximumLength;


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

- (void)setThumbnailImage:(UIImage *)image forTimestamp:(NSTimeInterval)timestamp isSummaryThubmnail:(bool)isSummaryThumbnail;

@end

@protocol TGVideoMessageScrubberDelegate <NSObject>

- (void)videoScrubberDidBeginScrubbing:(TGVideoMessageScrubber *)videoScrubber;
- (void)videoScrubberDidEndScrubbing:(TGVideoMessageScrubber *)videoScrubber;
- (void)videoScrubber:(TGVideoMessageScrubber *)videoScrubber valueDidChange:(NSTimeInterval)position;

- (void)videoScrubberDidBeginEditing:(TGVideoMessageScrubber *)videoScrubber;
- (void)videoScrubberDidEndEditing:(TGVideoMessageScrubber *)videoScrubber endValueChanged:(bool)endValueChanged;
- (void)videoScrubber:(TGVideoMessageScrubber *)videoScrubber editingStartValueDidChange:(NSTimeInterval)startValue;
- (void)videoScrubber:(TGVideoMessageScrubber *)videoScrubber editingEndValueDidChange:(NSTimeInterval)endValue;

- (void)videoScrubberDidFinishRequestingThumbnails:(TGVideoMessageScrubber *)videoScrubber;
- (void)videoScrubberDidCancelRequestingThumbnails:(TGVideoMessageScrubber *)videoScrubber;

@end

@protocol TGVideoMessageScrubberDataSource <NSObject>

- (NSTimeInterval)videoScrubberDuration:(TGVideoMessageScrubber *)videoScrubber;

- (NSArray *)videoScrubber:(TGVideoMessageScrubber *)videoScrubber evenlySpacedTimestamps:(NSInteger)count startingAt:(NSTimeInterval)startTimestamp endingAt:(NSTimeInterval)endTimestamp;

- (void)videoScrubber:(TGVideoMessageScrubber *)videoScrubber requestThumbnailImagesForTimestamps:(NSArray *)timestamps size:(CGSize)size isSummaryThumbnails:(bool)isSummaryThumbnails;

- (CGFloat)videoScrubberThumbnailAspectRatio:(TGVideoMessageScrubber *)videoScrubber;

- (CGSize)videoScrubberOriginalSize:(TGVideoMessageScrubber *)videoScrubber cropRect:(CGRect *)cropRect cropOrientation:(UIImageOrientation *)cropOrientation cropMirrored:(bool *)cropMirrored;

@end
