#ifndef VPATHMESURE_H
#define VPATHMESURE_H

#include "vpath.h"

V_BEGIN_NAMESPACE

class VPathMesure {
public:
    void  setOffset(float sp, float ep);
    VPath trim(const VPath &path);

private:
    float startOffset{0.0f};
    float endOffset{1.0f};
};

V_END_NAMESPACE

#endif  // VPATHMESURE_H
