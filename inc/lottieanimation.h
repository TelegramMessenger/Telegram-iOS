#ifndef _LOTTIE_ANIMATION_H_
#define _LOTTIE_ANIMATION_H_

#include <future>
#include <vector>
#include <memory>

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

class AnimationImpl;
class LOTNode;

namespace lottie {

class LOT_EXPORT Surface {
public:
    Surface() = default;
    Surface(uint32_t *buffer, size_t width, size_t height, size_t bytesPerLine);
    size_t width() const {return mWidth;}
    size_t height() const {return mHeight;}
    size_t  bytesPerLine() const {return mBytesPerLine;}
    uint32_t *buffer() const {return mBuffer;}

private:
    uint32_t    *mBuffer;
    size_t       mWidth;
    size_t       mHeight;
    size_t       mBytesPerLine;
};

class LOT_EXPORT Animation {
public:

    static std::unique_ptr<Animation>
    loadFromFile(const std::string &path);

    static std::unique_ptr<Animation>
    loadFromData(const char *jsonData, const char *key);

    double frameRate() const;
    size_t totalFrame() const;
    void   size(size_t &width, size_t &height) const;
    double duration() const;
    size_t frameAtPos(double pos);

    std::future<Surface> render(size_t frameNo, Surface surface);
    void              renderSync(size_t frameNo, Surface surface);

    ~Animation();
    Animation();

    const std::vector<LOTNode *> &renderList(size_t frameNo, size_t width, size_t height) const;
private:
    std::unique_ptr<AnimationImpl> d;
};
}  // namespace lotplayer

#endif  // _LOTTIE_ANIMATION_H_
