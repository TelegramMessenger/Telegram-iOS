#ifndef HasUpdate_hpp
#define HasUpdate_hpp

namespace lottie {

class HasUpdate {
public:
    /// The last frame in which this node was updated.
    virtual bool hasUpdate() = 0;
};

}

#endif /* HasUpdate_hpp */
