#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class TGPaintUndoManager;
@class TGMediaEditingContext;
@protocol TGMediaEditableItem;

@interface TGPaintingData : NSObject

@property (nonatomic, readonly) NSString *imagePath;

@property (nonatomic, readonly) NSData *drawingData;
@property (nonatomic, readonly) NSData *entitiesData;

@property (nonatomic, readonly) UIImage *image;
@property (nonatomic, readonly) UIImage *stillImage;

@property (nonatomic, readonly) NSArray *stickers;

@property (nonatomic, readonly) bool hasAnimation;

+ (instancetype)dataWithDrawingData:(NSData *)data entitiesData:(NSData *)entitiesData image:(UIImage *)image stillImage:(UIImage *)stillImage hasAnimation:(bool)hasAnimation;

+ (instancetype)dataWithPaintingImagePath:(NSString *)imagePath entitiesData:(NSData *)entitiesData;

+ (instancetype)dataWithPaintingImagePath:(NSString *)imagePath;

- (instancetype)dataForAnimation;

+ (void)storePaintingData:(TGPaintingData *)data inContext:(TGMediaEditingContext *)context forItem:(id<TGMediaEditableItem>)item forVideo:(bool)video;
+ (void)facilitatePaintingData:(TGPaintingData *)data;

@end
