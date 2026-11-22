#include <opus/opus_types.h>
#include "../opusfile/opusfile.h"
#import <CommonCrypto/CommonDigest.h>
#include <ogg/ogg.h>

#import "TGDataItem.h"
#import "TGOggOpusWriter.h"

#ifdef ENABLE_NLS
#include <libintl.h>
#define _(X) gettext(X)
#else
#define _(X) (X)
#define textdomain(X)
#define bindtextdomain(X, Y)
#endif
#ifdef gettext_noop
#define N_(X) gettext_noop(X)
#else
#define N_(X) (X)
#endif

typedef struct
{
    void *readdata;
    opus_int64 total_samples_per_channel;
    int rawmode;
    int channels;
    long rate;
    int gain;
    int samplesize;
    int endianness;
    char *infilename;
    int ignorelength;
    int skip;
    int extraout;
    char *comments;
    int comments_length;
    int copy_comments;
} oe_enc_opt;

typedef struct
{
    int (*id_func)(unsigned char *buf, int len); /* Returns true if can load file */
    int id_data_len; /* Amount of data needed to id whether this can load the file */
    int (*open_func)(FILE *in, oe_enc_opt *opt, unsigned char *buf, int buflen);
    void (*close_func)(void *);
    char *format;
    char *description;
} input_format;

#include <opus/opus.h>

#include <ogg/ogg.h>
#include "opus_header.h"

static bool comment_init(char **comments, int* length, const char *vendor_string);
static bool comment_add(char **comments, int* length, char *tag, char *val);
static bool comment_pad(char **comments, int* length, int amount);

static inline int writeOggPage(ogg_page *page, TGDataItem *fileItem)
{
    int written = (int)(page->header_len + page->body_len);
    
    NSMutableData *data = [[NSMutableData alloc] init];
    [data appendBytes:page->header length:page->header_len];
    [data appendBytes:page->body length:page->body_len];
    [fileItem appendData:data];
    
    return MAX(0, written);
}

@interface TGOggOpusWriter ()
{
    TGDataItem *_dataItem;
    
    OpusEncoder *_encoder;
    uint8_t *_packet;
    
    oe_enc_opt inopt;
    
    ogg_stream_state os;
    ogg_page og;
    ogg_packet op;
    ogg_int64_t last_granulepos;
    ogg_int64_t enc_granulepos;
    int last_segments;
    int eos;
    OpusHeader header;
    
    ogg_int32_t _packetId;
    int size_segments;
    
    opus_int64 nb_encoded;
    opus_int64 bytes_written;
    opus_int64 pages_out;
    opus_int64 total_bytes;
    opus_int64 total_samples;
    opus_int32 nb_samples;
    opus_int32 peak_bytes;
    opus_int32 min_bytes;
    
    int max_frame_bytes;
    opus_int32 bitrate;
    opus_int32 rate;
    opus_int32 coding_rate;
    opus_int32 frame_size;
    int with_cvbr;
    int max_ogg_delay;
    int comment_padding;
    int serialno;
    opus_int32 lookahead;
    opus_int16 _pcmBuffer[960];
    int _pcmCount;
    NSData *_pendingPacket;
    TGDataItem *_appendTarget;
    bool _finished;
    bool _failed;
}

@property (nonatomic) ogg_sync_state syncState;

@end

@implementation TGOggOpusWriter

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        bitrate = 30 * 1024;
        rate = 48000;
        coding_rate = 48000;
        frame_size = 960;
        with_cvbr = 1;
        max_ogg_delay = 48000;
        comment_padding = 512;
        
        _packetId = -1;
    }
    return self;
}

- (void)dealloc {
    [self cleanup];
}

- (void)cleanup
{
    if (_encoder != NULL)
    {
        opus_encoder_destroy(_encoder);
        _encoder = NULL;
    }
    
    ogg_stream_clear(&os);
    
    if (_packet != NULL)
    {
        free(_packet);
        _packet = NULL;
    }
}

