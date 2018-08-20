#ifndef LOTTIEITEM_H
#define LOTTIEITEM_H

#include<lottiemodel.h>
#include<sstream>
#include<memory>

#include"vmatrix.h"
#include"vpath.h"
#include"vpoint.h"
#include"vpathmesure.h"
#include"lottieplayer.h"
#include"vpainter.h"
#include"vdrawable.h"

V_USE_NAMESPACE

enum class DirtyFlagBit : uchar
{
   None   = 0x00,
   Matrix = 0x01,
   Alpha  = 0x02,
   All    = (Matrix | Alpha)
};

class LOTLayerItem;
class LOTMaskItem;
class VDrawable;

class LOTCompItem
{
public:
   LOTCompItem(LOTModel *model);
   static LOTLayerItem * createLayerItem(LOTLayerData *layerData);
   bool update(int frameNo);
   void resize(const VSize &size);
   VSize size() const;
   const std::vector<LOTNode *>& renderList()const;
   void buildRenderList();
   bool render(const LOTBuffer &buffer);
private:
   VMatrix                                    mScaleMatrix;
   VSize                                      mViewSize;
   LOTModel                                   *mRootModel;
   LOTCompositionData                         *mCompData;
   std::unique_ptr<LOTLayerItem>               mRootLayer;
   bool                                        mUpdateViewBox;
   int                                         mCurFrameNo;
   std::vector<LOTNode *>                      mRenderList;
   std::vector<VDrawable *>                    mDrawableList;
};

typedef vFlag<DirtyFlagBit> DirtyFlag;
class LOTLayerItem
{
public:
   LOTLayerItem(LOTLayerData *layerData);
   virtual ~LOTLayerItem(){}
   int id() const {return mLayerData->id();}
   int parentId() const {return mLayerData->parentId();}
   void setParentLayer(LOTLayerItem *parent){mParentLayer = parent;}
   void setPrecompLayer(LOTLayerItem *precomp){mPrecompLayer = precomp;}
   virtual void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha);
   VMatrix matrix(int frameNo) const;
   virtual void renderList(std::vector<VDrawable *> &list){}
   virtual void updateStaticProperty();
   virtual void render(VPainter *painter, const VRle &mask, LOTLayerItem *matteSource);
   bool hasMatte() { if (mLayerData->mMatteType == MatteType::None) return false; return true; }

protected:
   virtual void updateContent() = 0;
   inline VMatrix combinedMatrix() const {return mCombinedMatrix;}
   inline int frameNo() const {return mFrameNo;}
   inline float combinedAlpha() const {return mCombinedAlpha;}
   inline bool isStatic() const {return mStatic;}
   float opacity(int frameNo) const;
   bool visible() const;
   inline DirtyFlag flag() const {return mDirtyFlag;}
   VRle maskRle(const VRect &clipRect);
   bool hasMask() const {return !mMasks.empty();}
protected:
   std::vector<VDrawable *>                    mDrawableList;
   std::vector<std::unique_ptr<LOTMaskItem>>   mMasks;
   LOTLayerData                               *mLayerData;
   LOTLayerItem                               *mParentLayer;
   LOTLayerItem                               *mPrecompLayer;
   VMatrix                                    mCombinedMatrix;
   float                                       mCombinedAlpha;
   int                                         mFrameNo;
   DirtyFlag                                   mDirtyFlag;
   bool                                        mVisible;
   bool                                        mStatic;
};

class LOTCompLayerItem: public LOTLayerItem
{
public:
   ~LOTCompLayerItem();
   LOTCompLayerItem(LOTLayerData *layerData);
   void renderList(std::vector<VDrawable *> &list)final;
   void updateStaticProperty() final;
   void render(VPainter *painter, const VRle &mask, LOTLayerItem *matteSource) final;
protected:
   void updateContent() final;
private:
   std::vector<LOTLayerItem *>                  mLayers;
   int                                          mLastFrame;
};

