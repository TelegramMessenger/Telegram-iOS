/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * Licensed under the Flora License, Version 1.1 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://floralicense.org/license/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef VREGION_H
#define VREGION_H
#include <vglobal.h>
#include <vpoint.h>
#include <vrect.h>
#include <utility>
#include "vdebug.h"

V_BEGIN_NAMESPACE

struct VRegionData;

class VRegion {
public:
    VRegion();
    VRegion(int x, int y, int w, int h);
    VRegion(const VRect &r);
    VRegion(const VRegion &region);
    VRegion(VRegion &&other);
    ~VRegion();
    VRegion &      operator=(const VRegion &);
    VRegion &      operator=(VRegion &&);
    bool           empty() const;
    bool           contains(const VRect &r) const;
    VRegion        united(const VRect &r) const;
    VRegion        united(const VRegion &r) const;
    VRegion        intersected(const VRect &r) const;
    VRegion        intersected(const VRegion &r) const;
    VRegion        subtracted(const VRegion &r) const;
    void           translate(const VPoint &p);
    inline void    translate(int dx, int dy);
    VRegion        translated(const VPoint &p) const;
    inline VRegion translated(int dx, int dy) const;
    int            rectCount() const;
    VRect          rectAt(int index) const;

    VRegion  operator+(const VRect &r) const;
    VRegion  operator+(const VRegion &r) const;
    VRegion  operator-(const VRegion &r) const;
    VRegion &operator+=(const VRect &r);
    VRegion &operator+=(const VRegion &r);
    VRegion &operator-=(const VRegion &r);

    VRect boundingRect() const noexcept;
    bool  intersects(const VRegion &region) const;

    bool        operator==(const VRegion &r) const;
    inline bool operator!=(const VRegion &r) const { return !(operator==(r)); }
    friend VDebug &operator<<(VDebug &os, const VRegion &o);

private:
    bool    within(const VRect &r) const;
    VRegion copy() const;
    void    detach();
    void    cleanUp(VRegionData *x);

    struct VRegionData *d;
};
inline void VRegion::translate(int dx, int dy)
{
    translate(VPoint(dx, dy));
}

inline VRegion VRegion::translated(int dx, int dy) const
{
    return translated(VPoint(dx, dy));
}

V_END_NAMESPACE

#endif  // VREGION_H
