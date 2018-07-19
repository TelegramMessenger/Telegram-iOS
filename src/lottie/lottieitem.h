#ifndef LOTTIEITEM_H
#define LOTTIEITEM_H

#include<lottiemodel.h>
#include<sstream>
#include<memory>

#include"vmatrix.h"
#include"vpath.h"
#include"vpoint.h"
#include"lottieplayer.h"
#include"vbrush.h"
#include"vpainter.h"

V_USE_NAMESPACE

enum class DirtyFlagBit
{
   None   = 0x0001,
   Matrix = 0x0010,
   Alpha  = 0x0100,
   All    = (Matrix | Alpha)
};

class LOTLayerItem;
class LOTMaskItem;
class VDrawable;

class LOTCompItem
{
public:
   LOTCompItem(LOTModel *model);
   ~LOTCompItem();
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
   std::vector<LOTLayerItem *>                 mLayers;
   std::unordered_map<int, LOTLayerItem *>     mLayerMap;
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
   virtual void render(VPainter *painter, const VRle &mask);
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
   void render(VPainter *painter, const VRle &mask) final;
protected:
   void updateContent() final;
private:
   std::vector<LOTLayerItem *>                  mLayers;
   std::unordered_map<int, LOTLayerItem *>      mLayerMap;
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

class VDrawable
{
public:
    enum class DirtyState {
          None   = 0x00000000,
          Path   = 0x00000001,
          Stroke = 0x00000010,
          Brush  = 0x00000100,
          All    = (None | Path | Stroke | Brush)
    };
    enum class Type {
        Fill,
        Stroke,
    };
    typedef vFlag<DirtyState> DirtyFlag;
    VDrawable();
    void sync();
    void setPath(const VPath &path);
    void setFillRule(FillRule rule){mFillRule = rule;}
    void setBrush(const VBrush &brush){mBrush = brush;}
    void setStrokeInfo(CapStyle cap, JoinStyle join, float meterLimit, float strokeWidth);
    void setDashInfo(float *array, int size);
    void preprocess();
    VRle rle();
public:
    DirtyFlag          mFlag;
    VDrawable::Type    mType;
    VBrush             mBrush;
    VPath              mPath;
    FillRule           mFillRule;
    std::future<VRle>  mRleTask;
    VRle               mRle;
    struct  {
         bool         enable;
         float        width;
         CapStyle     cap;
         JoinStyle    join;
         float        meterLimit;
         float       *dashArray;
         int          dashArraySize;
    }mStroke;
    LOTNode           mCNode;
};

class LOTNode;
class LOTPathDataItem;
class LOTPaintDataItem;
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
   void renderList(std::vector<VDrawable *> &list) final;
private:
   void paintOperationHelper(std::vector<LOTPaintDataItem *> &list);
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
   inline float combinedAlpha() const{ return mCombinedAlpha;}
   void renderList(std::vector<VDrawable *> &list) final;
private:
   std::vector<LOTRenderNode>              mRenderList;
   std::vector<std::unique_ptr<VDrawable>> mNodeList;
   bool                                    mInit;
   bool                                    mStaticPath;
   VPath                                  mLocalPath;
   VPath                                  mFinalPath;
   bool                                    mPathChanged;
   float                                   mCombinedAlpha;
protected:
   virtual VPath getPath(int frameNo) = 0;
};

class LOTRectItem: public LOTPathDataItem
{
public:
   LOTRectItem(LOTRectData *data);
protected:
   VPath getPath(int frameNo) final;
   LOTRectData           *mData;
};

class LOTEllipseItem: public LOTPathDataItem
{
public:
   LOTEllipseItem(LOTEllipseData *data);
private:
   VPath getPath(int frameNo) final;
   LOTEllipseData           *mData;
};

class LOTShapeItem: public LOTPathDataItem
{
public:
   LOTShapeItem(LOTShapeData *data);
private:
   VPath getPath(int frameNo) final;
   LOTShapeData             *mData;
};

class LOTPolystarItem: public LOTPathDataItem
{
public:
   LOTPolystarItem(LOTPolystarData *data);
private:
   VPath getPath(int frameNo) final;
   LOTPolystarData             *mData;
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


