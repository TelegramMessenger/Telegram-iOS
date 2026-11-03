//
//  FFMpegAVSampleFormat.h
//  FFMpeg
//
//  Created by Peter Iakovlev on 11/12/2018.
//  Copyright © 2018 Telegram Messenger LLP. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum FFMpegAVSampleFormat {
    FFMPEG_AV_SAMPLE_FMT_NONE = -1,
    FFMPEG_AV_SAMPLE_FMT_U8,          ///< unsigned 8 bits
    FFMPEG_AV_SAMPLE_FMT_S16,         ///< signed 16 bits
    FFMPEG_AV_SAMPLE_FMT_S32,         ///< signed 32 bits
    FFMPEG_AV_SAMPLE_FMT_FLT,         ///< float
    FFMPEG_AV_SAMPLE_FMT_DBL,         ///< double
    
    FFMPEG_AV_SAMPLE_FMT_U8P,         ///< unsigned 8 bits, planar
    FFMPEG_AV_SAMPLE_FMT_S16P,        ///< signed 16 bits, planar
    FFMPEG_AV_SAMPLE_FMT_S32P,        ///< signed 32 bits, planar
    FFMPEG_AV_SAMPLE_FMT_FLTP,        ///< float, planar
    FFMPEG_AV_SAMPLE_FMT_DBLP,        ///< double, planar
    FFMPEG_AV_SAMPLE_FMT_S64,         ///< signed 64 bits
    FFMPEG_AV_SAMPLE_FMT_S64P,        ///< signed 64 bits, planar
    
    FFMPEG_AV_SAMPLE_FMT_NB           ///< Number of sample formats. DO NOT USE if linking dynamically
} FFMpegAVSampleFormat;

NS_ASSUME_NONNULL_END
