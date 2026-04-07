#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#include "h264_avcc.h"
#include "bs.h"
#include "h264_stream.h"

avcc_t* avcc_new()
{
  avcc_t* avcc = (avcc_t*)calloc(1, sizeof(avcc_t));
  avcc->sps_table = NULL;
  avcc->pps_table = NULL;
  return avcc;
}

void avcc_free(avcc_t* avcc)
{
  if (avcc->sps_table != NULL) { free(avcc->sps_table); }
  if (avcc->pps_table != NULL) { free(avcc->pps_table); }
  free(avcc);
}

int read_avcc(avcc_t* avcc, h264_stream_t* h, bs_t* b)
{
  avcc->configurationVersion = bs_read_u8(b);
  avcc->AVCProfileIndication = bs_read_u8(b);
  avcc->profile_compatibility = bs_read_u8(b);
  avcc->AVCLevelIndication = bs_read_u8(b);
  /* int reserved = */ bs_read_u(b, 6); // '111111'b;
  avcc->lengthSizeMinusOne = bs_read_u(b, 2);
  /* int reserved = */ bs_read_u(b, 3); // '111'b;

  avcc->numOfSequenceParameterSets = bs_read_u(b, 5);
  avcc->sps_table = (sps_t**)calloc(avcc->numOfSequenceParameterSets, sizeof(sps_t*));
  for (int i = 0; i < avcc->numOfSequenceParameterSets; i++)
  {
    int sequenceParameterSetLength = bs_read_u(b, 16);
    int len = sequenceParameterSetLength;
    uint8_t* buf = (uint8_t*)malloc(len);
    len = bs_read_bytes(b, buf, len);
    int rc = read_nal_unit(h, buf, len);
    free(buf);
    if (h->nal->nal_unit_type != NAL_UNIT_TYPE_SPS) { continue; } // TODO report errors
    if (rc < 0) { continue; }
    avcc->sps_table[i] = h->sps; // TODO copy data?
  }

  avcc->numOfPictureParameterSets = bs_read_u(b, 8);
  avcc->pps_table = (pps_t**)calloc(avcc->numOfPictureParameterSets, sizeof(pps_t*));
  for (int i = 0; i < avcc->numOfPictureParameterSets; i++)
  {
    int pictureParameterSetLength = bs_read_u(b, 16);
    int len = pictureParameterSetLength;
    uint8_t* buf = (uint8_t*)malloc(len);
    len = bs_read_bytes(b, buf, len);
    int rc = read_nal_unit(h, buf, len);
    free(buf);
    if (h->nal->nal_unit_type != NAL_UNIT_TYPE_PPS) { continue; } // TODO report errors
    if (rc < 0) { continue; }
    avcc->pps_table[i] = h->pps; // TODO copy data?
  }

  if (bs_overrun(b)) { return -1; }
  return bs_pos(b);
}


int write_avcc(avcc_t* avcc, h264_stream_t* h, bs_t* b)
{
  bs_write_u8(b, 1); // configurationVersion = 1;
  bs_write_u8(b, avcc->AVCProfileIndication);
  bs_write_u8(b, avcc->profile_compatibility);
  bs_write_u8(b, avcc->AVCLevelIndication);
  bs_write_u(b, 6, 0x3F); // reserved = '111111'b;
  bs_write_u(b, 2, avcc->lengthSizeMinusOne);
  bs_write_u(b, 3, 0x07); // reserved = '111'b;

  bs_write_u(b, 5, avcc->numOfSequenceParameterSets);
  for (int i = 0; i < avcc->numOfSequenceParameterSets; i++)
  {
    int max_len = 1024; // FIXME
    uint8_t* buf = (uint8_t*)malloc(max_len);
    h->nal->nal_ref_idc = 3; // NAL_REF_IDC_PRIORITY_HIGHEST;
    h->nal->nal_unit_type = NAL_UNIT_TYPE_SPS;
    h->sps = avcc->sps_table[i];
    int len = write_nal_unit(h, buf, max_len);
    if (len < 0) { free(buf); continue; } // TODO report errors
    int sequenceParameterSetLength = len;
    bs_write_u(b, 16, sequenceParameterSetLength);
    bs_write_bytes(b, buf, len);
    free(buf);
  }

  bs_write_u(b, 8, avcc->numOfPictureParameterSets);
  for (int i = 0; i < avcc->numOfPictureParameterSets; i++)
  {
    int max_len = 1024; // FIXME
    uint8_t* buf = (uint8_t*)malloc(max_len);
    h->nal->nal_ref_idc = 3; // NAL_REF_IDC_PRIORITY_HIGHEST;
    h->nal->nal_unit_type = NAL_UNIT_TYPE_PPS;
    h->pps = avcc->pps_table[i];
    int len = write_nal_unit(h, buf, max_len);
    if (len < 0) { free(buf); continue; } // TODO report errors
    int pictureParameterSetLength = len;
    bs_write_u(b, 16, pictureParameterSetLength);
    bs_write_bytes(b, buf, len);
    free(buf);
  }

  if (bs_overrun(b)) { return -1; }
  return bs_pos(b);
}

void debug_avcc(avcc_t* avcc)
{
  printf("======= AVC Decoder Configuration Record =======\n");
  printf(" configurationVersion: %d\n", avcc->configurationVersion );
  printf(" AVCProfileIndication: %d\n", avcc->AVCProfileIndication );
  printf(" profile_compatibility: %d\n", avcc->profile_compatibility );
  printf(" AVCLevelIndication: %d\n", avcc->AVCLevelIndication );
  printf(" lengthSizeMinusOne: %d\n", avcc->lengthSizeMinusOne );

  printf("\n");
  printf(" numOfSequenceParameterSets: %d\n", avcc->numOfSequenceParameterSets );
  for (int i = 0; i < avcc->numOfSequenceParameterSets; i++)
  {
    //printf(" sequenceParameterSetLength\n", avcc->sequenceParameterSetLength );
    if (avcc->sps_table[i] == NULL) { printf(" null sps\n"); continue; }
    debug_sps(avcc->sps_table[i]);
  }

  printf("\n");
  printf(" numOfPictureParameterSets: %d\n", avcc->numOfPictureParameterSets );
  for (int i = 0; i < avcc->numOfPictureParameterSets; i++)
  {
    //printf(" pictureParameterSetLength\n", avcc->pictureParameterSetLength );
    if (avcc->pps_table[i] == NULL) { printf(" null pps\n"); continue; }
    debug_pps(avcc->pps_table[i]);
  }
}
