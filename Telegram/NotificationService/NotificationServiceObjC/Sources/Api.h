#import <Foundation/Foundation.h>

/*
 * Layer 1
 */

@class Api1_Photo;
@class Api1_Photo_photoEmpty;
@class Api1_Photo_photo;

@class Api1_PhotoSize;
@class Api1_PhotoSize_photoSizeEmpty;
@class Api1_PhotoSize_photoSize;
@class Api1_PhotoSize_photoCachedSize;
@class Api1_PhotoSize_photoStrippedSize;
@class Api1_PhotoSize_photoSizeProgressive;

@class Api1_FileLocation;
@class Api1_FileLocation_fileLocationToBeDeprecated;

@class Api1_DocumentAttribute;
@class Api1_DocumentAttribute_documentAttributeImageSize;
@class Api1_DocumentAttribute_documentAttributeAnimated;
@class Api1_DocumentAttribute_documentAttributeSticker;
@class Api1_DocumentAttribute_documentAttributeVideo;
@class Api1_DocumentAttribute_documentAttributeAudio;
@class Api1_DocumentAttribute_documentAttributeFilename;
@class Api1_DocumentAttribute_documentAttributeHasStickers;

@class Api1_InputStickerSet;
@class Api1_InputStickerSet_inputStickerSetEmpty;
@class Api1_InputStickerSet_inputStickerSetID;
@class Api1_InputStickerSet_inputStickerSetShortName;

@class Api1_InputFileLocation;
@class Api1_InputFileLocation_inputPhotoFileLocation;
@class Api1_InputFileLocation_inputDocumentFileLocation;

@class Api1_MaskCoords;
@class Api1_MaskCoords_maskCoords;

@class Api1_Document;
@class Api1_Document_document;


@interface Api1__Environment : NSObject

+ (NSData *)serializeObject:(id)object;
+ (id)parseObject:(NSData *)data;

@end

@interface Api1_FunctionContext : NSObject

@property (nonatomic, strong, readonly) NSData *payload;
@property (nonatomic, copy, readonly) id (^responseParser)(NSData *);
@property (nonatomic, strong, readonly) id metadata;

- (instancetype)initWithPayload:(NSData *)payload responseParser:(id (^)(NSData *))responseParser metadata:(id)metadata;

@end

/*
 * Types 1
 */

@interface Api1_Photo : NSObject

@property (nonatomic, strong, readonly) NSNumber * pid;

+ (Api1_Photo_photoEmpty *)photoEmptyWithPid:(NSNumber *)pid;
+ (Api1_Photo_photo *)photoWithFlags:(NSNumber *)flags pid:(NSNumber *)pid accessHash:(NSNumber *)accessHash fileReference:(NSData *)fileReference date:(NSNumber *)date sizes:(NSArray *)sizes dcId:(NSNumber *)dcId;

@end

@interface Api1_Photo_photoEmpty : Api1_Photo

@end

@interface Api1_Photo_photo : Api1_Photo

@property (nonatomic, strong, readonly) NSNumber * flags;
@property (nonatomic, strong, readonly) NSNumber * accessHash;
@property (nonatomic, strong, readonly) NSData * fileReference;
@property (nonatomic, strong, readonly) NSNumber * date;
@property (nonatomic, strong, readonly) NSArray * sizes;
@property (nonatomic, strong, readonly) NSNumber * dcId;

@end


@interface Api1_PhotoSize : NSObject

@property (nonatomic, strong, readonly) NSString * type;

+ (Api1_PhotoSize_photoSizeEmpty *)photoSizeEmptyWithType:(NSString *)type;
+ (Api1_PhotoSize_photoSize *)photoSizeWithType:(NSString *)type location:(Api1_FileLocation *)location w:(NSNumber *)w h:(NSNumber *)h size:(NSNumber *)size;
+ (Api1_PhotoSize_photoCachedSize *)photoCachedSizeWithType:(NSString *)type location:(Api1_FileLocation *)location w:(NSNumber *)w h:(NSNumber *)h bytes:(NSData *)bytes;
+ (Api1_PhotoSize_photoStrippedSize *)photoStrippedSizeWithType:(NSString *)type bytes:(NSData *)bytes;
+ (Api1_PhotoSize_photoSizeProgressive *)photoSizeProgressiveWithType:(NSString *)type location:(Api1_FileLocation *)location w:(NSNumber *)w h:(NSNumber *)h sizes:(NSArray *)sizes;