class LOTSolidLayerItem: public LOTLayerItem
{
public:
   LOTSolidLayerItem(LOTLayerData *layerData);
protected:
   void updateContent() final;
   void renderList(std::vector<VDrawable *> &list) final;
private:
   std::unique_ptr<VDrawable>   mRenderNode;
};

class LOTContentItem;
class LOTContentGroupItem;
class LOTShapeLayerItem: public LOTLayerItem
{
public:
   ~LOTShapeLayerItem();
   LOTShapeLayerItem(LOTLayerData *layerData);
   static LOTContentItem * createContentItem(LOTData *contentData);
   void renderList(std::vector<VDrawable *> &list)final;
protected:
   void updateContent() final;
   LOTContentGroupItem       *mRoot;
};

class LOTNullLayerItem: public LOTLayerItem
{
public:
   LOTNullLayerItem(LOTLayerData *layerData);
protected:
   void updateContent() final;
};

class LOTMaskItem
{
public:
    LOTMaskItem(LOTMaskData *data): mData(data), mCombinedAlpha(0){}
    void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag);
    LOTMaskData::Mode maskMode() const { return mData->mMode;}
    VRle rle();
public:
    LOTMaskData             *mData;
    float                    mCombinedAlpha;
    VMatrix                  mCombinedMatrix;
    VPath                    mLocalPath;
    std::future<VRle>        mRleTask;
    VRle                     mRle;
};

class LOTDrawable : public VDrawable
{
public:
    void sync();
public:
    LOTNode           mCNode;
};

class LOTNode;
class LOTPathDataItem;
class LOTPaintDataItem;
class LOTTrimItem;
struct LOTRenderNode
{
   LOTRenderNode(LOTPathDataItem *path, LOTPaintDataItem *paint, VDrawable *render, bool sameG)
                  :pathNodeRef(path), paintNodeRef(paint), drawable(render), sameGroup(sameG){}
   LOTPathDataItem  *pathNodeRef;
   LOTPaintDataItem *paintNodeRef;
   VDrawable        *drawable;
   bool              sameGroup;
};

class LOTContentItem
{
public:
   LOTContentItem(){}
   virtual ~LOTContentItem(){}
   virtual void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag) = 0;
   virtual void renderList(std::vector<VDrawable *> &list){}
};

class LOTContentGroupItem: public LOTContentItem
{
public:
   ~LOTContentGroupItem();
   LOTContentGroupItem(LOTShapeGroupData *data);
   void addChildren(LOTGroupData *data);
   void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag) final;
   void processPaintOperation();
   void processTrimOperation();
   void renderList(std::vector<VDrawable *> &list) final;
private:
   void paintOperationHelper(std::vector<LOTPaintDataItem *> &list);
   void trimOperationHelper(std::vector<LOTTrimItem *> &list);
   LOTShapeGroupData                 *mData;
   std::vector<LOTContentItem *>      mContents;
};

class LOTPathDataItem : public LOTContentItem
{
public:
   LOTPathDataItem(bool staticPath):mInit(false), mStaticPath(staticPath){}
   void addPaintOperation(std::vector<LOTPaintDataItem *> &list, int externalCount);
   void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag) final;
   VPath path() const;
   void addTrimOperation(std::vector<LOTTrimItem *> &list);
   inline float combinedAlpha() const{ return mCombinedAlpha;}
   void renderList(std::vector<VDrawable *> &list) final;
private:
   std::vector<LOTTrimItem *>              mTrimNodeRefs;
   std::vector<LOTRenderNode>              mRenderList;
   std::vector<std::unique_ptr<VDrawable>> mNodeList;
   bool                                    mInit;
   bool                                    mStaticPath;
   VPath                                  mLocalPath;
   VPath                                  mFinalPath;
   bool                                    mPathChanged;
   float                                   mCombinedAlpha;
protected:
   virtual void updatePath(VPath& path, int frameNo) = 0;
   virtual bool hasChanged(int frameNo) = 0;
};

class LOTRectItem: public LOTPathDataItem
{
public:
   LOTRectItem(LOTRectData *data);
protected:
   void updatePath(VPath& path, int frameNo) final;
   LOTRectData           *mData;

