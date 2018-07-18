#include "lottieitem.h"
#include"vbitmap.h"
#include"vpainter.h"
#include"vraster.h"
#include"vdasher.h"
#include <cmath>


VDrawable::VDrawable():mFlag(DirtyState::All),
                       mType(Type::Fill),
                       mFillRule(FillRule::Winding)
{
    mStroke.dashArraySize = 0;
    mStroke.cap = CapStyle::Round;
    mStroke.join= JoinStyle::Round;
    mStroke.meterLimit = 10;
    mStroke.enable = false;
}

void VDrawable::preprocess()
{
    if (mFlag & (DirtyState::Path)) {
        if (mStroke.enable) {
            VPath newPath = mPath;
            if (mStroke.dashArraySize) {
                VDasher dasher(mStroke.dashArray, mStroke.dashArraySize);
                newPath = dasher.dashed(mPath);
            }
            FTOutline *outline = VRaster::toFTOutline(newPath);
            mRle = VRaster::instance().generateStrokeInfo(outline, mStroke.cap, mStroke.join,
                                                          mStroke.width, mStroke.meterLimit);
            VRaster::deleteFTOutline(outline);
        } else {
            FTOutline *outline = VRaster::toFTOutline(mPath);
            mRle = VRaster::instance().generateFillInfo(outline, mFillRule);
            VRaster::deleteFTOutline(outline);
        }
        mFlag &= ~DirtyFlag(DirtyState::Path);
    }
}

void VDrawable::setStrokeInfo(CapStyle cap, JoinStyle join, float meterLimit, float strokeWidth)
{
    mStroke.enable = true;
    mStroke.cap = cap;
    mStroke.join = join;
    mStroke.meterLimit = meterLimit;
    mStroke.width = strokeWidth;
    mFlag |= DirtyState::Path;
}
void VDrawable::setDashInfo(float *array, int size)
{
    mStroke.dashArray = array;
    mStroke.dashArraySize = size;
    mFlag |= DirtyState::Path;
}

void VDrawable::sync()
{
    mCNode.mFlag = ChangeFlagNone;
    if (mFlag & DirtyState::None) return;

    if (mFlag & DirtyState::Path) {
        const std::vector<VPath::Element> &elm = mPath.elements();
        const std::vector<VPointF> &pts  = mPath.points();
        const float *ptPtr = reinterpret_cast<const float *>(pts.data());
        const char *elmPtr = reinterpret_cast<const char *>(elm.data());
        mCNode.mPath.elmPtr = elmPtr;
        mCNode.mPath.elmCount = elm.size();
        mCNode.mPath.ptPtr = ptPtr;
        mCNode.mPath.ptCount = 2 * pts.size();
        mCNode.mFlag |= ChangeFlagPath;
    }

    if (mStroke.enable) {
        mCNode.mStroke.width = mStroke.width;
        mCNode.mStroke.meterLimit = mStroke.meterLimit;
        mCNode.mStroke.enable = 1;

        switch (mFillRule) {
        case FillRule::EvenOdd:
            mCNode.mFillRule = LOTNode::EvenOdd;
            break;
        default:
            mCNode.mFillRule = LOTNode::Winding;
            break;
        }

        switch (mStroke.cap) {
        case CapStyle::Flat:
            mCNode.mStroke.cap = LOTNode::FlatCap;
            break;
        case CapStyle::Square:
            mCNode.mStroke.cap = LOTNode::SquareCap;
            break;
        case CapStyle::Round:
            mCNode.mStroke.cap = LOTNode::RoundCap;
            break;
        default:
            mCNode.mStroke.cap = LOTNode::FlatCap;
            break;
        }

        switch (mStroke.join) {
        case JoinStyle::Miter:
            mCNode.mStroke.join = LOTNode::MiterJoin;
            break;
        case JoinStyle::Bevel:
            mCNode.mStroke.join = LOTNode::BevelJoin;
            break;
        case JoinStyle::Round:
            mCNode.mStroke.join = LOTNode::RoundJoin;
            break;
        default:
            mCNode.mStroke.join = LOTNode::MiterJoin;
            break;
        }

        mCNode.mStroke.dashArray = mStroke.dashArray;
        mCNode.mStroke.dashArraySize = mStroke.dashArraySize;

    } else {
        mCNode.mStroke.enable = 0;
    }

    switch (mBrush.type()) {
    case VBrush::Type::Solid:
        mCNode.mType = LOTNode::BrushSolid;
        mCNode.mColor.r = mBrush.mColor.r;
        mCNode.mColor.g = mBrush.mColor.g;
        mCNode.mColor.b = mBrush.mColor.b;
        mCNode.mColor.a = mBrush.mColor.a;
        break;
    case VBrush::Type::LinearGradient:
        mCNode.mType = LOTNode::BrushGradient;
        mCNode.mGradient.type = LOTNode::Gradient::Linear;
        mCNode.mGradient.start.x = mBrush.mGradient->linear.x1;
        mCNode.mGradient.start.y = mBrush.mGradient->linear.y1;
        mCNode.mGradient.end.x = mBrush.mGradient->linear.x2;
        mCNode.mGradient.end.y = mBrush.mGradient->linear.y2;
        break;
    case VBrush::Type::RadialGradient:
        mCNode.mType = LOTNode::BrushGradient;
        mCNode.mGradient.type = LOTNode::Gradient::Radial;
        mCNode.mGradient.center.x = mBrush.mGradient->radial.cx;
        mCNode.mGradient.center.y = mBrush.mGradient->radial.cy;
        mCNode.mGradient.focal.x = mBrush.mGradient->radial.fx;
        mCNode.mGradient.focal.y = mBrush.mGradient->radial.fy;
        mCNode.mGradient.cradius = mBrush.mGradient->radial.cradius;
        mCNode.mGradient.fradius = mBrush.mGradient->radial.fradius;
        break;
    default:
        break;
    }
}

