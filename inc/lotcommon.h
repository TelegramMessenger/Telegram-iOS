#ifndef _LOTCOMMON_H_
#define _LOTCOMMON_H_

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

struct LOTNode {

#define ChangeFlagNone 0x0000
#define ChangeFlagPath 0x0001
#define ChangeFlagPaint 0x0010
#define ChangeFlagAll (ChangeFlagPath & ChangeFlagPaint)

    enum BrushType { BrushSolid, BrushGradient };
    enum FillRule { EvenOdd, Winding };
    enum JoinStyle { MiterJoin, BevelJoin, RoundJoin };
    enum CapStyle { FlatCap, SquareCap, RoundCap };

    struct PathData {
        const float *ptPtr;
        int          ptCount;
        const char*  elmPtr;
        int          elmCount;
    };

    struct Color {
        unsigned char r, g, b, a;
    };

    struct Stroke {
        bool      enable;
        int       width;
        CapStyle  cap;
        JoinStyle join;
        int       meterLimit;
        float*    dashArray;
        int       dashArraySize;
    };

    struct Gradient {
        enum Type { Linear = 1, Radial = 2 };
        Gradient::Type type;
        struct {
            float x, y;
        } start, end, center, focal;
        float cradius;
        float fradius;
    };

    int       mFlag;
    BrushType mType;
    FillRule  mFillRule;
    PathData  mPath;
    Color     mColor;
    Stroke    mStroke;
    Gradient  mGradient;
};

struct LOTBuffer {
    uint32_t *buffer;
    int       width;
    int       height;
    int       bytesPerLine;
    bool      clear;
};

#endif  // _LOTCOMMON_H_
