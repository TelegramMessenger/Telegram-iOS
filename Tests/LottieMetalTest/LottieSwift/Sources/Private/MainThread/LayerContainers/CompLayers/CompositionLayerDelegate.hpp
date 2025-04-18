#ifndef CompositionLayerDelegate_hpp
#define CompositionLayerDelegate_hpp

namespace lottie {

class CompositionLayerDelegate {
public:
    virtual void frameUpdated(double frame) = 0;
};

}

#endif /* CompositionLayerDelegate_hpp */
