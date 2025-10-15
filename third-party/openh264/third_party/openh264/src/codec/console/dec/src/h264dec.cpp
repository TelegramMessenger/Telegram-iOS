/*!
 * \copy
 *     Copyright (c)  2004-2013, Cisco Systems
 *     All rights reserved.
 *
 *     Redistribution and use in source and binary forms, with or without
 *     modification, are permitted provided that the following conditions
 *     are met:
 *
 *        * Redistributions of source code must retain the above copyright
 *          notice, this list of conditions and the following disclaimer.
 *
 *        * Redistributions in binary form must reproduce the above copyright
 *          notice, this list of conditions and the following disclaimer in
 *          the documentation and/or other materials provided with the
 *          distribution.
 *
 *     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 *     FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *     COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 *     INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *     BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *     LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 *     CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 *     LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 *     ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *     POSSIBILITY OF SUCH DAMAGE.
 *
 * h264dec.cpp:         Wels Decoder Console Implementation file
 */

#if defined (_WIN32)
#define _CRT_SECURE_NO_WARNINGS
#include <windows.h>
#include <tchar.h>
#else
#include <string.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#if defined (ANDROID_NDK)
#include <android/log.h>
#endif
#include "codec_def.h"
#include "codec_app_def.h"
#include "codec_api.h"
#include "read_config.h"
#include "typedefs.h"
#include "measure_time.h"
#include "d3d9_utils.h"

using namespace std;

#if defined (WINDOWS_PHONE)
double g_dDecTime = 0.0;
float  g_fDecFPS = 0.0;
int    g_iDecodedFrameNum = 0;
#endif

#if defined(ANDROID_NDK)
#define LOG_TAG "welsdec"
#define LOGI(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define printf LOGI
#define fprintf(a, ...) LOGI(__VA_ARGS__)
#endif
//using namespace WelsDec;

int32_t readBit (uint8_t* pBufPtr, int32_t& curBit) {
  int nIndex = curBit / 8;
  int nOffset = curBit % 8 + 1;

  curBit++;
  return (pBufPtr[nIndex] >> (8 - nOffset)) & 0x01;
}

int32_t readBits (uint8_t* pBufPtr, int32_t& n, int32_t& curBit) {
  int r = 0;
  int i;
  for (i = 0; i < n; i++) {
    r |= (readBit (pBufPtr, curBit) << (n - i - 1));
  }
  return r;
}

int32_t bsGetUe (uint8_t* pBufPtr, int32_t& curBit) {
  int r = 0;
  int i = 0;
  while ((readBit (pBufPtr, curBit) == 0) && (i < 32)) {
    i++;
  }
  r = readBits (pBufPtr, i, curBit);
  r += (1 << i) - 1;
  return r;
}

int32_t readFirstMbInSlice (uint8_t* pSliceNalPtr) {
  int32_t curBit = 0;
  int32_t firstMBInSlice = bsGetUe (pSliceNalPtr + 1, curBit);
  return firstMBInSlice;
}

