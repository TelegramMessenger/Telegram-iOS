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

#include "lottieitem.h"
#include <cmath>
#include <algorithm>
#include "vbitmap.h"
#include "vdasher.h"
#include "vpainter.h"
#include "vraster.h"

/* Lottie Layer Rules
 * 1. time stretch is pre calculated and applied to all the properties of the
 * lottilayer model and all its children
 * 2. The frame property could be reversed using,time-reverse layer property in
 * AE. which means (start frame > endFrame) 3.
 */

LOTCompItem::LOTCompItem(LOTModel *model)
    : mRootModel(model), mUpdateViewBox(false), mCurFrameNo(-1)
{
    mCompData = model->mRoot.get();
    mRootLayer = createLayerItem(mCompData->mRootLayer.get());
    mRootLayer->updateStaticProperty();
    mViewSize = mCompData->size();
}

std::unique_ptr<LOTLayerItem>
LOTCompItem::createLayerItem(LOTLayerData *layerData)
{
    switch (layerData->mLayerType) {
    case LayerType::Precomp: {
        return std::make_unique<LOTCompLayerItem>(layerData);
        break;
    }
    case LayerType::Solid: {
        return std::make_unique<LOTSolidLayerItem>(layerData);
        break;
    }
    case LayerType::Shape: {
        return std::make_unique<LOTShapeLayerItem>(layerData);
        break;
    }
    case LayerType::Null: {
        return std::make_unique<LOTNullLayerItem>(layerData);
        break;
    }
    case LayerType::Image: {
        return std::make_unique<LOTImageLayerItem>(layerData);
        break;
    }
    default:
        return nullptr;
        break;
    }
}

void LOTCompItem::resize(const VSize &size)
{
    if (mViewSize == size) return;
    mViewSize = size;
    mUpdateViewBox = true;
}

VSize LOTCompItem::size() const
{
    return mViewSize;
}

bool LOTCompItem::update(int frameNo)
{
    // check if cached frame is same as requested frame.
    if (!mUpdateViewBox && (mCurFrameNo == frameNo)) return false;

    /*
     * if viewbox dosen't scale exactly to the viewport
     * we scale the viewbox keeping AspectRatioPreserved and then align the
     * viewbox to the viewport using AlignCenter rule.
     */
    VSize viewPort = mViewSize;
    VSize viewBox = mCompData->size();

    float sx = float(viewPort.width()) / viewBox.width();
    float sy = float(viewPort.height()) / viewBox.height();
    float scale = fmin(sx, sy);
    float tx = (viewPort.width() - viewBox.width() * scale) * 0.5;
    float ty = (viewPort.height() - viewBox.height() * scale) * 0.5;

    VMatrix m;
    m.translate(tx, ty).scale(scale, scale);
    mRootLayer->update(frameNo, m, 1.0);

    mCurFrameNo = frameNo;
    mUpdateViewBox = false;
    return true;
}

void LOTCompItem::buildRenderTree()
{
    mRootLayer->buildLayerNode();
}

const LOTLayerNode * LOTCompItem::renderTree() const
{
    return mRootLayer->layerNode();
}

bool LOTCompItem::render(const rlottie::Surface &surface)
{
    VBitmap bitmap(reinterpret_cast<uchar *>(surface.buffer()),
                   surface.width(), surface.height(),
                   surface.bytesPerLine(), VBitmap::Format::ARGB32_Premultiplied);

    /* schedule all preprocess task for this frame at once.
     */
    mDrawableList.clear();
    mRootLayer->renderList(mDrawableList);
    VRect clip(0, 0, surface.width(), surface.height());
    for (auto &e : mDrawableList) {
        e->preprocess(clip);
    }

    VPainter painter(&bitmap);
    mRootLayer->render(&painter, {}, {});

    return true;
}

void LOTMaskItem::update(int frameNo, const VMatrix &parentMatrix,
                         float parentAlpha, const DirtyFlag &flag)
{
    if (flag.testFlag(DirtyFlagBit::None) && mData->isStatic()) return;

    if (mData->mShape.isStatic()) {
        if (mLocalPath.empty()) {
            mData->mShape.value(frameNo).toPath(mLocalPath);
        }
    } else {
        mData->mShape.value(frameNo).toPath(mLocalPath);
    }
    float opacity = mData->opacity(frameNo);
    opacity = opacity * parentAlpha;
    mCombinedAlpha = opacity;

    mFinalPath.clone(mLocalPath);
    mFinalPath.transform(parentMatrix);

    VPath tmp = mFinalPath;

    if (!mRleFuture) mRleFuture = std::make_shared<VSharedState<VRle>>();

    mRleFuture->reuse();
    VRaster::generateFillInfo(mRleFuture, std::move(tmp), std::move(mRle));
    mRle = VRle();
}

VRle LOTMaskItem::rle()
{
    if (mRleFuture && mRleFuture->valid()) {
        mRle = mRleFuture->get();
        if (!vCompare(mCombinedAlpha, 1.0f))
            mRle *= (mCombinedAlpha * 255);
        if (mData->mInv) mRle.invert();
    }
    return mRle;
}

