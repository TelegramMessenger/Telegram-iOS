#ifndef LOTTIEITEM_H
#define LOTTIEITEM_H

#include<lottiemodel.h>
#include<sstream>
#include<memory>

#include"vmatrix.h"
#include"vpath.h"
#include"vpoint.h"
#include"vpathmesure.h"
#include"lottiecommon.h"
#include"lottieanimation.h"
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
   static std::unique_ptr<LOTLayerItem> createLayerItem(LOTLayerData *layerData);
   bool update(int frameNo);
   void resize(const VSize &size);
   VSize size() const;
   const std::vector<LOTNode *>& renderList()const;
   void buildRenderList();
   void buildRenderTree();
   const LOTLayerNode * renderTree()const;
   bool render(const lottie::Surface &surface);
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
   virtual ~LOTLayerItem()= default;
   int id() const {return mLayerData->id();}
   int parentId() const {return mLayerData->parentId();}
   void setParentLayer(LOTLayerItem *parent){mParentLayer = parent;}
   void setPrecompLayer(LOTLayerItem *precomp){mPrecompLayer = precomp;}
   virtual void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha);
   VMatrix matrix(int frameNo) const;
   virtual void renderList(std::vector<VDrawable *> &){}
   virtual void updateStaticProperty();
   virtual void render(VPainter *painter, const VRle &mask, const VRle &inheritMatte, LOTLayerItem *matteSource);
   bool hasMatte() { if (mLayerData->mMatteType == MatteType::None) return false; return true; }
   bool visible() const;
   virtual void buildLayerNode();
   LOTLayerNode * layerNode() const {return mLayerCNode.get();}
protected:
   virtual void updateContent() = 0;
   inline VMatrix combinedMatrix() const {return mCombinedMatrix;}
   inline int frameNo() const {return mFrameNo;}
   inline float combinedAlpha() const {return mCombinedAlpha;}
   inline bool isStatic() const {return mStatic;}
   float opacity(int frameNo) const;
   inline DirtyFlag flag() const {return mDirtyFlag;}
   VRle maskRle(const VRect &clipRect);
   bool hasMask() const {return !mMasks.empty();}
protected:
   std::unique_ptr<LOTLayerNode>               mLayerCNode;
   std::vector<VDrawable *>                    mDrawableList;
   std::vector<std::unique_ptr<LOTMaskItem>>   mMasks;
   LOTLayerData                               *mLayerData{nullptr};
   LOTLayerItem                               *mParentLayer{nullptr};
   LOTLayerItem                               *mPrecompLayer{nullptr};
   VMatrix                                     mCombinedMatrix;
   float                                       mCombinedAlpha{0.0};
   int                                         mFrameNo{-1};
   DirtyFlag                                   mDirtyFlag{DirtyFlagBit::All};
   bool                                        mStatic;
};

class LOTCompLayerItem: public LOTLayerItem
{
public:
   LOTCompLayerItem(LOTLayerData *layerData);
   void renderList(std::vector<VDrawable *> &list)final;
   void updateStaticProperty() final;
   void render(VPainter *painter, const VRle &mask, const VRle &inheritMatte, LOTLayerItem *matteSource) final;
   void buildLayerNode() final;
protected:
   void updateContent() final;
private:
   std::vector<LOTLayerNode *>                  mLayersCNode;
   std::vector<std::unique_ptr<LOTLayerItem>>   mLayers;
   int                                          mLastFrame;
};

class LOTSolidLayerItem: public LOTLayerItem
{
public:
   LOTSolidLayerItem(LOTLayerData *layerData);
   void buildLayerNode() final;
protected:
   void updateContent() final;
   void renderList(std::vector<VDrawable *> &list) final;
private:
   std::vector<LOTNode *>       mCNodeList;
   std::unique_ptr<VDrawable>   mRenderNode;
};

class LOTContentItem;
class LOTContentGroupItem;
class LOTShapeLayerItem: public LOTLayerItem
{
public:
   LOTShapeLayerItem(LOTLayerData *layerData);
   static std::unique_ptr<LOTContentItem> createContentItem(LOTData *contentData);
   void renderList(std::vector<VDrawable *> &list)final;
   void buildLayerNode() final;
protected:
   void updateContent() final;
   std::vector<LOTNode *>               mCNodeList;
   std::unique_ptr<LOTContentGroupItem> mRoot;
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
    std::unique_ptr<LOTNode>  mCNode;

    ~LOTDrawable() {
        if (mCNode && mCNode->mGradient.stopPtr)
          free(mCNode->mGradient.stopPtr);
    }
};

class LOTPathDataItem;
class LOTPaintDataItem;
class LOTTrimItem;

