#import <FFMpegBinding/FFMpegMP4StreamWriter.h>

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

#include "libavformat/avformat.h"
#include "libavutil/dict.h"
#include "libavutil/mem.h"
#include "libavutil/opt.h"

#define FFMpegMP4StreamWriterIOBufferSize (64 * 1024)
#define FFMpegMP4StreamWriterMdatHeaderSize 16
#define FFMpegMP4StreamWriterMaxStreams 2
#define FFMpegMP4StreamWriterChunkDuration 0.5
#define FFMpegMP4StreamWriterMaxBufferedDuration 10.0
#define FFMpegMP4StreamWriterMaxChunkSize (1 << 20)

typedef struct {
    AVPacket **packets;
    int count;
    int capacity;
    int64_t sampleCount;
    int64_t keyframeCount;
    int64_t timeToSampleRuns;
    int64_t compositionOffsetRuns;
    int64_t chunkCount;
    int64_t lastDts;
    int64_t lastDelta;
    int64_t lastCompositionOffset;
    int64_t extradataSize;
} FFMpegMP4StreamWriterTrack;

static int FFMpegMP4StreamWriterWrite(void *opaque, const uint8_t *buffer, int size);
static int64_t FFMpegMP4StreamWriterSeek(void *opaque, int64_t offset, int whence);

@interface FFMpegMP4StreamWriter () {
    AVFormatContext *_context;
    AVIOContext *_io;
    int _fd;
    int64_t _position;
    int64_t _size;
    int64_t _reservedMoovSize;
    int _videoStreamIndex;
    int _audioStreamIndex;
    FFMpegMP4StreamWriterTrack _tracks[FFMpegMP4StreamWriterMaxStreams];
    double _chunkEnd;
    bool _headerWritten;
    bool _finalizing;
}

- (int)writeBytes:(const uint8_t *)buffer size:(int)size;
- (int64_t)seekToOffset:(int64_t)offset whence:(int)whence;

@end

@implementation FFMpegMP4StreamWriter

- (instancetype _Nullable)initWithPath:(NSString *)path reservedMoovSize:(int64_t)reservedMoovSize {
    self = [super init];
    if (self != nil) {
        _fd = -1;
        _videoStreamIndex = -1;
        _audioStreamIndex = -1;
        _reservedMoovSize = reservedMoovSize;
        _chunkEnd = FFMpegMP4StreamWriterChunkDuration;

        _fd = open(path.UTF8String, O_RDWR | O_CREAT | O_TRUNC, 0644);
        if (_fd < 0) {
            return nil;
        }
        if (avformat_alloc_output_context2(&_context, NULL, "mp4", NULL) < 0 || _context == NULL) {
            return nil;
        }
        unsigned char *buffer = av_malloc(FFMpegMP4StreamWriterIOBufferSize);
        if (buffer == NULL) {
            return nil;
        }
        _io = avio_alloc_context(buffer, FFMpegMP4StreamWriterIOBufferSize, 1, (__bridge void *)self, NULL, &FFMpegMP4StreamWriterWrite, &FFMpegMP4StreamWriterSeek);
        if (_io == NULL) {
            av_free(buffer);
            return nil;
        }
        _io->seekable = AVIO_SEEKABLE_NORMAL;
        _context->pb = _io;
        _context->flags |= AVFMT_FLAG_CUSTOM_IO;
    }
    return self;
}

- (void)dealloc {
    for (int i = 0; i < FFMpegMP4StreamWriterMaxStreams; i++) {
        for (int j = 0; j < _tracks[i].count; j++) {
            av_packet_free(&_tracks[i].packets[j]);
        }
        av_free(_tracks[i].packets);
    }
    if (_io != NULL) {
        av_freep(&_io->buffer);
        avio_context_free(&_io);
    }
    if (_context != NULL) {
        _context->pb = NULL;
        avformat_free_context(_context);
    }
    if (_fd >= 0) {
        close(_fd);
    }
}

- (void)setError:(NSString *)stage code:(int)code {
    char description[AV_ERROR_MAX_STRING_SIZE] = { 0 };
    av_strerror(code, description, sizeof(description));
    _lastError = [NSString stringWithFormat:@"%@: %s (%d)", stage, description, code];
}

