#import <LegacyComponents/TGPaintingData.h>

#import <SSignalKit/SQueue.h>

#import <LegacyComponents/TGPaintUtils.h>
#import <LegacyComponents/TGPhotoPaintStickerEntity.h>

#import <LegacyComponents/TGMediaEditingContext.h>

@interface TGPaintingData ()
{
    UIImage *_image;
    UIImage *_stillImage;
    
    UIImage *(^_imageRetrievalBlock)(void);
    UIImage *(^_stillImageRetrievalBlock)(void);
}
@end

@implementation TGPaintingData

+ (instancetype)dataWithDrawingData:(NSData *)data entitiesData:(NSData *)entitiesData image:(UIImage *)image stillImage:(UIImage *)stillImage hasAnimation:(bool)hasAnimation stickers:(NSArray *)stickers
{
    TGPaintingData *paintingData = [[TGPaintingData alloc] init];
    paintingData->_drawingData = data;
    paintingData->_image = image;
    paintingData->_stillImage = stillImage;
    paintingData->_entitiesData = entitiesData;
    paintingData->_hasAnimation = hasAnimation;
    paintingData->_stickers = stickers;
    return paintingData;
}

+ (instancetype)dataWithPaintingImagePath:(NSString *)imagePath entitiesData:(NSData *)entitiesData hasAnimation:(bool)hasAnimation stickers:(NSArray *)stickers {
    TGPaintingData *paintingData = [[TGPaintingData alloc] init];
    paintingData->_imagePath = imagePath;
    paintingData->_entitiesData = entitiesData;
    paintingData->_hasAnimation = hasAnimation;
    paintingData->_stickers = stickers;
    return paintingData;
}

+ (instancetype)dataWithPaintingImagePath:(NSString *)imagePath
{
    TGPaintingData *paintingData = [[TGPaintingData alloc] init];
    paintingData->_imagePath = imagePath;
    return paintingData;
}

- (instancetype)dataForAnimation
{
    TGPaintingData *paintingData = [[TGPaintingData alloc] init];
    paintingData->_entitiesData = _entitiesData;
    paintingData->_hasAnimation = _hasAnimation;
    paintingData->_stickers = _stickers;
    return paintingData;
}

+ (void)storePaintingData:(TGPaintingData *)data inContext:(TGMediaEditingContext *)context forItem:(id<TGMediaEditableItem>)item forVideo:(bool)video
{
    [[TGPaintingData queue] dispatch:^
    {
        NSURL *dataUrl = nil;
        NSURL *entitiesDataUrl = nil;
        NSURL *imageUrl = nil;
        
        NSData *compressedDrawingData = TGPaintGZipDeflate(data.drawingData);
        NSData *compressedEntitiesData = TGPaintGZipDeflate(data.entitiesData);
        [context setPaintingData:compressedDrawingData entitiesData:compressedEntitiesData image:data.image stillImage:data.stillImage forItem:item dataUrl:&dataUrl entitiesDataUrl:&entitiesDataUrl imageUrl:&imageUrl forVideo:video];
        
        __weak TGMediaEditingContext *weakContext = context;
        [[SQueue mainQueue] dispatch:^
        {
            data->_imagePath = imageUrl.path;
            
            data->_imageRetrievalBlock = ^UIImage *
            {
                __strong TGMediaEditingContext *strongContext = weakContext;
                if (strongContext != nil)
                    return [strongContext paintingImageForItem:item];
                
                return nil;
            };
            
            data->_stillImageRetrievalBlock = ^UIImage *
            {
                __strong TGMediaEditingContext *strongContext = weakContext;
                if (strongContext != nil)
                    return [strongContext stillPaintingImageForItem:item];
                
                return nil;
            };
        }];
    }];
}

+ (void)facilitatePaintingData:(TGPaintingData *)data
{
    [[TGPaintingData queue] dispatch:^
    {
        if (data->_imagePath != nil)
            data->_image = nil;
    }];
}


- (UIImage *)image
{
    if (_image != nil)
        return _image;
    else if (_imageRetrievalBlock != nil)
        return _imageRetrievalBlock();
    else
        return nil;
}

- (UIImage *)stillImage
{
    if (_stillImage != nil)
        return _stillImage;
    else if (_stillImageRetrievalBlock != nil)
        return _stillImageRetrievalBlock();
    else
        return nil;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    TGPaintingData *data = (TGPaintingData *)object;
    return [data.entitiesData isEqual:self.entitiesData] && ((data.drawingData != nil && [data.drawingData isEqualToData:self.drawingData]) || (data.drawingData == nil && self.drawingData == nil));
}

+ (SQueue *)queue
{
    static dispatch_once_t onceToken;
    static SQueue *queue;
    dispatch_once(&onceToken, ^
    {
        queue = [SQueue wrapConcurrentNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)];
    });
    return queue;
}

@end
