//
//  svc_split.c
//  h264bitstream-svc
//
//  Created by qiwa on 12/18/16.
//  Copyright © 2016 qiwa. All rights reserved.
//

#include <stdio.h>

#include "h264_stream.h"

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#define BUFSIZE 32*1024*1024

int main(int argc, char *argv[])
{
    uint8_t* buf = (uint8_t*)malloc( BUFSIZE );
    
    h264_stream_t* h = h264_new();
    
    FILE* infile = fopen(argv[1], "rb");
    if (infile == NULL) { fprintf( stderr, "!! Error: could not open file: %s \n", strerror(errno)); exit(EXIT_FAILURE); }
    
    char fname_buf[1024] = {0};
    
    //create base layer file
    sprintf(fname_buf, "%s.base", argv[1]);
    FILE* outfile_base = fopen(fname_buf, "wb");
    if (outfile_base == NULL) { fprintf( stderr, "!! Error: could not open file: %s \n", strerror(errno)); exit(EXIT_FAILURE); }
    
    //scalable layer
    FILE* outfile_layers[32] = {0};
    
    //misc packets file
    memset(fname_buf, 0, 1024);
    sprintf(fname_buf, "%s.misc", argv[1]);
    FILE* outfile_misc = fopen(fname_buf, "wb");
    if (outfile_misc == NULL) { fprintf( stderr, "!! Error: could not open file: %s \n", strerror(errno)); exit(EXIT_FAILURE); }
    

    if (h264_dbgfile == NULL) { h264_dbgfile = stdout; }
    
    size_t rsz = 0;
    size_t sz = 0;
    int64_t off = 0;
    uint8_t* p = buf;
    
    int nal_start, nal_end;
    
    //this is to identify whether pps is written or not
    char *pps_buf[32];
    int pps_buf_size[32];
    
    while (1)
    {
        rsz = fread(buf + sz, 1, BUFSIZE - sz, infile);
        if (rsz == 0)
        {
            if (ferror(infile)) { fprintf( stderr, "!! Error: read failed: %s \n", strerror(errno)); break; }
            break;  // if (feof(infile))
        }
        
        sz += rsz;
        
        while (find_nal_unit(p, sz, &nal_start, &nal_end) > 0)
        {
            fprintf( h264_dbgfile, "!! Found NAL at offset %lld (0x%04llX), size %lld (0x%04llX) \n",
                        (long long int)(off + (p - buf) + nal_start),
                        (long long int)(off + (p - buf) + nal_start),
                        (long long int)(nal_end - nal_start),
                        (long long int)(nal_end - nal_start) );
            
            fprintf( h264_dbgfile, "XX ");
            debug_bytes(p, nal_end - nal_start >= 16 ? 16: nal_end - nal_start);
            
            p += nal_start;
            read_debug_nal_unit(h, p, nal_end - nal_start);
            
            //check nal type
            switch (h->nal->nal_unit_type)
            {
                case NAL_UNIT_TYPE_CODED_SLICE_IDR:
                case NAL_UNIT_TYPE_CODED_SLICE_NON_IDR:
                case NAL_UNIT_TYPE_CODED_SLICE_AUX:
                    printf("reference pps: %d & sps: %d\n", h->sh->pic_parameter_set_id,
                           h->pps_table[h->sh->pic_parameter_set_id]->seq_parameter_set_id);
                    
                    if (pps_buf[h->sh->pic_parameter_set_id] != NULL)
                    {
                        fwrite(pps_buf[h->sh->pic_parameter_set_id], 1, pps_buf_size[h->sh->pic_parameter_set_id], outfile_base);
                        free(pps_buf[h->sh->pic_parameter_set_id]);
                        pps_buf[h->sh->pic_parameter_set_id] = NULL;
                    }
                    
                    //start saving the slices
                    fwrite(p - nal_start, 1, nal_end, outfile_base);
                    
                    break;
                    
                case NAL_UNIT_TYPE_SPS:
                    fwrite(p - nal_start, 1, nal_end, outfile_base);
                    break;
                    
                case NAL_UNIT_TYPE_PPS:
                    pps_buf[h->pps->pic_parameter_set_id] = malloc(nal_end);
                    memcpy(pps_buf[h->pps->pic_parameter_set_id], p - nal_start, nal_end);
                    pps_buf_size[h->pps->pic_parameter_set_id] = nal_end;
                    
                    break;
                    
                    //SVC support
                case NAL_UNIT_TYPE_SUBSET_SPS:
                    printf("sps_ext id: %d\n", h->sps_subset->sps->seq_parameter_set_id);
                    memset(fname_buf, 0, 1024);
                    sprintf(fname_buf, "%s.l_%d", argv[1], h->sps_subset->sps->seq_parameter_set_id);
                    outfile_layers[h->sps_subset->sps->seq_parameter_set_id] = fopen(fname_buf, "wb");
                    if (outfile_layers[h->sps_subset->sps->seq_parameter_set_id] == NULL) { fprintf( stderr, "!! Error: could not open file: %s \n", strerror(errno)); exit(EXIT_FAILURE); }
                    
                    fwrite(p - nal_start, 1, nal_end, outfile_layers[h->sps_subset->sps->seq_parameter_set_id]);
                    break;
                    
                    //SVC support
                case NAL_UNIT_TYPE_CODED_SLICE_SVC_EXTENSION:            
                    printf("reference extension pps: %d & sps: %d\n", h->sh->pic_parameter_set_id,
                           h->pps_table[h->sh->pic_parameter_set_id]->seq_parameter_set_id);
                    
                    if (pps_buf[h->sh->pic_parameter_set_id] != NULL)
                    {
                        fwrite(pps_buf[h->sh->pic_parameter_set_id], 1, pps_buf_size[h->sh->pic_parameter_set_id], outfile_layers[h->pps_table[h->sh->pic_parameter_set_id]->seq_parameter_set_id]);
                        free(pps_buf[h->sh->pic_parameter_set_id]);
                        pps_buf[h->sh->pic_parameter_set_id] = NULL;
                    }
                    
                    //start saving the slices
                    fwrite(p - nal_start, 1, nal_end, outfile_layers[h->pps_table[h->sh->pic_parameter_set_id]->seq_parameter_set_id]);
                    break;
                    
                default:
                    fwrite(p - nal_start, 1, nal_end, outfile_misc);
                    break;
            }
            
            //save nal to corresponding file
            
            //skip to next NAL
            p += (nal_end - nal_start);
            sz -= nal_end;
            
        }
        
        // if no NALs found in buffer, discard it
        if (p == buf)
        {
            fprintf( stderr, "!! Did not find any NALs between offset %lld (0x%04llX), size %lld (0x%04llX), discarding \n",
                    (long long int)off,
                    (long long int)off,
                    (long long int)off + sz,
                    (long long int)off + sz);
            
            p = buf + sz;
            sz = 0;
        }
        
        memmove(buf, p, sz);
        off += p - buf;
        p = buf;
    }
    
    h264_free(h);
    free(buf);
    
    fclose(h264_dbgfile);
    fclose(infile);
    fclose(outfile_base);
    fclose(outfile_misc);
    for(int i = 0; i < 32; i++) {
        if (outfile_layers[i] != NULL)
            fclose(outfile_layers[i]);
    }

    return 0;
}
