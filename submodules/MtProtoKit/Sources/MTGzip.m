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

+ (NSData * _Nullable)compress:(NSData *)data {
    if (data.length == 0) {
        return data;
    }

    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.opaque = Z_NULL;
    stream.avail_in = (uint)data.length;
    stream.next_in = (Bytef *)(void *)data.bytes;
    stream.total_out = 0;
    stream.avail_out = 0;

    static const NSUInteger ChunkSize = 16384;

    NSMutableData *output = nil;
    int compression = Z_BEST_COMPRESSION;
    if (deflateInit2(&stream, compression, Z_DEFLATED, 31, 8, Z_DEFAULT_STRATEGY) == Z_OK)
    {
        output = [NSMutableData dataWithLength:ChunkSize];
        while (stream.avail_out == 0)
        {
            if (stream.total_out >= output.length)
            {
                output.length += ChunkSize;
            }
            stream.next_out = (uint8_t *)output.mutableBytes + stream.total_out;
            stream.avail_out = (uInt)(output.length - stream.total_out);
            deflate(&stream, Z_FINISH);
        }
        deflateEnd(&stream);
        output.length = stream.total_out;
    }

    return output;
}

@end
