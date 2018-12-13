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
struct LOTNode;
struct LOTLayerNode;

namespace lottie {

class LOT_EXPORT Surface {
public:
    /**
     *  @brief Surface object constructor.
     *
     *  @param[in] buffer surface buffer.
     *  @param[in] width  surface width.
     *  @param[in] height  surface height.
     *  @param[in] bytesPerLine  number of bytes in a surface scanline.
     *
     *  @note Default surface format is ARGB32_Premultiplied.
     *
     *  @internal
     */
    Surface(uint32_t *buffer, size_t width, size_t height, size_t bytesPerLine);

    /**
     *  @brief Returns width of the surface.
     *
     *  @return surface width
     *
     *  @internal
     *
     */
    size_t width() const {return mWidth;}

    /**
     *  @brief Returns height of the surface.
     *
     *  @return surface height
     *
     *  @internal
     */
    size_t height() const {return mHeight;}

    /**
     *  @brief Returns number of bytes in the surface scanline.
     *
     *  @return number of bytes in scanline.
     *
     *  @internal
     */
    size_t  bytesPerLine() const {return mBytesPerLine;}

    /**
     *  @brief Returns buffer attached tp the surface.
     *
     *  @return buffer attaced to the Surface.
     *
     *  @internal
     */
    uint32_t *buffer() const {return mBuffer;}

    /**
     *  @brief Default constructor.
     */
    Surface() = default;
private:
    uint32_t    *mBuffer;
    size_t       mWidth;
    size_t       mHeight;
    size_t       mBytesPerLine;
};

class LOT_EXPORT Animation {
public:

    /**
     *  @brief Constructs an animation object from filepath.
     *
     *  @param[in] path Lottie resource file path
     *
     *  @return Animation object that can render the contents of the
     *          lottie resource represented by file path.
     *
     *  @internal
     */
    static std::unique_ptr<Animation>
    loadFromFile(const std::string &path);

    /**
     *  @brief Constructs an animation object from json string data.
     *
     *  @param[in] jsonData The JSON string data.
     *  @param[in] key the string that will be used to cache the JSON string data.
     *
     *  @return Animation object that can render the contents of the
     *          lottie resource represented by JSON string data.
     *
     *  @internal
     */
    static std::unique_ptr<Animation>
    loadFromData(std::string jsonData, const std::string &key);

    /**
     *  @brief Returns default framerate of the lottie resource.
     *
     *  @return framerate of the lottie resource
     *
     *  @internal
     *
     */
    double frameRate() const;

    /**
     *  @brief Returns total number of frames present in the  lottie resource.
     *
     *  @return frame count of the lottie resource.
     *
     *  @note frame number starts with 0.
     *
     *  @internal
     */
    size_t totalFrame() const;

    /**
     *  @brief Returns default viewport size of the lottie resource.
     *
     *  @param[out] width  default width of the viewport.
     *  @param[out] height default height of the viewport.
     *
     *  @internal
     *
     */
    void   size(size_t &width, size_t &height) const;

    /**
     *  @brief Returns total animation duration of lottie resource in second.
     *         it uses totalFrame() and frameRate() to calcualte the duration.
     *         duration = totalFrame() / frameRate().
     *
     *  @return total animation duration in second.
     *  @retval 0 if the lottie resource has no animation.
     *
     *  @see totalFrame()
     *  @see frameRate()
     *
     *  @internal
     */
    double duration() const;

    /**
     *  @brief Returns frame number for a given position.
     *         this function helps to map the position value retuned
     *         by the animator to a frame number in side the lottie resource.
     *         frame_number = lerp(start_frame, endframe, pos);
     *
     *  @param[in] pos normalized position value [0 ... 1]
     *
     *  @return frame numer maps to the position value [startFrame .... endFrame]
     *
     *  @internal
     */
    size_t frameAtPos(double pos);

    /**
     *  @brief Renders the content to surface Asynchronously.
     *         it gives a future in return to get the result of the
     *         rendering at a future point.
     *         To get best performance user has to start rendering as soon as
     *         it finds that content at {frameNo} has to be rendered and get the
     *         result from the future at the last moment when the surface is needed
     *         to draw into the screen.
     *
     *
     *  @param[in] frameNo Content corresponds to the frameno needs to be drawn
     *  @param[in] surface Surface in which content will be drawn
     *
     *  @return future that will hold the result when rendering finished.
     *
     *  for Synchronus rendering @see renderSync
     *
     *  @see Surface
     *  @internal
     */
    std::future<Surface> render(size_t frameNo, Surface surface);

    /**
     *  @brief Renders the content to surface synchronously.
     *         for performance use the asyn rendering @see render
     *
     *  @param[in] frameNo Content corresponds to the frameno needs to be drawn
     *  @param[in] surface Surface in which content will be drawn
     *
     *  @internal
     */
    void              renderSync(size_t frameNo, Surface surface);

    /**
     *  @brief Returns root layer of the composition updated with
     *         content of the lottie resource at frame number {frameNo}.
     *
     *  @param[in] frameNo Content corresponds to the frameno needs to be extracted.
     *  @param[in] width   content viewbox width
     *  @param[in] height  content viewbox height
     *
     *  @return Root layer node.
     *
     *  @internal
     */
    const LOTLayerNode * renderTree(size_t frameNo, size_t width, size_t height) const;

    /**
     *  @brief default destructor
     *
     *  @internal
     */
    ~Animation();

private:
    /**
     *  @brief default constructor
     *
     *  @internal
     */
    Animation();

    std::unique_ptr<AnimationImpl> d;
};

}  // namespace lotplayer

#endif  // _LOTTIE_ANIMATION_H_