void LOTLayerItem::buildLayerNode()
{
    if (!mLayerCNode) {
        mLayerCNode = std::make_unique<LOTLayerNode>();
        mLayerCNode->mMaskList.ptr = nullptr;
        mLayerCNode->mMaskList.size = 0;
        mLayerCNode->mLayerList.ptr = nullptr;
        mLayerCNode->mLayerList.size = 0;
        mLayerCNode->mNodeList.ptr = nullptr;
        mLayerCNode->mNodeList.size = 0;
        mLayerCNode->mMatte = MatteNone;
        mLayerCNode->mVisible = 0;
        mLayerCNode->mClipPath.ptPtr = nullptr;
        mLayerCNode->mClipPath.elmPtr = nullptr;
        mLayerCNode->mClipPath.ptCount = 0;
        mLayerCNode->mClipPath.elmCount = 0;
    }
    mLayerCNode->mVisible = visible();
    // update matte
    if (hasMatte()) {
        switch (mLayerData->mMatteType) {
        case MatteType::Alpha:
            mLayerCNode->mMatte = MatteAlpha;
            break;
        case MatteType::AlphaInv:
            mLayerCNode->mMatte = MatteAlphaInv;
            break;
        case MatteType::Luma:
            mLayerCNode->mMatte = MatteLuma;
            break;
        case MatteType::LumaInv:
            mLayerCNode->mMatte = MatteLumaInv;
            break;
        default:
            mLayerCNode->mMatte = MatteNone;
            break;
        }
    }
    if (mLayerMask) {
        mMasksCNode.clear();
        for (const auto &mask : mLayerMask->mMasks) {
            LOTMask cNode;
            const std::vector<VPath::Element> &elm = mask.mFinalPath.elements();
            const std::vector<VPointF> &       pts = mask.mFinalPath.points();
            const float *ptPtr = reinterpret_cast<const float *>(pts.data());
            const char * elmPtr = reinterpret_cast<const char *>(elm.data());
            cNode.mPath.ptPtr = ptPtr;
            cNode.mPath.ptCount = pts.size();
            cNode.mPath.elmPtr = elmPtr;
            cNode.mPath.elmCount = elm.size();
            cNode.mAlpha = mask.mCombinedAlpha * 255;
            switch (mask.maskMode()) {
            case LOTMaskData::Mode::Add:
                cNode.mMode = MaskModeAdd;
                break;
            case LOTMaskData::Mode::Substarct:
                cNode.mMode = MaskModeSubstract;
                break;
            case LOTMaskData::Mode::Intersect:
                cNode.mMode = MaskModeIntersect;
                break;
            case LOTMaskData::Mode::Difference:
                cNode.mMode = MaskModeDifference;
                break;
            default:
                cNode.mMode = MaskModeAdd;
                break;
            }
            mMasksCNode.push_back(std::move(cNode));
        }
        mLayerCNode->mMaskList.ptr = mMasksCNode.data();
        mLayerCNode->mMaskList.size = mMasksCNode.size();
    }
}

void LOTLayerItem::render(VPainter *painter, const VRle &inheritMask, const VRle &matteRle)
{
    mDrawableList.clear();
    renderList(mDrawableList);

    VRle mask;
    if (mLayerMask) {
        mask = mLayerMask->maskRle(painter->clipBoundingRect());
        if (!inheritMask.empty())
            mask = mask & inheritMask;
        // if resulting mask is empty then return.
        if (mask.empty())
            return;
    } else {
        mask = inheritMask;
    }

    for (auto &i : mDrawableList) {
        painter->setBrush(i->mBrush);
        VRle rle = i->rle();
        if (matteRle.empty()) {
            if (mask.empty()) {
                // no mask no matte
                painter->drawRle(VPoint(), rle);
            } else {
                // only mask
                painter->drawRle(rle, mask);
            }

        } else {
            if (!mask.empty()) rle = rle & mask;

            if (rle.empty()) continue;
            if (matteType() == MatteType::AlphaInv) {
                rle = rle - matteRle;
                painter->drawRle(VPoint(), rle);
            } else {
                // render with matteRle as clip.
                painter->drawRle(rle, matteRle);
            }
        }
    }
}

LOTLayerMaskItem::LOTLayerMaskItem(LOTLayerData *layerData)
{
    mMasks.reserve(layerData->mMasks.size());

    for (auto &i : layerData->mMasks) {
        mMasks.emplace_back(i.get());
        mStatic &= i->isStatic();
    }
}

void LOTLayerMaskItem::update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag)
{
    if (flag.testFlag(DirtyFlagBit::None) && isStatic()) return;

    for (auto &i : mMasks) {
        i.update(frameNo, parentMatrix, parentAlpha, flag);
    }
    mDirty = true;
}

VRle LOTLayerMaskItem::maskRle(const VRect &clipRect)
{
    if (!mDirty) return mRle;

    VRle rle;
    for (auto &i : mMasks) {
        switch (i.maskMode()) {
        case LOTMaskData::Mode::Add: {
            rle = rle + i.rle();
            break;
        }
        case LOTMaskData::Mode::Substarct: {
            if (rle.empty() && !clipRect.empty())
                rle = VRle::toRle(clipRect);
            rle = rle - i.rle();
            break;
        }
        case LOTMaskData::Mode::Intersect: {
            rle = rle & i.rle();
            break;
        }
        case LOTMaskData::Mode::Difference: {
            rle = rle ^ i.rle();
            break;
        }
        default:
            break;
        }
    }

    mRle = rle;
    mDirty = false;
    return mRle;
}


LOTLayerItem::LOTLayerItem(LOTLayerData *layerData): mLayerData(layerData)
{
    if (mLayerData->mHasMask)
        mLayerMask = std::make_unique<LOTLayerMaskItem>(mLayerData);
}

void LOTLayerItem::updateStaticProperty()
{
    if (mParentLayer) mParentLayer->updateStaticProperty();

    mStatic = mLayerData->isStatic();
    mStatic = mParentLayer ? (mStatic & mParentLayer->isStatic()) : mStatic;
    mStatic = mPrecompLayer ? (mStatic & mPrecompLayer->isStatic()) : mStatic;
}

void LOTLayerItem::update(int frameNumber, const VMatrix &parentMatrix,
                          float parentAlpha)
{
    mFrameNo = frameNumber;
    // 1. check if the layer is part of the current frame
    if (!visible()) return;

    // 2. calculate the parent matrix and alpha
    VMatrix m = matrix(frameNo());
    m *= parentMatrix;
    float alpha = parentAlpha * opacity(frameNo());

    // 3. update the dirty flag based on the change
    if (!mCombinedMatrix.fuzzyCompare(m)) {
        mDirtyFlag |= DirtyFlagBit::Matrix;
    }
    if (!vCompare(mCombinedAlpha, alpha)) {
        mDirtyFlag |= DirtyFlagBit::Alpha;
    }
    mCombinedMatrix = m;
    mCombinedAlpha = alpha;

    // 4. update the mask
    if (mLayerMask) {
        mLayerMask->update(frameNo(), m, alpha, mDirtyFlag);
    }

    // 5. if no parent property change and layer is static then nothing to do.
    if (flag().testFlag(DirtyFlagBit::None) && isStatic()) return;

    // 6. update the content of the layer
    updateContent();

    // 7. reset the dirty flag
    mDirtyFlag = DirtyFlagBit::None;
}

float LOTLayerItem::opacity(int frameNo) const
{
    return mLayerData->mTransform->opacity(frameNo);
}

VMatrix LOTLayerItem::matrix(int frameNo) const
{
    if (mParentLayer)
        return mLayerData->mTransform->matrix(frameNo, mLayerData->autoOrient()) *
               mParentLayer->matrix(frameNo);
    else
        return mLayerData->mTransform->matrix(frameNo, mLayerData->autoOrient());
}

