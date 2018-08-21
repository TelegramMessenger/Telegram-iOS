#ifndef _LOT_COMMON_H_
#define _LOT_COMMON_H_

#ifdef _WIN32
#ifdef LOT_BUILD
#ifdef DLL_EXPORT
#define LOT_EXPORT __declspec(dllexport)
#else
#define LOT_EXPORT
#endif
#else
#define LOT_EXPORT __declspec(dllimport)
#endif
#else
#ifdef __GNUC__
#if __GNUC__ >= 4
#define LOT_EXPORT __attribute__((visibility("default")))
#else
#define LOT_EXPORT
#endif
#else
#define LOT_EXPORT
#endif
#endif


/**
 * @brief Enumeration for Lottie Player error code.
 */
typedef enum
{
   //TODO: Coding convention??
    LOT_PLAYER_ERROR_NONE = 0,
    LOT_PLAYER_ERROR_NOT_PERMITTED,
    LOT_PLAYER_ERROR_OUT_OF_MEMORY,
    LOT_PLAYER_ERROR_INVALID_PARAMETER,
    LOT_PLAYER_ERROR_RESULT_OUT_OF_RANGE,
    LOT_PLAYER_ERROR_ALREADY_IN_PROGRESS,
    LOT_PLAYER_ERROR_UNKNOWN
} LOTErrorType;

typedef enum
{
    BrushSolid = 0,
    BrushGradient
} LOTBrushType;

typedef enum
{
    FillEvenOdd = 0,
    FillWinding
} LOTFillRule;

typedef enum
{
    JoinMiter = 0,
    JoinBevel,
    JoinRound
} LOTJoinStyle;

typedef enum
{
    CapFlat = 0,
    CapSquare,
    CapRound
} LOTCapStyle;

typedef enum
{
    GradientLinear = 0,
    GradientRadial
} LOTGradientType;

typedef struct LOTNode {

#define ChangeFlagNone 0x0000
#define ChangeFlagPath 0x0001
#define ChangeFlagPaint 0x0010
#define ChangeFlagAll (ChangeFlagPath & ChangeFlagPaint)

    struct {
        const float *ptPtr;
        int          ptCount;
        const char*  elmPtr;
        int          elmCount;
    } mPath;

    struct {
        unsigned char r, g, b, a;
    } mColor;

    struct {
        bool      enable;
        int       width;
        LOTCapStyle  cap;
        LOTJoinStyle join;
        int       meterLimit;
        float*    dashArray;
        int       dashArraySize;
    } mStroke;

    struct {
        LOTGradientType type;
        struct {
            float x, y;
        } start, end, center, focal;
        float cradius;
        float fradius;
    } mGradient;

    int       mFlag;
    LOTBrushType mType;
    LOTFillRule  mFillRule;
} LOTNode;

typedef struct LOTBuffer {
    uint32_t *buffer;
    int       width;
    int       height;
    int       bytesPerLine;
    bool      clear;
} LOTBuffer;

#endif  // _LOT_COMMON_H_