@end

@interface Api1_PhotoSize_photoSizeEmpty : Api1_PhotoSize

@end

@interface Api1_PhotoSize_photoSize : Api1_PhotoSize

@property (nonatomic, strong, readonly) Api1_FileLocation * location;
@property (nonatomic, strong, readonly) NSNumber * w;
@property (nonatomic, strong, readonly) NSNumber * h;
@property (nonatomic, strong, readonly) NSNumber * size;

@end

@interface Api1_PhotoSize_photoCachedSize : Api1_PhotoSize

@property (nonatomic, strong, readonly) Api1_FileLocation * location;
@property (nonatomic, strong, readonly) NSNumber * w;
@property (nonatomic, strong, readonly) NSNumber * h;
@property (nonatomic, strong, readonly) NSData * bytes;

@end

@interface Api1_PhotoSize_photoStrippedSize : Api1_PhotoSize

@property (nonatomic, strong, readonly) NSData * bytes;

@end

@interface Api1_PhotoSize_photoSizeProgressive : Api1_PhotoSize

@property (nonatomic, strong) Api1_FileLocation * location;
@property (nonatomic, strong) NSNumber * w;
@property (nonatomic, strong) NSNumber * h;
@property (nonatomic, strong) NSArray * sizes;

@end

@interface Api1_FileLocation : NSObject

@property (nonatomic, strong, readonly) NSNumber * volumeId;
@property (nonatomic, strong, readonly) NSNumber * localId;

+ (Api1_FileLocation_fileLocationToBeDeprecated *)fileLocationToBeDeprecatedWithVolumeId:(NSNumber *)volumeId localId:(NSNumber *)localId;

@end

@interface Api1_FileLocation_fileLocationToBeDeprecated : Api1_FileLocation

@end


@interface Api1_DocumentAttribute : NSObject

+ (Api1_DocumentAttribute_documentAttributeImageSize *)documentAttributeImageSizeWithW:(NSNumber *)w h:(NSNumber *)h;
+ (Api1_DocumentAttribute_documentAttributeAnimated *)documentAttributeAnimated;
+ (Api1_DocumentAttribute_documentAttributeSticker *)documentAttributeStickerWithFlags:(NSNumber *)flags alt:(NSString *)alt stickerset:(Api1_InputStickerSet *)stickerset maskCoords:(Api1_MaskCoords *)maskCoords;
+ (Api1_DocumentAttribute_documentAttributeVideo *)documentAttributeVideoWithFlags:(NSNumber *)flags duration:(NSNumber *)duration w:(NSNumber *)w h:(NSNumber *)h;
+ (Api1_DocumentAttribute_documentAttributeAudio *)documentAttributeAudioWithFlags:(NSNumber *)flags duration:(NSNumber *)duration title:(NSString *)title performer:(NSString *)performer waveform:(NSData *)waveform;
+ (Api1_DocumentAttribute_documentAttributeFilename *)documentAttributeFilenameWithFileName:(NSString *)fileName;
+ (Api1_DocumentAttribute_documentAttributeHasStickers *)documentAttributeHasStickers;

@end

@interface Api1_DocumentAttribute_documentAttributeImageSize : Api1_DocumentAttribute

@property (nonatomic, strong, readonly) NSNumber * w;
@property (nonatomic, strong, readonly) NSNumber * h;

@end

@interface Api1_DocumentAttribute_documentAttributeAnimated : Api1_DocumentAttribute

@end

@interface Api1_DocumentAttribute_documentAttributeSticker : Api1_DocumentAttribute

@property (nonatomic, strong, readonly) NSNumber * flags;
@property (nonatomic, strong, readonly) NSString * alt;
@property (nonatomic, strong, readonly) Api1_InputStickerSet * stickerset;
@property (nonatomic, strong, readonly) Api1_MaskCoords * maskCoords;

@end

@interface Api1_DocumentAttribute_documentAttributeVideo : Api1_DocumentAttribute

@property (nonatomic, strong, readonly) NSNumber * flags;
@property (nonatomic, strong, readonly) NSNumber * duration;
@property (nonatomic, strong, readonly) NSNumber * w;
@property (nonatomic, strong, readonly) NSNumber * h;

@end

@interface Api1_DocumentAttribute_documentAttributeAudio : Api1_DocumentAttribute