bool LOTLayerItem::visible() const
{
    if (frameNo() >= mLayerData->inFrame() &&
        frameNo() < mLayerData->outFrame())
        return true;
    else
        return false;
}

LOTCompLayerItem::LOTCompLayerItem(LOTLayerData *layerModel)
    : LOTLayerItem(layerModel)
{
    // 1. create layer item
    for (auto &i : mLayerData->mChildren) {
        LOTLayerData *layerModel = static_cast<LOTLayerData *>(i.get());
        auto layerItem = LOTCompItem::createLayerItem(layerModel);
        if (layerItem) mLayers.push_back(std::move(layerItem));
    }

    // 2. update parent layer
    for (const auto &layer : mLayers) {
        int id = layer->parentId();
        if (id >= 0) {
            auto search = std::find_if(mLayers.begin(), mLayers.end(),
                            [id](const auto& val){ return val->id() == id;});
            if (search != mLayers.end()) layer->setParentLayer((*search).get());
        }
        // update the precomp layer if its not the root layer.
        if (!layerModel->root()) layer->setPrecompLayer(this);
    }

    // 3. keep the layer in back-to-front order.
    // as lottie model keeps the data in front-toback-order.
    std::reverse(mLayers.begin(), mLayers.end());

    // 4. check if its a nested composition
    if (!layerModel->layerSize().empty()) {
        mClipper = std::make_unique<LOTClipperItem>(layerModel->layerSize());
    }
}

void LOTCompLayerItem::updateStaticProperty()
{
    LOTLayerItem::updateStaticProperty();

    for (const auto &layer : mLayers) {
        layer->updateStaticProperty();
    }
}

void LOTCompLayerItem::buildLayerNode()
{
    LOTLayerItem::buildLayerNode();
    if (mClipper) {
        const std::vector<VPath::Element> &elm = mClipper->mPath.elements();
        const std::vector<VPointF> &       pts = mClipper->mPath.points();
        const float *ptPtr = reinterpret_cast<const float *>(pts.data());
        const char * elmPtr = reinterpret_cast<const char *>(elm.data());
        layerNode()->mClipPath.ptPtr = ptPtr;
        layerNode()->mClipPath.elmPtr = elmPtr;
        layerNode()->mClipPath.ptCount = 2 * pts.size();
        layerNode()->mClipPath.elmCount = elm.size();
    }
    if (mLayers.size() != mLayersCNode.size()) {
        for (const auto &layer : mLayers) {
            layer->buildLayerNode();
            mLayersCNode.push_back(layer->layerNode());
        }
        layerNode()->mLayerList.ptr = mLayersCNode.data();
        layerNode()->mLayerList.size = mLayersCNode.size();
    } else {
        for (const auto &layer : mLayers) {
            layer->buildLayerNode();
        }
    }
}

void LOTCompLayerItem::render(VPainter *painter, const VRle &inheritMask, const VRle &matteRle)
{
    VRle mask;
    if (mLayerMask) {
        mask = mLayerMask->maskRle(painter->clipBoundingRect());
        if (!inheritMask.empty())
            mask = mask & inheritMask;
        // if resulting mask is empty then return.
        if (mask.empty())
            return;
    } else {
        mask = inheritMask;
    }

    if (mClipper) {
        if (mask.empty()) {
            mask = mClipper->rle();
        } else {
            mask = mClipper->rle() & mask;
        }
    }

    LOTLayerItem *matteLayer = nullptr;
    for (const auto &layer : mLayers) {
        if (layer->hasMatte()) {
            if (matteLayer) {
                vWarning << "two consecutive layer has matter : not supported";
            }
            matteLayer = layer.get();
            continue;
        }

        if (layer->visible()) {
            if (matteLayer) {
                if (matteLayer->visible())
                    renderMatteLayer(painter, mask, matteRle, matteLayer, layer.get());
            } else {
                layer->render(painter, mask, matteRle);
            }
        }

        matteLayer = nullptr;
    }
}

void LOTCompLayerItem::renderMatteLayer(VPainter *painter,
                                        const VRle &mask,
                                        const VRle &matteRle,
                                        LOTLayerItem *layer,
                                        LOTLayerItem *src)
{
    VSize size = painter->clipBoundingRect().size();
    // Decide if we can use fast matte.
    // 1. draw src layer to matte buffer
    VPainter srcPainter;
    VBitmap srcBitmap(size.width(), size.height(), VBitmap::Format::ARGB32_Premultiplied);
    srcPainter.begin(&srcBitmap);
    src->render(&srcPainter, mask, matteRle);
    srcPainter.end();

    // 2. draw layer to layer buffer
    VPainter layerPainter;
    VBitmap layerBitmap(size.width(), size.height(), VBitmap::Format::ARGB32_Premultiplied);
    layerPainter.begin(&layerBitmap);
    layer->render(&layerPainter, mask, matteRle);

    // 2.1update composition mode
    switch (layer->matteType()) {
    case MatteType::Alpha:
    case MatteType::Luma: {
        layerPainter.setCompositionMode(VPainter::CompositionMode::CompModeDestIn);
        break;
    }
    case MatteType::AlphaInv:
    case MatteType::LumaInv: {
        layerPainter.setCompositionMode(VPainter::CompositionMode::CompModeDestOut);
        break;
    }
    default:
        break;
    }

    //2.2 update srcBuffer if the matte is luma type
    if (layer->matteType() == MatteType::Luma ||
        layer->matteType() == MatteType::LumaInv) {
        srcBitmap.updateLuma();
    }

    // 2.3 draw src buffer as mask
    layerPainter.drawBitmap(VPoint(), srcBitmap);
    layerPainter.end();
    // 3. draw the result buffer into painter
    painter->drawBitmap(VPoint(), layerBitmap);
}

void LOTClipperItem::update(const VMatrix &matrix)
{
    mPath.reset();
    mPath.addRect(VRectF(0,0, mSize.width(), mSize.height()));
    mPath.transform(matrix);

    VPath tmp = mPath;

    if (!mRleFuture) mRleFuture = std::make_shared<VSharedState<VRle>>();

    mRleFuture->reuse();
    VRaster::generateFillInfo(mRleFuture, std::move(tmp), std::move(mRle));
    mRle = VRle();
}