int32_t readPicture (uint8_t* pBuf, const int32_t& iFileSize, const int32_t& bufPos, uint8_t*& pSpsBuf,
                     int32_t& sps_byte_count) {
  int32_t bytes_available = iFileSize - bufPos;
  if (bytes_available < 4) {
    return bytes_available;
  }
  uint8_t* ptr = pBuf + bufPos;
  int32_t read_bytes = 0;
  int32_t sps_count = 0;
  int32_t pps_count = 0;
  int32_t non_idr_pict_count = 0;
  int32_t idr_pict_count = 0;
  int32_t nal_deliminator = 0;
  pSpsBuf = NULL;
  sps_byte_count = 0;
  while (read_bytes < bytes_available - 4) {
    bool has4ByteStartCode = ptr[0] == 0 && ptr[1] == 0 && ptr[2] == 0 && ptr[3] == 1;
    bool has3ByteStartCode = false;
    if (!has4ByteStartCode) {
      has3ByteStartCode = ptr[0] == 0 && ptr[1] == 0 && ptr[2] == 1;
    }
    if (has4ByteStartCode || has3ByteStartCode) {
      int32_t byteOffset = has4ByteStartCode ? 4 : 3;
      uint8_t nal_unit_type = has4ByteStartCode ? (ptr[4] & 0x1F) : (ptr[3] & 0x1F);
      if (nal_unit_type == 1) {
        int32_t firstMBInSlice = readFirstMbInSlice (ptr + byteOffset);
        if (++non_idr_pict_count >= 1 && idr_pict_count >= 1 && firstMBInSlice == 0) {
          return read_bytes;
        }
        if (non_idr_pict_count >= 2 && firstMBInSlice == 0) {
          return read_bytes;
        }
      } else if (nal_unit_type == 5) {
        int32_t firstMBInSlice = readFirstMbInSlice (ptr + byteOffset);
        if (++idr_pict_count >= 1 && non_idr_pict_count >= 1 && firstMBInSlice == 0) {
          return read_bytes;
        }
        if (idr_pict_count >= 2 && firstMBInSlice == 0) {
          return read_bytes;
        }
      } else if (nal_unit_type == 7) {
        pSpsBuf = ptr + (has4ByteStartCode ? 4 : 3);
        if ((++sps_count >= 1) && (non_idr_pict_count >= 1 || idr_pict_count >= 1)) {
          return read_bytes;
        }
        if (sps_count == 2) {
          return read_bytes;
        }
      } else if (nal_unit_type == 8) {
        if (++pps_count == 1 && sps_count == 1) {
          sps_byte_count = int32_t (ptr - pSpsBuf);
        }
        if (pps_count >= 1 && (non_idr_pict_count >= 1 || idr_pict_count >= 1)) {
          return read_bytes;
        }
      } else if (nal_unit_type == 9) {
        if (++nal_deliminator == 2) {
          return read_bytes;
        }
      }
      if (read_bytes >= bytes_available - 4) {
        return bytes_available;
      }
      read_bytes += 4;
      ptr += 4;
    } else {
      ++ptr;
      ++read_bytes;
    }
  }
  return bytes_available;
}

