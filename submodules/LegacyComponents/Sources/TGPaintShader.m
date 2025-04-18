#import "TGPaintShader.h"

#import "LegacyComponentsInternal.h"

#include <OpenGLES/ES2/glext.h>

#import <LegacyComponents/TGPaintUtils.h>

@implementation TGPaintShader

- (instancetype)initWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader attributes:(NSArray *)attributes uniforms:(NSArray *)uniforms
{
    self = [super init];
    if (self != nil)
    {
        GLuint vShader = 0;
        GLuint fShader = 0;
        
        _program = glCreateProgram();
        
        NSString *vShaderFilename = TGComponentsPathForResource(vertexShader, @"vsh");
        if (![self _compileShader:&vShader type:GL_VERTEX_SHADER fileName:vShaderFilename])
        {
            [self _destroyVertexShader:vShader fragmentShader:fShader program:_program];
            return nil;
        }
        
        NSString *fShaderFilename = TGComponentsPathForResource(fragmentShader, @"fsh");
        if (![self _compileShader:&fShader type:GL_FRAGMENT_SHADER fileName:fShaderFilename])
        {
            [self _destroyVertexShader:vShader fragmentShader:fShader program:_program];
            return nil;
        }
        
        glAttachShader(_program, vShader);
        glAttachShader(_program, fShader);
        
        [attributes enumerateObjectsUsingBlock:^(NSString *attribute, NSUInteger index, __unused BOOL *stop)
        {
            glBindAttribLocation(_program, (GLuint)index, [attribute UTF8String]);
        }];
        
        if (![self _linkProgram:_program])
        {
            [self _destroyVertexShader:vShader fragmentShader:fShader program:_program];
            return nil;
        }
        
        NSMutableDictionary *uniformsMap = [[NSMutableDictionary alloc] init];
        for (NSString *uniform in uniforms)
        {
            uniformsMap[uniform] = @(glGetUniformLocation(_program, [uniform UTF8String]));
        }
        _uniforms = uniformsMap;
        
        if (vShader != 0)
        {
            glDeleteShader(vShader);
            vShader = 0;
        }
        
        if (fShader != 0)
        {
            glDeleteShader(fShader);
            fShader = 0;
        }
    }
    return self;
}

- (void)dealloc
{
    [self cleanResources];
}

- (void)cleanResources
{
    glDeleteProgram(_program);
    _program = 0;
}

- (GLuint)uniformForKey:(NSString *)key
{
    return [_uniforms[key] unsignedIntValue];
}

#pragma mark - 

- (GLint)_compileShader:(GLuint *)shader type:(GLenum)type fileName:(NSString *)fileName
{
    GLint status;
    
    const GLchar *sources = (GLchar *)[[NSString stringWithContentsOfFile:fileName encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!sources) {
        NSLog(@"Failed to load vertex shader");
        return 0;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &sources, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to compile shader: %@", fileName);
    }
    
    return status;
}

- (GLint)_linkProgram:(GLuint)program
{
    GLint status;
    
    glLinkProgram(program);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        TGLegacyLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE)
        TGLegacyLog(@"Failed to link program %d", program);
    
    return status;
}

- (void)_destroyVertexShader:(GLuint)vertexShader fragmentShader:(GLuint)fragmentShader program:(GLuint)program
{
    if (vertexShader != 0)
        glDeleteShader(vertexShader);
    
    if (fragmentShader != 0)
        glDeleteShader(fragmentShader);
    
    if (program != 0)
        glDeleteProgram(program);
}

@end