VRle LOTClipperItem::rle()
{
    if (mRleFuture && mRleFuture->valid()) {
        mRle = mRleFuture->get();
    }
    return mRle;
}

void LOTCompLayerItem::updateContent()
{
    if (mClipper && flag().testFlag(DirtyFlagBit::Matrix)) {
        mClipper->update(combinedMatrix());
    }
    int mappedFrame = mLayerData->timeRemap(frameNo());
    for (const auto &layer : mLayers) {
        layer->update( mappedFrame, combinedMatrix(), combinedAlpha());
    }
}

void LOTCompLayerItem::renderList(std::vector<VDrawable *> &list)
{
    if (!visible()) return;

    for (const auto &layer : mLayers) {
        layer->renderList(list);
    }
}

LOTSolidLayerItem::LOTSolidLayerItem(LOTLayerData *layerData)
    : LOTLayerItem(layerData)
{
}

void LOTSolidLayerItem::updateContent()
{
    if (!mRenderNode) {
        mRenderNode = std::make_unique<LOTDrawable>();
        mRenderNode->mType = VDrawable::Type::Fill;
        mRenderNode->mFlag |= VDrawable::DirtyState::All;
    }

    if (flag() & DirtyFlagBit::Matrix) {
        VPath path;
        path.addRect(
            VRectF(0, 0, mLayerData->solidWidth(), mLayerData->solidHeight()));
        path.transform(combinedMatrix());
        mRenderNode->mFlag |= VDrawable::DirtyState::Path;
        mRenderNode->mPath = path;
    }
    if (flag() & DirtyFlagBit::Alpha) {
        LottieColor color = mLayerData->solidColor();
        VBrush      brush(color.toColor(combinedAlpha()));
        mRenderNode->setBrush(brush);
        mRenderNode->mFlag |= VDrawable::DirtyState::Brush;
    }
}

void LOTSolidLayerItem::buildLayerNode()
{
    LOTLayerItem::buildLayerNode();

    mDrawableList.clear();
    renderList(mDrawableList);

    mCNodeList.clear();
    for (auto &i : mDrawableList) {
        LOTDrawable *lotDrawable = static_cast<LOTDrawable *>(i);
        lotDrawable->sync();
        mCNodeList.push_back(lotDrawable->mCNode.get());
    }
    layerNode()->mNodeList.ptr = mCNodeList.data();
    layerNode()->mNodeList.size = mCNodeList.size();
}

void LOTSolidLayerItem::renderList(std::vector<VDrawable *> &list)
{
    if (!visible()) return;

    list.push_back(mRenderNode.get());
}

LOTImageLayerItem::LOTImageLayerItem(LOTLayerData *layerData)
    : LOTLayerItem(layerData)
{
}

void LOTImageLayerItem::updateContent()
{
    if (!mRenderNode) {
        mRenderNode = std::make_unique<LOTDrawable>();
        mRenderNode->mType = VDrawable::Type::Fill;
        mRenderNode->mFlag |= VDrawable::DirtyState::All;
        // load image
        //@TODO find a better way to load
        // so that can be shared by multiple layers
        VBrush brush(mLayerData->mAsset->bitmap());
        mRenderNode->setBrush(brush);
    }

    if (flag() & DirtyFlagBit::Matrix) {
        VPath path;
        path.addRect(
            VRectF(0, 0, mLayerData->mAsset->mWidth, mLayerData->mAsset->mHeight));
        path.transform(combinedMatrix());
        mRenderNode->mFlag |= VDrawable::DirtyState::Path;
        mRenderNode->mPath = path;
        mRenderNode->mBrush.setMatrix(combinedMatrix());
    }

    if (flag() & DirtyFlagBit::Alpha) {
        //@TODO handle alpha with the image.
    }
}

void LOTImageLayerItem::renderList(std::vector<VDrawable *> &list)
{
    if (!visible()) return;

    list.push_back(mRenderNode.get());
}

void LOTImageLayerItem::buildLayerNode()
{
    LOTLayerItem::buildLayerNode();

    mDrawableList.clear();
    renderList(mDrawableList);

    mCNodeList.clear();
    for (auto &i : mDrawableList) {
        LOTDrawable *lotDrawable = static_cast<LOTDrawable *>(i);
        lotDrawable->sync();
        mCNodeList.push_back(lotDrawable->mCNode.get());
    }
    layerNode()->mNodeList.ptr = mCNodeList.data();
    layerNode()->mNodeList.size = mCNodeList.size();
}

LOTNullLayerItem::LOTNullLayerItem(LOTLayerData *layerData)
    : LOTLayerItem(layerData)
{
}
void LOTNullLayerItem::updateContent() {}

LOTShapeLayerItem::LOTShapeLayerItem(LOTLayerData *layerData)
    : LOTLayerItem(layerData)
{
    mRoot = std::make_unique<LOTContentGroupItem>(nullptr);
    mRoot->addChildren(layerData);

    std::vector<LOTPathDataItem *> list;
    mRoot->processPaintItems(list);

    if (layerData->hasPathOperator()) {
        list.clear();
        mRoot->processTrimItems(list);
    }
}

std::unique_ptr<LOTContentItem>
LOTShapeLayerItem::createContentItem(LOTData *contentData)
{
    switch (contentData->type()) {
    case LOTData::Type::ShapeGroup: {
        return std::make_unique<LOTContentGroupItem>(
            static_cast<LOTGroupData *>(contentData));
        break;
    }
    case LOTData::Type::Rect: {
        return std::make_unique<LOTRectItem>(static_cast<LOTRectData *>(contentData));
        break;
    }
    case LOTData::Type::Ellipse: {
        return std::make_unique<LOTEllipseItem>(static_cast<LOTEllipseData *>(contentData));
        break;
    }
    case LOTData::Type::Shape: {
        return std::make_unique<LOTShapeItem>(static_cast<LOTShapeData *>(contentData));
        break;
    }
    case LOTData::Type::Polystar: {
        return std::make_unique<LOTPolystarItem>(static_cast<LOTPolystarData *>(contentData));
        break;
    }
    case LOTData::Type::Fill: {
        return std::make_unique<LOTFillItem>(static_cast<LOTFillData *>(contentData));
        break;
    }
    case LOTData::Type::GFill: {
        return std::make_unique<LOTGFillItem>(static_cast<LOTGFillData *>(contentData));
        break;
    }
    case LOTData::Type::Stroke: {
        return std::make_unique<LOTStrokeItem>(static_cast<LOTStrokeData *>(contentData));
        break;
    }
    case LOTData::Type::GStroke: {
        return std::make_unique<LOTGStrokeItem>(static_cast<LOTGStrokeData *>(contentData));
        break;
    }
    case LOTData::Type::Repeater: {
        return std::make_unique<LOTRepeaterItem>(static_cast<LOTRepeaterData *>(contentData));
        break;
    }
    case LOTData::Type::Trim: {
        return std::make_unique<LOTTrimItem>(static_cast<LOTTrimData *>(contentData));
        break;
    }
    default:
        return nullptr;
        break;
    }
}

