#ifndef DrawingAttributes_hpp
#define DrawingAttributes_hpp

namespace lottie {

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

}

#endif /* DrawingAttributes_hpp */