/* Lottie Layer Rules
 * 1. time stretch is pre calculated and applied to all the properties of the lottilayer model and all its children
 * 2. The frame property could be reversed using,time-reverse layer property in AE. which means (start frame > endFrame)
 * 3.
 */

LOTCompItem::LOTCompItem(LOTModel *model):mRootModel(model), mUpdateViewBox(false),mCurFrameNo(-1)
{
   // 1. build layer item list
   mCompData = model->mRoot.get();
   for(auto i : mCompData->mChildren) {
      LOTLayerData *layerData = dynamic_cast<LOTLayerData *>(i.get());
      if (layerData) {
         LOTLayerItem *layerItem = LOTCompItem::createLayerItem(layerData);
         if (layerItem) {
            mLayers.push_back(layerItem);
            mLayerMap[layerItem->id()] = layerItem;
         }
      }
   }

   //2. update parent layer
   for(auto i : mLayers) {
      int id = i->parentId();
      if (id >=0) {
         auto search = mLayerMap.find(id);
         if (search != mLayerMap.end()) {
           LOTLayerItem *parentLayer = search->second;
           i->setParentLayer(parentLayer);
         }
      }
   }
   //3. update static property of each layer
   for(auto i : mLayers) {
      i->updateStaticProperty();
   }

   mViewSize = mCompData->size();
}

LOTCompItem::~LOTCompItem()
{
    for(auto i : mLayers) {
       delete i;
    }
}

