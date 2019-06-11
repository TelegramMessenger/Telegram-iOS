#import "TGPaintShaderSet.h"

#import "TGPaintShader.h"
#import <LegacyComponents/TGPaintUtils.h>

@implementation TGPaintShaderSet

+ (NSDictionary *)availableShaders
{
    return @
    {
        @"brush": @
        {
            @"vertex": @"Paint_Brush",
            @"fragment": @"Paint_Brush",
            @"attributes": @[ @"inPosition", @"inTexcoord", @"alpha" ],
            @"uniforms" : @[ @"mvpMatrix", @"texture" ]
        },
        
        @"brushLight": @
        {
            @"vertex": @"Paint_Brush",
            @"fragment": @"Paint_BrushLight",
            @"attributes": @[ @"inPosition", @"inTexcoord", @"alpha" ],
            @"uniforms" : @[ @"mvpMatrix", @"texture" ]
        },
        
        @"brushLightPreview": @
        {
            @"vertex": @"Paint_Blit",
            @"fragment": @"Paint_BrushLightPreview",
            @"attributes": @[ @"inPosition", @"inTexcoord" ],
            @"uniforms": @[ @"mvpMatrix", @"mask", @"color" ]
        },
        
        @"blit": @
        {
            @"vertex": @"Paint_Blit",
            @"fragment": @"Paint_Blit",
            @"attributes": @[ @"inPosition", @"inTexcoord" ],
            @"uniforms": @[ @"mvpMatrix", @"texture" ]
        },
        
        @"blitWithMaskLight": @
        {
            @"vertex": @"Paint_Blit",
            @"fragment": @"Paint_BlitWithMaskLight",
            @"attributes": @[ @"inPosition", @"inTexcoord" ],
            @"uniforms": @[ @"mvpMatrix", @"texture", @"mask", @"color" ]
        },
        
        @"blitWithMask": @
        {
            @"vertex": @"Paint_Blit",
            @"fragment": @"Paint_BlitWithMask",
            @"attributes": @[ @"inPosition", @"inTexcoord" ],
            @"uniforms": @[ @"mvpMatrix", @"texture", @"mask", @"color" ]
        },
        
        @"blitWithEraseMask": @
        {
            @"vertex": @"Paint_Blit",
            @"fragment": @"Paint_BlitWithEraseMask",
            @"attributes": @[ @"inPosition", @"inTexcoord" ],
            @"uniforms": @[ @"mvpMatrix", @"texture", @"mask"]
        },
        
        @"compositeWithMask": @
        {
            @"vertex": @"Paint_Blit",
            @"fragment": @"Paint_CompositeWithMask",
            @"attributes": @[ @"inPosition", @"inTexcoord" ],
            @"uniforms": @[ @"mvpMatrix", @"texture", @"mask", @"color" ]
        },
        
        @"compositeWithMaskLight": @
        {
            @"vertex": @"Paint_Blit",
            @"fragment": @"Paint_CompositeWithMaskLight",
            @"attributes": @[ @"inPosition", @"inTexcoord" ],
            @"uniforms": @[ @"mvpMatrix", @"texture", @"mask", @"color" ]
        },
        
        @"compositeWithEraseMask": @
        {
            @"vertex": @"Paint_Blit",
            @"fragment": @"Paint_CompositeWithEraseMask",
            @"attributes": @[ @"inPosition", @"inTexcoord" ],
            @"uniforms": @[ @"mvpMatrix", @"texture", @"mask" ]
        },
        
        @"nonPremultipliedBlit": @
        {
            @"vertex": @"Paint_Blit",
            @"fragment": @"Paint_NonPremultipliedBlit",
            @"attributes": @[ @"inPosition", @"inTexcoord" ],
            @"uniforms": @[ @"mvpMatrix", @"texture" ]
        }
    };
}

+ (NSDictionary *)setup
{
    NSDictionary *shaderSet = [self availableShaders];
    
    NSMutableDictionary *shaders = [NSMutableDictionary dictionary];
    for (NSString *key in shaderSet.keyEnumerator)
    {
        NSDictionary *desc = shaderSet[key];
        NSString *vertex = desc[@"vertex"];
        NSString *fragment = desc[@"fragment"];
        NSArray *attributes = desc[@"attributes"];
        NSArray *uniforms = desc[@"uniforms"];
        
        TGPaintShader *shader = [[TGPaintShader alloc] initWithVertexShader:vertex fragmentShader:fragment attributes:attributes uniforms:uniforms];
        shaders[key] = shader;
    }

    TGPaintHasGLError();
    
    return shaders;
}

@end