void LOTShapeLayerItem::updateContent()
{
    mRoot->update(frameNo(), combinedMatrix(), combinedAlpha(), flag());

    if (mLayerData->hasPathOperator()) {
        mRoot->applyTrim();
    }
}

void LOTShapeLayerItem::buildLayerNode()
{
    LOTLayerItem::buildLayerNode();

    mDrawableList.clear();
    renderList(mDrawableList);

    mCNodeList.clear();
    for (auto &i : mDrawableList) {
        LOTDrawable *lotDrawable = static_cast<LOTDrawable *>(i);
        lotDrawable->sync();
        mCNodeList.push_back(lotDrawable->mCNode.get());
    }
    layerNode()->mNodeList.ptr = mCNodeList.data();
    layerNode()->mNodeList.size = mCNodeList.size();
}

void LOTShapeLayerItem::renderList(std::vector<VDrawable *> &list)
{
    if (!visible()) return;
    mRoot->renderList(list);
}

LOTContentGroupItem::LOTContentGroupItem(LOTGroupData *data) : mData(data)
{
    addChildren(mData);
}

void LOTContentGroupItem::addChildren(LOTGroupData *data)
{
    if (!data) return;

    for (auto &i : data->mChildren) {
        auto content = LOTShapeLayerItem::createContentItem(i.get());
        if (content) {
            content->setParent(this);
            mContents.push_back(std::move(content));
        }
    }

    // keep the content in back-to-front order.
    std::reverse(mContents.begin(), mContents.end());
}

void LOTContentGroupItem::update(int frameNo, const VMatrix &parentMatrix,
                                 float parentAlpha, const DirtyFlag &flag)
{
    VMatrix   m = parentMatrix;
    float     alpha = parentAlpha;
    DirtyFlag newFlag = flag;

    if (mData && mData->mTransform) {
        // update the matrix and the flag
        if ((flag & DirtyFlagBit::Matrix) ||
            !mData->mTransform->staticMatrix()) {
            newFlag |= DirtyFlagBit::Matrix;
        }
        m = mData->mTransform->matrix(frameNo);
        m *= parentMatrix;
        alpha *= mData->mTransform->opacity(frameNo);

        if (!vCompare(alpha, parentAlpha)) {
            newFlag |= DirtyFlagBit::Alpha;
        }
    }

    mMatrix = m;

    for (const auto &content : mContents) {
        content->update(frameNo, m, alpha, newFlag);
    }
}

void LOTContentGroupItem::applyTrim()
{
    for (auto i = mContents.rbegin(); i != mContents.rend(); ++i) {
        auto content = (*i).get();
        if (auto trim = dynamic_cast<LOTTrimItem *>(content)) {
            trim->update();
        } else if (auto group = dynamic_cast<LOTContentGroupItem *>(content)) {
            group->applyTrim();
        }
    }
}

void LOTContentGroupItem::renderList(std::vector<VDrawable *> &list)
{
    for (const auto &content : mContents) {
        content->renderList(list);
    }
}

void LOTContentGroupItem::processPaintItems(
    std::vector<LOTPathDataItem *> &list)
{
    int curOpCount = list.size();
    for (auto i = mContents.rbegin(); i != mContents.rend(); ++i) {
        auto content = (*i).get();
        if (auto pathNode = dynamic_cast<LOTPathDataItem *>(content)) {
            // add it to the list
            list.push_back(pathNode);
        } else if (auto paintNode = dynamic_cast<LOTPaintDataItem *>(content)) {
            // the node is a paint data node update the path list of the paint item.
            paintNode->addPathItems(list, curOpCount);
        } else if (auto groupNode =
                       dynamic_cast<LOTContentGroupItem *>(content)) {
            // update the groups node with current list
            groupNode->processPaintItems(list);
        }
    }
}

void LOTContentGroupItem::processTrimItems(
    std::vector<LOTPathDataItem *> &list)
{
    int curOpCount = list.size();
    for (auto i = mContents.rbegin(); i != mContents.rend(); ++i) {
        auto content = (*i).get();
        if (auto pathNode = dynamic_cast<LOTPathDataItem *>(content)) {
            // add it to the list
            list.push_back(pathNode);
        } else if (auto trimNode = dynamic_cast<LOTTrimItem *>(content)) {
            // the node is a paint data node update the path list of the paint item.
            trimNode->addPathItems(list, curOpCount);
        } else if (auto groupNode =
                       dynamic_cast<LOTContentGroupItem *>(content)) {
            // update the groups node with current list
            groupNode->processTrimItems(list);
        }
    }
}

/*
 * LOTPathDataItem uses 3 path objects for path object reuse.
 * mLocalPath -  keeps track of the local path of the item before
 * applying path operation and transformation.
 * mTemp - keeps a referece to the mLocalPath and can be updated by the
 *          path operation objects(trim, merge path),
 *  mFinalPath - it takes a deep copy of the intermediate path(mTemp) each time
 *  when the path is dirty(so if path changes every frame we don't realloc just copy to the
 *  final path).
 * NOTE: As path objects are COW objects we have to be carefull about the refcount so that
 * we don't generate deep copy while modifying the path objects.
 */
void LOTPathDataItem::update(int frameNo, const VMatrix &,
                             float, const DirtyFlag &flag)
{
    mPathChanged = false;

    // 1. update the local path if needed
    if (hasChanged(frameNo)) {
        // loose the reference to mLocalPath if any
        // from the last frame update.
        mTemp = VPath();

        updatePath(mLocalPath, frameNo);
        mPathChanged = true;
        mNeedUpdate = true;
    }
    // 2. keep a reference path in temp in case there is some
    // path operation like trim which will update the path.
    // we don't want to update the local path.
    mTemp = mLocalPath;

    // 3. compute the final path with parentMatrix
    if ((flag & DirtyFlagBit::Matrix) || mPathChanged) {
        mPathChanged = true;
    }
}