- (bool)beginWithDataItem:(TGDataItem *)dataItem
{
    if (dataItem == nil || _encoder != NULL) {
        return false;
    }
    _dataItem = dataItem;

    inopt.channels = 1;
    inopt.rate = coding_rate=rate;
    inopt.gain = 0;
    inopt.samplesize = 16;
    inopt.endianness = 0;
    inopt.rawmode = 0;
    inopt.ignorelength = 0;
    inopt.copy_comments = 0;
    
    arc4random_buf(&serialno, sizeof(serialno));
    
    const char *opus_version = opus_get_version_string();
    comment_init(&inopt.comments, &inopt.comments_length, opus_version);
    
//    bitrate = 16 * 1024;

//    inopt.rawmode = 1;
//    inopt.ignorelength = 1;
//    inopt.samplesize = 16;
//    inopt.rate = 16000;
//    inopt.channels = 1;
    
    rate = (opus_int32)inopt.rate;
    inopt.skip = 0;
    
    // In order to code the complete length we'll need to do a little padding
    //setup_padder(&inopt, &original_samples);
    
    if (rate > 24000)
        coding_rate = 48000;
    else if (rate > 16000)
        coding_rate = 24000;
    else if (rate > 12000)
        coding_rate = 16000;
    else if (rate > 8000)
        coding_rate = 12000;
    else
        coding_rate = 8000;
    
    // Scale the resampler complexity, but only for 48000 output because the near-cutoff behavior matters a lot more at lower rates
    if (rate != coding_rate)
    {
        NSLog(@"Invalid rate");
        return false;
    }
    
    header.channels = 1;
    header.channel_mapping = 0;
    header.input_sample_rate = rate;
    header.gain = inopt.gain;
    header.nb_streams = 1;
    
    int result = OPUS_OK;
    _encoder = opus_encoder_create(coding_rate, 1, OPUS_APPLICATION_AUDIO, &result);
    if (result != OPUS_OK)
    {
        NSLog(@"Error cannot create encoder: %s", opus_strerror(result));
        return false;
    }
    
    min_bytes = max_frame_bytes = (1275 * 3 + 7) * header.nb_streams;
    _packet = malloc(max_frame_bytes);
    if (_packet == NULL) { return false; }
    
    result = opus_encoder_ctl(_encoder, OPUS_SET_BITRATE(bitrate));
    if (result != OPUS_OK)
    {
        NSLog(@"Error OPUS_SET_BITRATE returned: %s", opus_strerror(result));
        return false;
    }
    
    /*result = opus_encoder_ctl(_encoder, OPUS_SET_VBR(1));
    if (result != OPUS_OK)
    {
        NSLog(@"Error OPUS_SET_VBR returned: %s", opus_strerror(result));
        return false;
    }*/
    
    /*ret = opus_multistream_encoder_ctl(st, OPUS_SET_VBR_CONSTRAINT(1));
    if (ret != OPUS_OK)
    {
        NSLog(@"Error OPUS_SET_VBR_CONSTRAINT returned: %s", opus_strerror(ret));
        return false;
    }*/
    
    /*ret = opus_multistream_encoder_ctl(st, OPUS_SET_COMPLEXITY(complexity));
    if(ret != OPUS_OK)
    {
        NSLog(@"Error OPUS_SET_COMPLEXITY returned: %s", opus_strerror(ret));
        return false;
    }*/
    
    /*result = opus_encoder_ctl(st, OPUS_SET_PACKET_LOSS_PERC(expect_loss));
    if (ret != OPUS_OK)
    {
        NSLog(@"Error OPUS_SET_PACKET_LOSS_PERC returned: %s", opus_strerror(ret));
        return false;
    }*/
    
#ifdef OPUS_SET_LSB_DEPTH
    result = opus_encoder_ctl(_encoder, OPUS_SET_LSB_DEPTH(MAX(8, MIN(24, inopt.samplesize))));
    if (result != OPUS_OK)
    {
        NSLog(@"Warning OPUS_SET_LSB_DEPTH returned: %s", opus_strerror(result));
    }
#endif
    
    // We do the lookahead check late so user CTLs can change it
    result = opus_encoder_ctl(_encoder, OPUS_GET_LOOKAHEAD(&lookahead));
    if (result != OPUS_OK)
    {
        NSLog(@"Error OPUS_GET_LOOKAHEAD returned: %s", opus_strerror(result));
        return false;
    }
    
    inopt.skip += lookahead;
    // Regardless of the rate we're coding at the ogg timestamping/skip is always timed at 48000.
    header.preskip = (int)(inopt.skip * (48000.0 / coding_rate));
    // Extra samples that need to be read to compensate for the pre-skip
    inopt.extraout = (int)(header.preskip * (rate / 48000.0));
    
    // Initialize Ogg stream struct
    if (ogg_stream_init(&os, serialno) == -1)
    {
        NSLog(@"Error: stream init failed");
        return false;
    }
    
    // Write header
    {
        unsigned char header_data[100];
        int packet_size = opus_header_to_packet(&header, header_data, 100);
        op.packet = header_data;
        op.bytes = packet_size;
        op.b_o_s = 1;
        op.e_o_s = 0;
        op.granulepos = 0;
        op.packetno = 0;
        ogg_stream_packetin(&os, &op);
        
        while ((result = ogg_stream_flush(&os, &og)))
        {
            if (!result)
                break;
            
            int pageBytesWritten = writeOggPage(&og, _dataItem);
            if (pageBytesWritten != og.header_len + og.body_len)
            {
                NSLog(@"Error: failed writing header to output stream");
                return false;
            }
            bytes_written += pageBytesWritten;
            pages_out++;
        }
        
        comment_pad(&inopt.comments, &inopt.comments_length, comment_padding);
        op.packet = (unsigned char *)inopt.comments;
        op.bytes = inopt.comments_length;
        op.b_o_s = 0;
        op.e_o_s = 0;
        op.granulepos = 0;
        op.packetno = 1;
        ogg_stream_packetin(&os, &op);
    }
    
    // Writing the rest of the opus header packets
    while ((result = ogg_stream_flush(&os, &og)))
    {
        if (result == 0)
            break;
        
        int writtenPageBytes = writeOggPage(&og, _dataItem);
        if (writtenPageBytes != og.header_len + og.body_len)
        {
            NSLog(@"Error: failed writing header to output stream");
            return false;
        }
        
        bytes_written += writtenPageBytes;
        pages_out++;
    }
    
    free(inopt.comments);
    
    return true;
}

