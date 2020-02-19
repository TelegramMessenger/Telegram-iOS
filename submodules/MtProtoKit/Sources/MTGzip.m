#import <MtProtoKit/MTGzip.h>

#import <zlib.h>

@implementation MTGzip
    
+ (NSData * _Nullable)decompress:(NSData *)data {
    const int kMemoryChunkSize = 1024;
    
    NSUInteger length = [data length];
    int windowBits = 15 + 32; //Default + gzip header instead of zlib header
    int retCode;
    unsigned char output[kMemoryChunkSize];
    uInt gotBack;
    NSMutableData *result;
    z_stream stream;
    
    if ((length == 0) || (length > UINT_MAX)) //FIXME: Support 64 bit inputs
        return nil;
    
    bzero(&stream, sizeof(z_stream));
    stream.avail_in = (uInt)length;
    stream.next_in = (unsigned char*)[data bytes];
    
    retCode = inflateInit2(&stream, windowBits);
    if(retCode != Z_OK)
    {
        NSLog(@"%s: inflateInit2() failed with error %i", __PRETTY_FUNCTION__, retCode);
        return nil;
    }
    
    result = [NSMutableData dataWithCapacity:(length * 4)];
    do
    {
        stream.avail_out = kMemoryChunkSize;
        stream.next_out = output;
        retCode = inflate(&stream, Z_NO_FLUSH);
        if ((retCode != Z_OK) && (retCode != Z_STREAM_END))
        {
            NSLog(@"%s: inflate() failed with error %i", __PRETTY_FUNCTION__, retCode);
            inflateEnd(&stream);
            return nil;
        }
        gotBack = kMemoryChunkSize - stream.avail_out;
        if (gotBack > 0)
        [result appendBytes:output length:gotBack];
    } while( retCode == Z_OK);
    inflateEnd(&stream);
    
    return (retCode == Z_STREAM_END ? result : nil);
}

@end
