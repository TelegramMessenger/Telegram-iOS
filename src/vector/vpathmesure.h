#ifndef VPATHMESURE_H
#define VPATHMESURE_H

#include "vpath.h"

V_BEGIN_NAMESPACE

class VPathMesureData;
class VPathMesure
{
public:
    ~VPathMesure();
    VPathMesure();
    VPathMesure(const VPathMesure &other);
    VPathMesure(VPathMesure &&other);
    VPathMesure &operator=(const VPathMesure &);
    VPathMesure &operator=(VPathMesure &&other);
    int getLength() const;
    void setPath(const VPath &path);
    VPath getPath();
    void setStart(float pos);
    void setEnd(float pos);
private:
    VPathMesure copy() const;
    void detach();
    void cleanUp(VPathMesureData *x);
    VPathMesureData *d;
};

V_END_NAMESPACE

#endif // VPATHMESURE_H