- (bool)beginAppendWithDataItem:(TGDataItem *)dataItem
{
    if (dataItem == nil || _encoder != NULL) {
        return false;
    }
    NSData *source = [dataItem.data copy];
    if (source.length == 0) {
        return [self beginWithDataItem:dataItem];
    }
    int error = 0;
    OggOpusFile *reader = op_open_memory(source.bytes, source.length, &error);
    if (reader == NULL || error != 0) {
        if (reader != NULL) { op_free(reader); }
        return false;
    }
    for (int i = 0; i < op_link_count(reader); i++) {
        if (op_channel_count(reader, i) != 1) {
            op_free(reader);
            return false;
        }
    }
    TGDataItem *prepared = [[TGDataItem alloc] init];
    if (![self beginWithDataItem:prepared]) {
        op_free(reader);
        return false;
    }
    opus_int16 samples[960];
    bool succeeded = true;
    while (true) {
        int count = op_read(reader, samples, 960, NULL);
        if (count == 0) { break; }
        if (count < 0 || ![self writeFrame:(uint8_t *)samples frameByteCount:count * sizeof(opus_int16)]) {
            succeeded = false;
            break;
        }
    }
    op_free(reader);
    if (!succeeded || ![self submitPendingPacket:false granule:enc_granulepos] || ![self flushPages]) {
        _failed = true;
        return false;
    }
    _appendTarget = dataItem;
    return true;
}

- (bool)submitPendingPacket:(bool)finished granule:(ogg_int64_t)granule
{
    if (_pendingPacket == nil) { return true; }
    op.packet = (unsigned char *)_pendingPacket.bytes;
    op.bytes = _pendingPacket.length;
    op.b_o_s = 0;
    op.e_o_s = finished;
    op.granulepos = granule;
    op.packetno = 2 + ++_packetId;
    if (ogg_stream_packetin(&os, &op) != 0) {
        return false;
    }
    _pendingPacket = nil;
    if (granule - last_granulepos >= max_ogg_delay) {
        return [self flushPages];
    }
    while (ogg_stream_pageout_fill(&os, &og, 255 * 255)) {
        int written = writeOggPage(&og, _dataItem);
        if (written != og.header_len + og.body_len) { return false; }
        bytes_written += written;
        pages_out++;
        last_granulepos = ogg_page_granulepos(&og);
    }
    return true;
}