@property (nonatomic, strong, readonly) NSNumber * flags;
@property (nonatomic, strong, readonly) NSNumber * duration;
@property (nonatomic, strong, readonly) NSString * title;
@property (nonatomic, strong, readonly) NSString * performer;
@property (nonatomic, strong, readonly) NSData * waveform;

@end

@interface Api1_DocumentAttribute_documentAttributeFilename : Api1_DocumentAttribute

@property (nonatomic, strong, readonly) NSString * fileName;

@end

@interface Api1_DocumentAttribute_documentAttributeHasStickers : Api1_DocumentAttribute

@end


@interface Api1_InputStickerSet : NSObject

+ (Api1_InputStickerSet_inputStickerSetEmpty *)inputStickerSetEmpty;
+ (Api1_InputStickerSet_inputStickerSetID *)inputStickerSetIDWithPid:(NSNumber *)pid accessHash:(NSNumber *)accessHash;
+ (Api1_InputStickerSet_inputStickerSetShortName *)inputStickerSetShortNameWithShortName:(NSString *)shortName;

@end

@interface Api1_InputStickerSet_inputStickerSetEmpty : Api1_InputStickerSet

@end

@interface Api1_InputStickerSet_inputStickerSetID : Api1_InputStickerSet

@property (nonatomic, strong, readonly) NSNumber * pid;
@property (nonatomic, strong, readonly) NSNumber * accessHash;

@end

@interface Api1_InputStickerSet_inputStickerSetShortName : Api1_InputStickerSet

@property (nonatomic, strong, readonly) NSString * shortName;

@end


@interface Api1_InputFileLocation : NSObject

@property (nonatomic, strong, readonly) NSNumber * pid;
@property (nonatomic, strong, readonly) NSNumber * accessHash;
@property (nonatomic, strong, readonly) NSData * fileReference;
@property (nonatomic, strong, readonly) NSString * thumbSize;

+ (Api1_InputFileLocation_inputPhotoFileLocation *)inputPhotoFileLocationWithPid:(NSNumber *)pid accessHash:(NSNumber *)accessHash fileReference:(NSData *)fileReference thumbSize:(NSString *)thumbSize;
+ (Api1_InputFileLocation_inputDocumentFileLocation *)inputDocumentFileLocationWithPid:(NSNumber *)pid accessHash:(NSNumber *)accessHash fileReference:(NSData *)fileReference thumbSize:(NSString *)thumbSize;

@end

@interface Api1_InputFileLocation_inputPhotoFileLocation : Api1_InputFileLocation

@end

@interface Api1_InputFileLocation_inputDocumentFileLocation : Api1_InputFileLocation

@end


@interface Api1_MaskCoords : NSObject

@property (nonatomic, strong, readonly) NSNumber * n;
@property (nonatomic, strong, readonly) NSNumber * x;
@property (nonatomic, strong, readonly) NSNumber * y;
@property (nonatomic, strong, readonly) NSNumber * zoom;

+ (Api1_MaskCoords_maskCoords *)maskCoordsWithN:(NSNumber *)n x:(NSNumber *)x y:(NSNumber *)y zoom:(NSNumber *)zoom;

@end

@interface Api1_MaskCoords_maskCoords : Api1_MaskCoords

@end


@interface Api1_Document : NSObject

@property (nonatomic, strong, readonly) NSNumber * flags;
@property (nonatomic, strong, readonly) NSNumber * pid;
@property (nonatomic, strong, readonly) NSNumber * accessHash;
@property (nonatomic, strong, readonly) NSData * fileReference;
@property (nonatomic, strong, readonly) NSNumber * date;
@property (nonatomic, strong, readonly) NSString * mimeType;
@property (nonatomic, strong, readonly) NSNumber * size;
@property (nonatomic, strong, readonly) NSArray * thumbs;
@property (nonatomic, strong, readonly) NSNumber * dcId;
@property (nonatomic, strong, readonly) NSArray * attributes;

+ (Api1_Document_document *)documentWithFlags:(NSNumber *)flags pid:(NSNumber *)pid accessHash:(NSNumber *)accessHash fileReference:(NSData *)fileReference date:(NSNumber *)date mimeType:(NSString *)mimeType size:(NSNumber *)size thumbs:(NSArray *)thumbs dcId:(NSNumber *)dcId attributes:(NSArray *)attributes;

@end

@interface Api1_Document_document : Api1_Document

@end


/*
 * Functions 1
 */

@interface Api1: NSObject

@end
