/* ANSI-C code produced by gperf version 3.0.3 */
/* Command-line: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/gperf -m100 auto/extension_to_mime_type.gperf  */
/* Computed positions: -k'1-4,6,$' */

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

#line 12 "auto/extension_to_mime_type.gperf"
struct extension_and_mime_type {
  const char *extension;
  const char *mime_type;
};
#include <string.h>
/* maximum key range = 3879, duplicates = 0 */

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
extension_hash (register const char *str, register unsigned int len)
{
  static const unsigned short asso_values[] =
    {
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916,   18, 3916, 3916,   19,  113,
       129,  700,   58,   21,   18,   20,   23,   21, 3916, 3916,
      3916, 3916, 3916, 3916, 3916,  326,  825,   38,   46,  692,
        40,  316,  979,  429, 1051,  546,  156,   19,  919,  593,
        29,  296,  157,   18,   21,  362,   95,   89,   26, 1194,
       557, 3916, 3916, 3916, 3916,   21,   18,  326,  825,   38,
        46,  692,   40,  316,  979,  429, 1051,  546,  156,   19,
       919,  593,   29,  296,  157,   18,   21,  362,   95,   89,
        26, 1194,  557, 1255,  389,   28,  622, 1358,  363,  973,
      1401,  183,   70, 1211,  216,  744,  362,  455,  698, 1759,
        18,   85, 3916, 3916, 3916, 3916, 3916, 3916,   21,  362,
        95,   89,   26, 1194,  557, 1255,  389,   28,  622, 1358,
       363,  973, 1401,  183,   70, 1211,  216,  744,  362,  455,
       698, 1759,   18,   85, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916, 3916,
      3916, 3916, 3916, 3916, 3916, 3916, 3916
    };
  register unsigned int hval = len;

  switch (hval)
    {
      default:
        hval += asso_values[(unsigned char)str[5]];
      /*FALLTHROUGH*/
      case 5:
      case 4:
        hval += asso_values[(unsigned char)str[3]];
      /*FALLTHROUGH*/
      case 3:
        hval += asso_values[(unsigned char)str[2]];
      /*FALLTHROUGH*/
      case 2:
        hval += asso_values[(unsigned char)str[1]+51];
      /*FALLTHROUGH*/
      case 1:
        hval += asso_values[(unsigned char)str[0]];
        break;
    }
  return hval + asso_values[(unsigned char)str[len - 1]];
}