- (bool)encodeBufferedFrame
{
    if (![self submitPendingPacket:false granule:enc_granulepos]) { return false; }
    int count = opus_encode(_encoder, _pcmBuffer, frame_size, _packet, max_frame_bytes);
    if (count < 0) { return false; }
    _pendingPacket = [NSData dataWithBytes:_packet length:count];
    nb_encoded += frame_size;
    enc_granulepos += frame_size * 48000 / coding_rate;
    total_bytes += count;
    _pcmCount = 0;
    return true;
}

- (bool)writeFrame:(uint8_t *)framePcmBytes frameByteCount:(NSUInteger)frameByteCount
{
    if (_encoder == NULL || _packet == NULL || _failed || (framePcmBytes == NULL && frameByteCount != 0) || frameByteCount % sizeof(opus_int16) != 0 || frameByteCount > sizeof(_pcmBuffer)) {
        return false;
    }
    if (_finished) { return framePcmBytes == NULL && frameByteCount == 0; }
    if (_appendTarget != nil) {
        if (![_appendTarget replaceData:_dataItem.data]) { return false; }
        _dataItem = _appendTarget;
        _appendTarget = nil;
    }
    if (framePcmBytes == NULL) {
        ogg_int64_t finalGranule = total_samples * 48000 / rate + header.preskip;
        while (enc_granulepos < finalGranule || _pcmCount > 0) {
            memset(_pcmBuffer + _pcmCount, 0, (frame_size - _pcmCount) * sizeof(opus_int16));
            if (![self encodeBufferedFrame]) { _failed = true; return false; }
        }
        if (![self submitPendingPacket:true granule:finalGranule] || ![self flushPages]) {
            _failed = true;
            return false;
        }
        _finished = true;
        return true;
    }
    int count = (int)(frameByteCount / sizeof(opus_int16));
    if (total_samples > INT64_MAX / 48000 - count) { return false; }
    total_samples += count;
    opus_int16 *samples = (opus_int16 *)framePcmBytes;
    while (count > 0) {
        int copied = MIN(count, frame_size - _pcmCount);
        memcpy(_pcmBuffer + _pcmCount, samples, copied * sizeof(opus_int16));
        _pcmCount += copied;
        samples += copied;
        count -= copied;
        if (_pcmCount == frame_size && ![self encodeBufferedFrame]) {
            _failed = true;
            return false;
        }
    }
    return true;
}

- (NSUInteger)encodedBytes
{
    return (NSUInteger)bytes_written;
}

- (NSTimeInterval)encodedDuration
{
    return total_samples / (NSTimeInterval)coding_rate;
}

- (NSDictionary *)pause
{
    if (_encoder == NULL || _failed || ![self submitPendingPacket:false granule:enc_granulepos] || ![self flushPages]) {
        return @{};
    }
    return [self saveState];
}

- (bool)resumeWithDataItem:(TGDataItem *)dataItem encoderState:(NSDictionary *)state
{
    if (state[@"encoderData"] == nil && state[@"opusVersion"] == nil && [state[@"bytes_written"] isKindOfClass:[NSNumber class]] &&
        [state[@"bytes_written"] unsignedLongLongValue] == dataItem.data.length && dataItem.data.length > 0) {
        return [self beginAppendWithDataItem:dataItem];
    }
    if (![self restoreState:state withDataItem:dataItem])
        return false;
    
    return true;
}

- (bool)flushPages
{
    while (ogg_stream_flush_fill(&os, &og, 255 * 255))
    {
        if (ogg_page_packets(&og) != 0)
            last_granulepos = ogg_page_granulepos(&og);
        
        int writtenPageBytes = writeOggPage(&og, _dataItem);
        if (writtenPageBytes != og.header_len + og.body_len)
        {
            NSLog(@"Error: failed writing data to output stream");
            return false;
        }
        bytes_written += writtenPageBytes;
        pages_out++;
    }
    return true;
}

