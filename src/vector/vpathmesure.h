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
    VPathMesure(const VPath *path, bool foceClose);
    int getLength() const;
    void setPath(const VPath &path);
    VPath getPath();
    void setStart(float pos);
    void setEnd(float pos);
private:
    VPathMesureData *d;
};

V_END_NAMESPACE

#endif // VPATHMESURE_H
