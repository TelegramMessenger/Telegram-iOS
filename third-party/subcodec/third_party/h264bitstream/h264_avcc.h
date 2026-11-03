#ifndef _H264_AVCC_H
#define _H264_AVCC_H        1

#include <stdint.h>
#include <assert.h>

#include "bs.h"
#include "h264_stream.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
   AVC decoder configuration record, ISO/IEC 14496-15:2004(E), Section 5.2.4.1
   Seen in seen in mp4 files as 'avcC' atom 
   Seen in flv files as AVCVIDEOPACKET with AVCPacketType == 0
*/
typedef struct
{
  int configurationVersion; // = 1
  int AVCProfileIndication;
  int profile_compatibility;
  int AVCLevelIndication;
  // bit(6) reserved = '111111'b;
  int lengthSizeMinusOne;
  // bit(3) reserved = '111'b;
  int numOfSequenceParameterSets;
  sps_t** sps_table;
  int numOfPictureParameterSets;
  pps_t** pps_table;
} avcc_t;

avcc_t* avcc_new();
void avcc_free(avcc_t* avcc);
int read_avcc(avcc_t* avcc, h264_stream_t* h, bs_t* b);
int write_avcc(avcc_t* avcc, h264_stream_t* h, bs_t* b);
void debug_avcc(avcc_t* avcc);

#ifdef __cplusplus
}
#endif

#endif
