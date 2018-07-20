#ifndef LOTPLAYER_H
#define LOTPLAYER_H

#include <vector>
#include <future>

#ifdef _WIN32
# ifdef LOT_BUILD
#  ifdef DLL_EXPORT
#   define LOT_EXPORT __declspec(dllexport)
#  else
#   define LOT_EXPORT
#  endif
# else
#  define LOT_EXPORT __declspec(dllimport)
# endif
#else
# ifdef __GNUC__
#  if __GNUC__ >= 4
#   define LOT_EXPORT __attribute__ ((visibility("default")))
#  else
#   define LOT_EXPORT
#  endif
# else
#  define LOT_EXPORT
# endif
#endif

class LOTPlayerPrivate;
class LOTNode;

struct LOT_EXPORT LOTBuffer
{
    uint32_t *buffer;
    int       width;
    int       height;
    int       bytesPerLine;
    bool      clear;
};

class LOT_EXPORT LOTPlayer
{
public:
    ~LOTPlayer();
    LOTPlayer();

    bool setFilePath(const char *filePath);

    float playTime() const;

    void setPos(float pos);
    float pos();

    const std::vector<LOTNode *>& renderList() const;

   //TODO: Consider correct position...
    void setSize(int width, int height);
    void size(int &width, int &height) const;
    std::future<bool> render(float pos, LOTBuffer &buffer);
    bool renderSync(float pos, LOTBuffer &buffer);

public:
    LOTPlayerPrivate         *d;
};

#define ChangeFlagNone  0x0000
#define ChangeFlagPath  0x0001
#define ChangeFlagPaint 0x0010
#define ChangeFlagAll   (ChangeFlagPath & ChangeFlagPaint)

class LOT_EXPORT LOTNode
{
public:
    struct PathData {
        const float *ptPtr;
        int          ptCount;
        const char  *elmPtr;
        int          elmCount;
    };
    struct Color {
        unsigned short r, g, b, a;
    };

    enum BrushType {
        BrushSolid,
        BrushGradient
    };
    enum FillRule {
        EvenOdd,
        Winding
    };

    enum JoinStyle {
        MiterJoin,
        BevelJoin,
        RoundJoin
    };

    enum CapStyle {
        FlatCap,
        SquareCap,
        RoundCap
    };

    struct Stroke {
        bool        enable;
        int         width;
        CapStyle    cap;
        JoinStyle   join;
        int         meterLimit;
        float      *dashArray;
        int         dashArraySize;
    };

    struct Gradient {
        enum Type {
            Linear = 1,
            Radial = 2
        };
        Gradient::Type type;
        struct {
            float x, y;
        } start, end;
        struct {
            float x, y;
        } center, focal;
        float cradius;
        float fradius;
    };

    ~LOTNode();
    LOTNode();

public:
    int                     mFlag;
    LOTNode::BrushType      mType;
    FillRule                mFillRule;
    PathData                mPath;
    Color                   mColor;
    Stroke                  mStroke;
    Gradient                mGradient;
};

#endif // LOTPLAYER_H
