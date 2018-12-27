/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * Licensed under the LGPL License, Version 2.1 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.gnu.org/licenses/
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef VPAINTER_H
#define VPAINTER_H

#include "vbrush.h"
#include "vpoint.h"
#include "vrle.h"

V_BEGIN_NAMESPACE

class VBitmap;
class VPainterImpl;
class VPainter {
public:
    enum CompositionMode { CompModeSrc, CompModeSrcOver };
    ~VPainter();
    VPainter();
    VPainter(VBitmap *buffer);
    bool  begin(VBitmap *buffer);
    void  end();
    void  setBrush(const VBrush &brush);
    void  drawRle(const VPoint &pos, const VRle &rle);
    void  drawRle(const VRle &rle, const VRle &clip);
    VRect clipBoundingRect() const;

private:
    VPainterImpl *mImpl;
};

V_END_NAMESPACE

#endif  // VPAINTER_H