class LOTContentItem
{
public:
   virtual ~LOTContentItem()= default;
   virtual void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag) = 0;
   virtual void renderList(std::vector<VDrawable *> &){}
   void setParent(LOTContentItem *parent) {mParent = parent;}
   LOTContentItem *parent() const {return mParent;}
private:
   LOTContentItem *mParent{nullptr};
};

class LOTContentGroupItem: public LOTContentItem
{
public:
   LOTContentGroupItem(LOTShapeGroupData *data);
   void addChildren(LOTGroupData *data);
   void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag) final;
   void applyTrim();
   void processTrimItems(std::vector<LOTPathDataItem *> &list);
   void processPaintItems(std::vector<LOTPathDataItem *> &list);
   void renderList(std::vector<VDrawable *> &list) final;
   const VMatrix & matrix() const { return mMatrix;}
private:
   LOTShapeGroupData                             *mData;
   std::vector<std::unique_ptr<LOTContentItem>>   mContents;
   VMatrix                                        mMatrix;
};

class LOTPathDataItem : public LOTContentItem
{
public:
   LOTPathDataItem(bool staticPath): mStaticPath(staticPath){}
   void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag) final;
   bool dirty() const {return mPathChanged;}
   const VPath &localPath() const {return mTemp;}
   const VPath &finalPath();
   void updatePath(const VPath &path) {mTemp.clone(path); mPathChanged = true; mNeedUpdate = true;}
   bool staticPath() const { return mStaticPath; }
protected:
   virtual void updatePath(VPath& path, int frameNo) = 0;
   virtual bool hasChanged(int frameNo) = 0;
private:
   VPath                                   mLocalPath;
   VPath                                   mTemp;
   VPath                                   mFinalPath;
   bool                                    mPathChanged{true};
   bool                                    mNeedUpdate{true};
   bool                                    mStaticPath;
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
        float                mRoundness;
        VPointF              mPos;
        VPointF              mSize;
   };
   Cache                     mCache;

   void updateCache(int frameNo, VPointF pos, VPointF size, float roundness) {
        mCache.mFrameNo = frameNo;
        mCache.mPos = pos;
        mCache.mSize = size;
        mCache.mRoundness = roundness;
   }
   bool hasChanged(int frameNo) final {
        if (mCache.mFrameNo != -1 && staticPath()) return false;
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
        if (mCache.mFrameNo != -1 && staticPath()) return false;
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
   struct Cache {
        int                     mFrameNo{-1};
   };
   Cache                        mCache;
   void updatePath(VPath& path, int frameNo) final;
   LOTShapeData             *mData;
   bool hasChanged(int frameNo) final {
       int prevFrame = mCache.mFrameNo;
       mCache.mFrameNo = frameNo;
       if (prevFrame == -1) return true;
       if (prevFrame == frameNo) return false;

       return mData->mShape.changed(prevFrame, frameNo);
   }
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
        if (mCache.mFrameNo != -1 && staticPath()) return false;
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
   LOTPaintDataItem(bool staticContent);
   void addPathItems(std::vector<LOTPathDataItem *> &list, int startOffset);
   void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag) override;
   void renderList(std::vector<VDrawable *> &list) final;
protected:
   virtual void updateContent(int frameNo) = 0;
   virtual void updateRenderNode();
   inline float parentAlpha() const {return mParentAlpha;}
public:
   float                            mParentAlpha;
   VPath                            mPath;
   DirtyFlag                        mFlag;
   int                              mFrameNo;
   std::vector<LOTPathDataItem *>   mPathItems;
   std::unique_ptr<VDrawable>       mDrawable;
   bool                             mStaticContent;
   bool                             mRenderNodeUpdate{true};
};

class LOTFillItem : public LOTPaintDataItem
{
public:
   LOTFillItem(LOTFillData *data);
protected:
   void updateContent(int frameNo) final;
   void updateRenderNode() final;
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
   void updateRenderNode() final;
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
   void updateRenderNode() final;
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
   void updateRenderNode() final;
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
   void update();
   void addPathItems(std::vector<LOTPathDataItem *> &list, int startOffset);
private:
   bool pathDirty() const {
       for (auto &i : mPathItems) {
           if (i->dirty())
               return true;
       }
       return false;
   }
   struct Cache {
        int                     mFrameNo{-1};
        LOTTrimData::Segment    mSegment{};
   };
   Cache                            mCache;
   std::vector<LOTPathDataItem *>   mPathItems;
   LOTTrimData                     *mData;
   bool                             mDirty{true};
};

class LOTRepeaterItem : public LOTContentItem
{
public:
   LOTRepeaterItem(LOTRepeaterData *data);
   void update(int frameNo, const VMatrix &parentMatrix, float parentAlpha, const DirtyFlag &flag) final;
   void renderList(std::vector<VDrawable *> &list) final;
private:
   LOTRepeaterData             *mData;
};


#endif // LOTTIEITEM_H