const VPath & LOTPathDataItem::finalPath()
{
    if (mPathChanged || mNeedUpdate) {
        mFinalPath.clone(mTemp);
        mFinalPath.transform(static_cast<LOTContentGroupItem *>(parent())->matrix());
        mNeedUpdate = false;
    }
    return mFinalPath;
}
LOTRectItem::LOTRectItem(LOTRectData *data)
    : LOTPathDataItem(data->isStatic()), mData(data)
{
}

void LOTRectItem::updatePath(VPath& path, int frameNo)
{
    VPointF pos = mData->mPos.value(frameNo);
    VPointF size = mData->mSize.value(frameNo);
    float   roundness = mData->mRound.value(frameNo);
    VRectF  r(pos.x() - size.x() / 2, pos.y() - size.y() / 2, size.x(),
             size.y());

    path.reset();
    path.addRoundRect(r, roundness, mData->direction());
}

LOTEllipseItem::LOTEllipseItem(LOTEllipseData *data)
    : LOTPathDataItem(data->isStatic()), mData(data)
{
}

void LOTEllipseItem::updatePath(VPath& path, int frameNo)
{
    VPointF pos = mData->mPos.value(frameNo);
    VPointF size = mData->mSize.value(frameNo);
    VRectF  r(pos.x() - size.x() / 2, pos.y() - size.y() / 2, size.x(),
             size.y());

    path.reset();
    path.addOval(r, mData->direction());
}

LOTShapeItem::LOTShapeItem(LOTShapeData *data)
    : LOTPathDataItem(data->isStatic()), mData(data)
{
}

void LOTShapeItem::updatePath(VPath& path, int frameNo)
{
    mData->mShape.value(frameNo).toPath(path);
}

LOTPolystarItem::LOTPolystarItem(LOTPolystarData *data)
    : LOTPathDataItem(data->isStatic()), mData(data)
{
}

void LOTPolystarItem::updatePath(VPath& path, int frameNo)
{
    VPointF pos = mData->mPos.value(frameNo);
    float   points = mData->mPointCount.value(frameNo);
    float   innerRadius = mData->mInnerRadius.value(frameNo);
    float   outerRadius = mData->mOuterRadius.value(frameNo);
    float   innerRoundness = mData->mInnerRoundness.value(frameNo);
    float   outerRoundness = mData->mOuterRoundness.value(frameNo);
    float   rotation = mData->mRotation.value(frameNo);

    path.reset();
    VMatrix m;

    if (mData->mType == LOTPolystarData::PolyType::Star) {
        path.addPolystar(points, innerRadius, outerRadius, innerRoundness,
                         outerRoundness, 0.0, 0.0, 0.0, mData->direction());
    } else {
        path.addPolygon(points, outerRadius, outerRoundness, 0.0, 0.0, 0.0,
                        mData->direction());
    }

    m.translate(pos.x(), pos.y()).rotate(rotation);
    m.rotate(rotation);
    path.transform(m);
}

/*
 * PaintData Node handling
 *
 */
LOTPaintDataItem::LOTPaintDataItem(bool staticContent):mDrawable(std::make_unique<LOTDrawable>()),
                                                       mStaticContent(staticContent){}

void LOTPaintDataItem::update(int frameNo, const VMatrix &parentMatrix,
                              float parentAlpha, const DirtyFlag &flag)
{
    mRenderNodeUpdate = true;
    mParentAlpha = parentAlpha;
    mFlag = flag;
    mFrameNo = frameNo;

    updateContent(frameNo);
}

void LOTPaintDataItem::updateRenderNode()
{
    bool dirty = false;
    for (auto &i : mPathItems) {
        if (i->dirty()) {
            dirty = true;
            break;
        }
    }

    if (dirty) {
        mPath.reset();

        for (auto &i : mPathItems) {
            mPath.addPath(i->finalPath());
        }
        mDrawable->setPath(mPath);
    } else {
        if (mDrawable->mFlag & VDrawable::DirtyState::Path)
            mDrawable->mPath = mPath;
    }
}

void LOTPaintDataItem::renderList(std::vector<VDrawable *> &list)
{
    if (mRenderNodeUpdate) {
        updateRenderNode();
        LOTPaintDataItem::updateRenderNode();
        mRenderNodeUpdate = false;
    }
    list.push_back(mDrawable.get());
}


void LOTPaintDataItem::addPathItems(std::vector<LOTPathDataItem *> &list, int startOffset)
{
    std::copy(list.begin() + startOffset, list.end(), back_inserter(mPathItems));
}


LOTFillItem::LOTFillItem(LOTFillData *data)
    : LOTPaintDataItem(data->isStatic()), mData(data)
{
}

void LOTFillItem::updateContent(int frameNo)
{
    LottieColor c = mData->mColor.value(frameNo);
    float       opacity = mData->opacity(frameNo);
    mColor = c.toColor(opacity);
    mFillRule = mData->fillRule();
}

void LOTFillItem::updateRenderNode()
{
    VColor color = mColor;

    color.setAlpha(color.a * parentAlpha());
    VBrush brush(color);
    mDrawable->setBrush(brush);
    mDrawable->setFillRule(mFillRule);
}

LOTGFillItem::LOTGFillItem(LOTGFillData *data)
    : LOTPaintDataItem(data->isStatic()), mData(data)
{
}

void LOTGFillItem::updateContent(int frameNo)
{
    mAlpha = mData->opacity(frameNo);
    mData->update(mGradient, frameNo);
    mGradient->mMatrix = static_cast<LOTContentGroupItem *>(parent())->matrix();
    mFillRule = mData->fillRule();
}

void LOTGFillItem::updateRenderNode()
{
    mGradient->setAlpha(mAlpha * parentAlpha());
    mDrawable->setBrush(VBrush(mGradient.get()));
    mDrawable->setFillRule(mFillRule);
}

LOTStrokeItem::LOTStrokeItem(LOTStrokeData *data)
    : LOTPaintDataItem(data->isStatic()), mData(data)
{
    mDashArraySize = 0;
}

