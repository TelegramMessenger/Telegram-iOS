#ifndef HasRenderUpdates_hpp
#define HasRenderUpdates_hpp

namespace lottie {

class HasRenderUpdates {
public:
    virtual bool hasRenderUpdates(double forFrame) = 0;
};

}

#endif /* HasRenderUpdates_hpp */