LOTLayerItem *
LOTCompItem::createLayerItem(LOTLayerData *layerData)
{
    switch(layerData->mLayerType) {
        case LayerType::Precomp: {
            return new LOTCompLayerItem(layerData);
            break;
        }
        case LayerType::Solid: {
            return new LOTSolidLayerItem(layerData);
            break;
        }
        case LayerType::Shape: {
            return new LOTShapeLayerItem(layerData);
            break;
        }
        case LayerType::Null: {
            return new LOTNullLayerItem(layerData);
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
   VMatrix m;
   float sx, sy;

   // check if cached frame is same as requested frame.
   if (!mUpdateViewBox && (mCurFrameNo == frameNo)) return false;

   sx = mViewSize.width() / float(mCompData->size().width());
   sy = mViewSize.height() / float(mCompData->size().height());
   float scale = fmin(sx, sy);
   m.scale(scale, scale);

   // update the layer from back to front
   for (auto i = mLayers.rbegin(); i != mLayers.rend(); ++i) {
      LOTLayerItem *layer = *i;
      layer->update(frameNo, m, 1.0);
   }
   buildRenderList();
   mCurFrameNo = frameNo;
   mUpdateViewBox = false;
   return true;
}

void LOTCompItem::buildRenderList()
{
    mRenderList.clear();
    std::vector<VDrawable *> list;
    for (auto i = mLayers.rbegin(); i != mLayers.rend(); ++i) {
       LOTLayerItem *layer = *i;
       layer->renderList(list);
    }

    for(auto i : list) {
        i->sync();
        mRenderList.push_back(&i->mCNode);
    }
}

const std::vector<LOTNode *>& LOTCompItem::renderList() const
{
    return mRenderList;
}

bool LOTCompItem::render(const LOTBuffer &buffer)
{
    VBitmap bitmap((uchar *)buffer.buffer, buffer.width, buffer.height,
                   buffer.bytesPerLine, VBitmap::Format::ARGB32_Premultiplied, nullptr, nullptr);

    VPainter painter(&bitmap);
    VRle mask;
    for (auto i = mLayers.rbegin(); i != mLayers.rend(); ++i) {
       LOTLayerItem *layer = *i;
       layer->render(&painter, mask);
    }

    return true;
}

void LOTMaskItem::update(int frameNo, const VMatrix &parentMatrix,
                         float parentAlpha, const DirtyFlag &flag)
{
    if (mData->mShape.isStatic()) {
        if (mLocalPath.isEmpty()) {
            mLocalPath = mData->mShape.value(frameNo).toPath();
        }
    } else {
        mLocalPath = mData->mShape.value(frameNo).toPath();
    }
    float opacity = mData->opacity(frameNo);
    opacity = opacity * parentAlpha;

    VPath path = mLocalPath;
    path.transform(parentMatrix);

    FTOutline *outline = VRaster::toFTOutline(path);
    mRle = VRaster::instance().generateFillInfo(outline);
    VRaster::deleteFTOutline(outline);

    mRle = mRle * (opacity * 255);

    if (mData->mInv) {
        mRle = ~mRle;
    }
}

void LOTLayerItem::render(VPainter *painter, const VRle &inheritMask)
{
    std::vector<VDrawable *> list;
    renderList(list);
    VRle mask = inheritMask;
    if (hasMask()) {
        if (mask.isEmpty())
            mask = maskRle(painter->clipBoundingRect());
        else
            mask = mask & inheritMask;
    }
    for(auto i : list) {
        i->preprocess();
        painter->setBrush(i->mBrush);
        if (!mask.isEmpty()) {
            VRle rle = i->mRle & mask;
            painter->drawRle(VPoint(), rle);
        } else {
            painter->drawRle(VPoint(), i->mRle);
        }
    }
}

VRle LOTLayerItem::maskRle(const VRect &clipRect)
{
    VRle rle;
    for (auto &i : mMasks) {
        switch (i->maskMode()) {
            case LOTMaskData::Mode::Add: {
                rle = rle + i->mRle;
                break;
            }
            case LOTMaskData::Mode::Substarct: {
                if (rle.isEmpty() && !clipRect.isEmpty())
                    rle = VRle::toRle(clipRect);
                rle = rle - i->mRle;
                break;
            }
            case LOTMaskData::Mode::Intersect: {
                rle = rle & i->mRle;
                break;
            }
            default:
                break;
        }
    }
    return rle;
}

LOTLayerItem::LOTLayerItem(LOTLayerData *layerData):mLayerData(layerData),
                                                    mParentLayer(nullptr),
                                                    mPrecompLayer(nullptr),
                                                    mFrameNo(-1),
                                                    mDirtyFlag(DirtyFlagBit::All)
{
    if (mLayerData->mHasMask) {
        for (auto i : mLayerData->mMasks) {
            mMasks.push_back(std::unique_ptr<LOTMaskItem>(new LOTMaskItem(i.get())));
        }
    }
}

void LOTLayerItem::updateStaticProperty()
{
   if (mParentLayer)
     mParentLayer->updateStaticProperty();

   mStatic = mLayerData->isStatic();
   mStatic = mParentLayer ? (mStatic & mParentLayer->isStatic()) : mStatic;
   mStatic = mPrecompLayer ? (mStatic & mPrecompLayer->isStatic()) : mStatic;
}

void LOTLayerItem::update(int frameNo, const VMatrix &parentMatrix, float parentAlpha)
{
   mFrameNo = frameNo;
   // 1. check if the layer is part of the current frame
   if (!visible()) return;

   // 2. calculate the parent matrix and alpha
   VMatrix m = matrix(frameNo) * parentMatrix;
   float alpha = parentAlpha * opacity(frameNo);

   //6. update the mask
   if (hasMask()) {
       for (auto &i : mMasks)
           i->update(frameNo, m, alpha, mDirtyFlag);
   }

   // 3. update the dirty flag based on the change
   if (!mCombinedMatrix.fuzzyCompare(m)) {
       mDirtyFlag |= DirtyFlagBit::Matrix;
   }
   if (!vCompare(mCombinedAlpha, alpha)) {
       mDirtyFlag |= DirtyFlagBit::Alpha;
   }
   mCombinedMatrix = m;
   mCombinedAlpha = alpha;

   // 4. if no parent property change and layer is static then nothing to do.
   if ((flag() & DirtyFlagBit::None) && isStatic())
      return;

   //5. update the content of the layer
   updateContent();

   //6. reset the dirty flag
   mDirtyFlag = DirtyFlagBit::None;
}

float
LOTLayerItem::opacity(int frameNo) const
{
   return mLayerData->mTransform->opacity(frameNo);
}

VMatrix
LOTLayerItem::matrix(int frameNo) const
{
    if (mParentLayer)
        return mLayerData->mTransform->matrix(frameNo) * mParentLayer->matrix(frameNo);
    else
        return mLayerData->mTransform->matrix(frameNo);
}

bool LOTLayerItem::visible() const
{
   if (frameNo() >= mLayerData->inFrame() && frameNo() < mLayerData->outFrame())
      return true;
   else
      return false;
}



LOTCompLayerItem::LOTCompLayerItem(LOTLayerData *layerModel):LOTLayerItem(layerModel)
{
   for(auto i : mLayerData->mChildren) {
      LOTLayerData *layerModel = dynamic_cast<LOTLayerData *>(i.get());
      if (layerModel) {
         LOTLayerItem *layerItem = LOTCompItem::createLayerItem(layerModel);
         if (layerItem) {
            mLayers.push_back(layerItem);
            mLayerMap[layerItem->id()] = layerItem;
         }
      }
   }

   //2. update parent layer
   for(auto i : mLayers) {
      int id = i->parentId();
      if (id >=0) {
         auto search = mLayerMap.find(id);
         if (search != mLayerMap.end()) {
           LOTLayerItem *parentLayer = search->second;
           i->setParentLayer(parentLayer);
         }
      }
      i->setPrecompLayer(this);
   }
}

void LOTCompLayerItem::updateStaticProperty()
{
    LOTLayerItem::updateStaticProperty();

    for(auto i : mLayers) {
       i->updateStaticProperty();
    }
}

void LOTCompLayerItem::render(VPainter *painter, const VRle &inheritMask)
{
    VRle mask = inheritMask;

    if (hasMask()) {
        if (mask.isEmpty())
            mask = maskRle(painter->clipBoundingRect());
        else
            mask = mask & inheritMask;
    }

    for(auto i : mLayers) {
       i->render(painter, mask);
    }
}

LOTCompLayerItem::~LOTCompLayerItem()
{
    for(auto i : mLayers) {
       delete i;
    }
}

void LOTCompLayerItem::updateContent()
{
    // update the layer from back to front
    for (auto i = mLayers.rbegin(); i != mLayers.rend(); ++i) {
       LOTLayerItem *layer = *i;
       layer->update(frameNo(), combinedMatrix(), combinedAlpha());
    }
}

void LOTCompLayerItem::renderList(std::vector<VDrawable *> &list)
{
    if (!visible()) return;

    // update the layer from back to front
    for (auto i = mLayers.rbegin(); i != mLayers.rend(); ++i) {
       LOTLayerItem *layer = *i;
       layer->renderList(list);
    }
}

LOTSolidLayerItem::LOTSolidLayerItem(LOTLayerData *layerData):LOTLayerItem(layerData)
{

}

void LOTSolidLayerItem::updateContent()
{
   if (!mRenderNode) {
      mRenderNode = std::unique_ptr<VDrawable>(new VDrawable());
      mRenderNode->mType = VDrawable::Type::Fill;
      mRenderNode->mFlag |= VDrawable::DirtyState::All;
   }

   if (flag() & DirtyFlagBit::Matrix) {
       VPath path;
       path.addRect(VRectF(0, 0, mLayerData->solidWidth(), mLayerData->solidHeight()));
       path.transform(combinedMatrix());
       mRenderNode->mFlag |= VDrawable::DirtyState::Path;
       mRenderNode->mPath = path;
   }
   if (flag() & DirtyFlagBit::Alpha) {
       LottieColor color = mLayerData->solidColor();
       VBrush brush(color.toColor(combinedAlpha()));
       mRenderNode->setBrush(brush);
       mRenderNode->mFlag |= VDrawable::DirtyState::Brush;
   }
}

void LOTSolidLayerItem::renderList(std::vector<VDrawable *> &list)
{
    if (!visible()) return;

    list.push_back(mRenderNode.get());
}

LOTNullLayerItem::LOTNullLayerItem(LOTLayerData *layerData):LOTLayerItem(layerData)
{

}
void LOTNullLayerItem::updateContent()
{

}


LOTShapeLayerItem::LOTShapeLayerItem(LOTLayerData *layerData):LOTLayerItem(layerData)
{
    mRoot = new LOTContentGroupItem(nullptr);
    mRoot->addChildren(layerData);
    mRoot->processPaintOperation();
}

LOTShapeLayerItem::~LOTShapeLayerItem()
{
    delete mRoot;
}

LOTContentItem * LOTShapeLayerItem::createContentItem(LOTData *contentData)
{
    switch(contentData->type()) {
        case LOTData::Type::ShapeGroup: {
            return new LOTContentGroupItem(static_cast<LOTShapeGroupData *>(contentData));
            break;
        }
        case LOTData::Type::Rect: {
            return new LOTRectItem(static_cast<LOTRectData *>(contentData));
            break;
        }
        case LOTData::Type::Ellipse: {
            return new LOTEllipseItem(static_cast<LOTEllipseData *>(contentData));
            break;
        }
        case LOTData::Type::Shape: {
            return new LOTShapeItem(static_cast<LOTShapeData *>(contentData));
            break;
        }
        case LOTData::Type::Polystar: {
            return new LOTPolystarItem(static_cast<LOTPolystarData *>(contentData));
            break;
        }
        case LOTData::Type::Fill: {
            return new LOTFillItem(static_cast<LOTFillData *>(contentData));
            break;
        }
        case LOTData::Type::GFill: {
            return new LOTGFillItem(static_cast<LOTGFillData *>(contentData));
            break;
        }
        case LOTData::Type::Stroke: {
            return new LOTStrokeItem(static_cast<LOTStrokeData *>(contentData));
            break;
        }
        case LOTData::Type::GStroke: {
            return new LOTGStrokeItem(static_cast<LOTGStrokeData *>(contentData));
            break;
        }
        case LOTData::Type::Repeater: {
                return new LOTRepeaterItem(static_cast<LOTRepeaterData *>(contentData));
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
}

void LOTShapeLayerItem::renderList(std::vector<VDrawable *> &list)
{
    if (!visible()) return;
    mRoot->renderList(list);
}

LOTContentGroupItem::LOTContentGroupItem(LOTShapeGroupData *data):mData(data)
{
   addChildren(mData);
}

void LOTContentGroupItem::addChildren(LOTGroupData *data)
{
   if (!data) return;

   for(auto i : data->mChildren) {
      LOTData *data = i.get();
      LOTContentItem *content = LOTShapeLayerItem::createContentItem(data);
      if (content)
         mContents.push_back(content);
   }
}

LOTContentGroupItem::~LOTContentGroupItem()
{
    for(auto i : mContents) {
        delete i;
    }
}


void LOTContentGroupItem::update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag)
{
   VMatrix m = parentMatrix;
   float alpha = parentAlpha;
   DirtyFlag newFlag = flag;

   if (mData) {
      // update the matrix and the flag
      if ((flag & DirtyFlagBit::Matrix) || !mData->mTransform->staticMatrix() ) {
         newFlag |= DirtyFlagBit::Matrix;
      }
      m = mData->mTransform->matrix(frameNo) * parentMatrix;
      alpha *= mData->mTransform->opacity(frameNo);

      if (!vCompare(alpha, parentAlpha)) {
         newFlag |= DirtyFlagBit::Alpha;
      }
   }

   for (auto i = mContents.rbegin(); i != mContents.rend(); ++i) {
      (*i)->update(frameNo, m, alpha, newFlag);
   }
}

void LOTContentGroupItem::renderList(std::vector<VDrawable *> &list)
{
    for (auto i = mContents.rbegin(); i != mContents.rend(); ++i) {
       (*i)->renderList(list);
    }
}

void LOTContentGroupItem::processPaintOperation()
{
   std::vector<LOTPaintDataItem *> list;
   paintOperationHelper(list);
}

void LOTContentGroupItem::paintOperationHelper(std::vector<LOTPaintDataItem *> &list)
{
   int curOpCount = list.size();
   for (auto i = mContents.rbegin(); i != mContents.rend(); ++i) {
      auto child = *i;
      if (auto pathNode = dynamic_cast<LOTPathDataItem *>(child)) {
         // the node is a path data node add the paint operation list to it.
         pathNode->addPaintOperation(list, curOpCount);
      } else if (auto paintNode = dynamic_cast<LOTPaintDataItem *>(child)) {
         // add it to the paint operation list
         list.push_back(paintNode);
      } else if (auto groupNode = dynamic_cast<LOTContentGroupItem *>(child)) {
         // update the groups node with current list
         groupNode->paintOperationHelper(list);
      }
   }
   list.erase(list.begin() + curOpCount, list.end());
}

void LOTPathDataItem::addPaintOperation(std::vector<LOTPaintDataItem *> &list, int externalCount)
{
    for(auto paintItem : list) {
      bool sameGroup = (externalCount-- > 0) ? false : true;
      mNodeList.push_back(std::unique_ptr<VDrawable>(new VDrawable()));
      mRenderList.push_back(LOTRenderNode(this, paintItem, mNodeList.back().get(), sameGroup));
    }
}


void LOTPathDataItem::update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag)
{
   mPathChanged = false;
   mCombinedAlpha = parentAlpha;

   // 1. update the local path if needed
   if (!(mInit && mStaticPath)) {
      mLocalPath = getPath(frameNo);
      mInit = true;
      mPathChanged = true;
   }

   // 2. apply path operation if needed
   // TODO

   // 3. compute the final path with parentMatrix
   if ((flag & DirtyFlagBit::Matrix) || mPathChanged) {
      mFinalPath = mLocalPath;
      mFinalPath.transform(parentMatrix);
      mPathChanged = true;
   }

   // 2. update the rendernode list
   for (const auto &i : mRenderList) {
      i.drawable->mFlag = VDrawable::DirtyState::None;
      i.paintNodeRef->updateRenderNode(i.pathNodeRef, i.drawable, i.sameGroup);
      if (mPathChanged) {
          i.drawable->mPath = mFinalPath;
          i.drawable->mFlag |= VDrawable::DirtyState::Path;
      }
   }
}

void LOTPathDataItem::renderList(std::vector<VDrawable *> &list)
{
   for (const auto &i : mRenderList) {
       list.push_back(i.drawable);
   }
}

VPath LOTPathDataItem::path() const
{
   return mFinalPath;
}


LOTRectItem::LOTRectItem(LOTRectData *data):LOTPathDataItem(data->isStatic()),mData(data)
{
}

VPath LOTRectItem::getPath(int frameNo)
{
   VPointF pos = mData->mPos.value(frameNo);
   VPointF size = mData->mSize.value(frameNo);
   float radius = mData->mRound.value(frameNo);
   VRectF r(pos.x() - size.x()/2, pos.y() - size.y()/2, size.x(), size.y());

   VPath path;
   path.addRoundRect(r, radius, radius, mData->direction());

   return path;
}

LOTEllipseItem::LOTEllipseItem(LOTEllipseData *data):LOTPathDataItem(data->isStatic()),mData(data)
{

}

VPath LOTEllipseItem::getPath(int frameNo)
{
   VPointF pos = mData->mPos.value(frameNo);
   VPointF size = mData->mSize.value(frameNo);
   VRectF r(pos.x() - size.x()/2, pos.y() - size.y()/2, size.x(), size.y());

   VPath path;
   path.addOval(r, mData->direction());

   return path;
}

LOTShapeItem::LOTShapeItem(LOTShapeData *data):LOTPathDataItem(data->isStatic()),mData(data)
{

}

VPath LOTShapeItem::getPath(int frameNo)
{
    LottieShapeData shapeData = mData->mShape.value(frameNo);

    if (shapeData.mPoints.empty())
     return VPath();

    VPath path;

    int size = shapeData.mPoints.size();
    const VPointF *points = shapeData.mPoints.data();
    path.moveTo(points[0]);
    for (int i = 1 ; i < size; i+=3) {
       path.cubicTo(points[i], points[i+1], points[i+2]);
    }
    if (shapeData.mClosed)
      path.close();

   return path;
}


LOTPolystarItem::LOTPolystarItem(LOTPolystarData *data):LOTPathDataItem(data->isStatic()),mData(data)
{

}

VPath LOTPolystarItem::getPath(int frameNo)
{
   VPointF pos = mData->mPos.value(frameNo);
   float points = mData->mPointCount.value(frameNo);
   float innerRadius = mData->mInnerRadius.value(frameNo);
   float outerRadius = mData->mOuterRadius.value(frameNo);
   float innerRoundness = mData->mInnerRoundness.value(frameNo);
   float outerRoundness = mData->mOuterRoundness.value(frameNo);
   float rotation = mData->mRotation.value(frameNo);

   VPath path;
   VMatrix m;

   if (mData->mType == LOTPolystarData::PolyType::Star) {
        path.addPolystarStar(0.0, 0.0, 0.0, points,
                             innerRadius, outerRadius,
                             innerRoundness, outerRoundness,
                             mData->direction());
   } else {
        path.addPolystarPolygon(0.0, 0.0, 0.0, points,
                                outerRadius, outerRoundness,
                                mData->direction());
   }

   m.translate(pos.x(), pos.y()).rotate(rotation);
   m.rotate(rotation);
   path.transform(m);

   return path;
}



/*
 * PaintData Node handling
 *
 */

void LOTPaintDataItem::update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag)
{
   mContentChanged = false;
   mParentAlpha = parentAlpha;
   mParentMatrix = parentMatrix;
   mFlag = flag;
   mFrameNo = frameNo;
   // 1. update the local content if needed
  // if (!(mInit && mStaticContent)) {
      mInit = true;
      updateContent(frameNo);
      mContentChanged = true;
  // }
}


LOTFillItem::LOTFillItem(LOTFillData *data):LOTPaintDataItem(data->isStatic()),mData(data)
{
}

void LOTFillItem::updateContent(int frameNo)
{
   LottieColor c = mData->mColor.value(frameNo);
   float opacity = mData->opacity(frameNo);
   mColor = c.toColor(opacity);
   mFillRule = mData->fillRule();
}

void LOTFillItem::updateRenderNode(LOTPathDataItem *pathNode, VDrawable *drawable, bool sameParent)
{
    VColor color = mColor;
    if (sameParent)
      color.setAlpha(color.a * pathNode->combinedAlpha());
    else
      color.setAlpha(color.a  * parentAlpha() * pathNode->combinedAlpha());
    VBrush brush(color);
    drawable->setBrush(brush);
    drawable->setFillRule(mFillRule);
}


LOTGFillItem::LOTGFillItem(LOTGFillData *data):LOTPaintDataItem(data->isStatic()),mData(data)
{
}

void LOTGFillItem::updateContent(int frameNo)
{
    mData->update(mGradient, frameNo);
    mGradient->mMatrix = mParentMatrix;
    mFillRule = mData->fillRule();
}

void LOTGFillItem::updateRenderNode(LOTPathDataItem *pathNode, VDrawable *drawable, bool sameParent)
{
    drawable->setBrush(VBrush(mGradient.get()));
    drawable->setFillRule(mFillRule);
}

LOTStrokeItem::LOTStrokeItem(LOTStrokeData *data):LOTPaintDataItem(data->isStatic()),mData(data)
{
    mDashArraySize = 0;
}

void LOTStrokeItem::updateContent(int frameNo)
{
    LottieColor c = mData->mColor.value(frameNo);
    float opacity = mData->opacity(frameNo);
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
    VPointF p1(0,0);
    VPointF p2(SQRT_2,SQRT_2);
    p1 = matrix.map(p1);
    p2 = matrix.map(p2);
    VPointF final = p2 - p1;

    return std::sqrt( final.x() * final.x() + final.y() * final.y());
}

void LOTStrokeItem::updateRenderNode(LOTPathDataItem *pathNode, VDrawable *drawable, bool sameParent)
{
    VColor color = mColor;
    if (sameParent)
      color.setAlpha(color.a * pathNode->combinedAlpha());
    else
      color.setAlpha(color.a  * parentAlpha() * pathNode->combinedAlpha());

    VBrush brush(color);
    drawable->setBrush(brush);

    drawable->setStrokeInfo(mCap, mJoin, mMiterLimit,  mWidth * getScale(mParentMatrix));
    if (mDashArraySize) {
        drawable->setDashInfo(mDashArray, mDashArraySize);
    }
}

LOTGStrokeItem::LOTGStrokeItem(LOTGStrokeData *data):LOTPaintDataItem(data->isStatic()),mData(data)
{
    mDashArraySize = 0;
}

void LOTGStrokeItem::updateContent(int frameNo)
{
    mData->update(mGradient, frameNo);
    mGradient->mMatrix = mParentMatrix;
    mCap = mData->capStyle();
    mJoin = mData->joinStyle();
    mMiterLimit = mData->meterLimit();
    mWidth = mData->width(frameNo);
    if (mData->hasDashInfo()) {
        mDashArraySize = mData->getDashInfo(frameNo, mDashArray);
    }
}

void LOTGStrokeItem::updateRenderNode(LOTPathDataItem *pathNode, VDrawable *drawable, bool sameParent)
{
    drawable->setBrush(VBrush(mGradient.get()));
    drawable->setStrokeInfo(mCap, mJoin, mMiterLimit,  mWidth * getScale(mParentMatrix));
    if (mDashArraySize) {
        drawable->setDashInfo(mDashArray, mDashArraySize);
    }
}

LOTTrimItem::LOTTrimItem(LOTTrimData *data):mData(data)
{

}

LOTRepeaterItem::LOTRepeaterItem(LOTRepeaterData *data):mData(data)
{

}

void LOTRepeaterItem::update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag)
{

}

void LOTRepeaterItem::renderList(std::vector<VDrawable *> &list)
{

}