void LOTStrokeItem::updateContent(int frameNo)
{
    LottieColor c = mData->mColor.value(frameNo);
    float       opacity = mData->opacity(frameNo);
    mColor = c.toColor(opacity);
    mCap = mData->capStyle();
    mJoin = mData->joinStyle();
    mMiterLimit = mData->meterLimit();
    mWidth = mData->width(frameNo);
    if (mData->hasDashInfo()) {
        mDashArraySize = mData->getDashInfo(frameNo, mDashArray);
    }
}

static float getScale(const VMatrix &matrix)
{
    constexpr float SQRT_2 = 1.41421;
    VPointF         p1(0, 0);
    VPointF         p2(SQRT_2, SQRT_2);
    p1 = matrix.map(p1);
    p2 = matrix.map(p2);
    VPointF final = p2 - p1;

    return std::sqrt(final.x() * final.x() + final.y() * final.y()) / 2.0;
}

void LOTStrokeItem::updateRenderNode()
{
    VColor color = mColor;

    color.setAlpha(color.a * parentAlpha());
    VBrush brush(color);
    mDrawable->setBrush(brush);
    float scale = getScale(static_cast<LOTContentGroupItem *>(parent())->matrix());
    mDrawable->setStrokeInfo(mCap, mJoin, mMiterLimit,
                            mWidth * scale);
    if (mDashArraySize) {
        for (int i = 0 ; i < mDashArraySize ; i++)
            mDashArray[i] *= scale;

        /* AE draw the dash even if dash value is 0 */
        if (vCompare(mDashArray[0], 0.0f)) mDashArray[0]= 0.1;

        mDrawable->setDashInfo(mDashArray, mDashArraySize);
    }
}

LOTGStrokeItem::LOTGStrokeItem(LOTGStrokeData *data)
    : LOTPaintDataItem(data->isStatic()), mData(data)
{
    mDashArraySize = 0;
}

void LOTGStrokeItem::updateContent(int frameNo)
{
    mAlpha = mData->opacity(frameNo);
    mData->update(mGradient, frameNo);
    mGradient->mMatrix = static_cast<LOTContentGroupItem *>(parent())->matrix();
    mCap = mData->capStyle();
    mJoin = mData->joinStyle();
    mMiterLimit = mData->meterLimit();
    mWidth = mData->width(frameNo);
    if (mData->hasDashInfo()) {
        mDashArraySize = mData->getDashInfo(frameNo, mDashArray);
    }
}

void LOTGStrokeItem::updateRenderNode()
{
    float scale = getScale(mGradient->mMatrix);
    mGradient->setAlpha(mAlpha * parentAlpha());
    mDrawable->setBrush(VBrush(mGradient.get()));
    mDrawable->setStrokeInfo(mCap, mJoin, mMiterLimit,
                            mWidth * scale);
    if (mDashArraySize) {
        for (int i = 0 ; i < mDashArraySize ; i++)
            mDashArray[i] *= scale;
        mDrawable->setDashInfo(mDashArray, mDashArraySize);
    }
}

LOTTrimItem::LOTTrimItem(LOTTrimData *data) : mData(data) {}

void LOTTrimItem::update(int frameNo, const VMatrix &/*parentMatrix*/,
                         float /*parentAlpha*/, const DirtyFlag &/*flag*/)
{
    mDirty = false;

    if (mCache.mFrameNo == frameNo) return;

    LOTTrimData::Segment segment = mData->segment(frameNo);

    if (!(vCompare(mCache.mSegment.start, segment.start) &&
          vCompare(mCache.mSegment.end, segment.end))) {
        mDirty = true;
        mCache.mSegment = segment;
    }
    mCache.mFrameNo = frameNo;
}

void LOTTrimItem::update()
{
    // when both path and trim are not dirty
    if (!(mDirty || pathDirty())) return;

    if (vCompare(mCache.mSegment.start, mCache.mSegment.end)) {
        for (auto &i : mPathItems) {
            i->updatePath(VPath());
        }
        return;
    }

    if (vCompare(std::fabs(mCache.mSegment.start - mCache.mSegment.end) , 1)) {
        for (auto &i : mPathItems) {
            i->updatePath(i->localPath());
        }
        return;
    }

    if (mData->type() == LOTTrimData::TrimType::Simultaneously) {
        for (auto &i : mPathItems) {
            VPathMesure pm;
            pm.setStart(mCache.mSegment.start);
            pm.setEnd(mCache.mSegment.end);
            i->updatePath(pm.trim(i->localPath()));
        }
    } else { // LOTTrimData::TrimType::Individually
        float totalLength = 0.0;
        for (auto &i : mPathItems) {
            totalLength += i->localPath().length();
        }
        float start = totalLength * mCache.mSegment.start;
        float end  = totalLength * mCache.mSegment.end;

        if (start < end ) {
            float curLen = 0.0;
            for (auto &i : mPathItems) {
                if (curLen > end) {
                    // update with empty path.
                    i->updatePath(VPath());
                    continue;
                }
                float len = i->localPath().length();

                if (curLen < start  && curLen + len < start) {
                    curLen += len;
                    // update with empty path.
                    i->updatePath(VPath());
                    continue;
                } else if (start <= curLen && end >= curLen + len) {
                    // inside segment
                    curLen += len;
                    continue;
                } else {
                    float local_start = start > curLen ? start - curLen : 0;
                    local_start /= len;
                    float local_end = curLen + len < end ? len : end - curLen;
                    local_end /= len;
                    VPathMesure pm;
                    pm.setStart(local_start);
                    pm.setEnd(local_end);
                    VPath p = pm.trim(i->localPath());
                    i->updatePath(p);
                    curLen += len;
                }
            }
        }
    }

}


void LOTTrimItem::addPathItems(std::vector<LOTPathDataItem *> &list, int startOffset)
{
    std::copy(list.begin() + startOffset, list.end(), back_inserter(mPathItems));
}


LOTRepeaterItem::LOTRepeaterItem(LOTRepeaterData *data) : mData(data)
{
    assert(mData->mChildren.size() == 1);
    LOTGroupData *root = reinterpret_cast<LOTGroupData *>(mData->mChildren[0].get());
    assert(root);

    for (int i= 0; i < mData->copies(0); i++) {
        auto content = std::make_unique<LOTContentGroupItem>(static_cast<LOTGroupData *>(root));
        content->setParent(this);
        mContents.push_back(std::move(content));
    }
}

