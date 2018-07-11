#ifndef VPATHMESURE_H
#define VPATHMESURE_H

#include "vpath.h"

class VPathMesureData;
class VPathMesure
{
public:
    ~VPathMesure();
    VPathMesure();
    VPathMesure(const VPath *path, bool foceClose);
    int getLength() const;
private:
    VPathMesureData *d;
};

#endif // VPATHMESURE_H