void FlushFrames (ISVCDecoder* pDecoder, int64_t& iTotal, FILE* pYuvFile, FILE* pOptionFile, int32_t& iFrameCount,
                  unsigned long long& uiTimeStamp, int32_t& iWidth, int32_t& iHeight, int32_t& iLastWidth, int32_t iLastHeight) {
  uint8_t* pData[3] = { NULL };
  uint8_t* pDst[3] = { NULL };
  SBufferInfo sDstBufInfo;
  int32_t num_of_frames_in_buffer = 0;
  CUtils cOutputModule;
  pDecoder->GetOption (DECODER_OPTION_NUM_OF_FRAMES_REMAINING_IN_BUFFER, &num_of_frames_in_buffer);
  for (int32_t i = 0; i < num_of_frames_in_buffer; ++i) {
    int64_t iStart = WelsTime();
    pData[0] = NULL;
    pData[1] = NULL;
    pData[2] = NULL;
    memset (&sDstBufInfo, 0, sizeof (SBufferInfo));
    sDstBufInfo.uiInBsTimeStamp = uiTimeStamp;
    pDecoder->FlushFrame (pData, &sDstBufInfo);
    if (sDstBufInfo.iBufferStatus == 1) {
      pDst[0] = sDstBufInfo.pDst[0];
      pDst[1] = sDstBufInfo.pDst[1];
      pDst[2] = sDstBufInfo.pDst[2];
    }
    int64_t iEnd = WelsTime();
    iTotal += iEnd - iStart;
    if (sDstBufInfo.iBufferStatus == 1) {
      cOutputModule.Process ((void**)pDst, &sDstBufInfo, pYuvFile);
      iWidth = sDstBufInfo.UsrData.sSystemBuffer.iWidth;
      iHeight = sDstBufInfo.UsrData.sSystemBuffer.iHeight;
      if (pOptionFile != NULL) {
        if (iWidth != iLastWidth && iHeight != iLastHeight) {
          fwrite (&iFrameCount, sizeof (iFrameCount), 1, pOptionFile);
          fwrite (&iWidth, sizeof (iWidth), 1, pOptionFile);
          fwrite (&iHeight, sizeof (iHeight), 1, pOptionFile);
          iLastWidth = iWidth;
          iLastHeight = iHeight;
        }
      }
      ++iFrameCount;
    }
  }
}
void H264DecodeInstance (ISVCDecoder* pDecoder, const char* kpH264FileName, const char* kpOuputFileName,
                         int32_t& iWidth, int32_t& iHeight, const char* pOptionFileName, const char* pLengthFileName,
                         int32_t iErrorConMethod,
                         bool bLegacyCalling) {
  FILE* pH264File   = NULL;
  FILE* pYuvFile    = NULL;
  FILE* pOptionFile = NULL;
// Lenght input mode support
  FILE* fpTrack = NULL;

  if (pDecoder == NULL) return;

  int32_t pInfo[4];
  unsigned long long uiTimeStamp = 0;
  int64_t iStart = 0, iEnd = 0, iTotal = 0;
  int32_t iSliceSize;
  int32_t iSliceIndex = 0;
  uint8_t* pBuf = NULL;
  uint8_t uiStartCode[4] = {0, 0, 0, 1};

  uint8_t* pData[3] = {NULL};
  uint8_t* pDst[3] = {NULL};
  SBufferInfo sDstBufInfo;

  int32_t iBufPos = 0;
  int32_t iFileSize;
  int32_t iLastWidth = 0, iLastHeight = 0;
  int32_t iFrameCount = 0;
  int32_t iEndOfStreamFlag = 0;
  pDecoder->SetOption (DECODER_OPTION_ERROR_CON_IDC, &iErrorConMethod);
  CUtils cOutputModule;
  double dElapsed = 0;
  uint8_t uLastSpsBuf[32];
  int32_t iLastSpsByteCount = 0;

  int32_t iThreadCount = 1;
  pDecoder->GetOption (DECODER_OPTION_NUM_OF_THREADS, &iThreadCount);

  if (kpH264FileName) {
    pH264File = fopen (kpH264FileName, "rb");
    if (pH264File == NULL) {
      fprintf (stderr, "Can not open h264 source file, check its legal path related please..\n");
      return;
    }
    fprintf (stderr, "H264 source file name: %s..\n", kpH264FileName);
  } else {
    fprintf (stderr, "Can not find any h264 bitstream file to read..\n");
    fprintf (stderr, "----------------decoder return------------------------\n");
    return;
  }

  if (kpOuputFileName) {
    pYuvFile = fopen (kpOuputFileName, "wb");
    if (pYuvFile == NULL) {
      fprintf (stderr, "Can not open yuv file to output result of decoding..\n");
      // any options
      //return; // can let decoder work in quiet mode, no writing any output
    } else
      fprintf (stderr, "Sequence output file name: %s..\n", kpOuputFileName);
  } else {
    fprintf (stderr, "Can not find any output file to write..\n");
    // any options
  }

  if (pOptionFileName) {
    pOptionFile = fopen (pOptionFileName, "wb");
    if (pOptionFile == NULL) {
      fprintf (stderr, "Can not open optional file for write..\n");
    } else
      fprintf (stderr, "Extra optional file: %s..\n", pOptionFileName);
  }

  if (pLengthFileName != NULL) {
    fpTrack = fopen (pLengthFileName, "rb");
    if (fpTrack == NULL)
      printf ("Length file open ERROR!\n");
  }

  printf ("------------------------------------------------------\n");

  fseek (pH264File, 0L, SEEK_END);
  iFileSize = (int32_t) ftell (pH264File);
  if (iFileSize <= 4) {
    fprintf (stderr, "Current Bit Stream File is too small, read error!!!!\n");
    goto label_exit;
  }
  fseek (pH264File, 0L, SEEK_SET);

  pBuf = new uint8_t[iFileSize + 4];
  if (pBuf == NULL) {
    fprintf (stderr, "new buffer failed!\n");
    goto label_exit;
  }

  if (fread (pBuf, 1, iFileSize, pH264File) != (uint32_t)iFileSize) {
    fprintf (stderr, "Unable to read whole file\n");
    goto label_exit;
  }

  memcpy (pBuf + iFileSize, &uiStartCode[0], 4); //confirmed_safe_unsafe_usage

  while (true) {

    if (iBufPos >= iFileSize) {
      iEndOfStreamFlag = true;
      if (iEndOfStreamFlag)
        pDecoder->SetOption (DECODER_OPTION_END_OF_STREAM, (void*)&iEndOfStreamFlag);
      break;
    }
// Read length from file if needed
    if (fpTrack) {
      if (fread (pInfo, 4, sizeof (int32_t), fpTrack) < 4)
        goto label_exit;
      iSliceSize = static_cast<int32_t> (pInfo[2]);
    } else {
      if (iThreadCount >= 1) {
        uint8_t* uSpsPtr = NULL;
        int32_t iSpsByteCount = 0;
        iSliceSize = readPicture (pBuf, iFileSize, iBufPos, uSpsPtr, iSpsByteCount);
        if (iLastSpsByteCount > 0 && iSpsByteCount > 0) {
          if (iSpsByteCount != iLastSpsByteCount || memcmp (uSpsPtr, uLastSpsBuf, iLastSpsByteCount) != 0) {
            //whenever new sequence is different from preceding sequence. All pending frames must be flushed out before the new sequence can start to decode.
            FlushFrames (pDecoder, iTotal, pYuvFile, pOptionFile, iFrameCount, uiTimeStamp, iWidth, iHeight, iLastWidth,
                         iLastHeight);
          }
        }
        if (iSpsByteCount > 0 && uSpsPtr != NULL) {
          if (iSpsByteCount > 32) iSpsByteCount = 32;
          iLastSpsByteCount = iSpsByteCount;
          memcpy (uLastSpsBuf, uSpsPtr, iSpsByteCount);
        }
      } else {
        int i = 0;
        for (i = 0; i < iFileSize; i++) {
          if ((pBuf[iBufPos + i] == 0 && pBuf[iBufPos + i + 1] == 0 && pBuf[iBufPos + i + 2] == 0 && pBuf[iBufPos + i + 3] == 1
               && i > 0) || (pBuf[iBufPos + i] == 0 && pBuf[iBufPos + i + 1] == 0 && pBuf[iBufPos + i + 2] == 1 && i > 0)) {
            break;
          }
        }
        iSliceSize = i;
      }
    }
    if (iSliceSize < 4) { //too small size, no effective data, ignore
      iBufPos += iSliceSize;
      continue;
    }

//for coverage test purpose
    int32_t iEndOfStreamFlag;
    pDecoder->GetOption (DECODER_OPTION_END_OF_STREAM, &iEndOfStreamFlag);
    int32_t iCurIdrPicId;
    pDecoder->GetOption (DECODER_OPTION_IDR_PIC_ID, &iCurIdrPicId);
    int32_t iFrameNum;
    pDecoder->GetOption (DECODER_OPTION_FRAME_NUM, &iFrameNum);
    int32_t bCurAuContainLtrMarkSeFlag;
    pDecoder->GetOption (DECODER_OPTION_LTR_MARKING_FLAG, &bCurAuContainLtrMarkSeFlag);
    int32_t iFrameNumOfAuMarkedLtr;
    pDecoder->GetOption (DECODER_OPTION_LTR_MARKED_FRAME_NUM, &iFrameNumOfAuMarkedLtr);
    int32_t iFeedbackVclNalInAu;
    pDecoder->GetOption (DECODER_OPTION_VCL_NAL, &iFeedbackVclNalInAu);
    int32_t iFeedbackTidInAu;
    pDecoder->GetOption (DECODER_OPTION_TEMPORAL_ID, &iFeedbackTidInAu);
//~end for

    iStart = WelsTime();
    pData[0] = NULL;
    pData[1] = NULL;
    pData[2] = NULL;
    uiTimeStamp ++;
    memset (&sDstBufInfo, 0, sizeof (SBufferInfo));
    sDstBufInfo.uiInBsTimeStamp = uiTimeStamp;
    if (!bLegacyCalling) {
      pDecoder->DecodeFrameNoDelay (pBuf + iBufPos, iSliceSize, pData, &sDstBufInfo);
    } else {
      pDecoder->DecodeFrame2 (pBuf + iBufPos, iSliceSize, pData, &sDstBufInfo);
    }

    if (sDstBufInfo.iBufferStatus == 1) {
      pDst[0] = sDstBufInfo.pDst[0];
      pDst[1] = sDstBufInfo.pDst[1];
      pDst[2] = sDstBufInfo.pDst[2];
    }
    iEnd    = WelsTime();
    iTotal += iEnd - iStart;
    if (sDstBufInfo.iBufferStatus == 1) {
      cOutputModule.Process ((void**)pDst, &sDstBufInfo, pYuvFile);
      iWidth  = sDstBufInfo.UsrData.sSystemBuffer.iWidth;
      iHeight = sDstBufInfo.UsrData.sSystemBuffer.iHeight;

      if (pOptionFile != NULL) {
        if (iWidth != iLastWidth && iHeight != iLastHeight) {
          fwrite (&iFrameCount, sizeof (iFrameCount), 1, pOptionFile);
          fwrite (&iWidth, sizeof (iWidth), 1, pOptionFile);
          fwrite (&iHeight, sizeof (iHeight), 1, pOptionFile);
          iLastWidth  = iWidth;
          iLastHeight = iHeight;
        }
      }
      ++ iFrameCount;
    }

    if (bLegacyCalling) {
      iStart = WelsTime();
      pData[0] = NULL;
      pData[1] = NULL;
      pData[2] = NULL;
      memset (&sDstBufInfo, 0, sizeof (SBufferInfo));
      sDstBufInfo.uiInBsTimeStamp = uiTimeStamp;
      pDecoder->DecodeFrame2 (NULL, 0, pData, &sDstBufInfo);
      if (sDstBufInfo.iBufferStatus == 1) {
        pDst[0] = sDstBufInfo.pDst[0];
        pDst[1] = sDstBufInfo.pDst[1];
        pDst[2] = sDstBufInfo.pDst[2];
      }
      iEnd    = WelsTime();
      iTotal += iEnd - iStart;
      if (sDstBufInfo.iBufferStatus == 1) {
        cOutputModule.Process ((void**)pDst, &sDstBufInfo, pYuvFile);
        iWidth  = sDstBufInfo.UsrData.sSystemBuffer.iWidth;
        iHeight = sDstBufInfo.UsrData.sSystemBuffer.iHeight;

        if (pOptionFile != NULL) {
          if (iWidth != iLastWidth && iHeight != iLastHeight) {
            fwrite (&iFrameCount, sizeof (iFrameCount), 1, pOptionFile);
            fwrite (&iWidth, sizeof (iWidth), 1, pOptionFile);
            fwrite (&iHeight, sizeof (iHeight), 1, pOptionFile);
            iLastWidth  = iWidth;
            iLastHeight = iHeight;
          }
        }
        ++ iFrameCount;
      }
    }
    iBufPos += iSliceSize;
    ++ iSliceIndex;
  }
  FlushFrames (pDecoder, iTotal, pYuvFile, pOptionFile, iFrameCount, uiTimeStamp, iWidth, iHeight, iLastWidth,
               iLastHeight);
  dElapsed = iTotal / 1e6;
  fprintf (stderr, "-------------------------------------------------------\n");
  fprintf (stderr, "iWidth:\t\t%d\nheight:\t\t%d\nFrames:\t\t%d\ndecode time:\t%f sec\nFPS:\t\t%f fps\n",
           iWidth, iHeight, iFrameCount, dElapsed, (iFrameCount * 1.0) / dElapsed);
  fprintf (stderr, "-------------------------------------------------------\n");

#if defined (WINDOWS_PHONE)
  g_dDecTime = dElapsed;
  g_fDecFPS = (iFrameCount * 1.0f) / (float) dElapsed;
  g_iDecodedFrameNum = iFrameCount;
#endif

  // coverity scan uninitial
label_exit:
  if (pBuf) {
    delete[] pBuf;
    pBuf = NULL;
  }
  if (pH264File) {
    fclose (pH264File);
    pH264File = NULL;
  }
  if (pYuvFile) {
    fclose (pYuvFile);
    pYuvFile = NULL;
  }
  if (pOptionFile) {
    fclose (pOptionFile);
    pOptionFile = NULL;
  }
  if (fpTrack) {
    fclose (fpTrack);
    fpTrack = NULL;
  }

}