- (int)writeBytes:(const uint8_t *)buffer size:(int)size {
    int written = 0;
    while (written < size) {
        ssize_t result = pwrite(_fd, buffer + written, (size_t)(size - written), _position + written);
        if (result <= 0) {
            return AVERROR(errno != 0 ? errno : EIO);
        }
        written += (int)result;
    }
    _position += size;
    if (_position > _size) {
        _size = _position;
    }
    if (_writeObserver != nil) {
        _writeObserver(_size, _finalizing);
    }
    return size;
}

- (int64_t)seekToOffset:(int64_t)offset whence:(int)whence {
    if (whence & AVSEEK_SIZE) {
        return _size;
    }
    switch (whence & ~AVSEEK_FORCE) {
        case SEEK_SET:
            _position = offset;
            break;
        case SEEK_CUR:
            _position += offset;
            break;
        case SEEK_END:
            _position = _size + offset;
            break;
        default:
            return AVERROR(EINVAL);
    }
    return _position;
}

static bool FFMpegMP4StreamWriterCopyExtradata(AVCodecParameters *parameters, NSData *extradata) {
    if (extradata.length == 0) {
        return true;
    }
    parameters->extradata = av_mallocz(extradata.length + AV_INPUT_BUFFER_PADDING_SIZE);
    if (parameters->extradata == NULL) {
        return false;
    }
    memcpy(parameters->extradata, extradata.bytes, extradata.length);
    parameters->extradata_size = (int)extradata.length;
    return true;
}

- (int)addVideoStreamWithCodec:(FFMpegMP4StreamWriterVideoCodec)codec width:(int32_t)width height:(int32_t)height extradata:(NSData *)extradata timescale:(int32_t)timescale {
    AVStream *stream = avformat_new_stream(_context, NULL);
    if (stream == NULL) {
        return -1;
    }
    stream->time_base = (AVRational){ 1, timescale };
    AVCodecParameters *parameters = stream->codecpar;
    parameters->codec_type = AVMEDIA_TYPE_VIDEO;
    if (codec == FFMpegMP4StreamWriterVideoCodecHEVC) {
        parameters->codec_id = AV_CODEC_ID_HEVC;
        parameters->codec_tag = MKTAG('h', 'v', 'c', '1');
    } else {
        parameters->codec_id = AV_CODEC_ID_H264;
        parameters->codec_tag = MKTAG('a', 'v', 'c', '1');
    }
    parameters->width = width;
    parameters->height = height;
    if (!FFMpegMP4StreamWriterCopyExtradata(parameters, extradata) || stream->index >= FFMpegMP4StreamWriterMaxStreams) {
        return -1;
    }
    _tracks[stream->index].extradataSize = extradata.length;
    _videoStreamIndex = stream->index;
    return stream->index;
}

- (int)addAudioStreamWithSampleRate:(int32_t)sampleRate channels:(int32_t)channels bitrate:(int32_t)bitrate initialPadding:(int32_t)initialPadding extradata:(NSData *)extradata {
    AVStream *stream = avformat_new_stream(_context, NULL);
    if (stream == NULL) {
        return -1;
    }
    stream->time_base = (AVRational){ 1, sampleRate };
    AVCodecParameters *parameters = stream->codecpar;
    parameters->codec_type = AVMEDIA_TYPE_AUDIO;
    parameters->codec_id = AV_CODEC_ID_AAC;
    parameters->sample_rate = sampleRate;
    av_channel_layout_default(&parameters->ch_layout, channels);
    parameters->frame_size = 1024;
    parameters->bit_rate = bitrate;
    parameters->initial_padding = initialPadding;
    if (!FFMpegMP4StreamWriterCopyExtradata(parameters, extradata) || stream->index >= FFMpegMP4StreamWriterMaxStreams) {
        return -1;
    }
    _tracks[stream->index].extradataSize = extradata.length;
    _audioStreamIndex = stream->index;
    return stream->index;
}

