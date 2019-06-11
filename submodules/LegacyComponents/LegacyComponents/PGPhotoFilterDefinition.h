#import <Foundation/Foundation.h>

typedef enum {
    PGPhotoFilterTypePassThrough,
    PGPhotoFilterTypeLookup,
    PGPhotoFilterTypeCustom
} PGPhotoFilterType;

@interface PGPhotoFilterDefinition : NSObject

@property (readonly, nonatomic) NSString *identifier;
@property (readonly, nonatomic) NSString *title;
@property (readonly, nonatomic) PGPhotoFilterType type;
@property (readonly, nonatomic) NSString *lookupFilename;
@property (readonly, nonatomic) NSString *shaderFilename;
@property (readonly, nonatomic) NSArray *textureFilenames;

+ (PGPhotoFilterDefinition *)originalFilterDefinition;
+ (PGPhotoFilterDefinition *)definitionWithDictionary:(NSDictionary *)dictionary;

@end