#if (defined(ANDROID_NDK)||defined(APPLE_IOS) || defined (WINDOWS_PHONE))
int32_t DecMain (int32_t iArgC, char* pArgV[]) {
#else
int32_t main (int32_t iArgC, char* pArgV[]) {
#endif
  ISVCDecoder* pDecoder = NULL;

  SDecodingParam sDecParam = {0};
  string strInputFile (""), strOutputFile (""), strOptionFile (""), strLengthFile ("");
  int iLevelSetting = (int) WELS_LOG_WARNING;
  bool bLegacyCalling = false;

  sDecParam.sVideoProperty.size = sizeof (sDecParam.sVideoProperty);
  sDecParam.eEcActiveIdc = ERROR_CON_SLICE_MV_COPY_CROSS_IDR_FREEZE_RES_CHANGE;

  if (iArgC < 2) {
    printf ("usage 1: h264dec.exe welsdec.cfg\n");
    printf ("usage 2: h264dec.exe welsdec.264 out.yuv\n");
    printf ("usage 3: h264dec.exe welsdec.264\n");
    return 1;
  } else if (iArgC == 2) {
    if (strstr (pArgV[1], ".cfg")) { // read config file //confirmed_safe_unsafe_usage
      CReadConfig cReadCfg (pArgV[1]);
      string strTag[4];
      string strReconFile ("");

      if (!cReadCfg.ExistFile()) {
        printf ("Specified file: %s not exist, maybe invalid path or parameter settting.\n", cReadCfg.GetFileName().c_str());
        return 1;
      }

      while (!cReadCfg.EndOfFile()) {
        long nRd = cReadCfg.ReadLine (&strTag[0]);
        if (nRd > 0) {
          if (strTag[0].compare ("InputFile") == 0) {
            strInputFile = strTag[1];
          } else if (strTag[0].compare ("OutputFile") == 0) {
            strOutputFile = strTag[1];
          } else if (strTag[0].compare ("RestructionFile") == 0) {
            strReconFile = strTag[1];
            int32_t iLen = (int32_t)strReconFile.length();
            sDecParam.pFileNameRestructed = new char[iLen + 1];
            if (sDecParam.pFileNameRestructed != NULL) {
              sDecParam.pFileNameRestructed[iLen] = 0;
            }

            strncpy (sDecParam.pFileNameRestructed, strReconFile.c_str(), iLen); //confirmed_safe_unsafe_usage
          } else if (strTag[0].compare ("TargetDQID") == 0) {
            sDecParam.uiTargetDqLayer = (uint8_t)atol (strTag[1].c_str());
          } else if (strTag[0].compare ("ErrorConcealmentIdc") == 0) {
            sDecParam.eEcActiveIdc = (ERROR_CON_IDC)atol (strTag[1].c_str());
          } else if (strTag[0].compare ("CPULoad") == 0) {
            sDecParam.uiCpuLoad = (uint32_t)atol (strTag[1].c_str());
          } else if (strTag[0].compare ("VideoBitstreamType") == 0) {
            sDecParam.sVideoProperty.eVideoBsType = (VIDEO_BITSTREAM_TYPE)atol (strTag[1].c_str());
          }
        }
      }
      if (strOutputFile.empty()) {
        printf ("No output file specified in configuration file.\n");
        return 1;
      }
    } else if (strstr (pArgV[1],
                       ".264")) { // no output dump yuv file, just try to render the decoded pictures //confirmed_safe_unsafe_usage
      strInputFile = pArgV[1];
      sDecParam.uiTargetDqLayer = (uint8_t) - 1;
      sDecParam.eEcActiveIdc = ERROR_CON_SLICE_COPY;
      sDecParam.sVideoProperty.eVideoBsType = VIDEO_BITSTREAM_DEFAULT;
    }
  } else { //iArgC > 2
    strInputFile = pArgV[1];
    strOutputFile = pArgV[2];
    sDecParam.uiTargetDqLayer = (uint8_t) - 1;
    sDecParam.eEcActiveIdc = ERROR_CON_SLICE_COPY;
    sDecParam.sVideoProperty.eVideoBsType = VIDEO_BITSTREAM_DEFAULT;
    if (iArgC > 3) {
      for (int i = 3; i < iArgC; i++) {
        char* cmd = pArgV[i];

        if (!strcmp (cmd, "-options")) {
          if (i + 1 < iArgC)
            strOptionFile = pArgV[++i];
          else {
            printf ("options file not specified.\n");
            return 1;
          }
        } else if (!strcmp (cmd, "-trace")) {
          if (i + 1 < iArgC)
            iLevelSetting = atoi (pArgV[++i]);
          else {
            printf ("trace level not specified.\n");
            return 1;
          }
        } else if (!strcmp (cmd, "-length")) {
          if (i + 1 < iArgC)
            strLengthFile = pArgV[++i];
          else {
            printf ("lenght file not specified.\n");
            return 1;
          }
        } else if (!strcmp (cmd, "-ec")) {
          if (i + 1 < iArgC) {
            int iEcActiveIdc = atoi (pArgV[++i]);
            sDecParam.eEcActiveIdc = (ERROR_CON_IDC)iEcActiveIdc;
            printf ("ERROR_CON(cealment) is set to %d.\n", iEcActiveIdc);
          }
        } else if (!strcmp (cmd, "-legacy")) {
          bLegacyCalling = true;
        }
      }
    }

    if (strOutputFile.empty()) {
      printf ("No output file specified in configuration file.\n");
      return 1;
    }
  }

  if (strInputFile.empty()) {
    printf ("No input file specified in configuration file.\n");
    return 1;
  }




  if (WelsCreateDecoder (&pDecoder)  || (NULL == pDecoder)) {
    printf ("Create Decoder failed.\n");
    return 1;
  }
  if (iLevelSetting >= 0) {
    pDecoder->SetOption (DECODER_OPTION_TRACE_LEVEL, &iLevelSetting);
  }

  int32_t iThreadCount = 0;
  pDecoder->SetOption (DECODER_OPTION_NUM_OF_THREADS, &iThreadCount);

  if (pDecoder->Initialize (&sDecParam)) {
    printf ("Decoder initialization failed.\n");
    return 1;
  }


  int32_t iWidth = 0;
  int32_t iHeight = 0;


  H264DecodeInstance (pDecoder, strInputFile.c_str(), !strOutputFile.empty() ? strOutputFile.c_str() : NULL, iWidth,
                      iHeight,
                      (!strOptionFile.empty() ? strOptionFile.c_str() : NULL), (!strLengthFile.empty() ? strLengthFile.c_str() : NULL),
                      (int32_t)sDecParam.eEcActiveIdc,
                      bLegacyCalling);

  if (sDecParam.pFileNameRestructed != NULL) {
    delete []sDecParam.pFileNameRestructed;
    sDecParam.pFileNameRestructed = NULL;
  }

  if (pDecoder) {
    pDecoder->Uninitialize();

    WelsDestroyDecoder (pDecoder);
  }

  return 0;
}