- (bool)writeHeader {
    AVDictionary *options = NULL;
    if (_reservedMoovSize > 0) {
        av_dict_set_int(&options, "moov_size", _reservedMoovSize, 0);
    }
    int result = avformat_write_header(_context, &options);
    av_dict_free(&options);
    if (result < 0) {
        [self setError:@"write_header" code:result];
        return false;
    }
    avio_flush(_io);
    _headerEnd = avio_tell(_io);
    _headerWritten = true;
    return true;
}

- (bool)writePacketWithStreamIndex:(int)streamIndex data:(NSData *)data pts:(int64_t)pts dts:(int64_t)dts duration:(int64_t)duration isKeyframe:(bool)isKeyframe {
    if (streamIndex < 0 || streamIndex >= (int)_context->nb_streams) {
        _lastError = @"invalid stream index";
        return false;
    }
    AVPacket *packet = av_packet_alloc();
    if (packet == NULL) {
        return false;
    }
    int result = av_new_packet(packet, (int)data.length);
    if (result < 0) {
        av_packet_free(&packet);
        [self setError:@"new_packet" code:result];
        return false;
    }
    memcpy(packet->data, data.bytes, data.length);
    packet->stream_index = streamIndex;
    packet->pts = pts;
    packet->dts = dts;
    packet->duration = duration;
    if (isKeyframe) {
        packet->flags |= AV_PKT_FLAG_KEY;
    }

    FFMpegMP4StreamWriterTrack *track = &_tracks[streamIndex];
    if (track->count == track->capacity) {
        int capacity = MAX(16, track->capacity * 2);
        AVPacket **packets = av_realloc_array(track->packets, capacity, sizeof(AVPacket *));
        if (packets == NULL) {
            av_packet_free(&packet);
            _lastError = @"out of memory";
            return false;
        }
        track->packets = packets;
        track->capacity = capacity;
    }
    track->packets[track->count] = packet;
    track->count += 1;
    [self countPacketWithTrack:track dts:dts pts:pts isKeyframe:isKeyframe];

    return [self writeChunksFinal:false];
}

- (void)countPacketWithTrack:(FFMpegMP4StreamWriterTrack *)track dts:(int64_t)dts pts:(int64_t)pts isKeyframe:(bool)isKeyframe {
    if (track->sampleCount != 0) {
        int64_t delta = dts - track->lastDts;
        if (track->sampleCount == 1 || delta != track->lastDelta) {
            track->timeToSampleRuns += 1;
        }
        track->lastDelta = delta;
    }
    int64_t compositionOffset = pts - dts;
    if (track->sampleCount == 0 || compositionOffset != track->lastCompositionOffset) {
        track->compositionOffsetRuns += 1;
    }
    track->lastCompositionOffset = compositionOffset;
    track->lastDts = dts;
    track->sampleCount += 1;
    if (isKeyframe) {
        track->keyframeCount += 1;
    }
}

- (double)timeOfPacket:(AVPacket *)packet {
    return packet->dts * av_q2d(_context->streams[packet->stream_index]->time_base);
}

- (bool)writeChunksFinal:(bool)final {
    int streamCount = (int)_context->nb_streams;
    while (true) {
        bool hasPackets = false;
        bool ready = true;
        double oldest = INFINITY;
        double newest = -INFINITY;
        for (int i = 0; i < streamCount; i++) {
            FFMpegMP4StreamWriterTrack *track = &_tracks[i];
            if (track->count == 0) {
                ready = false;
                continue;
            }
            hasPackets = true;
            double first = [self timeOfPacket:track->packets[0]];
            double last = [self timeOfPacket:track->packets[track->count - 1]];
            oldest = MIN(oldest, first);
            newest = MAX(newest, last);
            if (last < _chunkEnd) {
                ready = false;
            }
        }
        if (!hasPackets) {
            return true;
        }
        if (!ready && !final && newest - oldest < FFMpegMP4StreamWriterMaxBufferedDuration) {
            return true;
        }
        if (oldest >= _chunkEnd) {
            _chunkEnd += ceil((oldest - _chunkEnd) / FFMpegMP4StreamWriterChunkDuration) * FFMpegMP4StreamWriterChunkDuration;
            if (oldest >= _chunkEnd) {
                _chunkEnd += FFMpegMP4StreamWriterChunkDuration;
            }
        }
        for (int i = 0; i < streamCount; i++) {
            FFMpegMP4StreamWriterTrack *track = &_tracks[i];
            int written = 0;
            int64_t chunkBytes = 0;
            while (written < track->count && [self timeOfPacket:track->packets[written]] < _chunkEnd) {
                AVPacket *packet = track->packets[written];
                chunkBytes += packet->size;
                int result = av_write_frame(_context, packet);
                av_packet_free(&track->packets[written]);
                written += 1;
                if (result < 0) {
                    [self dropPackets:written fromTrack:track];
                    [self setError:@"write_packet" code:result];
                    return false;
                }
            }
            if (written != 0) {
                track->chunkCount += 1 + chunkBytes / FFMpegMP4StreamWriterMaxChunkSize;
                [self dropPackets:written fromTrack:track];
            }
        }
        _chunkEnd += FFMpegMP4StreamWriterChunkDuration;
    }
}

