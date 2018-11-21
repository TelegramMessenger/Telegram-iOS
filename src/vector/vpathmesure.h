#ifndef VPATHMESURE_H
#define VPATHMESURE_H

#include "vpath.h"

V_BEGIN_NAMESPACE

class VPathMesure {
public:
    void  setStart(float start){mStart = start;}
    void  setEnd(float end){mEnd = end;}
    VPath trim(const VPath &path);
private:
    float mStart{0.0f};
    float mEnd{1.0f};
};

V_END_NAMESPACE

#endif  // VPATHMESURE_H
