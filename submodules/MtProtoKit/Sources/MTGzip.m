#import <MtProtoKit/MTGzip.h>
#import <MtProtoKit/MTLogging.h>

#import <zlib.h>

NSUInteger const MTGzipDefaultMaxDecompressedLength = 32 * 1024 * 1024;

// Inflate and deflate both work through the stream in chunks of this size.
// An enum so it is an integer constant expression usable as a stack array size.
enum { MTGzipChunkSize = 16 * 1024 };

@implementation MTGzip

+ (NSData * _Nullable)decompress:(NSData *)data {
    return [self decompress:data maxOutputLength:MTGzipDefaultMaxDecompressedLength];
}

+ (NSData * _Nullable)decompress:(NSData *)data maxOutputLength:(NSUInteger)maxOutputLength {
    NSUInteger length = [data length];
    int windowBits = 15 + 32; //Default + gzip header instead of zlib header
    int retCode;
    unsigned char output[MTGzipChunkSize];
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
        if (MTLogEnabled()) {
            MTLog(@"[MTGzip inflateInit2() failed with error %i]", retCode);
        }
        return nil;
    }

    // Reserve a plausible amount up front, but never more than the ceiling: the
    // input is untrusted and its declared ratio means nothing.
    result = [NSMutableData dataWithCapacity:MIN(length * 4, maxOutputLength)];
    do
    {
        stream.avail_out = MTGzipChunkSize;
        stream.next_out = output;
        retCode = inflate(&stream, Z_NO_FLUSH);
        if ((retCode != Z_OK) && (retCode != Z_STREAM_END))
        {
            if (MTLogEnabled()) {
                MTLog(@"[MTGzip inflate() failed with error %i]", retCode);
            }
            inflateEnd(&stream);
            return nil;
        }
        gotBack = MTGzipChunkSize - stream.avail_out;
        if (gotBack > 0) {
            if (result.length + gotBack > maxOutputLength) {
                if (MTLogEnabled()) {
                    MTLog(@"[MTGzip refusing to inflate beyond %lu bytes]", (unsigned long)maxOutputLength);
                }
                inflateEnd(&stream);
                return nil;
            }
            [result appendBytes:output length:gotBack];
        }
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


    NSMutableData *output = nil;
    int compression = Z_BEST_COMPRESSION;
    if (deflateInit2(&stream, compression, Z_DEFLATED, 31, 8, Z_DEFAULT_STRATEGY) == Z_OK)
    {
        output = [NSMutableData dataWithLength:MTGzipChunkSize];
        while (stream.avail_out == 0)
        {
            if (stream.total_out >= output.length)
            {
                output.length += MTGzipChunkSize;
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