- (void)dropPackets:(int)count fromTrack:(FFMpegMP4StreamWriterTrack *)track {
    memmove(track->packets, track->packets + count, (size_t)(track->count - count) * sizeof(AVPacket *));
    track->count -= count;
}

- (int64_t)moovSizeUpperBound {
    int64_t bound = 8 * 1024;
    for (int i = 0; i < (int)_context->nb_streams; i++) {
        FFMpegMP4StreamWriterTrack *track = &_tracks[i];
        bound += 4 * 1024 + track->extradataSize;
        bound += track->sampleCount * 5;
        bound += (track->timeToSampleRuns + 2) * 8;
        bound += (track->compositionOffsetRuns + 1) * 8;
        if (track->keyframeCount < track->sampleCount) {
            bound += track->keyframeCount * 4;
        }
        bound += track->chunkCount * 20;
    }
    return bound;
}

- (bool)finish {
    if (!_headerWritten) {
        _lastError = @"header was not written";
        return false;
    }
    if (![self writeChunksFinal:true]) {
        return false;
    }
    avio_flush(_io);
    int result = 0;

    int64_t reservedStart = _headerEnd - FFMpegMP4StreamWriterMdatHeaderSize - _reservedMoovSize;
    bool moveMoovToEnd = _reservedMoovSize > 0 && [self moovSizeUpperBound] > _reservedMoovSize;
    if (moveMoovToEnd) {
        result = av_opt_set_int(_context->priv_data, "moov_size", 0, 0);
        if (result < 0) {
            [self setError:@"moov_size" code:result];
            return false;
        }
    }

    _finalizing = true;
    result = av_write_trailer(_context);
    if (result < 0) {
        [self setError:@"write_trailer" code:result];
        return false;
    }
    avio_flush(_io);

    if (moveMoovToEnd) {
        uint8_t freeHeader[8] = {
            (uint8_t)((_reservedMoovSize >> 24) & 0xff),
            (uint8_t)((_reservedMoovSize >> 16) & 0xff),
            (uint8_t)((_reservedMoovSize >> 8) & 0xff),
            (uint8_t)(_reservedMoovSize & 0xff),
            'f', 'r', 'e', 'e'
        };
        if (pwrite(_fd, freeHeader, sizeof(freeHeader), reservedStart) != sizeof(freeHeader)) {
            [self setError:@"free" code:AVERROR(errno != 0 ? errno : EIO)];
            return false;
        }
        _wroteMoovAtEnd = true;
    }

    if (fsync(_fd) != 0) {
        [self setError:@"fsync" code:AVERROR(errno)];
        return false;
    }
    return true;
}

@end

static int FFMpegMP4StreamWriterWrite(void *opaque, const uint8_t *buffer, int size) {
    FFMpegMP4StreamWriter *writer = (__bridge FFMpegMP4StreamWriter *)opaque;
    return [writer writeBytes:buffer size:size];
}

static int64_t FFMpegMP4StreamWriterSeek(void *opaque, int64_t offset, int whence) {
    FFMpegMP4StreamWriter *writer = (__bridge FFMpegMP4StreamWriter *)opaque;
    return [writer seekToOffset:offset whence:whence];
}