- (NSDictionary *)saveState
{
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    
    [state setObject:@(_packetId) forKey:@"packetId"];
    [state setObject:@(enc_granulepos) forKey:@"enc_granulepos"];
    [state setObject:@(last_granulepos) forKey:@"last_granulepos"];
    [state setObject:@(last_segments) forKey:@"last_segments"];
    [state setObject:@(nb_encoded) forKey:@"nb_encoded"];
    [state setObject:@(bytes_written) forKey:@"bytes_written"];
    [state setObject:@(pages_out) forKey:@"pages_out"];
    [state setObject:@(total_bytes) forKey:@"total_bytes"];
    [state setObject:@(total_samples) forKey:@"total_samples"];
    [state setObject:@(serialno) forKey:@"serialno"];
    
    [state setObject:@(rate) forKey:@"rate"];
    [state setObject:@(coding_rate) forKey:@"coding_rate"];
    [state setObject:@(frame_size) forKey:@"frame_size"];
    [state setObject:@(bitrate) forKey:@"bitrate"];
    [state setObject:@(with_cvbr) forKey:@"with_cvbr"];
    [state setObject:@(lookahead) forKey:@"lookahead"];
    
    NSDictionary *headerDict = @{
        @"channels": @(header.channels),
        @"channel_mapping": @(header.channel_mapping),
        @"input_sample_rate": @(header.input_sample_rate),
        @"gain": @(header.gain),
        @"nb_streams": @(header.nb_streams),
        @"preskip": @(header.preskip)
    };
    [state setObject:headerDict forKey:@"header"];
    NSData *encoderData = [NSData dataWithBytes:_encoder length:opus_encoder_get_size(header.channels)];
    state[@"encoderData"] = [encoderData base64EncodedStringWithOptions:0];
    state[@"encoderDigest"] = [self digest:encoderData];
    state[@"opusVersion"] = [NSString stringWithUTF8String:opus_get_version_string()];
    state[@"wordSize"] = @(sizeof(void *));
    state[@"architecture"] = [self stateArchitecture];
    state[@"pageno"] = @(os.pageno);
    state[@"bos"] = @(os.b_o_s);
    state[@"pcmData"] = [[NSData dataWithBytes:_pcmBuffer length:_pcmCount * sizeof(opus_int16)] base64EncodedStringWithOptions:0];
    state[@"finished"] = @(_finished);
    state[@"dataDigest"] = [self digest:_appendTarget != nil ? _appendTarget.data : _dataItem.data];
    if (_appendTarget != nil) {
        state[@"pendingReplacement"] = [_dataItem.data base64EncodedStringWithOptions:0];
        state[@"pendingReplacementDigest"] = [self digest:_dataItem.data];
    }
    
    return state;
}

- (NSString *)stateArchitecture
{
#if defined(__arm64__)
    return @"arm64";
#elif defined(__x86_64__)
    return @"x86_64";
#else
    return @"unsupported";
#endif
}

- (NSString *)digest:(NSData *)data
{
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    const uint8_t *bytes = data.bytes;
    NSUInteger remaining = data.length;
    while (remaining > 0) {
        CC_LONG count = (CC_LONG)MIN(remaining, UINT32_MAX);
        CC_SHA256_Update(&context, bytes, count);
        bytes += count;
        remaining -= count;
    }
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    return [[NSData dataWithBytes:digest length:sizeof(digest)] base64EncodedStringWithOptions:0];
}

