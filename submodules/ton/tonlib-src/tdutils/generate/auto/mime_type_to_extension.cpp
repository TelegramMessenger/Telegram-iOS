/* ANSI-C code produced by gperf version 3.0.3 */
/* Command-line: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/gperf -m100 auto/mime_type_to_extension.gperf  */
/* Computed positions: -k'1,6-7,9-10,13-18,20,23,25-26,31,36,$' */

#if !((' ' == 32) && ('!' == 33) && ('"' == 34) && ('#' == 35) \
      && ('%' == 37) && ('&' == 38) && ('\'' == 39) && ('(' == 40) \
      && (')' == 41) && ('*' == 42) && ('+' == 43) && (',' == 44) \
      && ('-' == 45) && ('.' == 46) && ('/' == 47) && ('0' == 48) \
      && ('1' == 49) && ('2' == 50) && ('3' == 51) && ('4' == 52) \
      && ('5' == 53) && ('6' == 54) && ('7' == 55) && ('8' == 56) \
      && ('9' == 57) && (':' == 58) && (';' == 59) && ('<' == 60) \
      && ('=' == 61) && ('>' == 62) && ('?' == 63) && ('A' == 65) \
      && ('B' == 66) && ('C' == 67) && ('D' == 68) && ('E' == 69) \
      && ('F' == 70) && ('G' == 71) && ('H' == 72) && ('I' == 73) \
      && ('J' == 74) && ('K' == 75) && ('L' == 76) && ('M' == 77) \
      && ('N' == 78) && ('O' == 79) && ('P' == 80) && ('Q' == 81) \
      && ('R' == 82) && ('S' == 83) && ('T' == 84) && ('U' == 85) \
      && ('V' == 86) && ('W' == 87) && ('X' == 88) && ('Y' == 89) \
      && ('Z' == 90) && ('[' == 91) && ('\\' == 92) && (']' == 93) \
      && ('^' == 94) && ('_' == 95) && ('a' == 97) && ('b' == 98) \
      && ('c' == 99) && ('d' == 100) && ('e' == 101) && ('f' == 102) \
      && ('g' == 103) && ('h' == 104) && ('i' == 105) && ('j' == 106) \
      && ('k' == 107) && ('l' == 108) && ('m' == 109) && ('n' == 110) \
      && ('o' == 111) && ('p' == 112) && ('q' == 113) && ('r' == 114) \
      && ('s' == 115) && ('t' == 116) && ('u' == 117) && ('v' == 118) \
      && ('w' == 119) && ('x' == 120) && ('y' == 121) && ('z' == 122) \
      && ('{' == 123) && ('|' == 124) && ('}' == 125) && ('~' == 126))
/* The character set is not based on ISO-646.  */
#error "gperf generated tables don't work with this execution character set. Please report a bug to <bug-gnu-gperf@gnu.org>."
#endif

#line 12 "auto/mime_type_to_extension.gperf"
struct mime_type_and_extension {
  const char *mime_type;
  const char *extension;
};
#include <string.h>
/* maximum key range = 4605, duplicates = 0 */

#ifndef GPERF_DOWNCASE
#define GPERF_DOWNCASE 1
static unsigned char gperf_downcase[256] =
  {
      0,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,
     15,  16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,
     30,  31,  32,  33,  34,  35,  36,  37,  38,  39,  40,  41,  42,  43,  44,
     45,  46,  47,  48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,
     60,  61,  62,  63,  64,  97,  98,  99, 100, 101, 102, 103, 104, 105, 106,
    107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121,
    122,  91,  92,  93,  94,  95,  96,  97,  98,  99, 100, 101, 102, 103, 104,
    105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119,
    120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134,
    135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149,
    150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164,
    165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179,
    180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194,
    195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209,
    210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224,
    225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239,
    240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254,
    255
  };
#endif

#ifndef GPERF_CASE_STRCMP
#define GPERF_CASE_STRCMP 1
static int
gperf_case_strcmp (register const char *s1, register const char *s2)
{
  for (;;)
    {
      unsigned char c1 = gperf_downcase[(unsigned char)*s1++];
      unsigned char c2 = gperf_downcase[(unsigned char)*s2++];
      if (c1 != 0 && c1 == c2)
        continue;
      return (int)c1 - (int)c2;
    }
}
#endif

#ifdef __GNUC__
__inline
#else
#ifdef __cplusplus
inline
#endif
#endif
static unsigned int
mime_type_hash (register const char *str, register unsigned int len)
{
  static const unsigned short asso_values[] =
    {
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686,  885, 4686,  246,   74,  610,   13,   13,
       208,   32,   14,   17,   23,   15,   12,   12, 4686, 4686,
      4686, 4686, 4686, 4686, 4686,   15,  927,   27,   48,   15,
       336,  654,  914,   13,  766, 1405,  205,   14,   12,   14,
        13,   30,   37,   12,   22,  755,   34, 1200,  156, 1446,
       392, 4686, 4686, 4686, 4686, 4686, 4686,   15,  927,   27,
        48,   15,  336,  654,  914,   13,  766, 1405,  205,   14,
        12,   14,   13,   30,   37,   12,   22,  755,   34, 1200,
       156, 1446,  392, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686, 4686,
      4686, 4686, 4686, 4686, 4686, 4686
    };
  register unsigned int hval = len;

  switch (hval)
    {
      default:
        hval += asso_values[(unsigned char)str[35]];
      /*FALLTHROUGH*/
      case 35:
      case 34:
      case 33:
      case 32:
      case 31:
        hval += asso_values[(unsigned char)str[30]];
      /*FALLTHROUGH*/
      case 30:
      case 29:
      case 28:
      case 27:
      case 26:
        hval += asso_values[(unsigned char)str[25]];
      /*FALLTHROUGH*/
      case 25:
        hval += asso_values[(unsigned char)str[24]];
      /*FALLTHROUGH*/
      case 24:
      case 23:
        hval += asso_values[(unsigned char)str[22]];
      /*FALLTHROUGH*/
      case 22:
      case 21:
      case 20:
        hval += asso_values[(unsigned char)str[19]];
      /*FALLTHROUGH*/
      case 19:
      case 18:
        hval += asso_values[(unsigned char)str[17]];
      /*FALLTHROUGH*/
      case 17:
        hval += asso_values[(unsigned char)str[16]];
      /*FALLTHROUGH*/
      case 16:
        hval += asso_values[(unsigned char)str[15]];
      /*FALLTHROUGH*/
      case 15:
        hval += asso_values[(unsigned char)str[14]];
      /*FALLTHROUGH*/
      case 14:
        hval += asso_values[(unsigned char)str[13]];
      /*FALLTHROUGH*/
      case 13:
        hval += asso_values[(unsigned char)str[12]];
      /*FALLTHROUGH*/
      case 12:
      case 11:
      case 10:
        hval += asso_values[(unsigned char)str[9]];
      /*FALLTHROUGH*/
      case 9:
        hval += asso_values[(unsigned char)str[8]];
      /*FALLTHROUGH*/
      case 8:
      case 7:
        hval += asso_values[(unsigned char)str[6]];
      /*FALLTHROUGH*/
      case 6:
        hval += asso_values[(unsigned char)str[5]];
      /*FALLTHROUGH*/
      case 5:
      case 4:
      case 3:
      case 2:
      case 1:
        hval += asso_values[(unsigned char)str[0]];
        break;
    }
  return hval + asso_values[(unsigned char)str[len - 1]];
}