const struct extension_and_mime_type *
search_extension (register const char *str, register unsigned int len)
{
  enum
    {
      TOTAL_KEYWORDS = 981,
      MIN_WORD_LENGTH = 1,
      MAX_WORD_LENGTH = 11,
      MIN_HASH_VALUE = 37,
      MAX_HASH_VALUE = 3915
    };

  static const struct extension_and_mime_type wordlist[] =
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
      {"",nullptr},
#line 685 "auto/extension_to_mime_type.gperf"
      {"s", "text/x-asm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 787 "auto/extension_to_mime_type.gperf"
      {"t", "text/troff"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 572 "auto/extension_to_mime_type.gperf"
      {"p", "text/x-pascal"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 84 "auto/extension_to_mime_type.gperf"
      {"c", "text/x-c"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 240 "auto/extension_to_mime_type.gperf"
      {"f", "text/x-fortran"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 581 "auto/extension_to_mime_type.gperf"
      {"pas", "text/x-pascal"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 686 "auto/extension_to_mime_type.gperf"
      {"s3m", "audio/s3m"},
      {"",nullptr}, {"",nullptr},
#line 797 "auto/extension_to_mime_type.gperf"
      {"tex", "application/x-tex"},
      {"",nullptr},
#line 96 "auto/extension_to_mime_type.gperf"
      {"cat", "application/vnd.ms-pki.seccat"},
      {"",nullptr},
#line 444 "auto/extension_to_mime_type.gperf"
      {"mets", "application/mets+xml"},
      {"",nullptr},
#line 931 "auto/extension_to_mime_type.gperf"
      {"xap", "application/x-silverlight-app"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 573 "auto/extension_to_mime_type.gperf"
      {"p10", "application/pkcs10"},
      {"",nullptr}, {"",nullptr},
#line 800 "auto/extension_to_mime_type.gperf"
      {"text", "text/plain"},
#line 94 "auto/extension_to_mime_type.gperf"
      {"cap", "application/vnd.tcpdump.pcap"},
      {"",nullptr},
#line 687 "auto/extension_to_mime_type.gperf"
      {"saf", "application/vnd.yamaha.smaf-audio"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 426 "auto/extension_to_mime_type.gperf"
      {"mads", "application/mads+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 93 "auto/extension_to_mime_type.gperf"
      {"caf", "audio/x-caf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 706 "auto/extension_to_mime_type.gperf"
      {"semf", "application/vnd.semf"},
      {"",nullptr}, {"",nullptr},
#line 160 "auto/extension_to_mime_type.gperf"
      {"daf", "application/vnd.mobius.daf"},
      {"",nullptr},
#line 693 "auto/extension_to_mime_type.gperf"
      {"scs", "application/scvp-cv-response"},
#line 689 "auto/extension_to_mime_type.gperf"
      {"sc", "application/vnd.ibm.secure-container"},
#line 691 "auto/extension_to_mime_type.gperf"
      {"scm", "application/vnd.lotus-screencam"},
#line 170 "auto/extension_to_mime_type.gperf"
      {"def", "text/plain"},
#line 937 "auto/extension_to_mime_type.gperf"
      {"xdm", "application/vnd.syncml.dm+xml"},
      {"",nullptr}, {"",nullptr},
#line 705 "auto/extension_to_mime_type.gperf"
      {"semd", "application/vnd.semd"},
      {"",nullptr},
#line 924 "auto/extension_to_mime_type.gperf"
      {"x3d", "model/x3d+xml"},
      {"",nullptr}, {"",nullptr},
#line 276 "auto/extension_to_mime_type.gperf"
      {"fzs", "application/vnd.fuzzysheet"},
#line 888 "auto/extension_to_mime_type.gperf"
      {"wax", "audio/x-ms-wax"},
      {"",nullptr}, {"",nullptr},
#line 700 "auto/extension_to_mime_type.gperf"
      {"sdp", "application/sdp"},
#line 589 "auto/extension_to_mime_type.gperf"
      {"pct", "image/x-pict"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 102 "auto/extension_to_mime_type.gperf"
      {"cc", "text/x-c"},
#line 246 "auto/extension_to_mime_type.gperf"
      {"fcs", "application/vnd.isac.fcs"},
      {"",nullptr},
#line 938 "auto/extension_to_mime_type.gperf"
      {"xdp", "application/vnd.adobe.xdp+xml"},
      {"",nullptr},
#line 103 "auto/extension_to_mime_type.gperf"
      {"cct", "application/x-director"},
#line 591 "auto/extension_to_mime_type.gperf"
      {"pcx", "image/x-pcx"},
      {"",nullptr}, {"",nullptr},
#line 113 "auto/extension_to_mime_type.gperf"
      {"cdx", "chemical/x-cdx"},
      {"",nullptr},
#line 415 "auto/extension_to_mime_type.gperf"
      {"m14", "application/x-msmediaview"},
      {"",nullptr},
#line 696 "auto/extension_to_mime_type.gperf"
      {"sdc", "application/vnd.stardivision.calc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 939 "auto/extension_to_mime_type.gperf"
      {"xdssc", "application/dssc+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 936 "auto/extension_to_mime_type.gperf"
      {"xdf", "application/xcap-diff+xml"},
      {"",nullptr}, {"",nullptr},
#line 593 "auto/extension_to_mime_type.gperf"
      {"pdf", "application/pdf"},
#line 697 "auto/extension_to_mime_type.gperf"
      {"sdd", "application/vnd.stardivision.impress"},
      {"",nullptr}, {"",nullptr},
#line 886 "auto/extension_to_mime_type.gperf"
      {"wad", "application/x-doom"},
      {"",nullptr},
#line 586 "auto/extension_to_mime_type.gperf"
      {"pcf", "application/x-font-pcf"},
#line 690 "auto/extension_to_mime_type.gperf"
      {"scd", "application/x-msschedule"},
#line 436 "auto/extension_to_mime_type.gperf"
      {"mcd", "application/vnd.mcd"},
#line 106 "auto/extension_to_mime_type.gperf"
      {"cdf", "application/x-netcdf"},
      {"",nullptr},
#line 247 "auto/extension_to_mime_type.gperf"
      {"fdf", "application/vnd.fdf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 655 "auto/extension_to_mime_type.gperf"
      {"ras", "image/x-cmu-raster"},
      {"",nullptr},
#line 653 "auto/extension_to_mime_type.gperf"
      {"ram", "audio/x-pn-realaudio"},
      {"",nullptr},
#line 399 "auto/extension_to_mime_type.gperf"
      {"les", "application/vnd.hhe.lesson-player"},
#line 660 "auto/extension_to_mime_type.gperf"
      {"res", "application/x-dtbresource+xml"},
      {"",nullptr},
#line 885 "auto/extension_to_mime_type.gperf"
      {"w3d", "application/x-director"},
#line 892 "auto/extension_to_mime_type.gperf"
      {"wcm", "application/vnd.ms-works"},
      {"",nullptr},
#line 245 "auto/extension_to_mime_type.gperf"
      {"fcdt", "application/vnd.adobe.formscentral.fcdt"},
      {"",nullptr},
#line 870 "auto/extension_to_mime_type.gperf"
      {"vcs", "text/x-vcalendar"},
#line 168 "auto/extension_to_mime_type.gperf"
      {"ddd", "application/vnd.fujixerox.ddd"},
#line 582 "auto/extension_to_mime_type.gperf"
      {"paw", "application/vnd.pawaafile"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 243 "auto/extension_to_mime_type.gperf"
      {"f90", "text/x-fortran"},
      {"",nullptr},
#line 894 "auto/extension_to_mime_type.gperf"
      {"wdp", "image/vnd.ms-photo"},
#line 640 "auto/extension_to_mime_type.gperf"
      {"pyv", "video/vnd.ms-playready.media.pyv"},
      {"",nullptr}, {"",nullptr},
#line 485 "auto/extension_to_mime_type.gperf"
      {"mpm", "application/vnd.blueice.multipass"},
#line 659 "auto/extension_to_mime_type.gperf"
      {"rep", "application/vnd.businessobjects"},
#line 871 "auto/extension_to_mime_type.gperf"
      {"vcx", "application/vnd.vcx"},
      {"",nullptr},
#line 488 "auto/extension_to_mime_type.gperf"
      {"mpt", "application/vnd.ms-project"},
#line 970 "auto/extension_to_mime_type.gperf"
      {"xps", "application/vnd.ms-xpsdocument"},
#line 810 "auto/extension_to_mime_type.gperf"
      {"tpt", "application/vnd.trid.tpt"},
#line 968 "auto/extension_to_mime_type.gperf"
      {"xpm", "image/x-xpixmap"},
#line 620 "auto/extension_to_mime_type.gperf"
      {"pps", "application/vnd.ms-powerpoint"},
      {"",nullptr},
#line 619 "auto/extension_to_mime_type.gperf"
      {"ppm", "image/x-portable-pixmap"},
#line 916 "auto/extension_to_mime_type.gperf"
      {"wqd", "application/vnd.wqd"},
#line 493 "auto/extension_to_mime_type.gperf"
      {"ms", "text/troff"},
#line 750 "auto/extension_to_mime_type.gperf"
      {"spx", "audio/ogg"},
#line 623 "auto/extension_to_mime_type.gperf"
      {"ppt", "application/vnd.ms-powerpoint"},
#line 416 "auto/extension_to_mime_type.gperf"
      {"m1v", "video/mpeg"},
      {"",nullptr},
#line 193 "auto/extension_to_mime_type.gperf"
      {"dp", "application/vnd.osgi.dp"},
      {"",nullptr},
#line 748 "auto/extension_to_mime_type.gperf"
      {"spp", "application/scvp-vp-response"},
#line 487 "auto/extension_to_mime_type.gperf"
      {"mpp", "application/vnd.ms-project"},
#line 972 "auto/extension_to_mime_type.gperf"
      {"xpx", "application/vnd.intercon.formnet"},
#line 630 "auto/extension_to_mime_type.gperf"
      {"ps", "application/postscript"},
#line 143 "auto/extension_to_mime_type.gperf"
      {"cpt", "application/mac-compactpro"},
#line 180 "auto/extension_to_mime_type.gperf"
      {"djv", "image/vnd.djvu"},
      {"",nullptr}, {"",nullptr},
#line 161 "auto/extension_to_mime_type.gperf"
      {"dart", "application/vnd.dart"},
      {"",nullptr},
#line 621 "auto/extension_to_mime_type.gperf"
      {"ppsm", "application/vnd.ms-powerpoint.slideshow.macroenabled.12"},
#line 868 "auto/extension_to_mime_type.gperf"
      {"vcf", "text/x-vcard"},
      {"",nullptr},
#line 624 "auto/extension_to_mime_type.gperf"
      {"pptm", "application/vnd.ms-powerpoint.presentation.macroenabled.12"},
      {"",nullptr}, {"",nullptr},
#line 267 "auto/extension_to_mime_type.gperf"
      {"fpx", "image/vnd.fpx"},
      {"",nullptr},
#line 744 "auto/extension_to_mime_type.gperf"
      {"spc", "application/x-pkcs7-certificates"},
#line 478 "auto/extension_to_mime_type.gperf"
      {"mpc", "application/vnd.mophun.certificate"},
#line 142 "auto/extension_to_mime_type.gperf"
      {"cpp", "text/x-c"},
#line 975 "auto/extension_to_mime_type.gperf"
      {"xsm", "application/vnd.syncml+xml"},
#line 745 "auto/extension_to_mime_type.gperf"
      {"spf", "application/vnd.yamaha.smaf-phrase"},
#line 867 "auto/extension_to_mime_type.gperf"
      {"vcd", "application/x-cdlink"},
#line 622 "auto/extension_to_mime_type.gperf"
      {"ppsx", "application/vnd.openxmlformats-officedocument.presentationml.slideshow"},
      {"",nullptr},
#line 701 "auto/extension_to_mime_type.gperf"
      {"sdw", "application/vnd.stardivision.writer"},
#line 625 "auto/extension_to_mime_type.gperf"
      {"pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 151 "auto/extension_to_mime_type.gperf"
      {"css", "text/css"},
      {"",nullptr}, {"",nullptr},
#line 940 "auto/extension_to_mime_type.gperf"
      {"xdw", "application/vnd.fujixerox.docuworks"},
      {"",nullptr}, {"",nullptr},
#line 152 "auto/extension_to_mime_type.gperf"
      {"cst", "application/x-director"},
#line 476 "auto/extension_to_mime_type.gperf"
      {"mp4s", "application/mp4"},
#line 270 "auto/extension_to_mime_type.gperf"
      {"fst", "image/vnd.fst"},
      {"",nullptr},
#line 887 "auto/extension_to_mime_type.gperf"
      {"wav", "audio/x-wav"},
      {"",nullptr}, {"",nullptr},
#line 927 "auto/extension_to_mime_type.gperf"
      {"x3dv", "model/x3d+vrml"},
#line 618 "auto/extension_to_mime_type.gperf"
      {"ppd", "application/vnd.cups-ppd"},
#line 454 "auto/extension_to_mime_type.gperf"
      {"mj2", "video/mj2"},
      {"",nullptr}, {"",nullptr},
#line 915 "auto/extension_to_mime_type.gperf"
      {"wps", "application/vnd.ms-works"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 150 "auto/extension_to_mime_type.gperf"
      {"csp", "application/vnd.commonspace"},
      {"",nullptr},
#line 758 "auto/extension_to_mime_type.gperf"
      {"ssf", "application/vnd.epson.ssf"},
#line 497 "auto/extension_to_mime_type.gperf"
      {"msf", "application/vnd.epson.msf"},
      {"",nullptr}, {"",nullptr},
#line 474 "auto/extension_to_mime_type.gperf"
      {"mp4", "video/mp4"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 923 "auto/extension_to_mime_type.gperf"
      {"x32", "application/x-authorware-bin"},
#line 633 "auto/extension_to_mime_type.gperf"
      {"psf", "application/x-font-linux-psf"},
#line 657 "auto/extension_to_mime_type.gperf"
      {"rdf", "application/rdf+xml"},
      {"",nullptr}, {"",nullptr},
#line 814 "auto/extension_to_mime_type.gperf"
      {"tsd", "application/timestamped-data"},
#line 114 "auto/extension_to_mime_type.gperf"
      {"cdxml", "application/vnd.chemdraw+xml"},
      {"",nullptr},
#line 269 "auto/extension_to_mime_type.gperf"
      {"fsc", "application/vnd.fsc.weblaunch"},
#line 574 "auto/extension_to_mime_type.gperf"
      {"p12", "application/x-pkcs12"},
      {"",nullptr},
#line 455 "auto/extension_to_mime_type.gperf"
      {"mjp2", "video/mj2"},
#line 104 "auto/extension_to_mime_type.gperf"
      {"ccxml", "application/ccxml+xml"},
#line 632 "auto/extension_to_mime_type.gperf"
      {"psd", "image/vnd.adobe.photoshop"},
#line 196 "auto/extension_to_mime_type.gperf"
      {"dsc", "text/prs.lines.tag"},
      {"",nullptr},
#line 435 "auto/extension_to_mime_type.gperf"
      {"mc1", "application/vnd.medcalcdata"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 880 "auto/extension_to_mime_type.gperf"
      {"vss", "application/vnd.visio"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 976 "auto/extension_to_mime_type.gperf"
      {"xspf", "application/xspf+xml"},
#line 881 "auto/extension_to_mime_type.gperf"
      {"vst", "application/vnd.visio"},
#line 430 "auto/extension_to_mime_type.gperf"
      {"mar", "application/octet-stream"},
#line 641 "auto/extension_to_mime_type.gperf"
      {"qam", "application/vnd.epson.quickanime"},
#line 791 "auto/extension_to_mime_type.gperf"
      {"tar", "application/x-tar"},
#line 197 "auto/extension_to_mime_type.gperf"
      {"dssc", "application/dssc+der"},
#line 707 "auto/extension_to_mime_type.gperf"
      {"ser", "application/java-serialized-object"},
      {"",nullptr}, {"",nullptr},
#line 932 "auto/extension_to_mime_type.gperf"
      {"xar", "application/vnd.xara"},
      {"",nullptr}, {"",nullptr},
#line 913 "auto/extension_to_mime_type.gperf"
      {"wpd", "application/vnd.wordperfect"},
#line 425 "auto/extension_to_mime_type.gperf"
      {"ma", "application/mathematica"},
#line 942 "auto/extension_to_mime_type.gperf"
      {"xer", "application/patch-ops-error+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 95 "auto/extension_to_mime_type.gperf"
      {"car", "application/vnd.curl.car"},
      {"",nullptr},
#line 281 "auto/extension_to_mime_type.gperf"
      {"gam", "application/x-tads"},
      {"",nullptr}, {"",nullptr},
#line 116 "auto/extension_to_mime_type.gperf"
      {"cer", "application/pkix-cert"},
#line 930 "auto/extension_to_mime_type.gperf"
      {"xaml", "application/xaml+xml"},
      {"",nullptr}, {"",nullptr},
#line 676 "auto/extension_to_mime_type.gperf"
      {"rp9", "application/vnd.cloanto.rp9"},
#line 26 "auto/extension_to_mime_type.gperf"
      {"aas", "application/x-authorware-seg"},
      {"",nullptr},
#line 25 "auto/extension_to_mime_type.gperf"
      {"aam", "application/x-authorware-map"},
#line 172 "auto/extension_to_mime_type.gperf"
      {"der", "application/x-x509-ca-cert"},
#line 971 "auto/extension_to_mime_type.gperf"
      {"xpw", "application/vnd.intercon.formnet"},
      {"",nullptr}, {"",nullptr},
#line 680 "auto/extension_to_mime_type.gperf"
      {"rs", "application/rls-services+xml"},
#line 879 "auto/extension_to_mime_type.gperf"
      {"vsf", "application/vnd.vsf"},
      {"",nullptr},
#line 167 "auto/extension_to_mime_type.gperf"
      {"dd2", "application/vnd.oma.dd2+xml"},
#line 286 "auto/extension_to_mime_type.gperf"
      {"gex", "application/vnd.geometry-explorer"},
#line 677 "auto/extension_to_mime_type.gperf"
      {"rpss", "application/vnd.nokia.radio-presets"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 735 "auto/extension_to_mime_type.gperf"
      {"sm", "application/vnd.stepmania.stepchart"},
#line 751 "auto/extension_to_mime_type.gperf"
      {"sql", "application/x-sql"},
#line 678 "auto/extension_to_mime_type.gperf"
      {"rpst", "application/vnd.nokia.radio-preset"},
      {"",nullptr},
#line 878 "auto/extension_to_mime_type.gperf"
      {"vsd", "application/vnd.visio"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 962 "auto/extension_to_mime_type.gperf"
      {"xm", "audio/xm"},
      {"",nullptr},
#line 682 "auto/extension_to_mime_type.gperf"
      {"rss", "application/rss+xml"},
#line 34 "auto/extension_to_mime_type.gperf"
      {"aep", "application/vnd.audiograph"},
      {"",nullptr},
#line 90 "auto/extension_to_mime_type.gperf"
      {"c4p", "application/vnd.clonk.c4group"},
#line 280 "auto/extension_to_mime_type.gperf"
      {"gac", "application/vnd.groove-account"},
      {"",nullptr}, {"",nullptr},
#line 770 "auto/extension_to_mime_type.gperf"
      {"sus", "application/vnd.sus-calendar"},
#line 503 "auto/extension_to_mime_type.gperf"
      {"mus", "application/vnd.musician"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 264 "auto/extension_to_mime_type.gperf"
      {"fm", "application/vnd.framemaker"},
#line 298 "auto/extension_to_mime_type.gperf"
      {"gqs", "application/vnd.grafeq"},
#line 24 "auto/extension_to_mime_type.gperf"
      {"aac", "audio/x-aac"},
      {"",nullptr}, {"",nullptr},
#line 935 "auto/extension_to_mime_type.gperf"
      {"xbm", "image/x-xbitmap"},
#line 815 "auto/extension_to_mime_type.gperf"
      {"tsv", "text/tab-separated-values"},
#line 793 "auto/extension_to_mime_type.gperf"
      {"tcl", "application/x-tcl"},
#line 584 "auto/extension_to_mime_type.gperf"
      {"pbm", "image/x-portable-bitmap"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 88 "auto/extension_to_mime_type.gperf"
      {"c4f", "application/vnd.clonk.c4group"},
      {"",nullptr},
#line 587 "auto/extension_to_mime_type.gperf"
      {"pcl", "application/vnd.hp-pcl"},
      {"",nullptr},
#line 244 "auto/extension_to_mime_type.gperf"
      {"fbs", "image/vnd.fastbidsheet"},
      {"",nullptr},
#line 97 "auto/extension_to_mime_type.gperf"
      {"cb7", "application/x-cbr"},
#line 974 "auto/extension_to_mime_type.gperf"
      {"xslt", "application/xslt+xml"},
#line 100 "auto/extension_to_mime_type.gperf"
      {"cbt", "application/x-cbr"},
#line 724 "auto/extension_to_mime_type.gperf"
      {"sis", "application/vnd.symbian.install"},
#line 153 "auto/extension_to_mime_type.gperf"
      {"csv", "text/csv"},
#line 185 "auto/extension_to_mime_type.gperf"
      {"dms", "application/octet-stream"},
#line 87 "auto/extension_to_mime_type.gperf"
      {"c4d", "application/vnd.clonk.c4group"},
#line 64 "auto/extension_to_mime_type.gperf"
      {"azs", "application/vnd.airzip.filesecure.azs"},
      {"",nullptr},
#line 726 "auto/extension_to_mime_type.gperf"
      {"sit", "application/x-stuffit"},
#line 494 "auto/extension_to_mime_type.gperf"
      {"mscml", "application/mediaservercontrol+xml"},
#line 477 "auto/extension_to_mime_type.gperf"
      {"mp4v", "video/mp4"},
#line 442 "auto/extension_to_mime_type.gperf"
      {"meta4", "application/metalink4+xml"},
#line 137 "auto/extension_to_mime_type.gperf"
      {"cmx", "image/x-cmx"},
      {"",nullptr},
#line 165 "auto/extension_to_mime_type.gperf"
      {"dcr", "application/x-director"},
      {"",nullptr},
#line 771 "auto/extension_to_mime_type.gperf"
      {"susp", "application/vnd.sus-calendar"},
#line 28 "auto/extension_to_mime_type.gperf"
      {"ac", "application/pkix-attr-cert"},
#line 136 "auto/extension_to_mime_type.gperf"
      {"cmp", "application/vnd.yellowriver-custom-menu"},
#line 470 "auto/extension_to_mime_type.gperf"
      {"mp2", "audio/mpeg"},
#line 736 "auto/extension_to_mime_type.gperf"
      {"smf", "application/vnd.stardivision.math"},
#line 462 "auto/extension_to_mime_type.gperf"
      {"mmf", "application/vnd.smaf"},
      {"",nullptr},
#line 588 "auto/extension_to_mime_type.gperf"
      {"pclxl", "application/vnd.hp-pclxl"},
#line 681 "auto/extension_to_mime_type.gperf"
      {"rsd", "application/rsd+xml"},
#line 297 "auto/extension_to_mime_type.gperf"
      {"gqf", "application/vnd.grafeq"},
#line 184 "auto/extension_to_mime_type.gperf"
      {"dmp", "application/vnd.tcpdump.pcap"},
#line 422 "auto/extension_to_mime_type.gperf"
      {"m3u8", "application/vnd.apple.mpegurl"},
      {"",nullptr},
#line 901 "auto/extension_to_mime_type.gperf"
      {"wm", "video/x-ms-wm"},
#line 177 "auto/extension_to_mime_type.gperf"
      {"dis", "application/vnd.mobius.dis"},
      {"",nullptr},
#line 33 "auto/extension_to_mime_type.gperf"
      {"adp", "audio/adpcm"},
#line 461 "auto/extension_to_mime_type.gperf"
      {"mmd", "application/vnd.chipnuts.karaoke-mmd"},
      {"",nullptr}, {"",nullptr},
#line 133 "auto/extension_to_mime_type.gperf"
      {"cmc", "application/vnd.cosmocaller"},
#line 725 "auto/extension_to_mime_type.gperf"
      {"sisx", "application/vnd.symbian.install"},
      {"",nullptr},
#line 934 "auto/extension_to_mime_type.gperf"
      {"xbd", "application/vnd.fujixerox.docuworks.binder"},
#line 727 "auto/extension_to_mime_type.gperf"
      {"sitx", "application/x-stuffitx"},
      {"",nullptr},
#line 583 "auto/extension_to_mime_type.gperf"
      {"pbd", "application/vnd.powerbuilder6"},
      {"",nullptr}, {"",nullptr},
#line 202 "auto/extension_to_mime_type.gperf"
      {"dump", "application/octet-stream"},
#line 890 "auto/extension_to_mime_type.gperf"
      {"wbs", "application/vnd.criticaltools.wbs+xml"},
#line 452 "auto/extension_to_mime_type.gperf"
      {"mif", "application/vnd.mif"},
#line 882 "auto/extension_to_mime_type.gperf"
      {"vsw", "application/vnd.visio"},
#line 805 "auto/extension_to_mime_type.gperf"
      {"tif", "image/tiff"},
#line 63 "auto/extension_to_mime_type.gperf"
      {"azf", "application/vnd.airzip.filesecure.azf"},
#line 654 "auto/extension_to_mime_type.gperf"
      {"rar", "application/x-rar-compressed"},
      {"",nullptr},
#line 602 "auto/extension_to_mime_type.gperf"
      {"pic", "image/x-pict"},
#line 948 "auto/extension_to_mime_type.gperf"
      {"xif", "image/vnd.xiff"},
#line 178 "auto/extension_to_mime_type.gperf"
      {"dist", "application/octet-stream"},
#line 29 "auto/extension_to_mime_type.gperf"
      {"acc", "application/vnd.americandynamics.acc"},
      {"",nullptr},
#line 720 "auto/extension_to_mime_type.gperf"
      {"sid", "image/x-mrsid-image"},
#line 449 "auto/extension_to_mime_type.gperf"
      {"mid", "audio/midi"},
#line 792 "auto/extension_to_mime_type.gperf"
      {"tcap", "application/vnd.3gpp2.tcap"},
      {"",nullptr},
#line 652 "auto/extension_to_mime_type.gperf"
      {"ra", "audio/x-pn-realaudio"},
#line 910 "auto/extension_to_mime_type.gperf"
      {"wmx", "video/x-ms-wmx"},
      {"",nullptr}, {"",nullptr},
#line 122 "auto/extension_to_mime_type.gperf"
      {"cif", "chemical/x-cif"},
      {"",nullptr},
#line 585 "auto/extension_to_mime_type.gperf"
      {"pcap", "application/vnd.tcpdump.pcap"},
      {"",nullptr},
#line 175 "auto/extension_to_mime_type.gperf"
      {"dic", "text/x-c"},
      {"",nullptr},
#line 746 "auto/extension_to_mime_type.gperf"
      {"spl", "application/x-futuresplash"},
      {"",nullptr},
#line 644 "auto/extension_to_mime_type.gperf"
      {"qps", "application/vnd.publishare-delta-tree"},
#line 809 "auto/extension_to_mime_type.gperf"
      {"tpl", "application/vnd.groove-tool-template"},
      {"",nullptr}, {"",nullptr},
#line 978 "auto/extension_to_mime_type.gperf"
      {"xvm", "application/xv+xml"},
#line 872 "auto/extension_to_mime_type.gperf"
      {"vis", "application/vnd.visionary"},
#line 967 "auto/extension_to_mime_type.gperf"
      {"xpl", "application/xproc+xml"},
#line 679 "auto/extension_to_mime_type.gperf"
      {"rq", "application/sparql-query"},
#line 969 "auto/extension_to_mime_type.gperf"
      {"xpr", "application/vnd.is-xpr"},
      {"",nullptr},
#line 424 "auto/extension_to_mime_type.gperf"
      {"m4v", "video/x-m4v"},
      {"",nullptr}, {"",nullptr},
#line 134 "auto/extension_to_mime_type.gperf"
      {"cmdf", "chemical/x-cmdf"},
#line 889 "auto/extension_to_mime_type.gperf"
      {"wbmp", "image/vnd.wap.wbmp"},
      {"",nullptr},
#line 806 "auto/extension_to_mime_type.gperf"
      {"tiff", "image/tiff"},
#line 904 "auto/extension_to_mime_type.gperf"
      {"wmf", "application/x-msmetafile"},
      {"",nullptr},
#line 279 "auto/extension_to_mime_type.gperf"
      {"g3w", "application/vnd.geospace"},
#line 336 "auto/extension_to_mime_type.gperf"
      {"ief", "image/ief"},
#line 395 "auto/extension_to_mime_type.gperf"
      {"lasxml", "application/vnd.las.las+xml"},
#line 273 "auto/extension_to_mime_type.gperf"
      {"fvt", "video/vnd.fvt"},
#line 668 "auto/extension_to_mime_type.gperf"
      {"rm", "application/vnd.rn-realmedia"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 903 "auto/extension_to_mime_type.gperf"
      {"wmd", "application/x-ms-wmd"},
      {"",nullptr},
#line 241 "auto/extension_to_mime_type.gperf"
      {"f4v", "video/x-f4v"},
#line 500 "auto/extension_to_mime_type.gperf"
      {"msl", "application/vnd.mobius.msl"},
      {"",nullptr},
#line 774 "auto/extension_to_mime_type.gperf"
      {"svc", "application/vnd.dvb.service"},
      {"",nullptr},
#line 296 "auto/extension_to_mime_type.gperf"
      {"gpx", "application/gpx+xml"},
      {"",nullptr}, {"",nullptr},
#line 973 "auto/extension_to_mime_type.gperf"
      {"xsl", "application/xml"},
      {"",nullptr},
#line 671 "auto/extension_to_mime_type.gperf"
      {"rms", "application/vnd.jcp.javame.midlet-rms"},
      {"",nullptr},
#line 471 "auto/extension_to_mime_type.gperf"
      {"mp21", "application/mp21"},
#line 789 "auto/extension_to_mime_type.gperf"
      {"taglet", "application/vnd.mynfc"},
#line 335 "auto/extension_to_mime_type.gperf"
      {"ics", "text/calendar"},
      {"",nullptr},
#line 333 "auto/extension_to_mime_type.gperf"
      {"icm", "application/vnd.iccprofile"},
      {"",nullptr}, {"",nullptr},
#line 775 "auto/extension_to_mime_type.gperf"
      {"svd", "application/vnd.svd"},
#line 759 "auto/extension_to_mime_type.gperf"
      {"ssml", "application/ssml+xml"},
      {"",nullptr}, {"",nullptr},
#line 163 "auto/extension_to_mime_type.gperf"
      {"davmount", "application/davmount+xml"},
      {"",nullptr},
#line 739 "auto/extension_to_mime_type.gperf"
      {"smv", "video/x-smv"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 617 "auto/extension_to_mime_type.gperf"
      {"ppam", "application/vnd.ms-powerpoint.addin.macroenabled.12"},
#line 670 "auto/extension_to_mime_type.gperf"
      {"rmp", "audio/x-pn-realaudio-plugin"},
      {"",nullptr},
#line 52 "auto/extension_to_mime_type.gperf"
      {"asm", "text/x-asm"},
      {"",nullptr},
#line 664 "auto/extension_to_mime_type.gperf"
      {"ris", "application/x-research-info-systems"},
      {"",nullptr},
#line 914 "auto/extension_to_mime_type.gperf"
      {"wpl", "application/vnd.ms-wpl"},
      {"",nullptr},
#line 149 "auto/extension_to_mime_type.gperf"
      {"csml", "chemical/x-csml"},
      {"",nullptr}, {"",nullptr},
#line 65 "auto/extension_to_mime_type.gperf"
      {"azw", "application/vnd.amazon.ebook"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 756 "auto/extension_to_mime_type.gperf"
      {"ssdl", "application/ssdl+xml"},
#line 54 "auto/extension_to_mime_type.gperf"
      {"asx", "video/x-ms-asf"},
      {"",nullptr},
#line 922 "auto/extension_to_mime_type.gperf"
      {"wvx", "video/x-ms-wvx"},
#line 580 "auto/extension_to_mime_type.gperf"
      {"p8", "application/pkcs8"},
      {"",nullptr}, {"",nullptr},
#line 331 "auto/extension_to_mime_type.gperf"
      {"icc", "application/vnd.iccprofile"},
      {"",nullptr},
#line 85 "auto/extension_to_mime_type.gperf"
      {"c11amc", "application/vnd.cluetrust.cartomobile-config"},
      {"",nullptr},
#line 663 "auto/extension_to_mime_type.gperf"
      {"rip", "audio/vnd.rip"},
      {"",nullptr},
#line 402 "auto/extension_to_mime_type.gperf"
      {"list", "text/plain"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 397 "auto/extension_to_mime_type.gperf"
      {"lbd", "application/vnd.llamagraphics.life-balance.desktop"},
      {"",nullptr},
#line 304 "auto/extension_to_mime_type.gperf"
      {"gsf", "application/x-font-ghostscript"},
#line 715 "auto/extension_to_mime_type.gperf"
      {"sgm", "text/sgml"},
      {"",nullptr},
#line 109 "auto/extension_to_mime_type.gperf"
      {"cdmic", "application/cdmi-container"},
      {"",nullptr}, {"",nullptr},
#line 50 "auto/extension_to_mime_type.gperf"
      {"asc", "application/pgp-signature"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 51 "auto/extension_to_mime_type.gperf"
      {"asf", "video/x-ms-asf"},
#line 110 "auto/extension_to_mime_type.gperf"
      {"cdmid", "application/cdmi-domain"},
#line 599 "auto/extension_to_mime_type.gperf"
      {"pgm", "image/x-portable-graymap"},
      {"",nullptr},
#line 662 "auto/extension_to_mime_type.gperf"
      {"rif", "application/reginfo+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 403 "auto/extension_to_mime_type.gperf"
      {"list3820", "application/vnd.ibm.modcap"},
      {"",nullptr},
#line 118 "auto/extension_to_mime_type.gperf"
      {"cgm", "image/cgm"},
#line 447 "auto/extension_to_mime_type.gperf"
      {"mgp", "application/vnd.osgeo.mapguide.package"},
#line 482 "auto/extension_to_mime_type.gperf"
      {"mpg4", "video/mp4"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 249 "auto/extension_to_mime_type.gperf"
      {"fg5", "application/vnd.fujitsu.oasysgp"},
      {"",nullptr}, {"",nullptr},
#line 909 "auto/extension_to_mime_type.gperf"
      {"wmv", "video/x-ms-wmv"},
      {"",nullptr},
#line 601 "auto/extension_to_mime_type.gperf"
      {"pgp", "application/pgp-encrypted"},
#line 907 "auto/extension_to_mime_type.gperf"
      {"wmls", "text/vnd.wap.wmlscript"},
      {"",nullptr}, {"",nullptr},
#line 773 "auto/extension_to_mime_type.gperf"
      {"sv4crc", "application/x-sv4crc"},
      {"",nullptr},
#line 533 "auto/extension_to_mime_type.gperf"
      {"oas", "application/vnd.fujitsu.oasys"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 891 "auto/extension_to_mime_type.gperf"
      {"wbxml", "application/vnd.wap.wbxml"},
      {"",nullptr}, {"",nullptr},
#line 404 "auto/extension_to_mime_type.gperf"
      {"listafp", "application/vnd.ibm.modcap"},
      {"",nullptr}, {"",nullptr},
#line 824 "auto/extension_to_mime_type.gperf"
      {"u32", "application/x-authorware-bin"},
#line 22 "auto/extension_to_mime_type.gperf"
      {"7z", "application/x-7z-compressed"},
      {"",nullptr}, {"",nullptr},
#line 919 "auto/extension_to_mime_type.gperf"
      {"wsdl", "application/wsdl+xml"},
      {"",nullptr},
#line 908 "auto/extension_to_mime_type.gperf"
      {"wmlsc", "application/vnd.wap.wmlscriptc"},
#line 982 "auto/extension_to_mime_type.gperf"
      {"xz", "application/x-xz"},
      {"",nullptr},
#line 411 "auto/extension_to_mime_type.gperf"
      {"lvp", "audio/vnd.lucent.voice"},
      {"",nullptr}, {"",nullptr},
#line 427 "auto/extension_to_mime_type.gperf"
      {"mag", "application/vnd.ecowin.chart"},
      {"",nullptr},
#line 873 "auto/extension_to_mime_type.gperf"
      {"viv", "video/vnd.vivo"},
      {"",nullptr}, {"",nullptr},
#line 458 "auto/extension_to_mime_type.gperf"
      {"mks", "video/x-matroska"},
#line 729 "auto/extension_to_mime_type.gperf"
      {"skm", "application/vnd.koan"},
#line 174 "auto/extension_to_mime_type.gperf"
      {"dgc", "application/x-dgc-compressed"},
      {"",nullptr}, {"",nullptr},
#line 731 "auto/extension_to_mime_type.gperf"
      {"skt", "application/vnd.koan"},
      {"",nullptr}, {"",nullptr},
#line 906 "auto/extension_to_mime_type.gperf"
      {"wmlc", "application/vnd.wap.wmlc"},
      {"",nullptr}, {"",nullptr},
#line 899 "auto/extension_to_mime_type.gperf"
      {"wgt", "application/widget"},
#line 250 "auto/extension_to_mime_type.gperf"
      {"fgd", "application/x-director"},
      {"",nullptr}, {"",nullptr},
#line 699 "auto/extension_to_mime_type.gperf"
      {"sdkm", "application/vnd.solent.sdkm+xml"},
      {"",nullptr}, {"",nullptr},
#line 796 "auto/extension_to_mime_type.gperf"
      {"teicorpus", "application/tei+xml"},
#line 463 "auto/extension_to_mime_type.gperf"
      {"mmr", "image/vnd.fujixerox.edmics-mmr"},
      {"",nullptr},
#line 730 "auto/extension_to_mime_type.gperf"
      {"skp", "application/vnd.koan"},
#line 639 "auto/extension_to_mime_type.gperf"
      {"pya", "audio/vnd.ms-playready.media.pya"},
#line 977 "auto/extension_to_mime_type.gperf"
      {"xul", "application/vnd.mozilla.xul+xml"},
#line 963 "auto/extension_to_mime_type.gperf"
      {"xml", "application/xml"},
      {"",nullptr}, {"",nullptr},
#line 610 "auto/extension_to_mime_type.gperf"
      {"pml", "application/vnd.ctc-posml"},
#line 692 "auto/extension_to_mime_type.gperf"
      {"scq", "application/scvp-cv-request"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 420 "auto/extension_to_mime_type.gperf"
      {"m3a", "audio/mpeg"},
#line 688 "auto/extension_to_mime_type.gperf"
      {"sbml", "application/sbml+xml"},
#line 135 "auto/extension_to_mime_type.gperf"
      {"cml", "chemical/x-cml"},
#line 99 "auto/extension_to_mime_type.gperf"
      {"cbr", "application/x-cbr"},
#line 985 "auto/extension_to_mime_type.gperf"
      {"z1", "application/x-zmachine"},
#line 704 "auto/extension_to_mime_type.gperf"
      {"sema", "application/vnd.sema"},
#line 284 "auto/extension_to_mime_type.gperf"
      {"gdl", "model/vnd.gdl"},
#line 545 "auto/extension_to_mime_type.gperf"
      {"ods", "application/vnd.oasis.opendocument.spreadsheet"},
#line 722 "auto/extension_to_mime_type.gperf"
      {"sil", "audio/silk"},
#line 543 "auto/extension_to_mime_type.gperf"
      {"odm", "application/vnd.oasis.opendocument.text-master"},
#line 866 "auto/extension_to_mime_type.gperf"
      {"vcard", "text/vcard"},
      {"",nullptr}, {"",nullptr},
#line 546 "auto/extension_to_mime_type.gperf"
      {"odt", "application/vnd.oasis.opendocument.text"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 293 "auto/extension_to_mime_type.gperf"
      {"gmx", "application/vnd.gmx"},
#line 728 "auto/extension_to_mime_type.gperf"
      {"skd", "application/vnd.koan"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 440 "auto/extension_to_mime_type.gperf"
      {"me", "text/troff"},
      {"",nullptr}, {"",nullptr},
#line 124 "auto/extension_to_mime_type.gperf"
      {"cil", "application/vnd.ms-artgalry"},
#line 544 "auto/extension_to_mime_type.gperf"
      {"odp", "application/vnd.oasis.opendocument.presentation"},
      {"",nullptr}, {"",nullptr},
#line 291 "auto/extension_to_mime_type.gperf"
      {"gim", "application/vnd.groove-identity-message"},
      {"",nullptr}, {"",nullptr},
#line 698 "auto/extension_to_mime_type.gperf"
      {"sdkd", "application/vnd.solent.sdkm+xml"},
#line 900 "auto/extension_to_mime_type.gperf"
      {"wks", "application/vnd.ms-works"},
      {"",nullptr},
#line 176 "auto/extension_to_mime_type.gperf"
      {"dir", "application/x-director"},
      {"",nullptr},
#line 626 "auto/extension_to_mime_type.gperf"
      {"pqa", "application/vnd.palm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 43 "auto/extension_to_mime_type.gperf"
      {"ait", "application/vnd.dvb.ait"},
#line 538 "auto/extension_to_mime_type.gperf"
      {"odc", "application/vnd.oasis.opendocument.chart"},
#line 695 "auto/extension_to_mime_type.gperf"
      {"sda", "application/vnd.stardivision.draw"},
#line 788 "auto/extension_to_mime_type.gperf"
      {"t3", "application/x-t3vm-image"},
#line 154 "auto/extension_to_mime_type.gperf"
      {"cu", "application/cu-seeme"},
#line 539 "auto/extension_to_mime_type.gperf"
      {"odf", "application/vnd.oasis.opendocument.formula"},
      {"",nullptr},
#line 905 "auto/extension_to_mime_type.gperf"
      {"wml", "text/vnd.wap.wml"},
#line 540 "auto/extension_to_mime_type.gperf"
      {"odft", "application/vnd.oasis.opendocument.formula-template"},
#line 928 "auto/extension_to_mime_type.gperf"
      {"x3dvz", "model/x3d+vrml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 387 "auto/extension_to_mime_type.gperf"
      {"kpt", "application/vnd.kde.kpresenter"},
      {"",nullptr},
#line 933 "auto/extension_to_mime_type.gperf"
      {"xbap", "application/x-ms-xbap"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 760 "auto/extension_to_mime_type.gperf"
      {"st", "application/vnd.sailingtracker.track"},
#line 421 "auto/extension_to_mime_type.gperf"
      {"m3u", "audio/x-mpegurl"},
      {"",nullptr},
#line 290 "auto/extension_to_mime_type.gperf"
      {"gif", "image/gif"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 694 "auto/extension_to_mime_type.gperf"
      {"scurl", "text/vnd.curl.scurl"},
#line 437 "auto/extension_to_mime_type.gperf"
      {"mcurl", "text/vnd.curl.mcurl"},
      {"",nullptr},
#line 749 "auto/extension_to_mime_type.gperf"
      {"spq", "application/scvp-vp-request"},
      {"",nullptr},
#line 39 "auto/extension_to_mime_type.gperf"
      {"aif", "audio/x-aiff"},
#line 779 "auto/extension_to_mime_type.gperf"
      {"swf", "application/x-shockwave-flash"},
#line 506 "auto/extension_to_mime_type.gperf"
      {"mwf", "application/vnd.mfer"},
      {"",nullptr},
#line 502 "auto/extension_to_mime_type.gperf"
      {"mts", "model/vnd.mts"},
      {"",nullptr},
#line 590 "auto/extension_to_mime_type.gperf"
      {"pcurl", "application/vnd.curl.pcurl"},
#line 820 "auto/extension_to_mime_type.gperf"
      {"twds", "application/vnd.simtech-mindmapper"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 388 "auto/extension_to_mime_type.gperf"
      {"kpxx", "application/vnd.ds-keypoint"},
      {"",nullptr}, {"",nullptr},
#line 819 "auto/extension_to_mime_type.gperf"
      {"twd", "application/vnd.simtech-mindmapper"},
      {"",nullptr},
#line 979 "auto/extension_to_mime_type.gperf"
      {"xvml", "application/xv+xml"},
      {"",nullptr}, {"",nullptr},
#line 980 "auto/extension_to_mime_type.gperf"
      {"xwd", "image/x-xwindowdump"},
      {"",nullptr},
#line 166 "auto/extension_to_mime_type.gperf"
      {"dcurl", "text/vnd.curl.dcurl"},
#line 214 "auto/extension_to_mime_type.gperf"
      {"edm", "application/vnd.novadigm.edm"},
#line 389 "auto/extension_to_mime_type.gperf"
      {"ksp", "application/vnd.kde.kspread"},
      {"",nullptr},
#line 869 "auto/extension_to_mime_type.gperf"
      {"vcg", "application/vnd.groove-vcard"},
#line 48 "auto/extension_to_mime_type.gperf"
      {"apr", "application/vnd.lotus-approach"},
#line 205 "auto/extension_to_mime_type.gperf"
      {"dwf", "model/vnd.dwf"},
#line 19 "auto/extension_to_mime_type.gperf"
      {"3ds", "image/x-3ds"},
#line 200 "auto/extension_to_mime_type.gperf"
      {"dts", "audio/vnd.dts"},
      {"",nullptr},
#line 346 "auto/extension_to_mime_type.gperf"
      {"ims", "application/vnd.ms-ims"},
#line 703 "auto/extension_to_mime_type.gperf"
      {"seed", "application/vnd.fdsn.seed"},
      {"",nullptr},
#line 459 "auto/extension_to_mime_type.gperf"
      {"mkv", "video/x-matroska"},
#line 40 "auto/extension_to_mime_type.gperf"
      {"aifc", "audio/x-aiff"},
#line 215 "auto/extension_to_mime_type.gperf"
      {"edx", "application/vnd.novadigm.edx"},
#line 481 "auto/extension_to_mime_type.gperf"
      {"mpg", "video/mpeg"},
      {"",nullptr},
#line 41 "auto/extension_to_mime_type.gperf"
      {"aiff", "audio/x-aiff"},
#line 747 "auto/extension_to_mime_type.gperf"
      {"spot", "text/vnd.in3d.spot"},
#line 761 "auto/extension_to_mime_type.gperf"
      {"stc", "application/vnd.sun.xml.calc.template"},
      {"",nullptr}, {"",nullptr},
#line 816 "auto/extension_to_mime_type.gperf"
      {"ttc", "application/x-font-ttf"},
#line 763 "auto/extension_to_mime_type.gperf"
      {"stf", "application/vnd.wt.stf"},
      {"",nullptr},
#line 32 "auto/extension_to_mime_type.gperf"
      {"acutc", "application/vnd.acucorp"},
#line 817 "auto/extension_to_mime_type.gperf"
      {"ttf", "application/x-font-ttf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 345 "auto/extension_to_mime_type.gperf"
      {"imp", "application/vnd.accpac.simply.imp"},
      {"",nullptr}, {"",nullptr},
#line 846 "auto/extension_to_mime_type.gperf"
      {"uvs", "video/vnd.dece.sd"},
#line 762 "auto/extension_to_mime_type.gperf"
      {"std", "application/vnd.sun.xml.draw.template"},
#line 844 "auto/extension_to_mime_type.gperf"
      {"uvm", "video/vnd.dece.mobile"},
#line 556 "auto/extension_to_mime_type.gperf"
      {"opf", "application/oebps-package+xml"},
#line 709 "auto/extension_to_mime_type.gperf"
      {"setreg", "application/set-registration-initiation"},
      {"",nullptr},
#line 847 "auto/extension_to_mime_type.gperf"
      {"uvt", "application/vnd.dece.ttml+xml"},
#line 271 "auto/extension_to_mime_type.gperf"
      {"ftc", "application/vnd.fluxtime.clip"},
#line 194 "auto/extension_to_mime_type.gperf"
      {"dpg", "application/vnd.dpgraph"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 308 "auto/extension_to_mime_type.gperf"
      {"gv", "text/vnd.graphviz"},
#line 27 "auto/extension_to_mime_type.gperf"
      {"abw", "application/x-abiword"},
      {"",nullptr}, {"",nullptr},
#line 864 "auto/extension_to_mime_type.gperf"
      {"uvx", "application/vnd.dece.unspecified"},
#line 155 "auto/extension_to_mime_type.gperf"
      {"curl", "text/vnd.curl"},
      {"",nullptr},
#line 531 "auto/extension_to_mime_type.gperf"
      {"oa2", "application/vnd.fujitsu.oasys2"},
#line 112 "auto/extension_to_mime_type.gperf"
      {"cdmiq", "application/cdmi-queue"},
      {"",nullptr},
#line 845 "auto/extension_to_mime_type.gperf"
      {"uvp", "video/vnd.dece.pd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 377 "auto/extension_to_mime_type.gperf"
      {"kar", "audio/midi"},
#line 199 "auto/extension_to_mime_type.gperf"
      {"dtd", "application/xml-dtd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 714 "auto/extension_to_mime_type.gperf"
      {"sgl", "application/vnd.stardivision.writer-global"},
#line 66 "auto/extension_to_mime_type.gperf"
      {"bat", "application/x-msdownload"},
#line 560 "auto/extension_to_mime_type.gperf"
      {"osf", "application/vnd.yamaha.openscoreformat"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 181 "auto/extension_to_mime_type.gperf"
      {"djvu", "image/vnd.djvu"},
      {"",nullptr}, {"",nullptr},
#line 840 "auto/extension_to_mime_type.gperf"
      {"uvf", "application/vnd.dece.data"},
#line 344 "auto/extension_to_mime_type.gperf"
      {"iif", "application/vnd.shana.informed.interchange"},
      {"",nullptr}, {"",nullptr},
#line 419 "auto/extension_to_mime_type.gperf"
      {"m2v", "video/mpeg"},
      {"",nullptr},
#line 108 "auto/extension_to_mime_type.gperf"
      {"cdmia", "application/cdmi-capability"},
      {"",nullptr},
#line 795 "auto/extension_to_mime_type.gperf"
      {"tei", "application/tei+xml"},
      {"",nullptr},
#line 716 "auto/extension_to_mime_type.gperf"
      {"sgml", "text/sgml"},
      {"",nullptr},
#line 839 "auto/extension_to_mime_type.gperf"
      {"uvd", "application/vnd.dece.data"},
      {"",nullptr},
#line 225 "auto/extension_to_mime_type.gperf"
      {"eps", "application/postscript"},
#line 412 "auto/extension_to_mime_type.gperf"
      {"lwp", "application/vnd.lotus-wordpro"},
#line 475 "auto/extension_to_mime_type.gperf"
      {"mp4a", "audio/mp4"},
#line 156 "auto/extension_to_mime_type.gperf"
      {"cww", "application/prs.cww"},
#line 288 "auto/extension_to_mime_type.gperf"
      {"ggt", "application/vnd.geogebra.tool"},
      {"",nullptr}, {"",nullptr},
#line 396 "auto/extension_to_mime_type.gperf"
      {"latex", "application/x-latex"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 988 "auto/extension_to_mime_type.gperf"
      {"z4", "application/x-zmachine"},
      {"",nullptr},
#line 798 "auto/extension_to_mime_type.gperf"
      {"texi", "application/x-texinfo"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 417 "auto/extension_to_mime_type.gperf"
      {"m21", "application/mp21"},
      {"",nullptr}, {"",nullptr},
#line 768 "auto/extension_to_mime_type.gperf"
      {"stw", "application/vnd.sun.xml.writer.template"},
      {"",nullptr},
#line 358 "auto/extension_to_mime_type.gperf"
      {"ivp", "application/vnd.immervision-ivp"},
#line 70 "auto/extension_to_mime_type.gperf"
      {"bed", "application/vnd.realvnc.bed"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 858 "auto/extension_to_mime_type.gperf"
      {"uvvs", "video/vnd.dece.sd"},
      {"",nullptr},
#line 856 "auto/extension_to_mime_type.gperf"
      {"uvvm", "video/vnd.dece.mobile"},
#line 69 "auto/extension_to_mime_type.gperf"
      {"bdm", "application/vnd.syncml.dm+wbxml"},
#line 684 "auto/extension_to_mime_type.gperf"
      {"rtx", "text/richtext"},
      {"",nullptr},
#line 859 "auto/extension_to_mime_type.gperf"
      {"uvvt", "application/vnd.dece.ttml+xml"},
      {"",nullptr}, {"",nullptr},
#line 997 "auto/extension_to_mime_type.gperf"
      {"zmm", "application/vnd.handheld-entertainment+xml"},
      {"",nullptr}, {"",nullptr},
#line 898 "auto/extension_to_mime_type.gperf"
      {"wg", "application/vnd.pmi.widget"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 862 "auto/extension_to_mime_type.gperf"
      {"uvvx", "application/vnd.dece.unspecified"},
#line 439 "auto/extension_to_mime_type.gperf"
      {"mdi", "image/vnd.ms-modi"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 857 "auto/extension_to_mime_type.gperf"
      {"uvvp", "video/vnd.dece.pd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 896 "auto/extension_to_mime_type.gperf"
      {"webm", "video/webm"},
#line 410 "auto/extension_to_mime_type.gperf"
      {"ltf", "application/vnd.frogans.ltf"},
#line 683 "auto/extension_to_mime_type.gperf"
      {"rtf", "application/rtf"},
      {"",nullptr}, {"",nullptr},
#line 472 "auto/extension_to_mime_type.gperf"
      {"mp2a", "audio/mpeg"},
      {"",nullptr},
#line 89 "auto/extension_to_mime_type.gperf"
      {"c4g", "application/vnd.clonk.c4group"},
      {"",nullptr},
#line 229 "auto/extension_to_mime_type.gperf"
      {"esf", "application/vnd.epson.esf"},
      {"",nullptr}, {"",nullptr},
#line 292 "auto/extension_to_mime_type.gperf"
      {"gml", "application/gml+xml"},
#line 282 "auto/extension_to_mime_type.gperf"
      {"gbr", "application/rpki-ghostbusters"},
#line 852 "auto/extension_to_mime_type.gperf"
      {"uvvf", "application/vnd.dece.data"},
#line 68 "auto/extension_to_mime_type.gperf"
      {"bdf", "application/x-font-bdf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 897 "auto/extension_to_mime_type.gperf"
      {"webp", "image/webp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 990 "auto/extension_to_mime_type.gperf"
      {"z6", "application/x-zmachine"},
#line 994 "auto/extension_to_mime_type.gperf"
      {"zip", "application/zip"},
#line 851 "auto/extension_to_mime_type.gperf"
      {"uvvd", "application/vnd.dece.data"},
      {"",nullptr},
#line 849 "auto/extension_to_mime_type.gperf"
      {"uvv", "video/vnd.dece.video"},
#line 634 "auto/extension_to_mime_type.gperf"
      {"pskcxml", "application/pskc+xml"},
      {"",nullptr},
#line 558 "auto/extension_to_mime_type.gperf"
      {"oprc", "application/vnd.palm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 504 "auto/extension_to_mime_type.gperf"
      {"musicxml", "application/vnd.recordare.musicxml+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 342 "auto/extension_to_mime_type.gperf"
      {"igs", "model/iges"},
      {"",nullptr},
#line 341 "auto/extension_to_mime_type.gperf"
      {"igm", "application/vnd.insors.igm"},
      {"",nullptr}, {"",nullptr},
#line 434 "auto/extension_to_mime_type.gperf"
      {"mbox", "application/mbox"},
      {"",nullptr},
#line 42 "auto/extension_to_mime_type.gperf"
      {"air", "application/vnd.adobe.air-application-installer-package+zip"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 179 "auto/extension_to_mime_type.gperf"
      {"distz", "application/octet-stream"},
      {"",nullptr},
#line 238 "auto/extension_to_mime_type.gperf"
      {"ez2", "application/vnd.ezpix-album"},
#line 647 "auto/extension_to_mime_type.gperf"
      {"qwt", "application/vnd.quark.quarkxpress"},
      {"",nullptr},
#line 343 "auto/extension_to_mime_type.gperf"
      {"igx", "application/vnd.micrografx.igx"},
#line 721 "auto/extension_to_mime_type.gperf"
      {"sig", "application/pgp-signature"},
#line 612 "auto/extension_to_mime_type.gperf"
      {"pnm", "image/x-portable-anymap"},
#line 183 "auto/extension_to_mime_type.gperf"
      {"dmg", "application/x-apple-diskimage"},
      {"",nullptr},
#line 386 "auto/extension_to_mime_type.gperf"
      {"kpr", "application/vnd.kde.kpresenter"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 534 "auto/extension_to_mime_type.gperf"
      {"obd", "application/x-msbinder"},
#line 941 "auto/extension_to_mime_type.gperf"
      {"xenc", "application/xenc+xml"},
#line 60 "auto/extension_to_mime_type.gperf"
      {"au", "audio/basic"},
      {"",nullptr},
#line 516 "auto/extension_to_mime_type.gperf"
      {"nc", "application/x-netcdf"},
#line 98 "auto/extension_to_mime_type.gperf"
      {"cba", "application/x-cbr"},
      {"",nullptr}, {"",nullptr},
#line 278 "auto/extension_to_mime_type.gperf"
      {"g3", "image/g3fax"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 423 "auto/extension_to_mime_type.gperf"
      {"m4u", "video/vnd.mpegurl"},
#line 645 "auto/extension_to_mime_type.gperf"
      {"qt", "video/quicktime"},
#line 256 "auto/extension_to_mime_type.gperf"
      {"fig", "application/x-xfig"},
      {"",nullptr},
#line 283 "auto/extension_to_mime_type.gperf"
      {"gca", "application/x-gca-compressed"},
      {"",nullptr}, {"",nullptr},
#line 517 "auto/extension_to_mime_type.gperf"
      {"ncx", "application/x-dtbncx+xml"},
#line 966 "auto/extension_to_mime_type.gperf"
      {"xpi", "application/x-xpinstall"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 742 "auto/extension_to_mime_type.gperf"
      {"snf", "application/x-font-snf"},
      {"",nullptr}, {"",nullptr},
#line 766 "auto/extension_to_mime_type.gperf"
      {"stl", "application/vnd.ms-pki.stl"},
      {"",nullptr},
#line 767 "auto/extension_to_mime_type.gperf"
      {"str", "application/vnd.pg.format"},
#line 818 "auto/extension_to_mime_type.gperf"
      {"ttl", "text/turtle"},
#line 91 "auto/extension_to_mime_type.gperf"
      {"c4u", "application/vnd.clonk.c4group"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 741 "auto/extension_to_mime_type.gperf"
      {"snd", "audio/basic"},
#line 835 "auto/extension_to_mime_type.gperf"
      {"ustar", "application/x-ustar"},
#line 837 "auto/extension_to_mime_type.gperf"
      {"uu", "text/x-uuencode"},
#line 646 "auto/extension_to_mime_type.gperf"
      {"qwd", "application/vnd.quark.quarkxpress"},
      {"",nullptr}, {"",nullptr},
#line 265 "auto/extension_to_mime_type.gperf"
      {"fnc", "application/vnd.frogans.fnc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 499 "auto/extension_to_mime_type.gperf"
      {"msi", "application/x-msdownload"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 306 "auto/extension_to_mime_type.gperf"
      {"gtm", "application/vnd.groove-tool-message"},
      {"",nullptr}, {"",nullptr},
#line 323 "auto/extension_to_mime_type.gperf"
      {"hqx", "application/mac-binhex40"},
      {"",nullptr},
#line 861 "auto/extension_to_mime_type.gperf"
      {"uvvv", "video/vnd.dece.video"},
#line 902 "auto/extension_to_mime_type.gperf"
      {"wma", "audio/x-ms-wma"},
#line 776 "auto/extension_to_mime_type.gperf"
      {"svg", "image/svg+xml"},
      {"",nullptr}, {"",nullptr},
#line 557 "auto/extension_to_mime_type.gperf"
      {"opml", "text/x-opml"},
#line 352 "auto/extension_to_mime_type.gperf"
      {"ipfix", "application/ipfix"},
#line 361 "auto/extension_to_mime_type.gperf"
      {"jam", "application/vnd.jam"},
      {"",nullptr},
#line 62 "auto/extension_to_mime_type.gperf"
      {"aw", "application/applixware"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 579 "auto/extension_to_mime_type.gperf"
      {"p7s", "application/pkcs7-signature"},
#line 217 "auto/extension_to_mime_type.gperf"
      {"ei6", "application/vnd.pg.osasli"},
#line 577 "auto/extension_to_mime_type.gperf"
      {"p7m", "application/pkcs7-mime"},
      {"",nullptr}, {"",nullptr},
#line 18 "auto/extension_to_mime_type.gperf"
      {"3dml", "text/vnd.in3d.3dml"},
#line 59 "auto/extension_to_mime_type.gperf"
      {"atx", "application/vnd.antix.game-component"},
#line 738 "auto/extension_to_mime_type.gperf"
      {"smil", "application/smil+xml"},
      {"",nullptr},
#line 992 "auto/extension_to_mime_type.gperf"
      {"z8", "application/x-zmachine"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 162 "auto/extension_to_mime_type.gperf"
      {"dataless", "application/vnd.fdsn.seed"},
      {"",nullptr},
#line 242 "auto/extension_to_mime_type.gperf"
      {"f77", "text/x-fortran"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 219 "auto/extension_to_mime_type.gperf"
      {"emf", "application/x-msmetafile"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 799 "auto/extension_to_mime_type.gperf"
      {"texinfo", "application/x-texinfo"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 38 "auto/extension_to_mime_type.gperf"
      {"ai", "application/postscript"},
      {"",nullptr},
#line 31 "auto/extension_to_mime_type.gperf"
      {"acu", "application/vnd.acucobol"},
#line 55 "auto/extension_to_mime_type.gperf"
      {"atc", "application/vnd.acucorp"},
      {"",nullptr},
#line 317 "auto/extension_to_mime_type.gperf"
      {"hdf", "application/x-hdf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 526 "auto/extension_to_mime_type.gperf"
      {"npx", "image/vnd.net-fpx"},
      {"",nullptr},
#line 576 "auto/extension_to_mime_type.gperf"
      {"p7c", "application/pkcs7-mime"},
      {"",nullptr},
#line 981 "auto/extension_to_mime_type.gperf"
      {"xyz", "chemical/x-xyz"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 360 "auto/extension_to_mime_type.gperf"
      {"jad", "text/vnd.sun.j2me.app-descriptor"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 83 "auto/extension_to_mime_type.gperf"
      {"bz2", "application/x-bzip2"},
      {"",nullptr},
#line 111 "auto/extension_to_mime_type.gperf"
      {"cdmio", "application/cdmi-object"},
#line 483 "auto/extension_to_mime_type.gperf"
      {"mpga", "audio/mpeg"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 656 "auto/extension_to_mime_type.gperf"
      {"rcprofile", "application/vnd.ipunplugged.rcprofile"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 277 "auto/extension_to_mime_type.gperf"
      {"g2w", "application/vnd.geoplan"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 322 "auto/extension_to_mime_type.gperf"
      {"hps", "application/vnd.hp-hps"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 550 "auto/extension_to_mime_type.gperf"
      {"ogx", "application/ogg"},
      {"",nullptr}, {"",nullptr},
#line 432 "auto/extension_to_mime_type.gperf"
      {"mb", "application/mathematica"},
#line 673 "auto/extension_to_mime_type.gperf"
      {"rnc", "application/relax-ng-compact-syntax"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 527 "auto/extension_to_mime_type.gperf"
      {"nsc", "application/x-conference"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 528 "auto/extension_to_mime_type.gperf"
      {"nsf", "application/vnd.lotus-notes"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 381 "auto/extension_to_mime_type.gperf"
      {"kml", "application/vnd.google-earth.kml+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 929 "auto/extension_to_mime_type.gperf"
      {"x3dz", "model/x3d+xml"},
#line 790 "auto/extension_to_mime_type.gperf"
      {"tao", "application/vnd.tao.intent-module-archive"},
      {"",nullptr},
#line 803 "auto/extension_to_mime_type.gperf"
      {"tga", "image/x-tga"},
#line 357 "auto/extension_to_mime_type.gperf"
      {"itp", "application/vnd.shana.informed.formtemplate"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 307 "auto/extension_to_mime_type.gperf"
      {"gtw", "model/vnd.gtw"},
#line 737 "auto/extension_to_mime_type.gperf"
      {"smi", "application/smil+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 76 "auto/extension_to_mime_type.gperf"
      {"bmp", "image/bmp"},
      {"",nullptr},
#line 711 "auto/extension_to_mime_type.gperf"
      {"sfs", "application/vnd.spotfire.sfs"},
      {"",nullptr}, {"",nullptr},
#line 445 "auto/extension_to_mime_type.gperf"
      {"mfm", "application/vnd.mfmp"},
      {"",nullptr},
#line 802 "auto/extension_to_mime_type.gperf"
      {"tfm", "application/x-tex-tfm"},
      {"",nullptr},
#line 446 "auto/extension_to_mime_type.gperf"
      {"mft", "application/rpki-manifest"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 995 "auto/extension_to_mime_type.gperf"
      {"zir", "application/vnd.zul"},
#line 596 "auto/extension_to_mime_type.gperf"
      {"pfm", "application/x-font-type1"},
      {"",nullptr}, {"",nullptr},
#line 794 "auto/extension_to_mime_type.gperf"
      {"teacher", "application/vnd.smart.teacher"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 117 "auto/extension_to_mime_type.gperf"
      {"cfs", "application/x-cfs-compressed"},
      {"",nullptr},
#line 813 "auto/extension_to_mime_type.gperf"
      {"trm", "application/x-msterminal"},
#line 753 "auto/extension_to_mime_type.gperf"
      {"srt", "application/x-subrip"},
#line 373 "auto/extension_to_mime_type.gperf"
      {"jpm", "video/jpm"},
      {"",nullptr}, {"",nullptr},
#line 598 "auto/extension_to_mime_type.gperf"
      {"pfx", "application/x-pkcs12"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 755 "auto/extension_to_mime_type.gperf"
      {"srx", "application/sparql-results+xml"},
      {"",nullptr},
#line 603 "auto/extension_to_mime_type.gperf"
      {"pkg", "application/octet-stream"},
#line 374 "auto/extension_to_mime_type.gperf"
      {"js", "application/javascript"},
#line 123 "auto/extension_to_mime_type.gperf"
      {"cii", "application/vnd.anser-web-certificate-issue-initiation"},
#line 394 "auto/extension_to_mime_type.gperf"
      {"kwt", "application/vnd.kde.kword"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 146 "auto/extension_to_mime_type.gperf"
      {"crt", "application/x-x509-ca-cert"},
      {"",nullptr},
#line 457 "auto/extension_to_mime_type.gperf"
      {"mka", "audio/x-matroska"},
      {"",nullptr},
#line 635 "auto/extension_to_mime_type.gperf"
      {"ptid", "application/vnd.pvi.ptid1"},
#line 987 "auto/extension_to_mime_type.gperf"
      {"z3", "application/x-zmachine"},
      {"",nullptr},
#line 340 "auto/extension_to_mime_type.gperf"
      {"igl", "application/vnd.igloader"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 752 "auto/extension_to_mime_type.gperf"
      {"src", "application/x-wais-source"},
#line 491 "auto/extension_to_mime_type.gperf"
      {"mrc", "application/marc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 46 "auto/extension_to_mime_type.gperf"
      {"appcache", "text/cache-manifest"},
#line 315 "auto/extension_to_mime_type.gperf"
      {"hal", "application/vnd.hal+xml"},
#line 450 "auto/extension_to_mime_type.gperf"
      {"midi", "audio/midi"},
#line 541 "auto/extension_to_mime_type.gperf"
      {"odg", "application/vnd.oasis.opendocument.graphics"},
#line 21 "auto/extension_to_mime_type.gperf"
      {"3gp", "video/3gpp"},
#line 627 "auto/extension_to_mime_type.gperf"
      {"prc", "application/x-mobipocket-ebook"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 629 "auto/extension_to_mime_type.gperf"
      {"prf", "application/pics-rules"},
#line 492 "auto/extension_to_mime_type.gperf"
      {"mrcx", "application/marcxml+xml"},
      {"",nullptr},
#line 945 "auto/extension_to_mime_type.gperf"
      {"xht", "application/xhtml+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 105 "auto/extension_to_mime_type.gperf"
      {"cdbcmsg", "application/vnd.contact.cmsg"},
      {"",nullptr}, {"",nullptr},
#line 120 "auto/extension_to_mime_type.gperf"
      {"chm", "application/vnd.ms-htmlhelp"},
      {"",nullptr},
#line 237 "auto/extension_to_mime_type.gperf"
      {"ez", "application/andrew-inset"},
#line 536 "auto/extension_to_mime_type.gperf"
      {"oda", "application/oda"},
#line 254 "auto/extension_to_mime_type.gperf"
      {"fh7", "image/x-freehand"},
#line 393 "auto/extension_to_mime_type.gperf"
      {"kwd", "application/vnd.kde.kword"},
#line 253 "auto/extension_to_mime_type.gperf"
      {"fh5", "image/x-freehand"},
      {"",nullptr},
#line 515 "auto/extension_to_mime_type.gperf"
      {"nbp", "application/vnd.wolfram.player"},
#line 549 "auto/extension_to_mime_type.gperf"
      {"ogv", "video/ogg"},
#line 144 "auto/extension_to_mime_type.gperf"
      {"crd", "application/x-mscardfile"},
#line 391 "auto/extension_to_mime_type.gperf"
      {"ktx", "image/ktx"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 943 "auto/extension_to_mime_type.gperf"
      {"xfdf", "application/vnd.adobe.xfdf"},
#line 804 "auto/extension_to_mime_type.gperf"
      {"thmx", "application/vnd.ms-officetheme"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 719 "auto/extension_to_mime_type.gperf"
      {"shf", "application/shf+xml"},
#line 710 "auto/extension_to_mime_type.gperf"
      {"sfd-hdstx", "application/vnd.hydrostatix.sof-data"},
#line 431 "auto/extension_to_mime_type.gperf"
      {"mathml", "application/mathml+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 204 "auto/extension_to_mime_type.gperf"
      {"dvi", "application/x-dvi"},
#line 658 "auto/extension_to_mime_type.gperf"
      {"rdz", "application/vnd.data-vision.rdz"},
      {"",nullptr}, {"",nullptr},
#line 418 "auto/extension_to_mime_type.gperf"
      {"m2a", "audio/mpeg"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 220 "auto/extension_to_mime_type.gperf"
      {"eml", "message/rfc822"},
#line 778 "auto/extension_to_mime_type.gperf"
      {"swa", "application/x-director"},
      {"",nullptr}, {"",nullptr},
#line 255 "auto/extension_to_mime_type.gperf"
      {"fhc", "image/x-freehand"},
#line 443 "auto/extension_to_mime_type.gperf"
      {"metalink", "application/metalink+xml"},
#line 568 "auto/extension_to_mime_type.gperf"
      {"ots", "application/vnd.oasis.opendocument.spreadsheet-template"},
      {"",nullptr}, {"",nullptr},
#line 206 "auto/extension_to_mime_type.gperf"
      {"dwg", "image/vnd.dwg"},
#line 986 "auto/extension_to_mime_type.gperf"
      {"z2", "application/x-zmachine"},
#line 669 "auto/extension_to_mime_type.gperf"
      {"rmi", "audio/midi"},
#line 569 "auto/extension_to_mime_type.gperf"
      {"ott", "application/vnd.oasis.opendocument.text-template"},
      {"",nullptr},
#line 484 "auto/extension_to_mime_type.gperf"
      {"mpkg", "application/vnd.apple.installer+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 362 "auto/extension_to_mime_type.gperf"
      {"jar", "application/java-archive"},
      {"",nullptr},
#line 811 "auto/extension_to_mime_type.gperf"
      {"tr", "text/troff"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 578 "auto/extension_to_mime_type.gperf"
      {"p7r", "application/x-pkcs7-certreqresp"},
#line 567 "auto/extension_to_mime_type.gperf"
      {"otp", "application/vnd.oasis.opendocument.presentation-template"},
      {"",nullptr}, {"",nullptr},
#line 740 "auto/extension_to_mime_type.gperf"
      {"smzip", "application/vnd.stepmania.package"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 712 "auto/extension_to_mime_type.gperf"
      {"sfv", "text/x-sfv"},
      {"",nullptr}, {"",nullptr},
#line 409 "auto/extension_to_mime_type.gperf"
      {"lrm", "application/vnd.ms-lrm"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 520 "auto/extension_to_mime_type.gperf"
      {"nitf", "application/vnd.nitf"},
#line 252 "auto/extension_to_mime_type.gperf"
      {"fh4", "image/x-freehand"},
      {"",nullptr},
#line 562 "auto/extension_to_mime_type.gperf"
      {"otc", "application/vnd.oasis.opendocument.chart-template"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 563 "auto/extension_to_mime_type.gperf"
      {"otf", "application/x-font-otf"},
#line 734 "auto/extension_to_mime_type.gperf"
      {"slt", "application/vnd.epson.salt"},
      {"",nullptr},
#line 954 "auto/extension_to_mime_type.gperf"
      {"xls", "application/vnd.ms-excel"},
      {"",nullptr},
#line 953 "auto/extension_to_mime_type.gperf"
      {"xlm", "application/vnd.ms-excel"},
#line 609 "auto/extension_to_mime_type.gperf"
      {"pls", "application/pls+xml"},
      {"",nullptr}, {"",nullptr},
#line 958 "auto/extension_to_mime_type.gperf"
      {"xlt", "application/vnd.ms-excel"},
      {"",nullptr},
#line 702 "auto/extension_to_mime_type.gperf"
      {"see", "application/vnd.seemail"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 713 "auto/extension_to_mime_type.gperf"
      {"sgi", "image/sgi"},
#line 456 "auto/extension_to_mime_type.gperf"
      {"mk3d", "video/x-matroska"},
#line 460 "auto/extension_to_mime_type.gperf"
      {"mlp", "application/vnd.dolby.mlp"},
      {"",nullptr},
#line 428 "auto/extension_to_mime_type.gperf"
      {"maker", "application/vnd.framemaker"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 956 "auto/extension_to_mime_type.gperf"
      {"xlsm", "application/vnd.ms-excel.sheet.macroenabled.12"},
      {"",nullptr}, {"",nullptr},
#line 959 "auto/extension_to_mime_type.gperf"
      {"xltm", "application/vnd.ms-excel.template.macroenabled.12"},
      {"",nullptr}, {"",nullptr},
#line 408 "auto/extension_to_mime_type.gperf"
      {"lrf", "application/octet-stream"},
      {"",nullptr},
#line 841 "auto/extension_to_mime_type.gperf"
      {"uvg", "image/vnd.dece.graphic"},
#line 262 "auto/extension_to_mime_type.gperf"
      {"flx", "text/vnd.fmi.flexstor"},
#line 159 "auto/extension_to_mime_type.gperf"
      {"dae", "model/vnd.collada+xml"},
      {"",nullptr}, {"",nullptr},
#line 132 "auto/extension_to_mime_type.gperf"
      {"clp", "application/x-msclip"},
#line 957 "auto/extension_to_mime_type.gperf"
      {"xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"},
      {"",nullptr}, {"",nullptr},
#line 960 "auto/extension_to_mime_type.gperf"
      {"xltx", "application/vnd.openxmlformats-officedocument.spreadsheetml.template"},
#line 213 "auto/extension_to_mime_type.gperf"
      {"ecma", "application/ecmascript"},
#line 951 "auto/extension_to_mime_type.gperf"
      {"xlc", "application/vnd.ms-excel"},
#line 732 "auto/extension_to_mime_type.gperf"
      {"sldm", "application/vnd.ms-powerpoint.slide.macroenabled.12"},
      {"",nullptr},
#line 607 "auto/extension_to_mime_type.gperf"
      {"plc", "application/vnd.mobius.plc"},
#line 952 "auto/extension_to_mime_type.gperf"
      {"xlf", "application/x-xliff+xml"},
#line 414 "auto/extension_to_mime_type.gperf"
      {"m13", "application/x-msmediaview"},
#line 82 "auto/extension_to_mime_type.gperf"
      {"bz", "application/x-bzip"},
#line 608 "auto/extension_to_mime_type.gperf"
      {"plf", "application/vnd.pocketlearn"},
      {"",nullptr},
#line 838 "auto/extension_to_mime_type.gperf"
      {"uva", "audio/vnd.dece.audio"},
#line 329 "auto/extension_to_mime_type.gperf"
      {"hvs", "application/vnd.yamaha.hv-script"},
      {"",nullptr},
#line 614 "auto/extension_to_mime_type.gperf"
      {"pot", "application/vnd.ms-powerpoint"},
#line 433 "auto/extension_to_mime_type.gperf"
      {"mbk", "application/vnd.mobius.mbk"},
      {"",nullptr},
#line 733 "auto/extension_to_mime_type.gperf"
      {"sldx", "application/vnd.openxmlformats-officedocument.presentationml.slide"},
      {"",nullptr},
#line 139 "auto/extension_to_mime_type.gperf"
      {"com", "application/x-msdownload"},
      {"",nullptr},
#line 946 "auto/extension_to_mime_type.gperf"
      {"xhtml", "application/xhtml+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 965 "auto/extension_to_mime_type.gperf"
      {"xop", "application/xop+xml"},
      {"",nullptr}, {"",nullptr},
#line 231 "auto/extension_to_mime_type.gperf"
      {"etx", "text/x-setext"},
#line 190 "auto/extension_to_mime_type.gperf"
      {"dot", "application/msword"},
#line 615 "auto/extension_to_mime_type.gperf"
      {"potm", "application/vnd.ms-powerpoint.template.macroenabled.12"},
      {"",nullptr},
#line 328 "auto/extension_to_mime_type.gperf"
      {"hvp", "application/vnd.yamaha.hv-voice"},
#line 121 "auto/extension_to_mime_type.gperf"
      {"chrt", "application/vnd.kde.kchart"},
      {"",nullptr}, {"",nullptr},
#line 926 "auto/extension_to_mime_type.gperf"
      {"x3dbz", "model/x3d+binary"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 164 "auto/extension_to_mime_type.gperf"
      {"dbk", "application/docbook+xml"},
      {"",nullptr}, {"",nullptr},
#line 467 "auto/extension_to_mime_type.gperf"
      {"mods", "application/mods+xml"},
#line 616 "auto/extension_to_mime_type.gperf"
      {"potx", "application/vnd.openxmlformats-officedocument.presentationml.template"},
      {"",nullptr}, {"",nullptr},
#line 191 "auto/extension_to_mime_type.gperf"
      {"dotm", "application/vnd.ms-word.template.macroenabled.12"},
      {"",nullptr},
#line 604 "auto/extension_to_mime_type.gperf"
      {"pki", "application/pkixcmp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 561 "auto/extension_to_mime_type.gperf"
      {"osfpvg", "application/vnd.yamaha.openscoreformat.osfpvg+xml"},
#line 101 "auto/extension_to_mime_type.gperf"
      {"cbz", "application/x-cbr"},
#line 20 "auto/extension_to_mime_type.gperf"
      {"3g2", "video/3gpp2"},
      {"",nullptr},
#line 364 "auto/extension_to_mime_type.gperf"
      {"jisp", "application/vnd.jisp"},
      {"",nullptr}, {"",nullptr},
#line 496 "auto/extension_to_mime_type.gperf"
      {"mseq", "application/vnd.mseq"},
#line 192 "auto/extension_to_mime_type.gperf"
      {"dotx", "application/vnd.openxmlformats-officedocument.wordprocessingml.template"},
      {"",nullptr},
#line 187 "auto/extension_to_mime_type.gperf"
      {"doc", "application/msword"},
#line 188 "auto/extension_to_mime_type.gperf"
      {"docm", "application/vnd.ms-word.document.macroenabled.12"},
      {"",nullptr},
#line 327 "auto/extension_to_mime_type.gperf"
      {"hvd", "application/vnd.yamaha.hv-dic"},
#line 480 "auto/extension_to_mime_type.gperf"
      {"mpeg", "video/mpeg"},
#line 285 "auto/extension_to_mime_type.gperf"
      {"geo", "application/vnd.dynageo"},
      {"",nullptr}, {"",nullptr},
#line 138 "auto/extension_to_mime_type.gperf"
      {"cod", "application/vnd.rim.cod"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 597 "auto/extension_to_mime_type.gperf"
      {"pfr", "application/font-tdpfr"},
#line 189 "auto/extension_to_mime_type.gperf"
      {"docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"},
      {"",nullptr},
#line 542 "auto/extension_to_mime_type.gperf"
      {"odi", "application/vnd.oasis.opendocument.image"},
#line 848 "auto/extension_to_mime_type.gperf"
      {"uvu", "video/vnd.uvvu.mp4"},
#line 643 "auto/extension_to_mime_type.gperf"
      {"qfx", "application/vnd.intu.qfx"},
      {"",nullptr}, {"",nullptr},
#line 853 "auto/extension_to_mime_type.gperf"
      {"uvvg", "image/vnd.dece.graphic"},
      {"",nullptr},
#line 44 "auto/extension_to_mime_type.gperf"
      {"ami", "application/vnd.amiga.ami"},
#line 876 "auto/extension_to_mime_type.gperf"
      {"vox", "application/x-authorware-bin"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 947 "auto/extension_to_mime_type.gperf"
      {"xhvml", "application/xv+xml"},
      {"",nullptr}, {"",nullptr},
#line 989 "auto/extension_to_mime_type.gperf"
      {"z5", "application/x-zmachine"},
      {"",nullptr},
#line 35 "auto/extension_to_mime_type.gperf"
      {"afm", "application/x-font-type1"},
      {"",nullptr},
#line 228 "auto/extension_to_mime_type.gperf"
      {"esa", "application/vnd.osgi.subsystem"},
#line 145 "auto/extension_to_mime_type.gperf"
      {"crl", "application/pkix-crl"},
#line 961 "auto/extension_to_mime_type.gperf"
      {"xlw", "application/vnd.ms-excel"},
#line 883 "auto/extension_to_mime_type.gperf"
      {"vtu", "model/vnd.vtu"},
      {"",nullptr},
#line 850 "auto/extension_to_mime_type.gperf"
      {"uvva", "audio/vnd.dece.audio"},
#line 911 "auto/extension_to_mime_type.gperf"
      {"wmz", "application/x-ms-wmz"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 807 "auto/extension_to_mime_type.gperf"
      {"tmo", "application/vnd.tmobile-livetv"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 780 "auto/extension_to_mime_type.gperf"
      {"swi", "application/vnd.aristanetworks.swi"},
      {"",nullptr},
#line 261 "auto/extension_to_mime_type.gperf"
      {"flw", "application/vnd.kde.kivio"},
#line 384 "auto/extension_to_mime_type.gperf"
      {"knp", "application/vnd.kinar"},
#line 36 "auto/extension_to_mime_type.gperf"
      {"afp", "application/vnd.ibm.modcap"},
#line 944 "auto/extension_to_mime_type.gperf"
      {"xfdl", "application/vnd.xfdl"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 479 "auto/extension_to_mime_type.gperf"
      {"mpe", "video/mpeg"},
#line 380 "auto/extension_to_mime_type.gperf"
      {"kia", "application/vnd.kidspiration"},
#line 260 "auto/extension_to_mime_type.gperf"
      {"flv", "video/x-flv"},
#line 371 "auto/extension_to_mime_type.gperf"
      {"jpgm", "video/jpm"},
#line 248 "auto/extension_to_mime_type.gperf"
      {"fe_launch", "application/vnd.denovo.fcselayout-link"},
#line 666 "auto/extension_to_mime_type.gperf"
      {"rlc", "image/vnd.fujixerox.edmics-rlc"},
      {"",nullptr},
#line 895 "auto/extension_to_mime_type.gperf"
      {"weba", "audio/webm"},
#line 522 "auto/extension_to_mime_type.gperf"
      {"nml", "application/vnd.enliven"},
#line 772 "auto/extension_to_mime_type.gperf"
      {"sv4cpio", "application/x-sv4cpio"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 45 "auto/extension_to_mime_type.gperf"
      {"apk", "application/vnd.android.package-archive"},
#line 473 "auto/extension_to_mime_type.gperf"
      {"mp3", "audio/mpeg"},
      {"",nullptr},
#line 390 "auto/extension_to_mime_type.gperf"
      {"ktr", "application/vnd.kahootz"},
      {"",nullptr}, {"",nullptr},
#line 667 "auto/extension_to_mime_type.gperf"
      {"rld", "application/resource-lists-diff+xml"},
#line 359 "auto/extension_to_mime_type.gperf"
      {"ivu", "application/vnd.immervision-ivu"},
      {"",nullptr},
#line 468 "auto/extension_to_mime_type.gperf"
      {"mov", "video/quicktime"},
#line 912 "auto/extension_to_mime_type.gperf"
      {"woff", "application/font-woff"},
#line 918 "auto/extension_to_mime_type.gperf"
      {"wrl", "model/vrml"},
#line 49 "auto/extension_to_mime_type.gperf"
      {"arc", "application/x-freearc"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 757 "auto/extension_to_mime_type.gperf"
      {"sse", "application/vnd.kodak-descriptor"},
      {"",nullptr},
#line 764 "auto/extension_to_mime_type.gperf"
      {"sti", "application/vnd.sun.xml.impress.template"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 464 "auto/extension_to_mime_type.gperf"
      {"mng", "video/x-mng"},
      {"",nullptr}, {"",nullptr},
#line 991 "auto/extension_to_mime_type.gperf"
      {"z7", "application/x-zmachine"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 611 "auto/extension_to_mime_type.gperf"
      {"png", "image/png"},
#line 551 "auto/extension_to_mime_type.gperf"
      {"omdoc", "application/omdoc+xml"},
      {"",nullptr},
#line 860 "auto/extension_to_mime_type.gperf"
      {"uvvu", "video/vnd.uvvu.mp4"},
#line 877 "auto/extension_to_mime_type.gperf"
      {"vrml", "model/vrml"},
#line 61 "auto/extension_to_mime_type.gperf"
      {"avi", "video/x-msvideo"},
#line 86 "auto/extension_to_mime_type.gperf"
      {"c11amz", "application/vnd.cluetrust.cartomobile-config-pkg"},
      {"",nullptr},
#line 272 "auto/extension_to_mime_type.gperf"
      {"fti", "application/vnd.anser-web-funds-transfer-initiation"},
#line 173 "auto/extension_to_mime_type.gperf"
      {"dfac", "application/vnd.dreamfactory"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 826 "auto/extension_to_mime_type.gperf"
      {"ufd", "application/vnd.ufdl"},
      {"",nullptr}, {"",nullptr},
#line 289 "auto/extension_to_mime_type.gperf"
      {"ghf", "application/vnd.groove-help"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 513 "auto/extension_to_mime_type.gperf"
      {"n3", "text/n3"},
#line 47 "auto/extension_to_mime_type.gperf"
      {"application", "application/x-ms-application"},
      {"",nullptr},
#line 338 "auto/extension_to_mime_type.gperf"
      {"ifm", "application/vnd.shana.informed.formdata"},
#line 119 "auto/extension_to_mime_type.gperf"
      {"chat", "application/x-chat"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 495 "auto/extension_to_mime_type.gperf"
      {"mseed", "application/vnd.fdsn.mseed"},
      {"",nullptr}, {"",nullptr},
#line 665 "auto/extension_to_mime_type.gperf"
      {"rl", "application/resource-lists+xml"},
#line 186 "auto/extension_to_mime_type.gperf"
      {"dna", "application/vnd.dna"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 843 "auto/extension_to_mime_type.gperf"
      {"uvi", "image/vnd.dece.graphic"},
      {"",nullptr}, {"",nullptr},
#line 354 "auto/extension_to_mime_type.gperf"
      {"irm", "application/vnd.ibm.rights-management"},
#line 675 "auto/extension_to_mime_type.gperf"
      {"roff", "text/troff"},
#line 211 "auto/extension_to_mime_type.gperf"
      {"ecelp7470", "audio/vnd.nuera.ecelp7470"},
#line 212 "auto/extension_to_mime_type.gperf"
      {"ecelp9600", "audio/vnd.nuera.ecelp9600"},
      {"",nullptr}, {"",nullptr},
#line 321 "auto/extension_to_mime_type.gperf"
      {"hpid", "application/vnd.hp-hpid"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 448 "auto/extension_to_mime_type.gperf"
      {"mgz", "application/vnd.proteus.magazine"},
      {"",nullptr},
#line 993 "auto/extension_to_mime_type.gperf"
      {"zaz", "application/vnd.zzazz.deck+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 355 "auto/extension_to_mime_type.gperf"
      {"irp", "application/vnd.irepository.package+xml"},
      {"",nullptr}, {"",nullptr},
#line 305 "auto/extension_to_mime_type.gperf"
      {"gtar", "application/x-gtar"},
#line 56 "auto/extension_to_mime_type.gperf"
      {"atom", "application/atom+xml"},
      {"",nullptr},
#line 353 "auto/extension_to_mime_type.gperf"
      {"ipk", "application/vnd.shana.informed.package"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 92 "auto/extension_to_mime_type.gperf"
      {"cab", "application/vnd.ms-cab-compressed"},
#line 334 "auto/extension_to_mime_type.gperf"
      {"ico", "image/x-icon"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 339 "auto/extension_to_mime_type.gperf"
      {"iges", "model/iges"},
#line 182 "auto/extension_to_mime_type.gperf"
      {"dll", "application/x-msdownload"},
#line 302 "auto/extension_to_mime_type.gperf"
      {"grv", "application/vnd.groove-injector"},
#line 210 "auto/extension_to_mime_type.gperf"
      {"ecelp4800", "audio/vnd.nuera.ecelp4800"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 169 "auto/extension_to_mime_type.gperf"
      {"deb", "application/x-debian-package"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 221 "auto/extension_to_mime_type.gperf"
      {"emma", "application/emma+xml"},
#line 53 "auto/extension_to_mime_type.gperf"
      {"aso", "application/vnd.accpac.simply.aso"},
      {"",nullptr},
#line 303 "auto/extension_to_mime_type.gperf"
      {"grxml", "application/srgs+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 372 "auto/extension_to_mime_type.gperf"
      {"jpgv", "video/jpeg"},
      {"",nullptr},
#line 529 "auto/extension_to_mime_type.gperf"
      {"ntf", "application/vnd.nitf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 950 "auto/extension_to_mime_type.gperf"
      {"xlam", "application/vnd.ms-excel.addin.macroenabled.12"},
#line 723 "auto/extension_to_mime_type.gperf"
      {"silo", "model/mesh"},
      {"",nullptr}, {"",nullptr},
#line 330 "auto/extension_to_mime_type.gperf"
      {"i2g", "application/vnd.intergeo"},
      {"",nullptr},
#line 266 "auto/extension_to_mime_type.gperf"
      {"for", "text/x-fortran"},
      {"",nullptr},
#line 350 "auto/extension_to_mime_type.gperf"
      {"install", "application/x-install-instructions"},
#line 438 "auto/extension_to_mime_type.gperf"
      {"mdb", "application/x-msaccess"},
      {"",nullptr},
#line 126 "auto/extension_to_mime_type.gperf"
      {"class", "application/java-vm"},
#line 325 "auto/extension_to_mime_type.gperf"
      {"htm", "text/html"},
      {"",nullptr},
#line 925 "auto/extension_to_mime_type.gperf"
      {"x3db", "model/x3d+binary"},
      {"",nullptr}, {"",nullptr},
#line 834 "auto/extension_to_mime_type.gperf"
      {"urls", "text/uri-list"},
      {"",nullptr},
#line 592 "auto/extension_to_mime_type.gperf"
      {"pdb", "application/vnd.palm"},
      {"",nullptr}, {"",nullptr},
#line 855 "auto/extension_to_mime_type.gperf"
      {"uvvi", "image/vnd.dece.graphic"},
#line 828 "auto/extension_to_mime_type.gperf"
      {"ulx", "application/x-glulx"},
      {"",nullptr}, {"",nullptr},
#line 407 "auto/extension_to_mime_type.gperf"
      {"lostxml", "application/lost+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 548 "auto/extension_to_mime_type.gperf"
      {"ogg", "audio/ogg"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 320 "auto/extension_to_mime_type.gperf"
      {"hpgl", "application/vnd.hp-hpgl"},
#line 451 "auto/extension_to_mime_type.gperf"
      {"mie", "application/x-mie"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 232 "auto/extension_to_mime_type.gperf"
      {"eva", "application/x-eva"},
      {"",nullptr},
#line 257 "auto/extension_to_mime_type.gperf"
      {"flac", "audio/x-flac"},
#line 547 "auto/extension_to_mime_type.gperf"
      {"oga", "audio/ogg"},
      {"",nullptr}, {"",nullptr},
#line 30 "auto/extension_to_mime_type.gperf"
      {"ace", "application/x-ace-compressed"},
#line 314 "auto/extension_to_mime_type.gperf"
      {"h264", "video/h264"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 875 "auto/extension_to_mime_type.gperf"
      {"vor", "application/vnd.stardivision.writer"},
      {"",nullptr},
#line 453 "auto/extension_to_mime_type.gperf"
      {"mime", "message/rfc822"},
      {"",nullptr},
#line 510 "auto/extension_to_mime_type.gperf"
      {"mxs", "application/vnd.triscape.mxs"},
#line 785 "auto/extension_to_mime_type.gperf"
      {"sxm", "application/vnd.sun.xml.math"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 58 "auto/extension_to_mime_type.gperf"
      {"atomsvc", "application/atomsvc+xml"},
#line 363 "auto/extension_to_mime_type.gperf"
      {"java", "text/x-java-source"},
      {"",nullptr},
#line 823 "auto/extension_to_mime_type.gperf"
      {"txt", "text/plain"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 893 "auto/extension_to_mime_type.gperf"
      {"wdb", "application/vnd.ms-works"},
      {"",nullptr}, {"",nullptr},
#line 356 "auto/extension_to_mime_type.gperf"
      {"iso", "application/x-iso9660-image"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 201 "auto/extension_to_mime_type.gperf"
      {"dtshd", "audio/vnd.dts.hd"},
      {"",nullptr},
#line 141 "auto/extension_to_mime_type.gperf"
      {"cpio", "application/x-cpio"},
      {"",nullptr},
#line 157 "auto/extension_to_mime_type.gperf"
      {"cxt", "application/x-director"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 642 "auto/extension_to_mime_type.gperf"
      {"qbo", "application/vnd.intu.qbo"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 158 "auto/extension_to_mime_type.gperf"
      {"cxx", "text/x-c"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 781 "auto/extension_to_mime_type.gperf"
      {"sxc", "application/vnd.sun.xml.calc"},
#line 765 "auto/extension_to_mime_type.gperf"
      {"stk", "application/hyperstudio"},
      {"",nullptr}, {"",nullptr},
#line 274 "auto/extension_to_mime_type.gperf"
      {"fxp", "application/vnd.adobe.fxp"},
#line 507 "auto/extension_to_mime_type.gperf"
      {"mxf", "application/mxf"},
      {"",nullptr},
#line 822 "auto/extension_to_mime_type.gperf"
      {"txf", "application/vnd.mobius.txf"},
      {"",nullptr}, {"",nullptr},
#line 208 "auto/extension_to_mime_type.gperf"
      {"dxp", "application/vnd.spotfire.dxp"},
      {"",nullptr}, {"",nullptr},
#line 370 "auto/extension_to_mime_type.gperf"
      {"jpg", "image/jpeg"},
      {"",nullptr}, {"",nullptr},
#line 782 "auto/extension_to_mime_type.gperf"
      {"sxd", "application/vnd.sun.xml.draw"},
#line 294 "auto/extension_to_mime_type.gperf"
      {"gnumeric", "application/x-gnumeric"},
#line 519 "auto/extension_to_mime_type.gperf"
      {"ngdat", "application/vnd.nokia.n-gage.data"},
#line 821 "auto/extension_to_mime_type.gperf"
      {"txd", "application/vnd.genomatix.tuxedo"},
      {"",nullptr}, {"",nullptr},
#line 594 "auto/extension_to_mime_type.gperf"
      {"pfa", "application/x-font-type1"},
      {"",nullptr}, {"",nullptr},
#line 429 "auto/extension_to_mime_type.gperf"
      {"man", "text/troff"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 812 "auto/extension_to_mime_type.gperf"
      {"tra", "application/vnd.trueapp"},
#line 207 "auto/extension_to_mime_type.gperf"
      {"dxf", "image/vnd.dxf"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 299 "auto/extension_to_mime_type.gperf"
      {"gram", "application/srgs"},
      {"",nullptr}, {"",nullptr},
#line 631 "auto/extension_to_mime_type.gperf"
      {"psb", "application/vnd.3gpp.pic-bw-small"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 398 "auto/extension_to_mime_type.gperf"
      {"lbe", "application/vnd.llamagraphics.life-balance.exchange+xml"},
      {"",nullptr},
#line 777 "auto/extension_to_mime_type.gperf"
      {"svgz", "image/svg+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 332 "auto/extension_to_mime_type.gperf"
      {"ice", "x-conference/x-cooltalk"},
#line 195 "auto/extension_to_mime_type.gperf"
      {"dra", "audio/vnd.dra"},
      {"",nullptr},
#line 300 "auto/extension_to_mime_type.gperf"
      {"gramps", "application/x-gramps-xml"},
      {"",nullptr}, {"",nullptr},
#line 718 "auto/extension_to_mime_type.gperf"
      {"shar", "application/x-shar"},
#line 827 "auto/extension_to_mime_type.gperf"
      {"ufdl", "application/vnd.ufdl"},
#line 312 "auto/extension_to_mime_type.gperf"
      {"h261", "video/h261"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 524 "auto/extension_to_mime_type.gperf"
      {"nns", "application/vnd.noblenet-sealer"},
      {"",nullptr}, {"",nullptr},
#line 865 "auto/extension_to_mime_type.gperf"
      {"uvz", "application/vnd.dece.zip"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 754 "auto/extension_to_mime_type.gperf"
      {"sru", "application/sru+xml"},
      {"",nullptr},
#line 786 "auto/extension_to_mime_type.gperf"
      {"sxw", "application/vnd.sun.xml.writer"},
#line 311 "auto/extension_to_mime_type.gperf"
      {"h", "text/x-c"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 564 "auto/extension_to_mime_type.gperf"
      {"otg", "application/vnd.oasis.opendocument.graphics-template"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 67 "auto/extension_to_mime_type.gperf"
      {"bcpio", "application/x-bcpio"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 523 "auto/extension_to_mime_type.gperf"
      {"nnd", "application/vnd.noblenet-directory"},
#line 129 "auto/extension_to_mime_type.gperf"
      {"clkt", "application/vnd.crick.clicker.template"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 131 "auto/extension_to_mime_type.gperf"
      {"clkx", "application/vnd.crick.clicker"},
      {"",nullptr},
#line 23 "auto/extension_to_mime_type.gperf"
      {"aab", "application/x-authorware-bin"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 128 "auto/extension_to_mime_type.gperf"
      {"clkp", "application/vnd.crick.clicker.palette"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 743 "auto/extension_to_mime_type.gperf"
      {"so", "application/octet-stream"},
      {"",nullptr}, {"",nullptr},
#line 532 "auto/extension_to_mime_type.gperf"
      {"oa3", "application/vnd.fujitsu.oasys3"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 964 "auto/extension_to_mime_type.gperf"
      {"xo", "application/vnd.olpc-sugar"},
      {"",nullptr}, {"",nullptr},
#line 441 "auto/extension_to_mime_type.gperf"
      {"mesh", "model/mesh"},
#line 382 "auto/extension_to_mime_type.gperf"
      {"kmz", "application/vnd.google-earth.kmz"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 863 "auto/extension_to_mime_type.gperf"
      {"uvvz", "application/vnd.dece.zip"},
      {"",nullptr}, {"",nullptr},
#line 769 "auto/extension_to_mime_type.gperf"
      {"sub", "image/vnd.dvb.subtitle"},
      {"",nullptr}, {"",nullptr},
#line 57 "auto/extension_to_mime_type.gperf"
      {"atomcat", "application/atomcat+xml"},
      {"",nullptr}, {"",nullptr},
#line 949 "auto/extension_to_mime_type.gperf"
      {"xla", "application/vnd.ms-excel"},
      {"",nullptr}, {"",nullptr},
#line 833 "auto/extension_to_mime_type.gperf"
      {"uris", "text/uri-list"},
#line 486 "auto/extension_to_mime_type.gperf"
      {"mpn", "application/vnd.mophun.application"},
#line 636 "auto/extension_to_mime_type.gperf"
      {"pub", "application/x-mspublisher"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 75 "auto/extension_to_mime_type.gperf"
      {"bmi", "application/vnd.bmi"},
      {"",nullptr},
#line 125 "auto/extension_to_mime_type.gperf"
      {"cla", "application/vnd.claymore"},
#line 401 "auto/extension_to_mime_type.gperf"
      {"link66", "application/vnd.route66.link66+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 326 "auto/extension_to_mime_type.gperf"
      {"html", "text/html"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 400 "auto/extension_to_mime_type.gperf"
      {"lha", "application/x-lzh-compressed"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 525 "auto/extension_to_mime_type.gperf"
      {"nnw", "application/vnd.noblenet-web"},
      {"",nullptr}, {"",nullptr},
#line 801 "auto/extension_to_mime_type.gperf"
      {"tfi", "application/thraud+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 81 "auto/extension_to_mime_type.gperf"
      {"btif", "image/prs.btif"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 508 "auto/extension_to_mime_type.gperf"
      {"mxl", "application/vnd.recordare.musicxml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 831 "auto/extension_to_mime_type.gperf"
      {"uoml", "application/vnd.uoml+xml"},
      {"",nullptr},
#line 651 "auto/extension_to_mime_type.gperf"
      {"qxt", "application/vnd.quark.quarkxpress"},
      {"",nullptr}, {"",nullptr},
#line 80 "auto/extension_to_mime_type.gperf"
      {"bpk", "application/octet-stream"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 514 "auto/extension_to_mime_type.gperf"
      {"nb", "application/mathematica"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 509 "auto/extension_to_mime_type.gperf"
      {"mxml", "application/xv+xml"},
      {"",nullptr}, {"",nullptr},
#line 605 "auto/extension_to_mime_type.gperf"
      {"pkipath", "application/pkix-pkipath"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 310 "auto/extension_to_mime_type.gperf"
      {"gxt", "application/vnd.geonext"},
      {"",nullptr},
#line 209 "auto/extension_to_mime_type.gperf"
      {"dxr", "application/x-director"},
      {"",nullptr},
#line 130 "auto/extension_to_mime_type.gperf"
      {"clkw", "application/vnd.crick.clicker.wordbank"},
      {"",nullptr}, {"",nullptr},
#line 505 "auto/extension_to_mime_type.gperf"
      {"mvb", "application/x-msmediaview"},
#line 349 "auto/extension_to_mime_type.gperf"
      {"inkml", "application/inkml+xml"},
#line 218 "auto/extension_to_mime_type.gperf"
      {"elc", "application/octet-stream"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 637 "auto/extension_to_mime_type.gperf"
      {"pvb", "application/vnd.3gpp.pic-bw-var"},
#line 224 "auto/extension_to_mime_type.gperf"
      {"eot", "application/vnd.ms-fontobject"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 275 "auto/extension_to_mime_type.gperf"
      {"fxpl", "application/vnd.adobe.fxp"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 649 "auto/extension_to_mime_type.gperf"
      {"qxd", "application/vnd.quark.quarkxpress"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 203 "auto/extension_to_mime_type.gperf"
      {"dvb", "video/vnd.dvb.file"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 309 "auto/extension_to_mime_type.gperf"
      {"gxf", "application/gxf"},
      {"",nullptr}, {"",nullptr},
#line 917 "auto/extension_to_mime_type.gperf"
      {"wri", "application/x-mswrite"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 222 "auto/extension_to_mime_type.gperf"
      {"emz", "application/x-msmetafile"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 239 "auto/extension_to_mime_type.gperf"
      {"ez3", "application/vnd.ezpix-package"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 884 "auto/extension_to_mime_type.gperf"
      {"vxml", "application/voicexml+xml"},
      {"",nullptr}, {"",nullptr},
#line 406 "auto/extension_to_mime_type.gperf"
      {"log", "text/plain"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 498 "auto/extension_to_mime_type.gperf"
      {"msh", "model/mesh"},
      {"",nullptr},
#line 566 "auto/extension_to_mime_type.gperf"
      {"oti", "application/vnd.oasis.opendocument.image-template"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 413 "auto/extension_to_mime_type.gperf"
      {"lzh", "application/x-lzh-compressed"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 17 "auto/extension_to_mime_type.gperf"
      {"123", "application/vnd.lotus-1-2-3"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 674 "auto/extension_to_mime_type.gperf"
      {"roa", "application/rpki-roa"},
      {"",nullptr},
#line 148 "auto/extension_to_mime_type.gperf"
      {"csh", "application/x-csh"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 996 "auto/extension_to_mime_type.gperf"
      {"zirz", "application/vnd.zul"},
      {"",nullptr},
#line 836 "auto/extension_to_mime_type.gperf"
      {"utz", "application/vnd.uiq.theme"},
#line 405 "auto/extension_to_mime_type.gperf"
      {"lnk", "application/x-ms-shortcut"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 316 "auto/extension_to_mime_type.gperf"
      {"hbci", "application/vnd.hbci"},
#line 366 "auto/extension_to_mime_type.gperf"
      {"jnlp", "application/x-java-jnlp-file"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 717 "auto/extension_to_mime_type.gperf"
      {"sh", "application/x-sh"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 258 "auto/extension_to_mime_type.gperf"
      {"fli", "video/x-fli"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 672 "auto/extension_to_mime_type.gperf"
      {"rmvb", "application/vnd.rn-realmedia-vbr"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 251 "auto/extension_to_mime_type.gperf"
      {"fh", "image/x-freehand"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 78 "auto/extension_to_mime_type.gperf"
      {"box", "application/vnd.previewsystems.box"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 268 "auto/extension_to_mime_type.gperf"
      {"frame", "application/vnd.framemaker"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 227 "auto/extension_to_mime_type.gperf"
      {"es3", "application/vnd.eszigno3+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 347 "auto/extension_to_mime_type.gperf"
      {"in", "text/plain"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 537 "auto/extension_to_mime_type.gperf"
      {"odb", "application/vnd.oasis.opendocument.database"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 71 "auto/extension_to_mime_type.gperf"
      {"bh2", "application/vnd.fujitsu.oasysprs"},
      {"",nullptr},
#line 553 "auto/extension_to_mime_type.gperf"
      {"onetmp", "application/onenote"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 554 "auto/extension_to_mime_type.gperf"
      {"onetoc", "application/onenote"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 661 "auto/extension_to_mime_type.gperf"
      {"rgb", "image/x-rgb"},
      {"",nullptr}, {"",nullptr},
#line 650 "auto/extension_to_mime_type.gperf"
      {"qxl", "application/vnd.quark.quarkxpress"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 571 "auto/extension_to_mime_type.gperf"
      {"oxt", "application/vnd.openofficeorg.extension"},
#line 319 "auto/extension_to_mime_type.gperf"
      {"hlp", "application/winhlp"},
#line 216 "auto/extension_to_mime_type.gperf"
      {"efif", "application/vnd.picsel"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 392 "auto/extension_to_mime_type.gperf"
      {"ktz", "application/vnd.kahootz"},
#line 223 "auto/extension_to_mime_type.gperf"
      {"eol", "audio/vnd.digital-winds"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 783 "auto/extension_to_mime_type.gperf"
      {"sxg", "application/vnd.sun.xml.writer.global"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 570 "auto/extension_to_mime_type.gperf"
      {"oxps", "application/oxps"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 600 "auto/extension_to_mime_type.gperf"
      {"pgn", "application/x-chess-pgn"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 832 "auto/extension_to_mime_type.gperf"
      {"uri", "text/uri-list"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 559 "auto/extension_to_mime_type.gperf"
      {"org", "application/vnd.lotus-organizer"},
      {"",nullptr}, {"",nullptr},
#line 140 "auto/extension_to_mime_type.gperf"
      {"conf", "text/plain"},
#line 198 "auto/extension_to_mime_type.gperf"
      {"dtb", "application/x-dtbook+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 555 "auto/extension_to_mime_type.gperf"
      {"onetoc2", "application/onenote"},
#line 365 "auto/extension_to_mime_type.gperf"
      {"jlt", "application/vnd.hp-jlyt"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 295 "auto/extension_to_mime_type.gperf"
      {"gph", "application/vnd.flographit"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 613 "auto/extension_to_mime_type.gperf"
      {"portpkg", "application/vnd.macports.portpkg"},
      {"",nullptr}, {"",nullptr},
#line 490 "auto/extension_to_mime_type.gperf"
      {"mqy", "application/vnd.mobius.mqy"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 921 "auto/extension_to_mime_type.gperf"
      {"wtb", "application/vnd.webturbo"},
      {"",nullptr},
#line 708 "auto/extension_to_mime_type.gperf"
      {"setpay", "application/set-payment-initiation"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 236 "auto/extension_to_mime_type.gperf"
      {"ext", "application/vnd.novadigm.ext"},
#line 348 "auto/extension_to_mime_type.gperf"
      {"ink", "application/inkml+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 511 "auto/extension_to_mime_type.gperf"
      {"mxu", "video/vnd.mpegurl"},
      {"",nullptr},
#line 351 "auto/extension_to_mime_type.gperf"
      {"iota", "application/vnd.astraea-software.iota"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 115 "auto/extension_to_mime_type.gperf"
      {"cdy", "application/vnd.cinderella"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 287 "auto/extension_to_mime_type.gperf"
      {"ggb", "application/vnd.geogebra.file"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 920 "auto/extension_to_mime_type.gperf"
      {"wspolicy", "application/wspolicy+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 369 "auto/extension_to_mime_type.gperf"
      {"jpeg", "image/jpeg"},
      {"",nullptr},
#line 107 "auto/extension_to_mime_type.gperf"
      {"cdkey", "application/vnd.mediastation.cdkey"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 638 "auto/extension_to_mime_type.gperf"
      {"pwn", "application/vnd.3m.post-it-notes"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 259 "auto/extension_to_mime_type.gperf"
      {"flo", "application/vnd.micrografx.flo"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 489 "auto/extension_to_mime_type.gperf"
      {"mpy", "application/vnd.ibm.minipay"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 368 "auto/extension_to_mime_type.gperf"
      {"jpe", "image/jpeg"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 628 "auto/extension_to_mime_type.gperf"
      {"pre", "application/vnd.lotus-freelance"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 784 "auto/extension_to_mime_type.gperf"
      {"sxi", "application/vnd.sun.xml.impress"},
      {"",nullptr}, {"",nullptr},
#line 469 "auto/extension_to_mime_type.gperf"
      {"movie", "video/x-sgi-movie"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 501 "auto/extension_to_mime_type.gperf"
      {"msty", "application/vnd.muvee.style"},
      {"",nullptr},
#line 37 "auto/extension_to_mime_type.gperf"
      {"ahead", "application/vnd.ahead.space"},
#line 171 "auto/extension_to_mime_type.gperf"
      {"deploy", "application/octet-stream"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 530 "auto/extension_to_mime_type.gperf"
      {"nzb", "application/x-nzb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 808 "auto/extension_to_mime_type.gperf"
      {"torrent", "application/x-bittorrent"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 830 "auto/extension_to_mime_type.gperf"
      {"unityweb", "application/vnd.unity"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 575 "auto/extension_to_mime_type.gperf"
      {"p7b", "application/x-pkcs7-certificates"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 983 "auto/extension_to_mime_type.gperf"
      {"yang", "application/yang"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 842 "auto/extension_to_mime_type.gperf"
      {"uvh", "video/vnd.dece.hd"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 825 "auto/extension_to_mime_type.gperf"
      {"udeb", "application/x-debian-package"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 829 "auto/extension_to_mime_type.gperf"
      {"umj", "application/vnd.umajin"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 230 "auto/extension_to_mime_type.gperf"
      {"et3", "application/vnd.eszigno3+xml"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 854 "auto/extension_to_mime_type.gperf"
      {"uvvh", "video/vnd.dece.hd"},
      {"",nullptr},
#line 595 "auto/extension_to_mime_type.gperf"
      {"pfb", "application/x-font-type1"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 226 "auto/extension_to_mime_type.gperf"
      {"epub", "application/epub+zip"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 383 "auto/extension_to_mime_type.gperf"
      {"kne", "application/vnd.kinar"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 301 "auto/extension_to_mime_type.gperf"
      {"gre", "application/vnd.geometry-explorer"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 552 "auto/extension_to_mime_type.gperf"
      {"onepkg", "application/onenote"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 379 "auto/extension_to_mime_type.gperf"
      {"kfo", "application/vnd.kde.kformula"},
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
#line 512 "auto/extension_to_mime_type.gperf"
      {"n-gage", "application/vnd.nokia.n-gage.symbian.install"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 521 "auto/extension_to_mime_type.gperf"
      {"nlu", "application/vnd.neurolanguage.nlu"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 127 "auto/extension_to_mime_type.gperf"
      {"clkk", "application/vnd.crick.clicker.keyboard"},
      {"",nullptr},
#line 606 "auto/extension_to_mime_type.gperf"
      {"plb", "application/vnd.3gpp.pic-bw-large"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 72 "auto/extension_to_mime_type.gperf"
      {"bin", "application/octet-stream"},
#line 955 "auto/extension_to_mime_type.gperf"
      {"xlsb", "application/vnd.ms-excel.sheet.binary.macroenabled.12"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 535 "auto/extension_to_mime_type.gperf"
      {"obj", "application/x-tgif"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 313 "auto/extension_to_mime_type.gperf"
      {"h263", "video/h263"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 376 "auto/extension_to_mime_type.gperf"
      {"jsonml", "application/jsonml+json"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 466 "auto/extension_to_mime_type.gperf"
      {"mobi", "application/x-mobipocket-ebook"},
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
#line 874 "auto/extension_to_mime_type.gperf"
      {"vob", "video/x-ms-vob"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 367 "auto/extension_to_mime_type.gperf"
      {"joda", "application/vnd.joost.joda-archive"},
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
#line 318 "auto/extension_to_mime_type.gperf"
      {"hh", "text/x-c"},
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
#line 337 "auto/extension_to_mime_type.gperf"
      {"ifb", "text/calendar"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 565 "auto/extension_to_mime_type.gperf"
      {"oth", "application/vnd.oasis.opendocument.text-web"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 518 "auto/extension_to_mime_type.gperf"
      {"nfo", "text/x-nfo"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 235 "auto/extension_to_mime_type.gperf"
      {"exi", "application/exi"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 79 "auto/extension_to_mime_type.gperf"
      {"boz", "application/x-bzip2"},
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
#line 465 "auto/extension_to_mime_type.gperf"
      {"mny", "application/x-msmoney"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 378 "auto/extension_to_mime_type.gperf"
      {"karbon", "application/vnd.kde.karbon"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr},
#line 984 "auto/extension_to_mime_type.gperf"
      {"yin", "application/yin+xml"},
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
#line 233 "auto/extension_to_mime_type.gperf"
      {"evy", "application/x-envoy"},
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
      {"",nullptr}, {"",nullptr},
#line 324 "auto/extension_to_mime_type.gperf"
      {"htke", "application/vnd.kenameaapp"},
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
#line 375 "auto/extension_to_mime_type.gperf"
      {"json", "application/json"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr},
#line 648 "auto/extension_to_mime_type.gperf"
      {"qxb", "application/vnd.quark.quarkxpress"},
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
      {"",nullptr}, {"",nullptr},
#line 74 "auto/extension_to_mime_type.gperf"
      {"blorb", "application/x-blorb"},
      {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 147 "auto/extension_to_mime_type.gperf"
      {"cryptonote", "application/vnd.rig.cryptonote"},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
      {"",nullptr}, {"",nullptr}, {"",nullptr}, {"",nullptr},
#line 385 "auto/extension_to_mime_type.gperf"
      {"kon", "application/vnd.kde.kontour"},
#line 263 "auto/extension_to_mime_type.gperf"
      {"fly", "text/vnd.fly"},
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
      {"",nullptr}, {"",nullptr},
#line 73 "auto/extension_to_mime_type.gperf"
      {"blb", "application/x-blorb"},
      {"",nullptr},
#line 234 "auto/extension_to_mime_type.gperf"
      {"exe", "application/x-msdownload"},
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
#line 77 "auto/extension_to_mime_type.gperf"
      {"book", "application/vnd.framemaker"}
    };

  if (len <= MAX_WORD_LENGTH && len >= MIN_WORD_LENGTH)
    {
      unsigned int key = extension_hash (str, len);

      if (key <= MAX_HASH_VALUE)
        {
          register const char *s = wordlist[key].extension;

          if ((((unsigned char)*str ^ (unsigned char)*s) & ~32) == 0 && !gperf_case_strcmp (str, s))
            return &wordlist[key];
        }
    }
  return 0;
}
#line 998 "auto/extension_to_mime_type.gperf"

const char *extension_to_mime_type(const char *extension, size_t extension_len) {
  const auto &result = search_extension(extension, extension_len);
  if (result == nullptr) {
    return nullptr;
  }

  return result->mime_type;
}