- (bool)restoreState:(NSDictionary *)state withDataItem:(TGDataItem *)dataItem
{
    if (state == nil || dataItem == nil || ![state[@"encoderData"] isKindOfClass:[NSString class]] || ![state[@"pcmData"] isKindOfClass:[NSString class]]) { return false; }
    NSDictionary *headerDict = state[@"header"];
    if (![headerDict isKindOfClass:[NSDictionary class]]) { return false; }
    for (NSString *key in @[@"rate", @"coding_rate", @"frame_size", @"wordSize", @"finished", @"total_samples", @"enc_granulepos", @"last_granulepos", @"nb_encoded", @"packetId", @"pageno", @"bos", @"bytes_written", @"pages_out", @"total_bytes", @"serialno", @"bitrate", @"with_cvbr", @"lookahead"]) {
        if (![state[key] isKindOfClass:[NSNumber class]]) { return false; }
    }
    for (NSString *key in @[@"channels", @"channel_mapping", @"input_sample_rate", @"gain", @"nb_streams", @"preskip"]) {
        if (![headerDict[key] isKindOfClass:[NSNumber class]]) { return false; }
    }
    NSData *encoderData = [[NSData alloc] initWithBase64EncodedString:state[@"encoderData"] options:0];
    NSData *pcmData = [[NSData alloc] initWithBase64EncodedString:state[@"pcmData"] options:0];
    if ([headerDict[@"channels"] intValue] != 1 || [state[@"rate"] intValue] != 48000 || [state[@"coding_rate"] intValue] != 48000 || [state[@"frame_size"] intValue] != 960 ||
        encoderData.length != opus_encoder_get_size(1) || pcmData == nil || pcmData.length >= sizeof(_pcmBuffer) || pcmData.length % sizeof(opus_int16) != 0 ||
        ![state[@"encoderDigest"] isEqual:[self digest:encoderData]] || ![state[@"dataDigest"] isEqual:[self digest:dataItem.data]] ||
        ![state[@"opusVersion"] isEqual:[NSString stringWithUTF8String:opus_get_version_string()]] || [state[@"wordSize"] unsignedIntegerValue] != sizeof(void *) || [state[@"finished"] boolValue] ||
        ![state[@"architecture"] isEqual:[self stateArchitecture]] || [[self stateArchitecture] isEqual:@"unsupported"] ||
        [state[@"total_samples"] longLongValue] < 0 || [state[@"total_samples"] longLongValue] > INT64_MAX / 48000 || [state[@"enc_granulepos"] longLongValue] < 0) {
        return false;
    }
    if ([state[@"nb_encoded"] longLongValue] != [state[@"enc_granulepos"] longLongValue] ||
        [state[@"nb_encoded"] longLongValue] != [state[@"total_samples"] longLongValue] - (long long)(pcmData.length / sizeof(opus_int16)) ||
        [state[@"nb_encoded"] longLongValue] % 960 != 0 || [state[@"packetId"] longLongValue] != [state[@"nb_encoded"] longLongValue] / 960 - 1 ||
        [state[@"last_granulepos"] longLongValue] < 0 || [state[@"last_granulepos"] longLongValue] > [state[@"enc_granulepos"] longLongValue] ||
        [state[@"pageno"] longLongValue] < 2 || [state[@"pageno"] longLongValue] > UINT32_MAX || [state[@"bos"] intValue] != 1 ||
        [headerDict[@"channel_mapping"] intValue] != 0 || [headerDict[@"input_sample_rate"] intValue] != 48000 || [headerDict[@"nb_streams"] intValue] != 1 ||
        [headerDict[@"preskip"] intValue] < 0 || [headerDict[@"preskip"] intValue] > UINT16_MAX) {
        return false;
    }
    NSData *replacement = nil;
    if (state[@"pendingReplacement"] != nil) {
        if (![state[@"pendingReplacement"] isKindOfClass:[NSString class]]) { return false; }
        replacement = [[NSData alloc] initWithBase64EncodedString:state[@"pendingReplacement"] options:0];
        if (replacement == nil || ![state[@"pendingReplacementDigest"] isEqual:[self digest:replacement]]) { return false; }
    }
    [self cleanup];
    _pendingPacket = nil;
    _appendTarget = replacement != nil ? dataItem : nil;
    _dataItem = replacement != nil ? [[TGDataItem alloc] initWithData:replacement] : dataItem;
    _finished = false;
    _failed = false;
    _packetId = [state[@"packetId"] intValue];
    enc_granulepos = [state[@"enc_granulepos"] longLongValue];
    last_granulepos = [state[@"last_granulepos"] longLongValue];
    last_segments = 0;
    nb_encoded = [state[@"nb_encoded"] longLongValue];
    bytes_written = [state[@"bytes_written"] longLongValue];
    pages_out = [state[@"pages_out"] longLongValue];
    total_bytes = [state[@"total_bytes"] longLongValue];
    total_samples = [state[@"total_samples"] longLongValue];
    serialno = [state[@"serialno"] intValue];
    rate = 48000;
    coding_rate = 48000;
    frame_size = 960;
    bitrate = [state[@"bitrate"] intValue];
    with_cvbr = [state[@"with_cvbr"] intValue];
    lookahead = [state[@"lookahead"] intValue];
    header.channels = 1;
    header.channel_mapping = 0;
    header.input_sample_rate = 48000;
    header.gain = [headerDict[@"gain"] intValue];
    header.nb_streams = 1;
    header.preskip = [headerDict[@"preskip"] intValue];
    int result = OPUS_OK;
    _encoder = opus_encoder_create(coding_rate, 1, OPUS_APPLICATION_AUDIO, &result);
    if (_encoder == NULL || result != OPUS_OK) { return false; }
    memcpy(_encoder, encoderData.bytes, encoderData.length);
    if (ogg_stream_init(&os, serialno) != 0) { return false; }
    os.pageno = [state[@"pageno"] longLongValue];
    os.b_o_s = [state[@"bos"] intValue];
    os.packetno = 3 + _packetId;
    os.granulepos = enc_granulepos;
    _pcmCount = (int)(pcmData.length / sizeof(opus_int16));
    memcpy(_pcmBuffer, pcmData.bytes, pcmData.length);
    min_bytes = max_frame_bytes = (1275 * 3 + 7);
    _packet = malloc(max_frame_bytes);
    return _packet != NULL;
}