const struct mime_type_and_extension *
search_mime_type (register const char *str, register unsigned int len)
{
  enum
    {
      TOTAL_KEYWORDS = 777,
      MIN_WORD_LENGTH = 7,
      MAX_WORD_LENGTH = 73,
      MIN_HASH_VALUE = 81,
      MAX_HASH_VALUE = 4685
    };

  static const struct mime_type_and_extension wordlist[] =
    {
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 714 "auto/mime_type_to_extension.gperf"
      {"text/css", "css"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 715 "auto/mime_type_to_extension.gperf"
      {"text/csv", "csv"},
      {"",nullptr},
#line 717 "auto/mime_type_to_extension.gperf"
      {"text/n3", "n3"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 65 "auto/mime_type_to_extension.gperf"
      {"application/mp4", "mp4s"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 713 "auto/mime_type_to_extension.gperf"
      {"text/calendar", "ics"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 110 "auto/mime_type_to_extension.gperf"
      {"application/sdp", "sdp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 69 "auto/mime_type_to_extension.gperf"
      {"application/oda", "oda"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 73 "auto/mime_type_to_extension.gperf"
      {"application/onenote", "onetoc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 54 "auto/mime_type_to_extension.gperf"
      {"application/marc", "mrc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 726 "auto/mime_type_to_extension.gperf"
      {"text/vcard", "vcard"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 90 "auto/mime_type_to_extension.gperf"
      {"application/postscript", "ai"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 33 "auto/mime_type_to_extension.gperf"
      {"application/ecmascript", "es"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 718 "auto/mime_type_to_extension.gperf"
      {"text/plain", "txt"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 36 "auto/mime_type_to_extension.gperf"
      {"application/exi", "exi"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 74 "auto/mime_type_to_extension.gperf"
      {"application/oxps", "oxps"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 323 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-ims", "ims"},
      {"",nullptr}, {"",nullptr},
#line 387 "auto/mime_type_to_extension.gperf"
      {"application/vnd.palm", "pdb"},
#line 410 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sema", "sema"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 194 "auto/mime_type_to_extension.gperf"
      {"application/vnd.enliven", "nml"},
#line 385 "auto/mime_type_to_extension.gperf"
      {"application/vnd.osgi.dp", "dp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 260 "auto/mime_type_to_extension.gperf"
      {"application/vnd.intergeo", "i2g"},
#line 185 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dna", "dna"},
#line 459 "auto/mime_type_to_extension.gperf"
      {"application/vnd.visio", "vsd"},
      {"",nullptr}, {"",nullptr},
#line 124 "auto/mime_type_to_extension.gperf"
      {"application/timestamped-data", "tsd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 340 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mseq", "mseq"},
      {"",nullptr},
#line 296 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mcd", "mcd"},
#line 64 "auto/mime_type_to_extension.gperf"
      {"application/mp21", "m21"},
      {"",nullptr},
#line 388 "auto/mime_type_to_extension.gperf"
      {"application/vnd.pawaafile", "paw"},
      {"",nullptr},
#line 442 "auto/mime_type_to_extension.gperf"
      {"application/vnd.svd", "svd"},
      {"",nullptr},
#line 266 "auto/mime_type_to_extension.gperf"
      {"application/vnd.isac.fcs", "fcs"},
      {"",nullptr}, {"",nullptr},
#line 133 "auto/mime_type_to_extension.gperf"
      {"application/vnd.acucorp", "atc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 452 "auto/mime_type_to_extension.gperf"
      {"application/vnd.trueapp", "tra"},
      {"",nullptr}, {"",nullptr},
#line 736 "auto/mime_type_to_extension.gperf"
      {"text/vnd.in3d.spot", "spot"},
#line 178 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dart", "dart"},
#line 183 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dece.zip", "uvz"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 328 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-powerpoint", "ppt"},
      {"",nullptr}, {"",nullptr},
#line 325 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-officetheme", "thmx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 256 "auto/mime_type_to_extension.gperf"
      {"application/vnd.immervision-ivp", "ivp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 411 "auto/mime_type_to_extension.gperf"
      {"application/vnd.semd", "semd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 180 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dece.data", "uvf"},
      {"",nullptr}, {"",nullptr},
#line 165 "auto/mime_type_to_extension.gperf"
      {"application/vnd.commonspace", "csp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 297 "auto/mime_type_to_extension.gperf"
      {"application/vnd.medcalcdata", "mc1"},
      {"",nullptr}, {"",nullptr},
#line 363 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.image", "odi"},
#line 450 "auto/mime_type_to_extension.gperf"
      {"application/vnd.trid.tpt", "tpt"},
      {"",nullptr}, {"",nullptr},
#line 365 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.presentation", "odp"},
      {"",nullptr}, {"",nullptr},
#line 396 "auto/mime_type_to_extension.gperf"
      {"application/vnd.proteus.magazine", "mgz"},
#line 197 "auto/mime_type_to_extension.gperf"
      {"application/vnd.epson.quickanime", "qam"},
#line 364 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.image-template", "oti"},
#line 129 "auto/mime_type_to_extension.gperf"
      {"application/vnd.3m.post-it-notes", "pwn"},
      {"",nullptr},
#line 367 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.spreadsheet", "ods"},
#line 305 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mobius.dis", "dis"},
#line 368 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.spreadsheet-template", "ots"},
#line 369 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.text", "odt"},
#line 366 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.presentation-template", "otp"},
#line 371 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.text-template", "ott"},
      {"",nullptr}, {"",nullptr},
#line 398 "auto/mime_type_to_extension.gperf"
      {"application/vnd.pvi.ptid1", "ptid"},
#line 356 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.chart", "odc"},
      {"",nullptr},
#line 357 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.chart-template", "otc"},
      {"",nullptr}, {"",nullptr},
#line 448 "auto/mime_type_to_extension.gperf"
      {"application/vnd.tcpdump.pcap", "pcap"},
      {"",nullptr},
#line 419 "auto/mime_type_to_extension.gperf"
      {"application/vnd.smart.teacher", "teacher"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 352 "auto/mime_type_to_extension.gperf"
      {"application/vnd.nokia.radio-presets", "rpss"},
      {"",nullptr}, {"",nullptr},
#line 370 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.text-master", "odm"},
#line 358 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.database", "odb"},
#line 425 "auto/mime_type_to_extension.gperf"
      {"application/vnd.stardivision.impress", "sdd"},
#line 423 "auto/mime_type_to_extension.gperf"
      {"application/vnd.stardivision.calc", "sdc"},
#line 326 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-pki.seccat", "cat"},
#line 741 "auto/mime_type_to_extension.gperf"
      {"text/x-c", "c"},
#line 351 "auto/mime_type_to_extension.gperf"
      {"application/vnd.nokia.radio-preset", "rpst"},
      {"",nullptr},
#line 422 "auto/mime_type_to_extension.gperf"
      {"application/vnd.spotfire.sfs", "sfs"},
#line 429 "auto/mime_type_to_extension.gperf"
      {"application/vnd.stepmania.package", "smzip"},
#line 451 "auto/mime_type_to_extension.gperf"
      {"application/vnd.triscape.mxs", "mxs"},
#line 182 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dece.unspecified", "uvx"},
      {"",nullptr},
#line 131 "auto/mime_type_to_extension.gperf"
      {"application/vnd.accpac.simply.imp", "imp"},
#line 152 "auto/mime_type_to_extension.gperf"
      {"application/vnd.astraea-software.iota", "iota"},
      {"",nullptr},
#line 130 "auto/mime_type_to_extension.gperf"
      {"application/vnd.accpac.simply.aso", "aso"},
      {"",nullptr}, {"",nullptr},
#line 470 "auto/mime_type_to_extension.gperf"
      {"application/vnd.xara", "xar"},
#line 740 "auto/mime_type_to_extension.gperf"
      {"text/x-asm", "asm"},
#line 190 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dvb.ait", "ait"},
#line 168 "auto/mime_type_to_extension.gperf"
      {"application/vnd.crick.clicker", "clkx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 430 "auto/mime_type_to_extension.gperf"
      {"application/vnd.stepmania.stepchart", "sm"},
      {"",nullptr},
#line 392 "auto/mime_type_to_extension.gperf"
      {"application/vnd.pmi.widget", "wg"},
      {"",nullptr},
#line 458 "auto/mime_type_to_extension.gperf"
      {"application/vnd.vcx", "vcx"},
      {"",nullptr}, {"",nullptr},
#line 427 "auto/mime_type_to_extension.gperf"
      {"application/vnd.stardivision.writer", "sdw"},
#line 265 "auto/mime_type_to_extension.gperf"
      {"application/vnd.is-xpr", "xpr"},
      {"",nullptr}, {"",nullptr},
#line 404 "auto/mime_type_to_extension.gperf"
      {"application/vnd.rim.cod", "cod"},
      {"",nullptr},
#line 170 "auto/mime_type_to_extension.gperf"
      {"application/vnd.crick.clicker.palette", "clkp"},
      {"",nullptr},
#line 421 "auto/mime_type_to_extension.gperf"
      {"application/vnd.spotfire.dxp", "dxp"},
#line 171 "auto/mime_type_to_extension.gperf"
      {"application/vnd.crick.clicker.template", "clkt"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 68 "auto/mime_type_to_extension.gperf"
      {"application/octet-stream", "bin"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 27 "auto/mime_type_to_extension.gperf"
      {"application/cdmi-queue", "cdmiq"},
      {"",nullptr}, {"",nullptr},
#line 391 "auto/mime_type_to_extension.gperf"
      {"application/vnd.picsel", "efif"},
#line 748 "auto/mime_type_to_extension.gperf"
      {"text/x-setext", "etx"},
#line 324 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-lrm", "lrm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 752 "auto/mime_type_to_extension.gperf"
      {"text/x-vcard", "vcf"},
#line 191 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dvb.service", "svc"},
#line 742 "auto/mime_type_to_extension.gperf"
      {"text/x-fortran", "f"},
      {"",nullptr},
#line 605 "auto/mime_type_to_extension.gperf"
      {"application/zip", "zip"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 111 "auto/mime_type_to_extension.gperf"
      {"application/set-payment-initiation", "setpay"},
#line 316 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-excel", "xls"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 25 "auto/mime_type_to_extension.gperf"
      {"application/cdmi-domain", "cdmid"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 18 "auto/mime_type_to_extension.gperf"
      {"application/applixware", "aw"},
      {"",nullptr},
#line 52 "auto/mime_type_to_extension.gperf"
      {"application/mac-compactpro", "cpt"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 539 "auto/mime_type_to_extension.gperf"
      {"application/x-mie", "mie"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 132 "auto/mime_type_to_extension.gperf"
      {"application/vnd.acucobol", "acu"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 198 "auto/mime_type_to_extension.gperf"
      {"application/vnd.epson.salt", "slt"},
#line 516 "auto/mime_type_to_extension.gperf"
      {"application/x-eva", "eva"},
      {"",nullptr}, {"",nullptr},
#line 505 "auto/mime_type_to_extension.gperf"
      {"application/x-cpio", "cpio"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 727 "auto/mime_type_to_extension.gperf"
      {"text/vnd.curl", "curl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 24 "auto/mime_type_to_extension.gperf"
      {"application/cdmi-container", "cdmic"},
      {"",nullptr},
#line 112 "auto/mime_type_to_extension.gperf"
      {"application/set-registration-initiation", "setreg"},
#line 161 "auto/mime_type_to_extension.gperf"
      {"application/vnd.cloanto.rp9", "rp9"},
#line 546 "auto/mime_type_to_extension.gperf"
      {"application/x-msaccess", "mdb"},
      {"",nullptr}, {"",nullptr},
#line 167 "auto/mime_type_to_extension.gperf"
      {"application/vnd.cosmocaller", "cmc"},
      {"",nullptr},
#line 510 "auto/mime_type_to_extension.gperf"
      {"application/x-doom", "wad"},
      {"",nullptr}, {"",nullptr},
#line 514 "auto/mime_type_to_extension.gperf"
      {"application/x-dvi", "dvi"},
      {"",nullptr},
#line 576 "auto/mime_type_to_extension.gperf"
      {"application/x-tads", "gam"},
#line 577 "auto/mime_type_to_extension.gperf"
      {"application/x-tar", "tar"},
      {"",nullptr},
#line 159 "auto/mime_type_to_extension.gperf"
      {"application/vnd.cinderella", "cdy"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 332 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-powerpoint.slideshow.macroenabled.12", "ppsm"},
#line 573 "auto/mime_type_to_extension.gperf"
      {"application/x-sv4cpio", "sv4cpio"},
      {"",nullptr}, {"",nullptr},
#line 330 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-powerpoint.presentation.macroenabled.12", "pptm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 751 "auto/mime_type_to_extension.gperf"
      {"text/x-vcalendar", "vcs"},
#line 333 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-powerpoint.template.macroenabled.12", "potm"},
      {"",nullptr},
#line 303 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mif", "mif"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 574 "auto/mime_type_to_extension.gperf"
      {"application/x-sv4crc", "sv4crc"},
#line 300 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mfmp", "mfm"},
#line 405 "auto/mime_type_to_extension.gperf"
      {"application/vnd.rn-realmedia", "rm"},
      {"",nullptr}, {"",nullptr},
#line 309 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mobius.plc", "plc"},
#line 461 "auto/mime_type_to_extension.gperf"
      {"application/vnd.vsf", "vsf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 644 "auto/mime_type_to_extension.gperf"
      {"font/collection", "ttc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 745 "auto/mime_type_to_extension.gperf"
      {"text/x-opml", "opml"},
      {"",nullptr}, {"",nullptr},
#line 662 "auto/mime_type_to_extension.gperf"
      {"image/sgi", "sgi"},
#line 79 "auto/mime_type_to_extension.gperf"
      {"application/pics-rules", "prf"},
#line 315 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-cab-compressed", "cab"},
#line 550 "auto/mime_type_to_extension.gperf"
      {"application/x-msdownload", "exe"},
#line 612 "auto/mime_type_to_extension.gperf"
      {"audio/s3m", "s3m"},
      {"",nullptr},
#line 609 "auto/mime_type_to_extension.gperf"
      {"audio/mp4", "m4a"},
      {"",nullptr},
#line 331 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-powerpoint.slide.macroenabled.12", "sldm"},
#line 596 "auto/mime_type_to_extension.gperf"
      {"application/xml", "xml"},
#line 509 "auto/mime_type_to_extension.gperf"
      {"application/x-director", "dir"},
#line 329 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-powerpoint.addin.macroenabled.12", "ppam"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 700 "auto/mime_type_to_extension.gperf"
      {"model/iges", "igs"},
#line 650 "auto/mime_type_to_extension.gperf"
      {"image/cgm", "cgm"},
#line 401 "auto/mime_type_to_extension.gperf"
      {"application/vnd.recordare.musicxml", "mxl"},
      {"",nullptr}, {"",nullptr},
#line 320 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-excel.template.macroenabled.12", "xltm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 762 "auto/mime_type_to_extension.gperf"
      {"video/mp4", "mp4"},
#line 299 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mfer", "mwf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 606 "auto/mime_type_to_extension.gperf"
      {"audio/adpcm", "adp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 645 "auto/mime_type_to_extension.gperf"
      {"font/otf", "otf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 608 "auto/mime_type_to_extension.gperf"
      {"audio/midi", "midi"},
#line 646 "auto/mime_type_to_extension.gperf"
      {"font/ttf", "ttf"},
#line 753 "auto/mime_type_to_extension.gperf"
      {"video/3gpp", "3gp"},
#line 409 "auto/mime_type_to_extension.gperf"
      {"application/vnd.seemail", "see"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 319 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-excel.sheet.macroenabled.12", "xlsm"},
      {"",nullptr}, {"",nullptr},
#line 317 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-excel.addin.macroenabled.12", "xlam"},
      {"",nullptr}, {"",nullptr},
#line 359 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.formula", "odf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 375 "auto/mime_type_to_extension.gperf"
      {"application/vnd.openofficeorg.extension", "oxt"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 360 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.formula-template", "odft"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 318 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-excel.sheet.binary.macroenabled.12", "xlsb"},
      {"",nullptr}, {"",nullptr},
#line 208 "auto/mime_type_to_extension.gperf"
      {"application/vnd.framemaker", "fm"},
#line 107 "auto/mime_type_to_extension.gperf"
      {"application/scvp-cv-response", "scs"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 109 "auto/mime_type_to_extension.gperf"
      {"application/scvp-vp-response", "spp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 205 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fdsn.seed", "seed"},
#line 259 "auto/mime_type_to_extension.gperf"
      {"application/vnd.intercon.formnet", "xpw"},
#line 765 "auto/mime_type_to_extension.gperf"
      {"video/quicktime", "mov"},
      {"",nullptr},
#line 43 "auto/mime_type_to_extension.gperf"
      {"application/ipfix", "ipfix"},
      {"",nullptr},
#line 549 "auto/mime_type_to_extension.gperf"
      {"application/x-msclip", "clp"},
#line 482 "auto/mime_type_to_extension.gperf"
      {"application/voicexml+xml", "vxml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 106 "auto/mime_type_to_extension.gperf"
      {"application/scvp-cv-request", "scq"},
      {"",nullptr},
#line 204 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fdsn.mseed", "mseed"},
#line 744 "auto/mime_type_to_extension.gperf"
      {"text/x-nfo", "nfo"},
#line 735 "auto/mime_type_to_extension.gperf"
      {"text/vnd.in3d.3dml", "3dml"},
#line 552 "auto/mime_type_to_extension.gperf"
      {"application/x-msmetafile", "wmf"},
      {"",nullptr},
#line 108 "auto/mime_type_to_extension.gperf"
      {"application/scvp-vp-request", "spq"},
#line 637 "auto/mime_type_to_extension.gperf"
      {"audio/xm", "xm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 556 "auto/mime_type_to_extension.gperf"
      {"application/x-msterminal", "trm"},
#line 37 "auto/mime_type_to_extension.gperf"
      {"application/font-tdpfr", "pfr"},
#line 149 "auto/mime_type_to_extension.gperf"
      {"application/vnd.apple.installer+xml", "mpkg"},
#line 555 "auto/mime_type_to_extension.gperf"
      {"application/x-msschedule", "scd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 308 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mobius.msl", "msl"},
      {"",nullptr},
#line 706 "auto/mime_type_to_extension.gperf"
      {"model/vnd.mts", "mts"},
#line 617 "auto/mime_type_to_extension.gperf"
      {"audio/vnd.dts", "dts"},
      {"",nullptr},
#line 624 "auto/mime_type_to_extension.gperf"
      {"audio/vnd.rip", "rip"},
      {"",nullptr}, {"",nullptr},
#line 327 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-pki.stl", "stl"},
#line 616 "auto/mime_type_to_extension.gperf"
      {"audio/vnd.dra", "dra"},
      {"",nullptr}, {"",nullptr},
#line 117 "auto/mime_type_to_extension.gperf"
      {"application/srgs", "gram"},
      {"",nullptr}, {"",nullptr},
#line 104 "auto/mime_type_to_extension.gperf"
      {"application/rtf", "rtf"},
      {"",nullptr},
#line 76 "auto/mime_type_to_extension.gperf"
      {"application/pdf", "pdf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 673 "auto/mime_type_to_extension.gperf"
      {"image/vnd.fst", "fst"},
      {"",nullptr},
#line 749 "auto/mime_type_to_extension.gperf"
      {"text/x-sfv", "sfv"},
#line 689 "auto/mime_type_to_extension.gperf"
      {"image/x-pict", "pic"},
      {"",nullptr}, {"",nullptr},
#line 597 "auto/mime_type_to_extension.gperf"
      {"application/xml-dtd", "dtd"},
#line 686 "auto/mime_type_to_extension.gperf"
      {"image/x-icon", "ico"},
      {"",nullptr},
#line 586 "auto/mime_type_to_extension.gperf"
      {"application/x-x509-ca-cert", "der"},
#line 548 "auto/mime_type_to_extension.gperf"
      {"application/x-mscardfile", "crd"},
      {"",nullptr},
#line 402 "auto/mime_type_to_extension.gperf"
      {"application/vnd.recordare.musicxml+xml", "musicxml"},
#line 626 "auto/mime_type_to_extension.gperf"
      {"audio/x-aac", "aac"},
      {"",nullptr}, {"",nullptr},
#line 579 "auto/mime_type_to_extension.gperf"
      {"application/x-tex", "tex"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 534 "auto/mime_type_to_extension.gperf"
      {"application/x-install-instructions", "install"},
#line 772 "auto/mime_type_to_extension.gperf"
      {"video/vnd.fvt", "fvt"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 347 "auto/mime_type_to_extension.gperf"
      {"application/vnd.noblenet-sealer", "nns"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 633 "auto/mime_type_to_extension.gperf"
      {"audio/x-ms-wma", "wma"},
      {"",nullptr},
#line 786 "auto/mime_type_to_extension.gperf"
      {"video/x-ms-wm", "wm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 792 "auto/mime_type_to_extension.gperf"
      {"video/x-smv", "smv"},
      {"",nullptr},
#line 781 "auto/mime_type_to_extension.gperf"
      {"video/x-m4v", "m4v"},
#line 746 "auto/mime_type_to_extension.gperf"
      {"text/x-pascal", "pas"},
      {"",nullptr},
#line 776 "auto/mime_type_to_extension.gperf"
      {"video/vnd.vivo", "viv"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 542 "auto/mime_type_to_extension.gperf"
      {"application/x-ms-shortcut", "lnk"},
      {"",nullptr},
#line 682 "auto/mime_type_to_extension.gperf"
      {"image/x-3ds", "3ds"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 541 "auto/mime_type_to_extension.gperf"
      {"application/x-ms-application", "application"},
#line 301 "auto/mime_type_to_extension.gperf"
      {"application/vnd.micrografx.flo", "flo"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 377 "auto/mime_type_to_extension.gperf"
      {"application/vnd.openxmlformats-officedocument.presentationml.slide", "sldx"},
#line 254 "auto/mime_type_to_extension.gperf"
      {"application/vnd.iccprofile", "icc"},
#line 381 "auto/mime_type_to_extension.gperf"
      {"application/vnd.openxmlformats-officedocument.spreadsheetml.template", "xltx"},
#line 379 "auto/mime_type_to_extension.gperf"
      {"application/vnd.openxmlformats-officedocument.presentationml.template", "potx"},
#line 376 "auto/mime_type_to_extension.gperf"
      {"application/vnd.openxmlformats-officedocument.presentationml.presentation", "pptx"},
#line 383 "auto/mime_type_to_extension.gperf"
      {"application/vnd.openxmlformats-officedocument.wordprocessingml.template", "dotx"},
#line 380 "auto/mime_type_to_extension.gperf"
      {"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "xlsx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 428 "auto/mime_type_to_extension.gperf"
      {"application/vnd.stardivision.writer-global", "sgl"},
#line 382 "auto/mime_type_to_extension.gperf"
      {"application/vnd.openxmlformats-officedocument.wordprocessingml.document", "docx"},
      {"",nullptr}, {"",nullptr},
#line 48 "auto/mime_type_to_extension.gperf"
      {"application/json", "json"},
      {"",nullptr},
#line 537 "auto/mime_type_to_extension.gperf"
      {"application/x-latex", "latex"},
      {"",nullptr}, {"",nullptr},
#line 754 "auto/mime_type_to_extension.gperf"
      {"video/3gpp2", "3g2"},
#line 787 "auto/mime_type_to_extension.gperf"
      {"video/x-ms-wmv", "wmv"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 790 "auto/mime_type_to_extension.gperf"
      {"video/x-msvideo", "avi"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 489 "auto/mime_type_to_extension.gperf"
      {"application/x-ace-compressed", "ace"},
#line 67 "auto/mime_type_to_extension.gperf"
      {"application/mxf", "mxf"},
      {"",nullptr}, {"",nullptr},
#line 524 "auto/mime_type_to_extension.gperf"
      {"application/x-font-type1", "pfa"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 569 "auto/mime_type_to_extension.gperf"
      {"application/x-sql", "sql"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 285 "auto/mime_type_to_extension.gperf"
      {"application/vnd.las.las+xml", "lasxml"},
      {"",nullptr},
#line 578 "auto/mime_type_to_extension.gperf"
      {"application/x-tcl", "tcl"},
#line 545 "auto/mime_type_to_extension.gperf"
      {"application/x-ms-xbap", "xbap"},
#line 374 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oma.dd2+xml", "dd2"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 345 "auto/mime_type_to_extension.gperf"
      {"application/vnd.nitf", "ntf"},
#line 418 "auto/mime_type_to_extension.gperf"
      {"application/vnd.smaf", "mmf"},
#line 412 "auto/mime_type_to_extension.gperf"
      {"application/vnd.semf", "semf"},
#line 563 "auto/mime_type_to_extension.gperf"
      {"application/x-rar-compressed", "rar"},
      {"",nullptr},
#line 526 "auto/mime_type_to_extension.gperf"
      {"application/x-freearc", "arc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 504 "auto/mime_type_to_extension.gperf"
      {"application/x-conference", "nsc"},
      {"",nullptr}, {"",nullptr},
#line 226 "auto/mime_type_to_extension.gperf"
      {"application/vnd.geoplan", "g2w"},
      {"",nullptr}, {"",nullptr},
#line 591 "auto/mime_type_to_extension.gperf"
      {"application/x-zmachine", "z1"},
      {"",nullptr},
#line 688 "auto/mime_type_to_extension.gperf"
      {"image/x-pcx", "pcx"},
#line 684 "auto/mime_type_to_extension.gperf"
      {"image/x-cmx", "cmx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 203 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fdf", "fdf"},
      {"",nullptr}, {"",nullptr},
#line 174 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ctc-posml", "pml"},
      {"",nullptr},
#line 390 "auto/mime_type_to_extension.gperf"
      {"application/vnd.pg.osasli", "ei6"},
      {"",nullptr}, {"",nullptr},
#line 227 "auto/mime_type_to_extension.gperf"
      {"application/vnd.geospace", "g3w"},
#line 225 "auto/mime_type_to_extension.gperf"
      {"application/vnd.geonext", "gxt"},
#line 144 "auto/mime_type_to_extension.gperf"
      {"application/vnd.amiga.ami", "ami"},
      {"",nullptr},
#line 199 "auto/mime_type_to_extension.gperf"
      {"application/vnd.epson.ssf", "ssf"},
      {"",nullptr},
#line 196 "auto/mime_type_to_extension.gperf"
      {"application/vnd.epson.msf", "msf"},
#line 195 "auto/mime_type_to_extension.gperf"
      {"application/vnd.epson.esf", "esf"},
      {"",nullptr}, {"",nullptr},
#line 255 "auto/mime_type_to_extension.gperf"
      {"application/vnd.igloader", "igl"},
#line 47 "auto/mime_type_to_extension.gperf"
      {"application/javascript", "js"},
      {"",nullptr}, {"",nullptr},
#line 683 "auto/mime_type_to_extension.gperf"
      {"image/x-cmu-raster", "ras"},
      {"",nullptr},
#line 619 "auto/mime_type_to_extension.gperf"
      {"audio/vnd.lucent.voice", "lvp"},
      {"",nullptr}, {"",nullptr},
#line 697 "auto/mime_type_to_extension.gperf"
      {"image/x-xpixmap", "xpm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 302 "auto/mime_type_to_extension.gperf"
      {"application/vnd.micrografx.igx", "igx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 349 "auto/mime_type_to_extension.gperf"
      {"application/vnd.nokia.n-gage.data", "ngdat"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 128 "auto/mime_type_to_extension.gperf"
      {"application/vnd.3gpp2.tcap", "tcap"},
#line 769 "auto/mime_type_to_extension.gperf"
      {"video/vnd.dece.sd", "uvs"},
#line 768 "auto/mime_type_to_extension.gperf"
      {"video/vnd.dece.pd", "uvp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 724 "auto/mime_type_to_extension.gperf"
      {"text/turtle", "ttl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 361 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.graphics", "odg"},
#line 770 "auto/mime_type_to_extension.gperf"
      {"video/vnd.dece.video", "uvv"},
#line 166 "auto/mime_type_to_extension.gperf"
      {"application/vnd.contact.cmsg", "cdbcmsg"},
#line 490 "auto/mime_type_to_extension.gperf"
      {"application/x-apple-diskimage", "dmg"},
      {"",nullptr},
#line 581 "auto/mime_type_to_extension.gperf"
      {"application/x-texinfo", "texinfo"},
      {"",nullptr},
#line 720 "auto/mime_type_to_extension.gperf"
      {"text/richtext", "rtx"},
#line 267 "auto/mime_type_to_extension.gperf"
      {"application/vnd.jam", "jam"},
      {"",nullptr},
#line 148 "auto/mime_type_to_extension.gperf"
      {"application/vnd.antix.game-component", "atx"},
      {"",nullptr},
#line 362 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.graphics-template", "otg"},
      {"",nullptr}, {"",nullptr},
#line 258 "auto/mime_type_to_extension.gperf"
      {"application/vnd.insors.igm", "igm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 269 "auto/mime_type_to_extension.gperf"
      {"application/vnd.jisp", "jisp"},
#line 353 "auto/mime_type_to_extension.gperf"
      {"application/vnd.novadigm.edm", "edm"},
      {"",nullptr},
#line 304 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mobius.daf", "daf"},
      {"",nullptr}, {"",nullptr},
#line 761 "auto/mime_type_to_extension.gperf"
      {"video/mj2", "mj2"},
      {"",nullptr},
#line 341 "auto/mime_type_to_extension.gperf"
      {"application/vnd.musician", "mus"},
#line 355 "auto/mime_type_to_extension.gperf"
      {"application/vnd.novadigm.ext", "ext"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 708 "auto/mime_type_to_extension.gperf"
      {"model/vrml", "wrl"},
      {"",nullptr}, {"",nullptr},
#line 228 "auto/mime_type_to_extension.gperf"
      {"application/vnd.gmx", "gmx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 723 "auto/mime_type_to_extension.gperf"
      {"text/troff", "t"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 672 "auto/mime_type_to_extension.gperf"
      {"image/vnd.fpx", "fpx"},
      {"",nullptr},
#line 207 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fluxtime.clip", "ftc"},
#line 721 "auto/mime_type_to_extension.gperf"
      {"text/sgml", "sgml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 384 "auto/mime_type_to_extension.gperf"
      {"application/vnd.osgeo.mapguide.package", "mgp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 175 "auto/mime_type_to_extension.gperf"
      {"application/vnd.cups-ppd", "ppd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 589 "auto/mime_type_to_extension.gperf"
      {"application/x-xpinstall", "xpi"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 676 "auto/mime_type_to_extension.gperf"
      {"image/vnd.ms-modi", "mdi"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 632 "auto/mime_type_to_extension.gperf"
      {"audio/x-ms-wax", "wax"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 56 "auto/mime_type_to_extension.gperf"
      {"application/mathematica", "ma"},
#line 334 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-project", "mpp"},
      {"",nullptr}, {"",nullptr},
#line 627 "auto/mime_type_to_extension.gperf"
      {"audio/x-aiff", "aif"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 454 "auto/mime_type_to_extension.gperf"
      {"application/vnd.uiq.theme", "utz"},
      {"",nullptr},
#line 788 "auto/mime_type_to_extension.gperf"
      {"video/x-ms-wmx", "wmx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 628 "auto/mime_type_to_extension.gperf"
      {"audio/x-caf", "caf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 471 "auto/mime_type_to_extension.gperf"
      {"application/vnd.xfdl", "xfdl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 179 "auto/mime_type_to_extension.gperf"
      {"application/vnd.data-vision.rdz", "rdz"},
#line 789 "auto/mime_type_to_extension.gperf"
      {"video/x-ms-wvx", "wvx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 778 "auto/mime_type_to_extension.gperf"
      {"video/x-f4v", "f4v"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 704 "auto/mime_type_to_extension.gperf"
      {"model/vnd.gdl", "gdl"},
#line 28 "auto/mime_type_to_extension.gperf"
      {"application/cu-seeme", "cu"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 638 "auto/mime_type_to_extension.gperf"
      {"chemical/x-cdx", "cdx"},
#line 31 "auto/mime_type_to_extension.gperf"
      {"application/dssc+der", "dssc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 399 "auto/mime_type_to_extension.gperf"
      {"application/vnd.quark.quarkxpress", "qxd"},
#line 77 "auto/mime_type_to_extension.gperf"
      {"application/pgp-encrypted", "pgp"},
      {"",nullptr}, {"",nullptr},
#line 354 "auto/mime_type_to_extension.gperf"
      {"application/vnd.novadigm.edx", "edx"},
#line 310 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mobius.txf", "txf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 155 "auto/mime_type_to_extension.gperf"
      {"application/vnd.bmi", "bmi"},
      {"",nullptr},
#line 46 "auto/mime_type_to_extension.gperf"
      {"application/java-vm", "class"},
      {"",nullptr},
#line 29 "auto/mime_type_to_extension.gperf"
      {"application/davmount+xml", "davmount"},
      {"",nullptr}, {"",nullptr},
#line 621 "auto/mime_type_to_extension.gperf"
      {"audio/vnd.nuera.ecelp4800", "ecelp4800"},
      {"",nullptr},
#line 622 "auto/mime_type_to_extension.gperf"
      {"audio/vnd.nuera.ecelp7470", "ecelp7470"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 522 "auto/mime_type_to_extension.gperf"
      {"application/x-font-snf", "snf"},
#line 521 "auto/mime_type_to_extension.gperf"
      {"application/x-font-pcf", "pcf"},
#line 520 "auto/mime_type_to_extension.gperf"
      {"application/x-font-otf", "otf"},
#line 623 "auto/mime_type_to_extension.gperf"
      {"audio/vnd.nuera.ecelp9600", "ecelp9600"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 523 "auto/mime_type_to_extension.gperf"
      {"application/x-font-ttf", "ttf"},
#line 96 "auto/mime_type_to_extension.gperf"
      {"application/resource-lists+xml", "rl"},
      {"",nullptr}, {"",nullptr},
#line 558 "auto/mime_type_to_extension.gperf"
      {"application/x-netcdf", "nc"},
#line 564 "auto/mime_type_to_extension.gperf"
      {"application/x-research-info-systems", "ris"},
#line 162 "auto/mime_type_to_extension.gperf"
      {"application/vnd.clonk.c4group", "c4g"},
      {"",nullptr},
#line 501 "auto/mime_type_to_extension.gperf"
      {"application/x-cfs-compressed", "cfs"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 447 "auto/mime_type_to_extension.gperf"
      {"application/vnd.tao.intent-module-archive", "tao"},
      {"",nullptr},
#line 532 "auto/mime_type_to_extension.gperf"
      {"application/x-gtar", "gtar"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 641 "auto/mime_type_to_extension.gperf"
      {"chemical/x-cml", "cml"},
      {"",nullptr},
#line 44 "auto/mime_type_to_extension.gperf"
      {"application/java-archive", "jar"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 26 "auto/mime_type_to_extension.gperf"
      {"application/cdmi-object", "cdmio"},
      {"",nullptr},
#line 221 "auto/mime_type_to_extension.gperf"
      {"application/vnd.genomatix.tuxedo", "txd"},
      {"",nullptr}, {"",nullptr},
#line 535 "auto/mime_type_to_extension.gperf"
      {"application/x-iso9660-image", "iso"},
      {"",nullptr},
#line 642 "auto/mime_type_to_extension.gperf"
      {"chemical/x-csml", "csml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 139 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ahead.space", "ahead"},
#line 236 "auto/mime_type_to_extension.gperf"
      {"application/vnd.groove-tool-message", "gtm"},
#line 575 "auto/mime_type_to_extension.gperf"
      {"application/x-t3vm-image", "t3"},
      {"",nullptr},
#line 580 "auto/mime_type_to_extension.gperf"
      {"application/x-tex-tfm", "tfm"},
#line 487 "auto/mime_type_to_extension.gperf"
      {"application/x-7z-compressed", "7z"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 750 "auto/mime_type_to_extension.gperf"
      {"text/x-uuencode", "uu"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 186 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dolby.mlp", "mlp"},
#line 722 "auto/mime_type_to_extension.gperf"
      {"text/tab-separated-values", "tsv"},
      {"",nullptr},
#line 232 "auto/mime_type_to_extension.gperf"
      {"application/vnd.groove-account", "gac"},
      {"",nullptr},
#line 237 "auto/mime_type_to_extension.gperf"
      {"application/vnd.groove-tool-template", "tpl"},
      {"",nullptr}, {"",nullptr},
#line 291 "auto/mime_type_to_extension.gperf"
      {"application/vnd.lotus-notes", "nsf"},
#line 176 "auto/mime_type_to_extension.gperf"
      {"application/vnd.curl.car", "car"},
#line 339 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-xpsdocument", "xps"},
#line 657 "auto/mime_type_to_extension.gperf"
      {"image/ief", "ief"},
      {"",nullptr}, {"",nullptr},
#line 583 "auto/mime_type_to_extension.gperf"
      {"application/x-tgsticker", "tgs"},
#line 238 "auto/mime_type_to_extension.gperf"
      {"application/vnd.groove-vcard", "vcg"},
#line 725 "auto/mime_type_to_extension.gperf"
      {"text/uri-list", "uri"},
      {"",nullptr},
#line 417 "auto/mime_type_to_extension.gperf"
      {"application/vnd.simtech-mindmapper", "twd"},
      {"",nullptr},
#line 72 "auto/mime_type_to_extension.gperf"
      {"application/omdoc+xml", "omdoc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 231 "auto/mime_type_to_extension.gperf"
      {"application/vnd.grafeq", "gqf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 389 "auto/mime_type_to_extension.gperf"
      {"application/vnd.pg.format", "str"},
      {"",nullptr},
#line 224 "auto/mime_type_to_extension.gperf"
      {"application/vnd.geometry-explorer", "gex"},
#line 372 "auto/mime_type_to_extension.gperf"
      {"application/vnd.oasis.opendocument.text-web", "oth"},
      {"",nullptr}, {"",nullptr},
#line 426 "auto/mime_type_to_extension.gperf"
      {"application/vnd.stardivision.math", "smf"},
      {"",nullptr},
#line 584 "auto/mime_type_to_extension.gperf"
      {"application/x-ustar", "ustar"},
      {"",nullptr},
#line 733 "auto/mime_type_to_extension.gperf"
      {"text/vnd.fmi.flexstor", "flx"},
#line 293 "auto/mime_type_to_extension.gperf"
      {"application/vnd.lotus-screencam", "scm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 394 "auto/mime_type_to_extension.gperf"
      {"application/vnd.powerbuilder6", "pbd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 629 "auto/mime_type_to_extension.gperf"
      {"audio/x-flac", "flac"},
#line 311 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mophun.application", "mpn"},
      {"",nullptr}, {"",nullptr},
#line 779 "auto/mime_type_to_extension.gperf"
      {"video/x-fli", "fli"},
#line 743 "auto/mime_type_to_extension.gperf"
      {"text/x-java-source", "java"},
#line 58 "auto/mime_type_to_extension.gperf"
      {"application/mbox", "mbox"},
#line 373 "auto/mime_type_to_extension.gperf"
      {"application/vnd.olpc-sugar", "xo"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 747 "auto/mime_type_to_extension.gperf"
      {"text/x-php", "php"},
#line 145 "auto/mime_type_to_extension.gperf"
      {"application/vnd.android.package-archive", "apk"},
      {"",nullptr},
#line 716 "auto/mime_type_to_extension.gperf"
      {"text/html", "html"},
      {"",nullptr}, {"",nullptr},
#line 435 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sun.xml.impress", "sxi"},
#line 251 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ibm.modcap", "afp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 780 "auto/mime_type_to_extension.gperf"
      {"video/x-flv", "flv"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 431 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sun.xml.calc", "sxc"},
#line 312 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mophun.certificate", "mpc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 150 "auto/mime_type_to_extension.gperf"
      {"application/vnd.apple.mpegurl", "m3u8"},
      {"",nullptr}, {"",nullptr},
#line 436 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sun.xml.impress.template", "sti"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 122 "auto/mime_type_to_extension.gperf"
      {"application/tei+xml", "tei"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 247 "auto/mime_type_to_extension.gperf"
      {"application/vnd.hp-pcl", "pcl"},
      {"",nullptr},
#line 661 "auto/mime_type_to_extension.gperf"
      {"image/prs.btif", "btif"},
      {"",nullptr}, {"",nullptr},
#line 103 "auto/mime_type_to_extension.gperf"
      {"application/rss+xml", "rss"},
#line 59 "auto/mime_type_to_extension.gperf"
      {"application/mediaservercontrol+xml", "mscml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 432 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sun.xml.calc.template", "stc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 712 "auto/mime_type_to_extension.gperf"
      {"text/cache-manifest", "appcache"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 590 "auto/mime_type_to_extension.gperf"
      {"application/x-xz", "xz"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 760 "auto/mime_type_to_extension.gperf"
      {"video/jpm", "jpm"},
      {"",nullptr}, {"",nullptr},
#line 268 "auto/mime_type_to_extension.gperf"
      {"application/vnd.jcp.javame.midlet-rms", "rms"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 599 "auto/mime_type_to_extension.gperf"
      {"application/xproc+xml", "xpl"},
#line 116 "auto/mime_type_to_extension.gperf"
      {"application/sparql-results+xml", "srx"},
      {"",nullptr}, {"",nullptr},
#line 102 "auto/mime_type_to_extension.gperf"
      {"application/rsd+xml", "rsd"},
#line 531 "auto/mime_type_to_extension.gperf"
      {"application/x-gramps-xml", "gramps"},
      {"",nullptr},
#line 233 "auto/mime_type_to_extension.gperf"
      {"application/vnd.groove-help", "ghf"},
#line 670 "auto/mime_type_to_extension.gperf"
      {"image/vnd.dxf", "dxf"},
#line 703 "auto/mime_type_to_extension.gperf"
      {"model/vnd.dwf", "dwf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 457 "auto/mime_type_to_extension.gperf"
      {"application/vnd.uoml+xml", "uoml"},
      {"",nullptr}, {"",nullptr},
#line 434 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sun.xml.draw.template", "std"},
      {"",nullptr}, {"",nullptr},
#line 66 "auto/mime_type_to_extension.gperf"
      {"application/msword", "doc"},
      {"",nullptr},
#line 253 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ibm.secure-container", "sc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 695 "auto/mime_type_to_extension.gperf"
      {"image/x-tga", "tga"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 17 "auto/mime_type_to_extension.gperf"
      {"application/andrew-inset", "ez"},
      {"",nullptr}, {"",nullptr},
#line 737 "auto/mime_type_to_extension.gperf"
      {"text/vnd.sun.j2me.app-descriptor", "jad"},
      {"",nullptr}, {"",nullptr},
#line 783 "auto/mime_type_to_extension.gperf"
      {"video/x-mng", "mng"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 494 "auto/mime_type_to_extension.gperf"
      {"application/x-bcpio", "bcpio"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 730 "auto/mime_type_to_extension.gperf"
      {"text/vnd.curl.scurl", "scurl"},
#line 502 "auto/mime_type_to_extension.gperf"
      {"application/x-chat", "chat"},
#line 729 "auto/mime_type_to_extension.gperf"
      {"text/vnd.curl.mcurl", "mcurl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 20 "auto/mime_type_to_extension.gperf"
      {"application/atomcat+xml", "atomcat"},
      {"",nullptr}, {"",nullptr},
#line 449 "auto/mime_type_to_extension.gperf"
      {"application/vnd.tmobile-livetv", "tmo"},
#line 21 "auto/mime_type_to_extension.gperf"
      {"application/atomsvc+xml", "atomsvc"},
      {"",nullptr}, {"",nullptr},
#line 593 "auto/mime_type_to_extension.gperf"
      {"application/xcap-diff+xml", "xdf"},
      {"",nullptr}, {"",nullptr},
#line 566 "auto/mime_type_to_extension.gperf"
      {"application/x-shar", "shar"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 784 "auto/mime_type_to_extension.gperf"
      {"video/x-ms-asf", "asf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 499 "auto/mime_type_to_extension.gperf"
      {"application/x-cbr", "cbr"},
      {"",nullptr}, {"",nullptr},
#line 639 "auto/mime_type_to_extension.gperf"
      {"chemical/x-cif", "cif"},
#line 264 "auto/mime_type_to_extension.gperf"
      {"application/vnd.irepository.package+xml", "irp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 728 "auto/mime_type_to_extension.gperf"
      {"text/vnd.curl.dcurl", "dcurl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 206 "auto/mime_type_to_extension.gperf"
      {"application/vnd.flographit", "gph"},
      {"",nullptr}, {"",nullptr},
#line 598 "auto/mime_type_to_extension.gperf"
      {"application/xop+xml", "xop"},
      {"",nullptr},
#line 262 "auto/mime_type_to_extension.gperf"
      {"application/vnd.intu.qfx", "qfx"},
#line 468 "auto/mime_type_to_extension.gperf"
      {"application/vnd.wqd", "wqd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 400 "auto/mime_type_to_extension.gperf"
      {"application/vnd.realvnc.bed", "bed"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 547 "auto/mime_type_to_extension.gperf"
      {"application/x-msbinder", "obd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 495 "auto/mime_type_to_extension.gperf"
      {"application/x-bittorrent", "torrent"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 248 "auto/mime_type_to_extension.gperf"
      {"application/vnd.hp-pclxl", "pclxl"},
      {"",nullptr},
#line 528 "auto/mime_type_to_extension.gperf"
      {"application/x-gca-compressed", "gca"},
#line 200 "auto/mime_type_to_extension.gperf"
      {"application/vnd.eszigno3+xml", "es3"},
#line 40 "auto/mime_type_to_extension.gperf"
      {"application/gxf", "gxf"},
#line 83 "auto/mime_type_to_extension.gperf"
      {"application/pkcs8", "p8"},
      {"",nullptr},
#line 640 "auto/mime_type_to_extension.gperf"
      {"chemical/x-cmdf", "cmdf"},
#line 649 "auto/mime_type_to_extension.gperf"
      {"image/bmp", "bmp"},
      {"",nullptr}, {"",nullptr},
#line 791 "auto/mime_type_to_extension.gperf"
      {"video/x-sgi-movie", "movie"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 97 "auto/mime_type_to_extension.gperf"
      {"application/resource-lists-diff+xml", "rld"},
#line 89 "auto/mime_type_to_extension.gperf"
      {"application/pls+xml", "pls"},
      {"",nullptr},
#line 441 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sus-calendar", "sus"},
      {"",nullptr}, {"",nullptr},
#line 80 "auto/mime_type_to_extension.gperf"
      {"application/pkcs10", "p10"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 406 "auto/mime_type_to_extension.gperf"
      {"application/vnd.rn-realmedia-vbr", "rmvb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 508 "auto/mime_type_to_extension.gperf"
      {"application/x-dgc-compressed", "dgc"},
#line 34 "auto/mime_type_to_extension.gperf"
      {"application/emma+xml", "emma"},
#line 653 "auto/mime_type_to_extension.gperf"
      {"image/heic", "heic"},
#line 607 "auto/mime_type_to_extension.gperf"
      {"audio/basic", "au"},
      {"",nullptr},
#line 755 "auto/mime_type_to_extension.gperf"
      {"video/h261", "h261"},
#line 62 "auto/mime_type_to_extension.gperf"
      {"application/mets+xml", "mets"},
#line 757 "auto/mime_type_to_extension.gperf"
      {"video/h264", "h264"},
#line 19 "auto/mime_type_to_extension.gperf"
      {"application/atom+xml", "atom"},
      {"",nullptr}, {"",nullptr},
#line 480 "auto/mime_type_to_extension.gperf"
      {"application/vnd.zul", "zir"},
      {"",nullptr},
#line 758 "auto/mime_type_to_extension.gperf"
      {"video/h265", "h265"},
      {"",nullptr},
#line 518 "auto/mime_type_to_extension.gperf"
      {"application/x-font-ghostscript", "gsf"},
      {"",nullptr},
#line 136 "auto/mime_type_to_extension.gperf"
      {"application/vnd.adobe.fxp", "fxp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 22 "auto/mime_type_to_extension.gperf"
      {"application/ccxml+xml", "ccxml"},
#line 134 "auto/mime_type_to_extension.gperf"
      {"application/vnd.adobe.air-application-installer-package+zip", "air"},
      {"",nullptr}, {"",nullptr},
#line 467 "auto/mime_type_to_extension.gperf"
      {"application/vnd.wordperfect", "wpd"},
#line 63 "auto/mime_type_to_extension.gperf"
      {"application/mods+xml", "mods"},
#line 53 "auto/mime_type_to_extension.gperf"
      {"application/mads+xml", "mads"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 57 "auto/mime_type_to_extension.gperf"
      {"application/mathml+xml", "mathml"},
#line 424 "auto/mime_type_to_extension.gperf"
      {"application/vnd.stardivision.draw", "sda"},
#line 290 "auto/mime_type_to_extension.gperf"
      {"application/vnd.lotus-freelance", "pre"},
#line 32 "auto/mime_type_to_extension.gperf"
      {"application/dssc+xml", "xdssc"},
#line 756 "auto/mime_type_to_extension.gperf"
      {"video/h263", "h263"},
      {"",nullptr},
#line 322 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-htmlhelp", "chm"},
      {"",nullptr}, {"",nullptr},
#line 313 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mozilla.xul+xml", "xul"},
      {"",nullptr}, {"",nullptr},
#line 664 "auto/mime_type_to_extension.gperf"
      {"image/tiff", "tiff"},
      {"",nullptr},
#line 55 "auto/mime_type_to_extension.gperf"
      {"application/marcxml+xml", "mrcx"},
      {"",nullptr},
#line 570 "auto/mime_type_to_extension.gperf"
      {"application/x-stuffit", "sit"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 151 "auto/mime_type_to_extension.gperf"
      {"application/vnd.aristanetworks.swi", "swi"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 181 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dece.ttml+xml", "uvt"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 407 "auto/mime_type_to_extension.gperf"
      {"application/vnd.route66.link66+xml", "link66"},
      {"",nullptr}, {"",nullptr},
#line 209 "auto/mime_type_to_extension.gperf"
      {"application/vnd.frogans.fnc", "fnc"},
#line 699 "auto/mime_type_to_extension.gperf"
      {"message/rfc822", "eml"},
#line 416 "auto/mime_type_to_extension.gperf"
      {"application/vnd.shana.informed.package", "ipk"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 217 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fujixerox.ddd", "ddd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 338 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-wpl", "wpl"},
      {"",nullptr},
#line 414 "auto/mime_type_to_extension.gperf"
      {"application/vnd.shana.informed.formtemplate", "itp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 283 "auto/mime_type_to_extension.gperf"
      {"application/vnd.koan", "skp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 415 "auto/mime_type_to_extension.gperf"
      {"application/vnd.shana.informed.interchange", "iif"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 678 "auto/mime_type_to_extension.gperf"
      {"image/vnd.net-fpx", "npx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 413 "auto/mime_type_to_extension.gperf"
      {"application/vnd.shana.informed.formdata", "ifm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 775 "auto/mime_type_to_extension.gperf"
      {"video/vnd.uvvu.mp4", "uvu"},
      {"",nullptr}, {"",nullptr},
#line 177 "auto/mime_type_to_extension.gperf"
      {"application/vnd.curl.pcurl", "pcurl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 282 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kinar", "kne"},
#line 88 "auto/mime_type_to_extension.gperf"
      {"application/pkixcmp", "pki"},
      {"",nullptr}, {"",nullptr},
#line 503 "auto/mime_type_to_extension.gperf"
      {"application/x-chess-pgn", "pgn"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 568 "auto/mime_type_to_extension.gperf"
      {"application/x-silverlight-app", "xap"},
#line 288 "auto/mime_type_to_extension.gperf"
      {"application/vnd.lotus-1-2-3", "123"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 602 "auto/mime_type_to_extension.gperf"
      {"application/xv+xml", "mxml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 614 "auto/mime_type_to_extension.gperf"
      {"audio/vnd.dece.audio", "uva"},
      {"",nullptr},
#line 594 "auto/mime_type_to_extension.gperf"
      {"application/xenc+xml", "xenc"},
      {"",nullptr},
#line 280 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kenameaapp", "htke"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 453 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ufdl", "ufd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 93 "auto/mime_type_to_extension.gperf"
      {"application/rdf+xml", "rdf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 281 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kidspiration", "kia"},
#line 651 "auto/mime_type_to_extension.gperf"
      {"image/g3fax", "g3"},
      {"",nullptr},
#line 463 "auto/mime_type_to_extension.gperf"
      {"application/vnd.wap.wmlc", "wmlc"},
#line 121 "auto/mime_type_to_extension.gperf"
      {"application/ssml+xml", "ssml"},
#line 114 "auto/mime_type_to_extension.gperf"
      {"application/smil+xml", "smi"},
      {"",nullptr},
#line 680 "auto/mime_type_to_extension.gperf"
      {"image/vnd.xiff", "xif"},
#line 571 "auto/mime_type_to_extension.gperf"
      {"application/x-stuffitx", "sitx"},
      {"",nullptr},
#line 189 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ds-keypoint", "kpxx"},
      {"",nullptr}, {"",nullptr},
#line 557 "auto/mime_type_to_extension.gperf"
      {"application/x-mswrite", "wri"},
#line 50 "auto/mime_type_to_extension.gperf"
      {"application/lost+xml", "lostxml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 192 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dynageo", "geo"},
      {"",nullptr}, {"",nullptr},
#line 719 "auto/mime_type_to_extension.gperf"
      {"text/prs.lines.tag", "dsc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 455 "auto/mime_type_to_extension.gperf"
      {"application/vnd.umajin", "umj"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 585 "auto/mime_type_to_extension.gperf"
      {"application/x-wais-source", "src"},
      {"",nullptr},
#line 120 "auto/mime_type_to_extension.gperf"
      {"application/ssdl+xml", "ssdl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 75 "auto/mime_type_to_extension.gperf"
      {"application/patch-ops-error+xml", "xer"},
      {"",nullptr}, {"",nullptr},
#line 469 "auto/mime_type_to_extension.gperf"
      {"application/vnd.wt.stf", "stf"},
#line 173 "auto/mime_type_to_extension.gperf"
      {"application/vnd.criticaltools.wbs+xml", "wbs"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 81 "auto/mime_type_to_extension.gperf"
      {"application/pkcs7-mime", "p7m"},
      {"",nullptr},
#line 687 "auto/mime_type_to_extension.gperf"
      {"image/x-mrsid-image", "sid"},
      {"",nullptr},
#line 284 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kodak-descriptor", "sse"},
#line 78 "auto/mime_type_to_extension.gperf"
      {"application/pgp-signature", "asc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 497 "auto/mime_type_to_extension.gperf"
      {"application/x-bzip", "bz"},
      {"",nullptr}, {"",nullptr},
#line 582 "auto/mime_type_to_extension.gperf"
      {"application/x-tgif", "obj"},
#line 275 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kde.kivio", "flw"},
#line 464 "auto/mime_type_to_extension.gperf"
      {"application/vnd.wap.wmlscriptc", "wmlsc"},
#line 336 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-word.template.macroenabled.12", "dotm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 671 "auto/mime_type_to_extension.gperf"
      {"image/vnd.fastbidsheet", "fbs"},
      {"",nullptr}, {"",nullptr},
#line 257 "auto/mime_type_to_extension.gperf"
      {"application/vnd.immervision-ivu", "ivu"},
      {"",nullptr},
#line 188 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dreamfactory", "dfac"},
      {"",nullptr},
#line 298 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mediastation.cdkey", "cdkey"},
#line 272 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kde.karbon", "karbon"},
#line 210 "auto/mime_type_to_extension.gperf"
      {"application/vnd.frogans.ltf", "ltf"},
      {"",nullptr},
#line 335 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-word.document.macroenabled.12", "docm"},
      {"",nullptr},
#line 101 "auto/mime_type_to_extension.gperf"
      {"application/rpki-roa", "roa"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 618 "auto/mime_type_to_extension.gperf"
      {"audio/vnd.dts.hd", "dtshd"},
#line 511 "auto/mime_type_to_extension.gperf"
      {"application/x-dtbncx+xml", "ncx"},
      {"",nullptr}, {"",nullptr},
#line 278 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kde.kspread", "ksp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 403 "auto/mime_type_to_extension.gperf"
      {"application/vnd.rig.cryptonote", "cryptonote"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 634 "auto/mime_type_to_extension.gperf"
      {"audio/x-pn-realaudio", "ram"},
#line 100 "auto/mime_type_to_extension.gperf"
      {"application/rpki-manifest", "mft"},
      {"",nullptr},
#line 277 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kde.kpresenter", "kpr"},
      {"",nullptr},
#line 184 "auto/mime_type_to_extension.gperf"
      {"application/vnd.denovo.fcselayout-link", "fe_launch"},
      {"",nullptr},
#line 279 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kde.kword", "kwd"},
      {"",nullptr},
#line 169 "auto/mime_type_to_extension.gperf"
      {"application/vnd.crick.clicker.keyboard", "clkk"},
#line 478 "auto/mime_type_to_extension.gperf"
      {"application/vnd.yamaha.smaf-phrase", "spf"},
      {"",nullptr}, {"",nullptr},
#line 49 "auto/mime_type_to_extension.gperf"
      {"application/jsonml+json", "jsonml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 477 "auto/mime_type_to_extension.gperf"
      {"application/vnd.yamaha.smaf-audio", "saf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 696 "auto/mime_type_to_extension.gperf"
      {"image/x-xbitmap", "xbm"},
#line 115 "auto/mime_type_to_extension.gperf"
      {"application/sparql-query", "rq"},
#line 98 "auto/mime_type_to_extension.gperf"
      {"application/rls-services+xml", "rs"},
      {"",nullptr},
#line 732 "auto/mime_type_to_extension.gperf"
      {"text/vnd.fly", "fly"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 475 "auto/mime_type_to_extension.gperf"
      {"application/vnd.yamaha.openscoreformat", "osf"},
#line 223 "auto/mime_type_to_extension.gperf"
      {"application/vnd.geogebra.tool", "ggt"},
#line 766 "auto/mime_type_to_extension.gperf"
      {"video/vnd.dece.hd", "uvh"},
#line 143 "auto/mime_type_to_extension.gperf"
      {"application/vnd.americandynamics.acc", "acc"},
#line 592 "auto/mime_type_to_extension.gperf"
      {"application/xaml+xml", "xaml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 600 "auto/mime_type_to_extension.gperf"
      {"application/xslt+xml", "xslt"},
      {"",nullptr}, {"",nullptr},
#line 660 "auto/mime_type_to_extension.gperf"
      {"image/png", "png"},
      {"",nullptr}, {"",nullptr},
#line 611 "auto/mime_type_to_extension.gperf"
      {"audio/ogg", "oga"},
      {"",nullptr},
#line 652 "auto/mime_type_to_extension.gperf"
      {"image/gif", "gif"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 675 "auto/mime_type_to_extension.gperf"
      {"image/vnd.fujixerox.edmics-rlc", "rlc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 610 "auto/mime_type_to_extension.gperf"
      {"audio/mpeg", "mp3"},
      {"",nullptr},
#line 674 "auto/mime_type_to_extension.gperf"
      {"image/vnd.fujixerox.edmics-mmr", "mmr"},
#line 764 "auto/mime_type_to_extension.gperf"
      {"video/ogg", "ogv"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 240 "auto/mime_type_to_extension.gperf"
      {"application/vnd.handheld-entertainment+xml", "zmm"},
#line 393 "auto/mime_type_to_extension.gperf"
      {"application/vnd.pocketlearn", "plf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 263 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ipunplugged.rcprofile", "rcprofile"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 763 "auto/mime_type_to_extension.gperf"
      {"video/mpeg", "mpeg"},
      {"",nullptr},
#line 23 "auto/mime_type_to_extension.gperf"
      {"application/cdmi-capability", "cdmia"},
      {"",nullptr}, {"",nullptr},
#line 615 "auto/mime_type_to_extension.gperf"
      {"audio/vnd.digital-winds", "eol"},
#line 261 "auto/mime_type_to_extension.gperf"
      {"application/vnd.intu.qbo", "qbo"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 160 "auto/mime_type_to_extension.gperf"
      {"application/vnd.claymore", "cla"},
#line 530 "auto/mime_type_to_extension.gperf"
      {"application/x-gnumeric", "gnumeric"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 246 "auto/mime_type_to_extension.gperf"
      {"application/vnd.hp-jlyt", "jlt"},
      {"",nullptr},
#line 292 "auto/mime_type_to_extension.gperf"
      {"application/vnd.lotus-organizer", "org"},
      {"",nullptr},
#line 60 "auto/mime_type_to_extension.gperf"
      {"application/metalink+xml", "metalink"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 553 "auto/mime_type_to_extension.gperf"
      {"application/x-msmoney", "mny"},
      {"",nullptr},
#line 85 "auto/mime_type_to_extension.gperf"
      {"application/pkix-cert", "cer"},
#line 631 "auto/mime_type_to_extension.gperf"
      {"audio/x-mpegurl", "m3u"},
#line 515 "auto/mime_type_to_extension.gperf"
      {"application/x-envoy", "evy"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 677 "auto/mime_type_to_extension.gperf"
      {"image/vnd.ms-photo", "wdp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 252 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ibm.rights-management", "irm"},
#line 636 "auto/mime_type_to_extension.gperf"
      {"audio/x-wav", "wav"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 135 "auto/mime_type_to_extension.gperf"
      {"application/vnd.adobe.formscentral.fcdt", "fcdt"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 498 "auto/mime_type_to_extension.gperf"
      {"application/x-bzip2", "bz2"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 222 "auto/mime_type_to_extension.gperf"
      {"application/vnd.geogebra.file", "ggb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 601 "auto/mime_type_to_extension.gperf"
      {"application/xspf+xml", "xspf"},
      {"",nullptr},
#line 543 "auto/mime_type_to_extension.gperf"
      {"application/x-ms-wmd", "wmd"},
#line 71 "auto/mime_type_to_extension.gperf"
      {"application/ogg", "ogx"},
#line 483 "auto/mime_type_to_extension.gperf"
      {"application/widget", "wgt"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 235 "auto/mime_type_to_extension.gperf"
      {"application/vnd.groove-injector", "grv"},
      {"",nullptr},
#line 84 "auto/mime_type_to_extension.gperf"
      {"application/pkix-attr-cert", "ac"},
      {"",nullptr},
#line 378 "auto/mime_type_to_extension.gperf"
      {"application/vnd.openxmlformats-officedocument.presentationml.slideshow", "ppsx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 343 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mynfc", "taglet"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 669 "auto/mime_type_to_extension.gperf"
      {"image/vnd.dwg", "dwg"},
#line 466 "auto/mime_type_to_extension.gperf"
      {"application/vnd.wolfram.player", "nbp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 767 "auto/mime_type_to_extension.gperf"
      {"video/vnd.dece.mobile", "uvm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 245 "auto/mime_type_to_extension.gperf"
      {"application/vnd.hp-hps", "hps"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 462 "auto/mime_type_to_extension.gperf"
      {"application/vnd.wap.wbxml", "wbxml"},
      {"",nullptr}, {"",nullptr},
#line 476 "auto/mime_type_to_extension.gperf"
      {"application/vnd.yamaha.openscoreformat.osfpvg+xml", "osfpvg"},
#line 711 "auto/mime_type_to_extension.gperf"
      {"model/x3d+xml", "x3d"},
#line 533 "auto/mime_type_to_extension.gperf"
      {"application/x-hdf", "hdf"},
#line 472 "auto/mime_type_to_extension.gperf"
      {"application/vnd.yamaha.hv-dic", "hvd"},
#line 241 "auto/mime_type_to_extension.gperf"
      {"application/vnd.hbci", "hbci"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 474 "auto/mime_type_to_extension.gperf"
      {"application/vnd.yamaha.hv-voice", "hvp"},
#line 138 "auto/mime_type_to_extension.gperf"
      {"application/vnd.adobe.xfdf", "xfdf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 473 "auto/mime_type_to_extension.gperf"
      {"application/vnd.yamaha.hv-script", "hvs"},
      {"",nullptr},
#line 710 "auto/mime_type_to_extension.gperf"
      {"model/x3d+vrml", "x3dv"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 517 "auto/mime_type_to_extension.gperf"
      {"application/x-font-bdf", "bdf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 141 "auto/mime_type_to_extension.gperf"
      {"application/vnd.airzip.filesecure.azs", "azs"},
#line 202 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ezpix-package", "ez3"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 119 "auto/mime_type_to_extension.gperf"
      {"application/sru+xml", "sru"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 212 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fujitsu.oasys", "oas"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 39 "auto/mime_type_to_extension.gperf"
      {"application/gpx+xml", "gpx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 215 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fujitsu.oasysgp", "fg5"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 187 "auto/mime_type_to_extension.gperf"
      {"application/vnd.dpgraph", "dpg"},
#line 214 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fujitsu.oasys3", "oa3"},
      {"",nullptr}, {"",nullptr},
#line 685 "auto/mime_type_to_extension.gperf"
      {"image/x-freehand", "fh"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 244 "auto/mime_type_to_extension.gperf"
      {"application/vnd.hp-hpid", "hpid"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 216 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fujitsu.oasysprs", "bh2"},
#line 125 "auto/mime_type_to_extension.gperf"
      {"application/vnd.3gpp.pic-bw-large", "plb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 647 "auto/mime_type_to_extension.gperf"
      {"font/woff", "woff"},
#line 655 "auto/mime_type_to_extension.gperf"
      {"image/heif", "heif"},
      {"",nullptr},
#line 731 "auto/mime_type_to_extension.gperf"
      {"text/vnd.dvb.subtitle", "sub"},
#line 289 "auto/mime_type_to_extension.gperf"
      {"application/vnd.lotus-approach", "apr"},
#line 38 "auto/mime_type_to_extension.gperf"
      {"application/gml+xml", "gml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 127 "auto/mime_type_to_extension.gperf"
      {"application/vnd.3gpp.pic-bw-var", "pvb"},
#line 154 "auto/mime_type_to_extension.gperf"
      {"application/vnd.blueice.multipass", "mpm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 123 "auto/mime_type_to_extension.gperf"
      {"application/thraud+xml", "tfi"},
      {"",nullptr}, {"",nullptr},
#line 420 "auto/mime_type_to_extension.gperf"
      {"application/vnd.solent.sdkm+xml", "sdkm"},
      {"",nullptr},
#line 572 "auto/mime_type_to_extension.gperf"
      {"application/x-subrip", "srt"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 163 "auto/mime_type_to_extension.gperf"
      {"application/vnd.cluetrust.cartomobile-config", "c11amc"},
      {"",nullptr},
#line 437 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sun.xml.math", "sxm"},
#line 118 "auto/mime_type_to_extension.gperf"
      {"application/srgs+xml", "grxml"},
#line 164 "auto/mime_type_to_extension.gperf"
      {"application/vnd.cluetrust.cartomobile-config-pkg", "c11amz"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 397 "auto/mime_type_to_extension.gperf"
      {"application/vnd.publishare-delta-tree", "qps"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 630 "auto/mime_type_to_extension.gperf"
      {"audio/x-matroska", "mka"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 51 "auto/mime_type_to_extension.gperf"
      {"application/mac-binhex40", "hqx"},
      {"",nullptr}, {"",nullptr},
#line 346 "auto/mime_type_to_extension.gperf"
      {"application/vnd.noblenet-directory", "nnd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 707 "auto/mime_type_to_extension.gperf"
      {"model/vnd.vtu", "vtu"},
      {"",nullptr}, {"",nullptr},
#line 782 "auto/mime_type_to_extension.gperf"
      {"video/x-matroska", "mkv"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 230 "auto/mime_type_to_extension.gperf"
      {"application/vnd.google-earth.kmz", "kmz"},
      {"",nullptr},
#line 648 "auto/mime_type_to_extension.gperf"
      {"font/woff2", "woff2"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 587 "auto/mime_type_to_extension.gperf"
      {"application/x-xfig", "fig"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 229 "auto/mime_type_to_extension.gperf"
      {"application/vnd.google-earth.kml+xml", "kml"},
      {"",nullptr}, {"",nullptr},
#line 562 "auto/mime_type_to_extension.gperf"
      {"application/x-pkcs7-certreqresp", "p7r"},
      {"",nullptr},
#line 667 "auto/mime_type_to_extension.gperf"
      {"image/vnd.djvu", "djvu"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 565 "auto/mime_type_to_extension.gperf"
      {"application/x-sh", "sh"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 659 "auto/mime_type_to_extension.gperf"
      {"image/ktx", "ktx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 61 "auto/mime_type_to_extension.gperf"
      {"application/metalink4+xml", "meta4"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 506 "auto/mime_type_to_extension.gperf"
      {"application/x-csh", "csh"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 86 "auto/mime_type_to_extension.gperf"
      {"application/pkix-crl", "crl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 213 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fujitsu.oasys2", "oa2"},
#line 560 "auto/mime_type_to_extension.gperf"
      {"application/x-pkcs12", "p12"},
#line 321 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-fontobject", "eot"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 126 "auto/mime_type_to_extension.gperf"
      {"application/vnd.3gpp.pic-bw-small", "psb"},
      {"",nullptr}, {"",nullptr},
#line 702 "auto/mime_type_to_extension.gperf"
      {"model/vnd.collada+xml", "dae"},
#line 538 "auto/mime_type_to_extension.gperf"
      {"application/x-lzh-compressed", "lzh"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 771 "auto/mime_type_to_extension.gperf"
      {"video/vnd.dvb.file", "dvb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 694 "auto/mime_type_to_extension.gperf"
      {"image/x-rgb", "rgb"},
      {"",nullptr},
#line 201 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ezpix-album", "ez2"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 693 "auto/mime_type_to_extension.gperf"
      {"image/x-portable-pixmap", "ppm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 30 "auto/mime_type_to_extension.gperf"
      {"application/docbook+xml", "dbk"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 519 "auto/mime_type_to_extension.gperf"
      {"application/x-font-linux-psf", "psf"},
#line 465 "auto/mime_type_to_extension.gperf"
      {"application/vnd.webturbo", "wtb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 654 "auto/mime_type_to_extension.gperf"
      {"image/heic-sequence", "heics"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 94 "auto/mime_type_to_extension.gperf"
      {"application/reginfo+xml", "rif"},
      {"",nullptr}, {"",nullptr},
#line 484 "auto/mime_type_to_extension.gperf"
      {"application/winhlp", "hlp"},
      {"",nullptr}, {"",nullptr},
#line 70 "auto/mime_type_to_extension.gperf"
      {"application/oebps-package+xml", "opf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 529 "auto/mime_type_to_extension.gperf"
      {"application/x-glulx", "ulx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 140 "auto/mime_type_to_extension.gperf"
      {"application/vnd.airzip.filesecure.azf", "azf"},
      {"",nullptr}, {"",nullptr},
#line 536 "auto/mime_type_to_extension.gperf"
      {"application/x-java-jnlp-file", "jnlp"},
#line 701 "auto/mime_type_to_extension.gperf"
      {"model/mesh", "msh"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 271 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kahootz", "ktz"},
#line 295 "auto/mime_type_to_extension.gperf"
      {"application/vnd.macports.portpkg", "portpkg"},
      {"",nullptr},
#line 157 "auto/mime_type_to_extension.gperf"
      {"application/vnd.chemdraw+xml", "cdxml"},
      {"",nullptr},
#line 554 "auto/mime_type_to_extension.gperf"
      {"application/x-mspublisher", "pub"},
#line 239 "auto/mime_type_to_extension.gperf"
      {"application/vnd.hal+xml", "hal"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 456 "auto/mime_type_to_extension.gperf"
      {"application/vnd.unity", "unityweb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 588 "auto/mime_type_to_extension.gperf"
      {"application/x-xliff+xml", "xlf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 595 "auto/mime_type_to_extension.gperf"
      {"application/xhtml+xml", "xhtml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 243 "auto/mime_type_to_extension.gperf"
      {"application/vnd.hp-hpgl", "hpgl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 137 "auto/mime_type_to_extension.gperf"
      {"application/vnd.adobe.xdp+xml", "xdp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 344 "auto/mime_type_to_extension.gperf"
      {"application/vnd.neurolanguage.nlu", "nlu"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 193 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ecowin.chart", "mag"},
#line 386 "auto/mime_type_to_extension.gperf"
      {"application/vnd.osgi.subsystem", "esa"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 294 "auto/mime_type_to_extension.gperf"
      {"application/vnd.lotus-wordpro", "lwp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 666 "auto/mime_type_to_extension.gperf"
      {"image/vnd.dece.graphic", "uvi"},
      {"",nullptr}, {"",nullptr},
#line 492 "auto/mime_type_to_extension.gperf"
      {"application/x-authorware-map", "aam"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 734 "auto/mime_type_to_extension.gperf"
      {"text/vnd.graphviz", "gv"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 663 "auto/mime_type_to_extension.gperf"
      {"image/svg+xml", "svg"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 438 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sun.xml.writer", "sxw"},
      {"",nullptr}, {"",nullptr},
#line 274 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kde.kformula", "kfo"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 433 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sun.xml.draw", "sxd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 496 "auto/mime_type_to_extension.gperf"
      {"application/x-blorb", "blb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 276 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kde.kontour", "kon"},
#line 113 "auto/mime_type_to_extension.gperf"
      {"application/shf+xml", "shf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 561 "auto/mime_type_to_extension.gperf"
      {"application/x-pkcs7-certificates", "p7b"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 45 "auto/mime_type_to_extension.gperf"
      {"application/java-serialized-object", "ser"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 314 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-artgalry", "cil"},
      {"",nullptr},
#line 82 "auto/mime_type_to_extension.gperf"
      {"application/pkcs7-signature", "p7s"},
      {"",nullptr},
#line 91 "auto/mime_type_to_extension.gperf"
      {"application/prs.cww", "cww"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 350 "auto/mime_type_to_extension.gperf"
      {"application/vnd.nokia.n-gage.symbian.install", "n-gage"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 773 "auto/mime_type_to_extension.gperf"
      {"video/vnd.mpegurl", "mxu"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 513 "auto/mime_type_to_extension.gperf"
      {"application/x-dtbresource+xml", "res"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 785 "auto/mime_type_to_extension.gperf"
      {"video/x-ms-vob", "vob"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 105 "auto/mime_type_to_extension.gperf"
      {"application/sbml+xml", "sbml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 658 "auto/mime_type_to_extension.gperf"
      {"image/jpeg", "jpg"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 220 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fuzzysheet", "fzs"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 342 "auto/mime_type_to_extension.gperf"
      {"application/vnd.muvee.style", "msty"},
      {"",nullptr},
#line 759 "auto/mime_type_to_extension.gperf"
      {"video/jpeg", "jpgv"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 488 "auto/mime_type_to_extension.gperf"
      {"application/x-abiword", "abw"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 147 "auto/mime_type_to_extension.gperf"
      {"application/vnd.anser-web-funds-transfer-initiation", "fti"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 559 "auto/mime_type_to_extension.gperf"
      {"application/x-nzb", "nzb"},
#line 544 "auto/mime_type_to_extension.gperf"
      {"application/x-ms-wmz", "wmz"},
      {"",nullptr}, {"",nullptr},
#line 525 "auto/mime_type_to_extension.gperf"
      {"application/x-font-woff", "woff"},
      {"",nullptr}, {"",nullptr},
#line 146 "auto/mime_type_to_extension.gperf"
      {"application/vnd.anser-web-certificate-issue-initiation", "cii"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 656 "auto/mime_type_to_extension.gperf"
      {"image/heif-sequence", "heifs"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 234 "auto/mime_type_to_extension.gperf"
      {"application/vnd.groove-identity-message", "gim"},
#line 250 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ibm.minipay", "mpy"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 635 "auto/mime_type_to_extension.gperf"
      {"audio/x-pn-realaudio-plugin", "rmp"},
      {"",nullptr},
#line 681 "auto/mime_type_to_extension.gperf"
      {"image/webp", "webp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 625 "auto/mime_type_to_extension.gperf"
      {"audio/webm", "weba"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 273 "auto/mime_type_to_extension.gperf"
      {"application/vnd.kde.kchart", "chrt"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 777 "auto/mime_type_to_extension.gperf"
      {"video/webm", "webm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 479 "auto/mime_type_to_extension.gperf"
      {"application/vnd.yellowriver-custom-menu", "cmp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 604 "auto/mime_type_to_extension.gperf"
      {"application/yin+xml", "yin"},
#line 286 "auto/mime_type_to_extension.gperf"
      {"application/vnd.llamagraphics.life-balance.desktop", "lbd"},
#line 270 "auto/mime_type_to_extension.gperf"
      {"application/vnd.joost.joda-archive", "joda"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 42 "auto/mime_type_to_extension.gperf"
      {"application/inkml+xml", "ink"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 439 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sun.xml.writer.global", "sxg"},
      {"",nullptr},
#line 440 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sun.xml.writer.template", "stw"},
      {"",nullptr},
#line 218 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fujixerox.docuworks", "xdw"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 603 "auto/mime_type_to_extension.gperf"
      {"application/yang", "yang"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 348 "auto/mime_type_to_extension.gperf"
      {"application/vnd.noblenet-web", "nnw"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 87 "auto/mime_type_to_extension.gperf"
      {"application/pkix-pkipath", "pkipath"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 337 "auto/mime_type_to_extension.gperf"
      {"application/vnd.ms-works", "wps"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 739 "auto/mime_type_to_extension.gperf"
      {"text/vnd.wap.wmlscript", "wmls"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 692 "auto/mime_type_to_extension.gperf"
      {"image/x-portable-graymap", "pgm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 153 "auto/mime_type_to_extension.gperf"
      {"application/vnd.audiograph", "aep"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 446 "auto/mime_type_to_extension.gperf"
      {"application/vnd.syncml.dm+xml", "xdm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 156 "auto/mime_type_to_extension.gperf"
      {"application/vnd.businessobjects", "rep"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 219 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fujixerox.docuworks.binder", "xbd"},
      {"",nullptr}, {"",nullptr},
#line 507 "auto/mime_type_to_extension.gperf"
      {"application/x-debian-package", "deb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 551 "auto/mime_type_to_extension.gperf"
      {"application/x-msmediaview", "mvb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 92 "auto/mime_type_to_extension.gperf"
      {"application/pskc+xml", "pskcxml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 485 "auto/mime_type_to_extension.gperf"
      {"application/wsdl+xml", "wsdl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 287 "auto/mime_type_to_extension.gperf"
      {"application/vnd.llamagraphics.life-balance.exchange+xml", "lbe"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 679 "auto/mime_type_to_extension.gperf"
      {"image/vnd.wap.wbmp", "wbmp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 738 "auto/mime_type_to_extension.gperf"
      {"text/vnd.wap.wml", "wml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 172 "auto/mime_type_to_extension.gperf"
      {"application/vnd.crick.clicker.wordbank", "clkw"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 444 "auto/mime_type_to_extension.gperf"
      {"application/vnd.syncml+xml", "xsm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 643 "auto/mime_type_to_extension.gperf"
      {"chemical/x-xyz", "xyz"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 95 "auto/mime_type_to_extension.gperf"
      {"application/relax-ng-compact-syntax", "rnc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 249 "auto/mime_type_to_extension.gperf"
      {"application/vnd.hydrostatix.sof-data", "sfd-hdstx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 443 "auto/mime_type_to_extension.gperf"
      {"application/vnd.symbian.install", "sis"},
      {"",nullptr},
#line 35 "auto/mime_type_to_extension.gperf"
      {"application/epub+zip", "epub"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 142 "auto/mime_type_to_extension.gperf"
      {"application/vnd.amazon.ebook", "azw"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 481 "auto/mime_type_to_extension.gperf"
      {"application/vnd.zzazz.deck+xml", "zaz"},
      {"",nullptr},
#line 512 "auto/mime_type_to_extension.gperf"
      {"application/x-dtbook+xml", "dtb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 445 "auto/mime_type_to_extension.gperf"
      {"application/vnd.syncml.dm+wbxml", "bdm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 540 "auto/mime_type_to_extension.gperf"
      {"application/x-mobipocket-ebook", "prc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 705 "auto/mime_type_to_extension.gperf"
      {"model/vnd.gtw", "gtw"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 493 "auto/mime_type_to_extension.gperf"
      {"application/x-authorware-seg", "aas"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 691 "auto/mime_type_to_extension.gperf"
      {"image/x-portable-bitmap", "pbm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 486 "auto/mime_type_to_extension.gperf"
      {"application/wspolicy+xml", "wspolicy"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 460 "auto/mime_type_to_extension.gperf"
      {"application/vnd.visionary", "vis"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 395 "auto/mime_type_to_extension.gperf"
      {"application/vnd.previewsystems.box", "box"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 211 "auto/mime_type_to_extension.gperf"
      {"application/vnd.fsc.weblaunch", "fsc"},
#line 307 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mobius.mqy", "mqy"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 41 "auto/mime_type_to_extension.gperf"
      {"application/hyperstudio", "stk"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 99 "auto/mime_type_to_extension.gperf"
      {"application/rpki-ghostbusters", "gbr"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 491 "auto/mime_type_to_extension.gperf"
      {"application/x-authorware-bin", "aab"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 668 "auto/mime_type_to_extension.gperf"
      {"image/vnd.dvb.subtitle", "sub"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 500 "auto/mime_type_to_extension.gperf"
      {"application/x-cdlink", "vcd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 613 "auto/mime_type_to_extension.gperf"
      {"audio/silk", "sil"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 242 "auto/mime_type_to_extension.gperf"
      {"application/vnd.hhe.lesson-player", "les"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 665 "auto/mime_type_to_extension.gperf"
      {"image/vnd.adobe.photoshop", "psd"},
#line 690 "auto/mime_type_to_extension.gperf"
      {"image/x-portable-anymap", "pnm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 408 "auto/mime_type_to_extension.gperf"
      {"application/vnd.sailingtracker.track", "st"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 306 "auto/mime_type_to_extension.gperf"
      {"application/vnd.mobius.mbk", "mbk"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 567 "auto/mime_type_to_extension.gperf"
      {"application/x-shockwave-flash", "swf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 158 "auto/mime_type_to_extension.gperf"
      {"application/vnd.chipnuts.karaoke-mmd", "mmd"},
      {"",nullptr},
#line 698 "auto/mime_type_to_extension.gperf"
      {"image/x-xwindowdump", "xwd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 620 "auto/mime_type_to_extension.gperf"
      {"audio/vnd.ms-playready.media.pya", "pya"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 774 "auto/mime_type_to_extension.gperf"
      {"video/vnd.ms-playready.media.pyv", "pyv"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 527 "auto/mime_type_to_extension.gperf"
      {"application/x-futuresplash", "spl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 793 "auto/mime_type_to_extension.gperf"
      {"x-conference/x-cooltalk", "ice"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 709 "auto/mime_type_to_extension.gperf"
      {"model/x3d+binary", "x3db"}
    };

  if (len <= MAX_WORD_LENGTH && len >= MIN_WORD_LENGTH)
    {
      unsigned int key = mime_type_hash (str, len);

      if (key <= MAX_HASH_VALUE)
        {
          register const char *s = wordlist[key].mime_type;

          if ((((unsigned char)*str ^ (unsigned char)*s) & ~32) == 0 && !gperf_case_strcmp (str, s))
            return &wordlist[key];
        }
    }
  return 0;
}
#line 794 "auto/mime_type_to_extension.gperf"

const char *mime_type_to_extension(const char *mime_type, size_t mime_type_len) {
  const auto &result = search_mime_type(mime_type, mime_type_len);
  if (result == nullptr) {
    return nullptr;
  }

  return result->extension;
}
