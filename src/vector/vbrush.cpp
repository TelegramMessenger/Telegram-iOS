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

#include "vbrush.h"

V_BEGIN_NAMESPACE

VGradient::VGradient(VGradient::Type type)
    : mType(type),
      mSpread(VGradient::Spread::Pad),
      mMode(VGradient::Mode::Absolute)
{
}

void VGradient::setStops(const VGradientStops &stops)
{
    mStops = stops;
}

VLinearGradient::VLinearGradient(const VPointF &start, const VPointF &stop)
    : VGradient(VGradient::Type::Linear)
{
    linear.x1 = start.x();
    linear.y1 = start.y();
    linear.x1 = stop.x();
    linear.y1 = stop.y();
}

VLinearGradient::VLinearGradient(float xStart, float yStart, float xStop,
                                 float yStop)
    : VGradient(VGradient::Type::Linear)
{
    linear.x1 = xStart;
    linear.y1 = yStart;
    linear.x1 = xStop;
    linear.y1 = yStop;
}

VRadialGradient::VRadialGradient(const VPointF &center, float cradius,
                                 const VPointF &focalPoint, float fradius)
    : VGradient(VGradient::Type::Radial)
{
    radial.cx = center.x();
    radial.cy = center.y();
    radial.fx = focalPoint.x();
    radial.fy = focalPoint.y();
    radial.cradius = cradius;
    radial.fradius = fradius;
}

VRadialGradient::VRadialGradient(float cx, float cy, float cradius, float fx,
                                 float fy, float fradius)
    : VGradient(VGradient::Type::Radial)
{
    radial.cx = cx;
    radial.cy = cy;
    radial.fx = fx;
    radial.fy = fy;
    radial.cradius = cradius;
    radial.fradius = fradius;
}

VBrush::VBrush(const VColor &color) : mType(VBrush::Type::Solid), mColor(color)
{
}

VBrush::VBrush(int r, int g, int b, int a)
    : mType(VBrush::Type::Solid), mColor(r, g, b, a)

{
}

VBrush::VBrush(const VGradient *gradient) : mType(VBrush::Type::NoBrush)
{
    if (!gradient) return;

    mGradient = gradient;

    if (gradient->mType == VGradient::Type::Linear) {
        mType = VBrush::Type::LinearGradient;
    } else if (gradient->mType == VGradient::Type::Radial) {
        mType = VBrush::Type::RadialGradient;
    }
}

V_END_NAMESPACE
