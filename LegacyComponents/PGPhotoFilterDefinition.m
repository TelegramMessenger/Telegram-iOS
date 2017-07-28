#import "PGPhotoFilterDefinition.h"

@implementation PGPhotoFilterDefinition

+ (PGPhotoFilterDefinition *)originalFilterDefinition
{
    PGPhotoFilterDefinition *definition = [[PGPhotoFilterDefinition alloc] init];
    definition->_type = PGPhotoFilterTypePassThrough;
    definition->_identifier = @"0_0";
    definition->_title = @"Original";
    
    return definition;
}

+ (PGPhotoFilterDefinition *)definitionWithDictionary:(NSDictionary *)dictionary
{
    PGPhotoFilterDefinition *definition = [[PGPhotoFilterDefinition alloc] init];
    
    if ([dictionary[@"type"] isEqualToString:@"lookup"])
        definition->_type = PGPhotoFilterTypeLookup;
    else if ([dictionary[@"type"] isEqualToString:@"custom"])
        definition->_type = PGPhotoFilterTypeCustom;
    else
        return nil;
    
    definition->_identifier = dictionary[@"id"];
    definition->_title = dictionary[@"title"];
    definition->_lookupFilename = dictionary[@"lookup_name"];
    definition->_shaderFilename = dictionary[@"shader_name"];
    definition->_textureFilenames = dictionary[@"texture_names"];
    
    return definition;
}

@end
