/*
 * Copyright (c) 2018 Samsung Electronics Co., Ltd. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#ifndef LOTTIEPROXYMODEL_H
#define LOTTIEPROXYMODEL_H

#include "lottiemodel.h"

template <typename T>
class LOTProxyModel
{
public:
    LOTProxyModel(T *model): _modelData(model) {}
    void addValueProvider() {/* Impement*/}
    void removeValueProvider() {/* Impement*/}
    bool hasValueProvider() {return false;}
    LottieColor color(int frame) const { return _modelData->color(frame);}
    float opacity(int frame) const { return _modelData->opacity(frame);}
    FillRule fillRule() const {return _modelData->fillRule();}

    float strokeWidth(int frame) const {return _modelData->strokeWidth(frame);}
    float meterLimit() const {return _modelData->meterLimit();}
    CapStyle capStyle() const {return _modelData->capStyle();}
    JoinStyle joinStyle() const {return _modelData->joinStyle();}
    bool hasDashInfo() const { return _modelData->hasDashInfo();}
    int getDashInfo(int frameNo, float *array) const {return _modelData->getDashInfo(frameNo, array);}

private:
    T *_modelData;
};

#endif // LOTTIEITEM_H