   struct Cache {
        int                  mFrameNo{-1};
        VPointF              mPos;
        VPointF              mSize;
        float                mRoundness;
   };
   Cache                     mCache;

   void updateCache(int frameNo, VPointF pos, VPointF size, float roundness) {
        mCache.mFrameNo = frameNo;
        mCache.mPos = pos;
        mCache.mSize = size;
        mCache.mRoundness = roundness;
   }
   bool hasChanged(int frameNo) final {
        if (mCache.mFrameNo == frameNo) return false;

        VPointF pos = mData->mPos.value(frameNo);
        VPointF size = mData->mSize.value(frameNo);
        float   roundness = mData->mRound.value(frameNo);

        if (vCompare(mCache.mPos.x(), pos.x()) && vCompare(mCache.mPos.y(), pos.y()) &&
            vCompare(mCache.mSize.x(), size.x()) && vCompare(mCache.mSize.y(), size.y()) &&
            vCompare(mCache.mRoundness, roundness))
          return false;

        return true;
   }
};

class LOTEllipseItem: public LOTPathDataItem
{
public:
   LOTEllipseItem(LOTEllipseData *data);
private:
   void updatePath(VPath& path, int frameNo) final;
   LOTEllipseData           *mData;

   struct Cache {
        int                  mFrameNo{-1};
        VPointF              mPos;
        VPointF              mSize;
   };
   Cache                     mCache;

   void updateCache(int frameNo, VPointF pos, VPointF size) {
        mCache.mFrameNo = frameNo;
        mCache.mPos = pos;
        mCache.mSize = size;
   }
   bool hasChanged(int frameNo) final {
        if (mCache.mFrameNo == frameNo) return false;

        VPointF pos = mData->mPos.value(frameNo);
        VPointF size = mData->mSize.value(frameNo);

        if (vCompare(mCache.mPos.x(), pos.x()) && vCompare(mCache.mPos.y(), pos.y()) &&
            vCompare(mCache.mSize.x(), size.x()) && vCompare(mCache.mSize.y(), size.y()))
          return false;

        return true;
   }
};

class LOTShapeItem: public LOTPathDataItem
{
public:
   LOTShapeItem(LOTShapeData *data);
private:
   void updatePath(VPath& path, int frameNo) final;
   LOTShapeData             *mData;
   bool hasChanged(int frameNo) final { return true; }
};

class LOTPolystarItem: public LOTPathDataItem
{
public:
   LOTPolystarItem(LOTPolystarData *data);
private:
   void updatePath(VPath& path, int frameNo) final;
   LOTPolystarData             *mData;

   struct Cache {
        int                     mFrameNo{-1};
        VPointF                 mPos;
        float                   mPoints{0};
        float                   mInnerRadius{0};
        float                   mOuterRadius{0};
        float                   mInnerRoundness{0};
        float                   mOuterRoundness{0};
        float                   mRotation{0};
   };
   Cache                        mCache;

   void updateCache(int frameNo, VPointF pos, float points, float innerRadius, float outerRadius,
                    float innerRoundness, float outerRoundness, float rotation) {
        mCache.mFrameNo = frameNo;
        mCache.mPos = pos;
        mCache.mPoints = points;
        mCache.mInnerRadius = innerRadius;
        mCache.mOuterRadius = outerRadius;
        mCache.mInnerRoundness = innerRoundness;
        mCache.mOuterRoundness = outerRoundness;
        mCache.mRotation = rotation;
   }
   bool hasChanged(int frameNo) final {
        if (mCache.mFrameNo == frameNo) return false;

        VPointF pos = mData->mPos.value(frameNo);
        float   points = mData->mPointCount.value(frameNo);
        float   innerRadius = mData->mInnerRadius.value(frameNo);
        float   outerRadius = mData->mOuterRadius.value(frameNo);
        float   innerRoundness = mData->mInnerRoundness.value(frameNo);
        float   outerRoundness = mData->mOuterRoundness.value(frameNo);
        float   rotation = mData->mRotation.value(frameNo);

        if (vCompare(mCache.mPos.x(), pos.x()) && vCompare(mCache.mPos.y(), pos.y()) &&
            vCompare(mCache.mPoints, points) && vCompare(mCache.mRotation, rotation) &&
            vCompare(mCache.mInnerRadius, innerRadius) && vCompare(mCache.mOuterRadius, outerRadius) &&
            vCompare(mCache.mInnerRoundness, innerRoundness) && vCompare(mCache.mOuterRoundness, outerRoundness))
          return false;

        return true;
   }
};



