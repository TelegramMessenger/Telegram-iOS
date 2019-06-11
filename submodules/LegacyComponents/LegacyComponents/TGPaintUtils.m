#import "TGPaintUtils.h"
#import "TGPhotoEditorUtils.h"

#import "LegacyComponentsInternal.h"

#import <zlib.h>

void TGPaintHasGLError_(const char* file, int line) {
    GLenum error = glGetError();
    if (error != 0)
    {
        NSString *message;
        switch (error)
        {
            case GL_INVALID_ENUM:
                message = @"GL_INVALID_ENUM";
                break;
            
            case GL_INVALID_FRAMEBUFFER_OPERATION:
                message = @"GL_INVALID_FRAMEBUFFER_OPERATION";
                break;
                
            case GL_INVALID_OPERATION:
                message = @"GL_INVALID_OPERATION";
                break;
                
            case GL_INVALID_VALUE:
                message = @"GL_INVALID_VALUE";
                break;
                
            case GL_OUT_OF_MEMORY:
                message = @"GL_OUT_OF_MEMORY";
                break;
                
            default:
                message = [NSString stringWithFormat:@"UNKNOWN: 0x%x", error];
                break;
        }
        
        TGLegacyLog(@"PAINT ERROR: glGetError %@ at %s:%d", message, file, line);
    }
}

void TGSetupColorUniform(GLint location, UIColor *color)
{
    NSInteger componentsCount = CGColorGetNumberOfComponents(color.CGColor);
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    CGFloat red = 0.0f;
    CGFloat green = 0.0f;
    CGFloat blue = 0.0f;
    CGFloat alpha = 1.0f;
    
    if (componentsCount == 4)
    {
        red = components[0];
        green = components[1];
        blue = components[2];
        alpha = components[3];
    }
    else
    {
        red = green = blue = components[0];
    }
    
    glUniform4f(location, (GLfloat)red, (GLfloat)green, (GLfloat)blue, (GLfloat)alpha);
}

UIImage *TGPaintCombineImages(UIImage *background, UIImage *foreground, bool opaque)
{
    return TGPaintCombineCroppedImages(background, foreground, opaque, CGSizeZero, CGRectNull, UIImageOrientationUp, 0, false);
}

UIImage *TGPaintCombineCroppedImages(UIImage *background, UIImage *foreground, bool opaque, CGSize originalSize, CGRect cropRect, UIImageOrientation cropOrientation, CGFloat cropRotation, bool mirrored)
{
    if (foreground == nil)
        return background;
    
    CGFloat width = TGOrientationIsSideward(cropOrientation, NULL) ? background.size.height : background.size.width;
    CGFloat scale = originalSize.width / foreground.size.width / cropRect.size.width * width;
    CGFloat pRatio = foreground.size.width / originalSize.width;
    CGSize rotatedContentSize = TGRotatedContentSize(foreground.size, cropRotation);
    
    UIGraphicsBeginImageContextWithOptions(background.size, opaque, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect backgroundRect = CGRectMake(0, 0, background.size.width, background.size.height);
    [background drawInRect:backgroundRect blendMode:kCGBlendModeCopy alpha:1.0f];
    
    if (!CGSizeEqualToSize(originalSize, CGSizeZero))
    {
        CGAffineTransform transform = CGAffineTransformIdentity;
        transform = CGAffineTransformTranslate(transform, background.size.width / 2.0f, background.size.height / 2.0f);
        transform = CGAffineTransformScale(transform, scale, scale);
        transform = CGAffineTransformRotate(transform, TGRotationForOrientation(cropOrientation));
        transform = CGAffineTransformTranslate(transform, (rotatedContentSize.width / 2 - CGRectGetMidX(cropRect) * pRatio), (rotatedContentSize.height / 2 - CGRectGetMidY(cropRect) * pRatio));
        transform = CGAffineTransformRotate(transform, cropRotation);
        CGContextConcatCTM(context, transform);
        
        if (mirrored)
            CGContextScaleCTM(context, -1.0f, 1.0f);
        
        [foreground drawAtPoint:CGPointMake(-foreground.size.width / 2.0f, -foreground.size.height / 2.0f) blendMode:kCGBlendModeNormal alpha:1.0f];
    }
    else
    {
        [foreground drawInRect:backgroundRect];
    }
    
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return outputImage;
}

NSData *TGPaintGZipInflate(NSData *data)
{
    if (data.length == 0)
        return data;
    
    NSUInteger fullLength = data.length;
    NSUInteger halfLength = data.length / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength:fullLength + halfLength];
    bool done = false;
    int status;
    
    z_stream strm;
    strm.next_in = (Bytef *)data.bytes;
    strm.avail_in = (uint32_t)data.length;
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    if (inflateInit2(&strm, (15+32)) != Z_OK)
        return nil;
    
    while (!done)
    {
        if (strm.total_out >= decompressed.length)
            [decompressed increaseLengthBy:halfLength];
        
        strm.next_out = decompressed.mutableBytes + strm.total_out;
        strm.avail_out = (uint32_t)(decompressed.length - strm.total_out);
        
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END)
            done = true;
        else if (status != Z_OK)
            break;
    }
    
    if (inflateEnd (&strm) != Z_OK)
        return nil;
    
    if (done)
    {
        [decompressed setLength:strm.total_out];
        return [NSData dataWithData:decompressed];
    }
    
    return nil;
}

NSData *TGPaintGZipDeflate(NSData *data)
{
    if (data.length == 0)
        return data;
    
    z_stream strm;
    
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.total_out = 0;
    strm.next_in = (Bytef *)data.bytes;
    strm.avail_in = (uint32_t)data.length;
    
    if (deflateInit2(&strm, Z_BEST_SPEED, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK)
        return nil;
    
    NSMutableData *compressed = [NSMutableData dataWithLength:16384];
    do
    {
        if (strm.total_out >= compressed.length)
            [compressed increaseLengthBy:16384];
        
        strm.next_out = compressed.mutableBytes + strm.total_out;
        strm.avail_out = (uint32_t)(compressed.length - strm.total_out);
        
        deflate(&strm, Z_FINISH);
        
    } while (strm.avail_out == 0);
    
    deflateEnd(&strm);
    
    [compressed setLength:strm.total_out];
    return [NSData dataWithData:compressed];
}