@end

/*
 Comments will be stored in the Vorbis style.
 It is describled in the "Structure" section of
    http://www.xiph.org/ogg/vorbis/doc/v-comment.html

 However, Opus and other non-vorbis formats omit the "framing_bit".

The comment header is decoded as follows:
  1) [vendor_length] = read an unsigned integer of 32 bits
  2) [vendor_string] = read a UTF-8 vector as [vendor_length] octets
  3) [user_comment_list_length] = read an unsigned integer of 32 bits
  4) iterate [user_comment_list_length] times {
     5) [length] = read an unsigned integer of 32 bits
     6) this iteration's user comment = read a UTF-8 vector as [length] octets
     }
  7) done.
*/

#define readint(buf, base) (((buf[base+3]<<24)&0xff000000)| \
                           ((buf[base+2]<<16)&0xff0000)| \
                           ((buf[base+1]<<8)&0xff00)| \
                           (buf[base]&0xff))
#define writeint(buf, base, val) do{ buf[base+3]=((val)>>24)&0xff; \
                                     buf[base+2]=((val)>>16)&0xff; \
                                     buf[base+1]=((val)>>8)&0xff; \
                                     buf[base]=(val)&0xff; \
                                 }while(0)

static bool comment_init(char **comments, int *length, const char *vendor_string)
{
    // The 'vendor' field should be the actual encoding library used
    int vendor_length = (int)strlen(vendor_string);
    int user_comment_list_length = 0;
    int len = 8 + 4 + vendor_length + 4;
    char *p = (char *)malloc(len);
    memcpy(p, "OpusTags", 8);
    writeint(p, 8, vendor_length);
    memcpy(p + 12, vendor_string, vendor_length);
    writeint(p, 12 + vendor_length, user_comment_list_length);
    *length = len;
    *comments = p;
    
    return true;
}

__unused bool comment_add(char **comments, int* length, char *tag, char *val)
{
    char *p = *comments;
    int vendor_length = readint(p, 8);
    int user_comment_list_length = readint(p, 8 + 4 + vendor_length);
    int tag_len = (tag ? (int)strlen(tag) + 1 : 0);
    int val_len = (int)strlen(val);
    int len = (*length) + 4 + tag_len + val_len;
    
    p = (char *)realloc(p, len);
    
    writeint(p, *length, tag_len+val_len);      /* length of comment */
    if (tag)
    {
        memcpy(p + *length + 4, tag, tag_len);        /* comment tag */
        (p+*length+4)[tag_len-1] = '=';           /* separator */
    }
    memcpy(p + *length + 4 + tag_len, val, val_len);  /* comment */
    writeint(p, 8 + 4 + vendor_length, user_comment_list_length + 1);
    *comments = p;
    *length = len;
    
    return true;
}

static bool comment_pad(char **comments, int* length, int amount)
{
    if (amount > 0)
    {
        char *p = *comments;
        // Make sure there is at least amount worth of padding free, and round up to the maximum that fits in the current ogg segments
        int newlen = (*length + amount + 255) / 255 * 255 - 1;
        p = realloc(p, newlen);
        for (int i = *length; i < newlen; i++)
        {
            p[i] = 0;
        }
        *comments = p;
        *length = newlen;
    }
    
    return true;
}

#undef readint
#undef writeint