class LOTPaintDataItem : public LOTContentItem
{
public:
   LOTPaintDataItem(bool staticContent):mInit(false), mStaticContent(staticContent){}
   virtual void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag);
   virtual void updateRenderNode(LOTPathDataItem *pathNode, VDrawable *renderer, bool sameParent) = 0;
protected:
   virtual void updateContent(int frameNo) = 0;
   inline float parentAlpha() const {return mParentAlpha;}
   inline bool  contentChanged() const{return mContentChanged;}
public:
   float         mParentAlpha;
   VMatrix      mParentMatrix;
   DirtyFlag     mFlag;
   int           mFrameNo;
   bool          mInit;
   bool          mStaticContent;
   bool          mContentChanged;
};

class LOTFillItem : public LOTPaintDataItem
{
public:
   LOTFillItem(LOTFillData *data);
protected:
   void updateContent(int frameNo) final;
   void updateRenderNode(LOTPathDataItem *pathNode, VDrawable *renderer, bool sameParent) final;
private:
   LOTFillData             *mData;
   VColor                  mColor;
   FillRule                mFillRule;
};

class LOTGFillItem : public LOTPaintDataItem
{
public:
   LOTGFillItem(LOTGFillData *data);
protected:
   void updateContent(int frameNo) final;
   void updateRenderNode(LOTPathDataItem *pathNode, VDrawable *renderer, bool sameParent) final;
private:
   LOTGFillData                 *mData;
   std::unique_ptr<VGradient>    mGradient;
   FillRule                      mFillRule;
};

class LOTStrokeItem : public LOTPaintDataItem
{
public:
   LOTStrokeItem(LOTStrokeData *data);
protected:
   void updateContent(int frameNo) final;
   void updateRenderNode(LOTPathDataItem *pathNode, VDrawable *renderer, bool sameParent) final;
private:
   LOTStrokeData             *mData;
   CapStyle                  mCap;
   JoinStyle                 mJoin;
   float                     mMiterLimit;
   VColor                    mColor;
   float                     mWidth;
   float                     mDashArray[6];
   int                       mDashArraySize;
};

class LOTGStrokeItem : public LOTPaintDataItem
{
public:
   LOTGStrokeItem(LOTGStrokeData *data);
protected:
   void updateContent(int frameNo) final;
   void updateRenderNode(LOTPathDataItem *pathNode, VDrawable *renderer, bool sameParent) final;
private:
   LOTGStrokeData               *mData;
   std::unique_ptr<VGradient>    mGradient;
   CapStyle                      mCap;
   JoinStyle                     mJoin;
   float                         mMiterLimit;
   VColor                        mColor;
   float                         mWidth;
   float                         mDashArray[6];
   int                           mDashArraySize;
};


// Trim Item

class LOTTrimItem : public LOTContentItem
{
public:
   LOTTrimItem(LOTTrimData *data);
   void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag) final;
   float getStart(int frameNo) {return mData->mStart.value(frameNo);}
   float getEnd(int frameNo) {return mData->mEnd.value(frameNo);}
private:
   LOTTrimData             *mData;
};

class LOTRepeaterItem : public LOTContentItem
{
public:
   LOTRepeaterItem(LOTRepeaterData *data);
   virtual void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag) final;
   virtual void renderList(std::vector<VDrawable *> &list) final;
private:
   LOTRepeaterData             *mData;
};


#endif // LOTTIEITEM_H