void LOTRepeaterItem::update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag)
{

    DirtyFlag newFlag = flag;

    if (mData->hasMtrixChange(frameNo)) {
        newFlag |= DirtyFlagBit::Matrix;
    }

    float multiplier = mData->offset(frameNo);
    float startOpacity = mData->mTransform->startOpacity(frameNo);
    float endOpacity = mData->mTransform->endOpacity(frameNo);
    float index = 0;
    float copies = mData->copies(frameNo);
    if (!vCompare(copies, 1)) copies -=1;

    newFlag |= DirtyFlagBit::Alpha;
    for (const auto &content : mContents) {
        float newAlpha = parentAlpha * lerp(startOpacity, endOpacity, index / copies);
        VMatrix result = mData->mTransform->matrixForRepeater(frameNo, multiplier) * parentMatrix;
        content->update(frameNo, result, newAlpha, newFlag);
        multiplier += 1;
        index +=1;
    }
}

static void updateGStops(LOTNode *n, const VGradient *grad)
{
    if (grad->mStops.size() != n->mGradient.stopCount) {
        if (n->mGradient.stopCount)
            free(n->mGradient.stopPtr);
        n->mGradient.stopCount = grad->mStops.size();
        n->mGradient.stopPtr = (LOTGradientStop *) malloc(n->mGradient.stopCount * sizeof(LOTGradientStop));
    }

    LOTGradientStop *ptr = n->mGradient.stopPtr;
    for (const auto &i : grad->mStops) {
        ptr->pos = i.first;
        ptr->a = i.second.alpha() * grad->alpha();
        ptr->r = i.second.red();
        ptr->g = i.second.green();
        ptr->b = i.second.blue();
        ptr++;
    }

}

void LOTDrawable::sync()
{
    if (!mCNode) {
        mCNode = std::make_unique<LOTNode>();
        mCNode->mGradient.stopPtr = nullptr;
        mCNode->mGradient.stopCount = 0;
    }

    mCNode->mFlag = ChangeFlagNone;
    if (mFlag & DirtyState::None) return;

    if (mFlag & DirtyState::Path) {
        if (mStroke.mDash.size()) {
            VDasher dasher(mStroke.mDash.data(), mStroke.mDash.size());
            mPath = dasher.dashed(mPath);
        }
        const std::vector<VPath::Element> &elm = mPath.elements();
        const std::vector<VPointF> &       pts = mPath.points();
        const float *ptPtr = reinterpret_cast<const float *>(pts.data());
        const char * elmPtr = reinterpret_cast<const char *>(elm.data());
        mCNode->mPath.elmPtr = elmPtr;
        mCNode->mPath.elmCount = elm.size();
        mCNode->mPath.ptPtr = ptPtr;
        mCNode->mPath.ptCount = 2 * pts.size();
        mCNode->mFlag |= ChangeFlagPath;
    }

    if (mStroke.enable) {
        mCNode->mStroke.width = mStroke.width;
        mCNode->mStroke.meterLimit = mStroke.meterLimit;
        mCNode->mStroke.enable = 1;

        switch (mStroke.cap) {
        case CapStyle::Flat:
            mCNode->mStroke.cap = LOTCapStyle::CapFlat;
            break;
        case CapStyle::Square:
            mCNode->mStroke.cap = LOTCapStyle::CapSquare;
            break;
        case CapStyle::Round:
            mCNode->mStroke.cap = LOTCapStyle::CapRound;
            break;
        default:
            mCNode->mStroke.cap = LOTCapStyle::CapFlat;
            break;
        }

        switch (mStroke.join) {
        case JoinStyle::Miter:
            mCNode->mStroke.join = LOTJoinStyle::JoinMiter;
            break;
        case JoinStyle::Bevel:
            mCNode->mStroke.join = LOTJoinStyle::JoinBevel;
            break;
        case JoinStyle::Round:
            mCNode->mStroke.join = LOTJoinStyle::JoinRound;
            break;
        default:
            mCNode->mStroke.join = LOTJoinStyle::JoinMiter;
            break;
        }
    } else {
        mCNode->mStroke.enable = 0;
    }

    switch (mFillRule) {
    case FillRule::EvenOdd:
        mCNode->mFillRule = LOTFillRule::FillEvenOdd;
        break;
    default:
        mCNode->mFillRule = LOTFillRule::FillWinding;
        break;
    }

    switch (mBrush.type()) {
    case VBrush::Type::Solid:
        mCNode->mBrushType = LOTBrushType::BrushSolid;
        mCNode->mColor.r = mBrush.mColor.r;
        mCNode->mColor.g = mBrush.mColor.g;
        mCNode->mColor.b = mBrush.mColor.b;
        mCNode->mColor.a = mBrush.mColor.a;
        break;
    case VBrush::Type::LinearGradient: {
        mCNode->mBrushType = LOTBrushType::BrushGradient;
        mCNode->mGradient.type = LOTGradientType::GradientLinear;
        VPointF s = mBrush.mGradient->mMatrix.map({mBrush.mGradient->linear.x1,
                                                   mBrush.mGradient->linear.y1});
        VPointF e = mBrush.mGradient->mMatrix.map({mBrush.mGradient->linear.x2,
                                                   mBrush.mGradient->linear.y2});
        mCNode->mGradient.start.x = s.x();
        mCNode->mGradient.start.y = s.y();
        mCNode->mGradient.end.x = e.x();
        mCNode->mGradient.end.y = e.y();
        updateGStops(mCNode.get(), mBrush.mGradient);
        break;
    }
    case VBrush::Type::RadialGradient: {
        mCNode->mBrushType = LOTBrushType::BrushGradient;
        mCNode->mGradient.type = LOTGradientType::GradientRadial;
        VPointF c = mBrush.mGradient->mMatrix.map({mBrush.mGradient->radial.cx,
                                                   mBrush.mGradient->radial.cy});
        VPointF f = mBrush.mGradient->mMatrix.map({mBrush.mGradient->radial.fx,
                                                   mBrush.mGradient->radial.fy});
        mCNode->mGradient.center.x = c.x();
        mCNode->mGradient.center.y = c.y();
        mCNode->mGradient.focal.x = f.x();
        mCNode->mGradient.focal.y = f.y();

        float scale = getScale(mBrush.mGradient->mMatrix);
        mCNode->mGradient.cradius = mBrush.mGradient->radial.cradius * scale;
        mCNode->mGradient.fradius = mBrush.mGradient->radial.fradius * scale;
        updateGStops(mCNode.get(), mBrush.mGradient);
        break;
    }
    default:
        break;
    }
}
