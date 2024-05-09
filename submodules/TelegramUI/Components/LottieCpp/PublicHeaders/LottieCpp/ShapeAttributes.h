#ifndef ShapeAttributes_h
#define ShapeAttributes_h

#ifdef __cplusplus

namespace lottie {

enum class FillRule: int {
    None = 0,
    NonZeroWinding = 1,
    EvenOdd = 2
};

enum class LineCap: int {
    None = 0,
    Butt = 1,
    Round = 2,
    Square = 3
};

enum class LineJoin: int {
    None = 0,
    Miter = 1,
    Round = 2,
    Bevel = 3
};

enum class GradientType: int {
    None = 0,
    Linear = 1,
    Radial = 2
};

}

#endif

#endif /* LottieColor_h */
