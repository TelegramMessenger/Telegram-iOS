#import "OggOpusReader.h"

#import "opusfile/opusfile.h"

static int is_opus(ogg_page *og) {
    ogg_stream_state os;
    ogg_packet op;

    ogg_stream_init(&os, ogg_page_serialno(og));
    ogg_stream_pagein(&os, og);
    if (ogg_stream_packetout(&os, &op) == 1)
    {
        if (op.bytes >= 19 && !memcmp(op.packet, "OpusHead", 8))
        {
            ogg_stream_clear(&os);
            return 1;
        }
    }
    ogg_stream_clear(&os);
    return 0;
}

@implementation OggOpusFrame

- (instancetype)initWithNumSamples:(int)numSamples data:(NSData *)data {
    self = [super init];
    if (self != nil) {
        _numSamples = numSamples;
        _data = data;
    }
    return self;
}

@end

@interface OggOpusReader () {
    OggOpusFile *_opusFile;
}

@end

@implementation OggOpusReader

- (instancetype _Nullable)initWithPath:(NSString *)path {
    self = [super init];
    if (self != nil) {
        int error = OPUS_OK;
        _opusFile = op_open_file(path.UTF8String, &error);
        if (_opusFile == NULL || error != OPUS_OK) {
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    if (_opusFile) {
        op_free(_opusFile);
    }
}

- (int32_t)read:(void *)pcmData bufSize:(int)bufSize {
    return op_read(_opusFile, pcmData, bufSize, NULL);
}

+ (NSArray<OggOpusFrame *> * _Nullable)extractFrames:(NSData *)data {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    ogg_page opage;
    ogg_packet opacket;
    ogg_sync_state ostate;
    ogg_stream_state ostream;
    int sampleRate = 48000;
    
    if (ogg_sync_init(&ostate) < 0) {
        return nil;
    }
    
    char *obuffer;
    long obufferSize = (long)data.length;
    
    obuffer = ogg_sync_buffer(&ostate, obufferSize);
    if (!obuffer) {
        return nil;
    }
    
    memcpy(obuffer, data.bytes, data.length);
    // ogg_sync_wrote function is used to tell the ogg_sync_state struct how many bytes we wrote into the buffer.
    if (ogg_sync_wrote(&ostate, obufferSize) < 0) {
        return nil;
    }
    
    int pages = 0;
    int packetsout = 0;
    int invalid = 0;
    int eos = 0;
    
    int headers = 0;
    int serialno = 0;
    
    /* LOOP START */
    while (ogg_sync_pageout(&ostate, &opage) == 1) {
        pages++;
        
        if (headers == 0) {
            if (is_opus(&opage)) {
                /* this is the start of an Opus stream */
                serialno = ogg_page_serialno(&opage);
                if (ogg_stream_init(&ostream, ogg_page_serialno(&opage)) < 0) {
                    return nil;
                }
                
                headers++;
            } else if (!ogg_page_bos(&opage)) {
                // We're past the header and haven't found an Opus stream.
                // Time to give up.
                break;
            } else {
                /* try again */
                continue;
            }
        }
        
        eos = ogg_page_eos(&opage);
        
        /* submit the page for packetization */
        if (ogg_stream_pagein(&ostream, &opage) < 0) {
            return nil;
        }
        
        /* read and process available packets */
        while (ogg_stream_packetout(&ostream, &opacket) == 1) {
            
            packetsout++;
            
            int samples;
            /* skip header packets */
            if (headers == 1 && opacket.bytes >= 19 && !memcmp(opacket.packet, "OpusHead", 8)) {
                headers++;
                continue;
            }
            if (headers == 2 && opacket.bytes >= 16 && !memcmp(opacket.packet, "OpusTags", 8)) {
                headers++;
                continue;
            }
            
            /* get packet duration */
            samples = opus_packet_get_nb_samples(opacket.packet, opacket.bytes, sampleRate);
            if (samples <= 0) {
                invalid++;
                continue; // skipping invalid packet
            }
            
            [result addObject:[[OggOpusFrame alloc] initWithNumSamples:samples data:[NSData dataWithBytes:opacket.packet length:opacket.bytes]]];
            
            /* update the rtp header and send */
            /*this->rtp.header_size = 12 + 4 * this->rtp.cc;
            this->rtp.seq++;
            this->rtp.time += samples;
            this->rtp.payload_size = opacket.bytes;
            
            // Create RTP Packet
            unsigned char *packet;
            size_t packetSize = this->rtp.header_size + this->rtp.payload_size;
            packet = (unsigned char *)malloc(packetSize);
            if (!packet)
                throw Napi::Error::New(info.Env(), "Couldn't allocate packet buffer.");
            
            // Serialize header and copy to packet. Then copy payload to packet.
            serialize_rtp_header(packet, this->rtp.header_size, &this->rtp);
            memcpy(packet + this->rtp.header_size, opacket.packet, opacket.bytes);
            
            Napi::Buffer<unsigned char> output = Napi::Buffer<unsigned char>::Copy(env, reinterpret_cast<unsigned char *>(packet), packetSize);
            
            push.Call(thisObj, {output});*/
        }
        
        if (eos > 0) {
            // End of the logical bitstream, clear headers to reset.
            headers = 0;
        }
    }
    
    /* CLEAN UP */
    if (eos > 0)
    {
        ogg_stream_clear(&ostream);
        ogg_sync_clear(&ostate);
    }
    
    return result;
}

@end
