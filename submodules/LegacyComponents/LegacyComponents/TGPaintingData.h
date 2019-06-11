#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class TGPaintUndoManager;
@class TGMediaEditingContext;
@protocol TGMediaEditableItem;

@interface TGPaintingData : NSObject

@property (nonatomic, readonly) NSString *imagePath;
@property (nonatomic, readonly) NSString *dataPath;
@property (nonatomic, readonly) NSArray *entities;
@property (nonatomic, readonly) TGPaintUndoManager *undoManager;
@property (nonatomic, readonly) NSArray *stickers;

@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) UIImage *image;

+ (instancetype)dataWithPaintingData:(NSData *)data image:(UIImage *)image entities:(NSArray *)entities undoManager:(TGPaintUndoManager *)undoManager;

+ (instancetype)dataWithPaintingImagePath:(NSString *)imagePath;

+ (void)storePaintingData:(TGPaintingData *)data inContext:(TGMediaEditingContext *)context forItem:(id<TGMediaEditableItem>)item forVideo:(bool)video;
+ (void)facilitatePaintingData:(TGPaintingData *)data;

@end
