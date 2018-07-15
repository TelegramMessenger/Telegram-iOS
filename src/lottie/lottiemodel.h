#ifndef LOTModel_H
#define LOTModel_H

#include<vector>
#include<memory>
#include<unordered_map>
#include"vpoint.h"
#include"vrect.h"
#include"vinterpolator.h"
#include"vmatrix.h"
#include"vbezier.h"
#include"vbrush.h"
#include"vpath.h"

V_USE_NAMESPACE

class LOTCompositionData;
class LOTLayerData;
class LOTTransformData;
class LOTShapeGroupData;
class LOTShapeData;
class LOTRectData;
class LOTEllipseData;
class LOTTrimData;
class LOTRepeaterData;
class LOTFillData;
class LOTStrokeData;
class LOTGroupData;
class LOTGFillData;
class LOTGStrokeData;
class LottieShapeData;
class LOTPolystarData;
class LOTMaskData;

class LOTDataVisitor
{
public:
    virtual ~LOTDataVisitor() {}
    virtual void visit(LOTCompositionData *) = 0;
    virtual void visit(LOTLayerData *) = 0;
    virtual void visit(LOTTransformData *) = 0;
    virtual void visit(LOTShapeGroupData *) = 0;
    virtual void visit(LOTShapeData *) = 0;
    virtual void visit(LOTRectData *) = 0;
    virtual void visit(LOTEllipseData *) = 0;
    virtual void visit(LOTPolystarData *) {};
    virtual void visit(LOTTrimData *) = 0;
    virtual void visit(LOTRepeaterData *) = 0;
    virtual void visit(LOTFillData *) = 0;
    virtual void visit(LOTStrokeData *) = 0;
    virtual void visit(LOTGFillData *){};
    virtual void visit(LOTGStrokeData *){};
    virtual void visitChildren(LOTGroupData *) = 0;
};

enum class MatteType
{
    None = 0,
    Alpha = 1,
    AlphaInv,
    Luma,
    LumaInv
};

enum class LayerType {
    Precomp = 0,
    Solid = 1,
    Image = 2,
    Null = 3,
    Shape = 4,
    Text = 5
};

class LottieColor
{
public:
    LottieColor():r(1),g(1), b(1){}
    LottieColor(float red, float green , float blue):r(red), g(green),b(blue){}
    VColor toColor(float a=1){ return VColor((255 * r), (255 * g), (255 * b), (255 * a));}
    friend inline LottieColor operator+(const LottieColor &c1, const LottieColor &c2);
    friend inline LottieColor operator-(const LottieColor &c1, const LottieColor &c2);
public:
    float r;
    float g;
    float b;
};

inline LottieColor operator-(const LottieColor &c1, const LottieColor &c2)
{
    return LottieColor(c1.r - c2.r, c1.g - c2.g, c1.b - c2.b);
}
inline LottieColor operator+(const LottieColor &c1, const LottieColor &c2)
{
    return LottieColor(c1.r + c2.r, c1.g + c2.g, c1.b + c2.b);
}

inline const LottieColor operator*(const LottieColor &c, float m)
{ return LottieColor(c.r*m, c.g*m, c.b*m); }

inline const LottieColor operator*(float m, const LottieColor &c)
{ return LottieColor(c.r*m, c.g*m, c.b*m); }

class LottieShapeData
{
public:
    VPath toPath() const{
        if (mPoints.empty()) return VPath();

        VPath path;
        int size = mPoints.size();
        const VPointF *points = mPoints.data();
        path.moveTo(points[0]);
        for (int i = 1 ; i < size; i+=3) {
           path.cubicTo(points[i], points[i+1], points[i+2]);
        }
        if (mClosed)
          path.close();

       return path;
    }
public:
    std::vector<VPointF>    mPoints;
    bool                     mClosed = false;   /* "c" */
};


template<typename T>
class LOTKeyFrame
{
public:
    LOTKeyFrame():mStartValue(),
                     mEndValue(),
                     mStartFrame(0),
                     mEndFrame(0),
                     mInterpolator(nullptr),
                     mInTangent(),
                     mOutTangent(),
                     mPathKeyFrame(false){}

    T value(int frameNo) const {
        float progress = mInterpolator->value(float(frameNo - mStartFrame) / float(mEndFrame - mStartFrame));
        return mStartValue + progress * (mEndValue - mStartValue);
    }

public:
    T                   mStartValue;
    T                   mEndValue;
    int                 mStartFrame;
    int                 mEndFrame;
    std::shared_ptr<VInterpolator> mInterpolator;

    /* this is for interpolating position along a path
     * Need to move to other place because its only applicable
     * for positional property.
     */
    VPointF            mInTangent;
    VPointF            mOutTangent;
    bool                mPathKeyFrame;
};

template<>
class LOTKeyFrame<VPointF>
{
public:
    LOTKeyFrame():mStartValue(),
                  mEndValue(),
                  mStartFrame(0),
                  mEndFrame(0),
                  mInterpolator(nullptr),
                  mInTangent(),
                  mOutTangent(),
                  mPathKeyFrame(false){}

    VPointF value(int frameNo) const {
        float progress = mInterpolator->value(float(frameNo - mStartFrame) / float(mEndFrame - mStartFrame));
        if (mPathKeyFrame & 1) {
            return VBezier::fromPoints(mStartValue, mStartValue + mOutTangent,  mEndValue + mInTangent, mEndValue).pointAt(progress);
        } else {
            return mStartValue + progress * (mEndValue - mStartValue);
        }
    }

public:
    VPointF                   mStartValue;
    VPointF                   mEndValue;
    int                        mStartFrame;
    int                        mEndFrame;
    std::shared_ptr<VInterpolator> mInterpolator;

    /* this is for interpolating position along a path
     * Need to move to other place because its only applicable
     * for positional property.
     */
    VPointF            mInTangent;
    VPointF            mOutTangent;
    bool                mPathKeyFrame;
};

template<>
class LOTKeyFrame<LottieShapeData>
{
public:
    LOTKeyFrame():mStartValue(),
                     mEndValue(),
                     mStartFrame(0),
                     mEndFrame(0),
                     mInterpolator(nullptr),
                     mInTangent(),
                     mOutTangent(),
                     mPathKeyFrame(false){}

    LottieShapeData value(int frameNo) const {
         float progress = mInterpolator->value(float(frameNo - mStartFrame) / float(mEndFrame - mStartFrame));

         if (mStartValue.mPoints.size() != mEndValue.mPoints.size())
            return LottieShapeData();

         LottieShapeData result;
         for (unsigned int i = 0 ; i < mStartValue.mPoints.size(); i++) {
            result.mPoints.push_back(mStartValue.mPoints[i] + progress * (mEndValue.mPoints[i] - mStartValue.mPoints[i]));
         }
        return result;
    }

public:
    LottieShapeData                   mStartValue;
    LottieShapeData                   mEndValue;
    int                 mStartFrame;
    int                 mEndFrame;
    std::shared_ptr<VInterpolator> mInterpolator;

    /* this is for interpolating position along a path
     * Need to move to other place because its only applicable
     * for positional property.
     */
    VPointF            mInTangent;
    VPointF            mOutTangent;
    bool                mPathKeyFrame;
};

template<typename T>
class LOTAnimInfo
{
public:
    T value(int frameNo) const {
        if (mKeyFrames.front().mStartFrame >= frameNo)
            return mKeyFrames.front().mStartValue;
        if(mKeyFrames.back().mEndFrame <= frameNo)
            return mKeyFrames.back().mEndValue;

        for(auto keyFrame : mKeyFrames) {
            if (frameNo >= keyFrame.mStartFrame && frameNo < keyFrame.mEndFrame)
                return keyFrame.value(frameNo);
        }
        return T();
    }
public:
    std::vector<LOTKeyFrame<T>>    mKeyFrames;
};

template<typename T>
class LOTAnimatable
{
public:
    LOTAnimatable():mValue(),mAnimInfo(nullptr){}
    LOTAnimatable(const T &value): mValue(value){}
    bool isStatic() const {if (mAnimInfo) return false; else return true;}
    T value(int frameNo) const{
        if (isStatic())
            return mValue;
        else
            return mAnimInfo->value(frameNo);
    }
public:
    T                                    mValue;
    int                                  mPropertyIndex; /* "ix" */
    std::shared_ptr<LOTAnimInfo<T>>   mAnimInfo;
};

enum class LottieBlendMode
{
    Normal = 0,
    Multiply = 1,
    Screen = 2,
    OverLay = 3
};

class LOTDataVisitor;
class LOTData
{
public:
    enum class Type {
        Composition = 1,
        Layer,
        ShapeGroup,
        Transform,
        Fill,
        Stroke,
        GFill,
        GStroke,
        Rect,
        Ellipse,
        Shape,
        Polystar,
        Trim,
        Repeater
    };
    inline LOTData::Type type() const {return mType;}
    virtual void accept(LOTDataVisitor *){}
    virtual ~LOTData(){}
    LOTData(LOTData::Type  type): mStatic(true), mType(type){}
    bool isStatic() const{return mStatic;}
    void setStatic(bool value) {mStatic = value;}
    virtual bool hasChildren() {return false;}
public:
    bool                mStatic;
    LOTData::Type  mType;
};

class LOTGroupData: public LOTData
{
public:
    LOTGroupData(LOTData::Type  type):LOTData(type){}
    virtual bool hasChildren() {return true;}
public:
    std::vector<std::shared_ptr<LOTData>>  mChildren;
    std::shared_ptr<LOTTransformData>      mTransform;
};

class LOTShapeGroupData : public LOTGroupData
{
public:
    void accept(LOTDataVisitor *visitor) override
    {visitor->visit(this); visitor->visitChildren(this);}

    LOTShapeGroupData():LOTGroupData(LOTData::Type::ShapeGroup){}
};

class LOTLayerData;
class LOTAsset
{
public:
    LOTAsset(){}
    int                                          mAssetType; //lottie asset type  (precomp/char/image)
    std::string                                  mRefId; // ref id
    std::vector<std::shared_ptr<LOTData>>   mLayers;
};

class LOTCompositionData : public LOTGroupData
{
public:
    void processPathOperatorObjects();
    void processPaintOperatorObjects();
    void processRepeaterObjects();
    void accept(LOTDataVisitor *visitor) override
    {visitor->visit(this); visitor->visitChildren(this);}
    LOTCompositionData():LOTGroupData(LOTData::Type::Composition){}
    inline long frameDuration()const{return mEndFrame - mStartFrame -1;}
    inline long frameRate()const{return mFrameRate;}
    inline long startFrame() const {return mStartFrame;}
    inline long endFrame() const {return mEndFrame;}
    inline VSize size() const { return mSize;}

public:
    std::string          mVersion;
    VSize               mSize;
    bool                 mAnimation = false;
    long                 mStartFrame = 0;
    long                 mEndFrame = 0;
    float                mFrameRate;
    LottieBlendMode      mBlendMode;
    std::unordered_map<std::string,
                       std::shared_ptr<VInterpolator>> mInterpolatorCache;
    std::unordered_map<std::string,
                       std::shared_ptr<LOTAsset>>    mAssets;
};

class LOTLayerData : public LOTGroupData
{
public:
    void accept(LOTDataVisitor *visitor) override
    {visitor->visit(this); visitor->visitChildren(this);}
    LOTLayerData():LOTGroupData(LOTData::Type::Layer),
                  mMatteType(MatteType::None),
                  mParentId(-1),
                  mId(-1),
                  mHasPathOperator(false), mHasMask(false){}
    inline bool hasPathOperator() const noexcept {return mHasPathOperator;}
    inline int id() const noexcept{ return mId;}
    inline int parentId() const noexcept{ return mParentId;}
    inline int inFrame() const noexcept{return mInFrame;}
    inline int outFrame() const noexcept{return mOutFrame;}
    inline int startFrame() const noexcept{return mOutFrame;}
    inline int solidWidth() const noexcept{return mSolidLayer.mWidth;}
    inline int solidHeight() const noexcept{return mSolidLayer.mHeight;}
    inline LottieColor solidColor() const noexcept{return mSolidLayer.mColor;}
public:
    MatteType            mMatteType;
    VRect               mBound;
    LayerType            mLayerType; //lottie layer type  (solid/shape/precomp)
    int                  mParentId; // Lottie the id of the parent in the composition
    int                  mId;  // Lottie the group id  used for parenting.
    long                 mInFrame = 0;
    long                 mOutFrame = 0;
    long                 mStartFrame = 0;
    LottieBlendMode      mBlendMode;
    float                mTimeStreatch;
    std::string          mPreCompRefId;
    LOTAnimatable<float>     mTimeRemap;  /* "tm" */
    struct SolidLayer {
        int            mWidth;
        int            mHeight;
        LottieColor    mColor;
    };
    SolidLayer          mSolidLayer;
    bool                mHasPathOperator;
    bool                mHasMask;
    std::vector<std::shared_ptr<LOTMaskData>>  mMasks;
};

class LOTTransformData : public LOTData
{
public:
    void accept(LOTDataVisitor *visitor) final
    {visitor->visit(this);}
    LOTTransformData():LOTData(LOTData::Type::Transform),
                      mRotation(0),
                      mScale(VPointF(100, 100)),
                      mPosition(VPointF(0, 0)),
                      mAnchor(VPointF(0, 0)),
                      mOpacity(100),
                      mSkew(0),
                      mSkewAxis(0),
                      mStaticMatrix(true){}
    VMatrix matrix(int frameNo) const;
    float    opacity(int frameNo) const;
    void cacheMatrix();
    inline bool staticMatrix() const {return mStaticMatrix;}
private:
    VMatrix computeMatrix(int frameNo) const;
public:
    LOTAnimatable<float>     mRotation;  /* "r" */
    LOTAnimatable<VPointF>  mScale;     /* "s" */
    LOTAnimatable<VPointF>  mPosition;  /* "p" */
    LOTAnimatable<VPointF>  mAnchor;    /* "a" */
    LOTAnimatable<float>     mOpacity;   /* "o" */
    LOTAnimatable<float>     mSkew;      /* "sk" */
    LOTAnimatable<float>     mSkewAxis;  /* "sa" */
    bool                     mStaticMatrix;
    VMatrix                 mCachedMatrix;
};

class LOTFillData : public LOTData
{
public:
    void accept(LOTDataVisitor *visitor) final
    {visitor->visit(this);}
    LOTFillData():LOTData(LOTData::Type::Fill), mFillRule(FillRule::Winding){}
    inline float opacity(int frameNo) const {return mOpacity.value(frameNo)/100.0;}
    inline FillRule fillRule() const {return mFillRule;}
public:
    FillRule                       mFillRule; /* "r" */
    LOTAnimatable<LottieColor>     mColor;   /* "c" */
    LOTAnimatable<int>             mOpacity;  /* "o" */
    bool                           mEnabled = true; /* "fillEnabled" */
};

struct LOTDashProperty
{
    LOTDashProperty():mDashCount(0), mStatic(true){}
    LOTAnimatable<float>     mDashArray[5]; /* "d" "g" "o"*/
    int                      mDashCount;
    bool                     mStatic;
};

class LOTStrokeData : public LOTData
{
public:
    void accept(LOTDataVisitor *visitor) final
    {visitor->visit(this);}
    LOTStrokeData():LOTData(LOTData::Type::Stroke){}
    inline float opacity(int frameNo) const {return mOpacity.value(frameNo)/100.0;}
    inline float width(int frameNo) const {return mWidth.value(frameNo);}
    inline CapStyle capStyle() const {return mCapStyle;}
    inline JoinStyle joinStyle() const {return mJoinStyle;}
    inline float meterLimit() const{return mMeterLimit;}
    inline bool hasDashInfo() const { return !(mDash.mDashCount == 0);}
    int getDashInfo(int frameNo, float *array) const;
public:
    LOTAnimatable<LottieColor>        mColor;      /* "c" */
    LOTAnimatable<int>                mOpacity;    /* "o" */
    LOTAnimatable<float>              mWidth;      /* "w" */
    CapStyle                          mCapStyle;   /* "lc" */
    JoinStyle                         mJoinStyle;  /* "lj" */
    float                             mMeterLimit; /* "ml" */
    LOTDashProperty                   mDash;
    bool                              mEnabled = true; /* "fillEnabled" */
};

class LottieGradient
{
public:
    friend inline LottieGradient operator+(const LottieGradient &g1, const LottieGradient &g2);
    friend inline LottieGradient operator-(const LottieGradient &g1, const LottieGradient &g2);
    friend inline LottieGradient operator*(float m, const LottieGradient &g);
public:
    std::vector<float>    mGradient;
};

inline LottieGradient operator+(const LottieGradient &g1, const LottieGradient &g2)
{
    if (g1.mGradient.size() != g2.mGradient.size())
        return g1;

    LottieGradient newG;
    newG.mGradient = g1.mGradient;

    auto g2It = g2.mGradient.begin();
    for(auto &i : newG.mGradient) {
        i = i + *g2It;
        g2It++;
    }

    return newG;
}

inline LottieGradient operator-(const LottieGradient &g1, const LottieGradient &g2)
{
    if (g1.mGradient.size() != g2.mGradient.size())
        return g1;
    LottieGradient newG;
    newG.mGradient = g1.mGradient;

    auto g2It = g2.mGradient.begin();
    for(auto &i : newG.mGradient) {
        i = i - *g2It;
        g2It++;
    }

    return newG;
}

inline LottieGradient operator*(float m, const LottieGradient &g)
{
    LottieGradient newG;
    newG.mGradient = g.mGradient;

    for(auto &i : newG.mGradient) {
        i = i * m;
    }
    return newG;
}



class LOTGradient : public LOTData
{
public:
    LOTGradient(LOTData::Type  type):LOTData(type), mColorPoints(-1){}
    inline float opacity(int frameNo) const {return mOpacity.value(frameNo)/100.0;}
    void update(std::unique_ptr<VGradient> &grad, int frameNo);

private:
    void populate(VGradientStops &stops, int frameNo);
public:
    int                                 mGradientType;        /* "t" Linear=1 , Radial = 2*/
    LOTAnimatable<VPointF>              mStartPoint;          /* "s" */
    LOTAnimatable<VPointF>              mEndPoint;            /* "e" */
    LOTAnimatable<int>                  mHighlightLength;     /* "h" */
    LOTAnimatable<int>                  mHighlightAngle;      /* "a" */
    LOTAnimatable<int>                  mOpacity;             /* "o" */
    LOTAnimatable<LottieGradient>       mGradient;            /* "g" */
    int                                 mColorPoints;
    bool                                mEnabled = true;      /* "fillEnabled" */
};

class LOTGFillData : public LOTGradient
{
public:
    void accept(LOTDataVisitor *visitor) final
    {visitor->visit(this);}
    LOTGFillData():LOTGradient(LOTData::Type::GFill), mFillRule(FillRule::Winding){}
    inline FillRule fillRule() const {return mFillRule;}
public:
    FillRule                       mFillRule; /* "r" */
};

class LOTGStrokeData : public LOTGradient
{
public:
    void accept(LOTDataVisitor *visitor) final
    {visitor->visit(this);}
    LOTGStrokeData():LOTGradient(LOTData::Type::GStroke){}
    inline float width(int frameNo) const {return mWidth.value(frameNo);}
    inline CapStyle capStyle() const {return mCapStyle;}
    inline JoinStyle joinStyle() const {return mJoinStyle;}
    inline float meterLimit() const{return mMeterLimit;}
    inline bool hasDashInfo() const { return !(mDash.mDashCount == 0);}
    int getDashInfo(int frameNo, float *array) const;
public:
    LOTAnimatable<float>           mWidth;       /* "w" */
    CapStyle                       mCapStyle;    /* "lc" */
    JoinStyle                      mJoinStyle;   /* "lj" */
    float                          mMeterLimit;  /* "ml" */
    LOTDashProperty                mDash;
};

class LOTPath : public LOTData
{
public:
    LOTPath(LOTData::Type  type):LOTData(type), mDirection(3){}
    bool isDirectionCW() const { return ((mDirection == 3) ? false : true );}
public:
    int                                    mDirection;
    std::vector<std::shared_ptr<LOTData>>  mPathOperations;
    std::vector<std::shared_ptr<LOTData>>  mPaintOperations;
};

class LOTShapeData : public LOTPath
{
public:
    void accept(LOTDataVisitor *visitor) final
    {visitor->visit(this);}
    void process();
    LOTShapeData():LOTPath(LOTData::Type::Shape){}
public:
    LOTAnimatable<LottieShapeData>    mShape;
};

class LOTMaskData
{
public:
    enum class Mode {
      None,
      Add,
      Substarct,
      Intersect
    };
    LOTMaskData():mInv(false), mIsStatic(true){}
    inline float opacity(int frameNo) const {return mOpacity.value(frameNo)/100.0;}
    inline bool isStatic() const {return mIsStatic;}
public:
    LOTAnimatable<LottieShapeData>    mShape;
    LOTAnimatable<float>              mOpacity;
    bool                              mInv;
    bool                              mIsStatic;
    LOTMaskData::Mode                 mMode;
};

class LOTRectData : public LOTPath
{
public:
    void accept(LOTDataVisitor *visitor) final
    {visitor->visit(this);}
    LOTRectData():LOTPath(LOTData::Type::Rect),
                       mPos(VPointF(0,0)),
                       mSize(VPointF(0,0)),
                       mRound(0){}
public:
    LOTAnimatable<VPointF>    mPos;
    LOTAnimatable<VPointF>    mSize;
    LOTAnimatable<float>       mRound;
};

class LOTEllipseData : public LOTPath
{
public:
    void accept(LOTDataVisitor *visitor) final
    {visitor->visit(this);}
    LOTEllipseData():LOTPath(LOTData::Type::Ellipse),
                          mPos(VPointF(0,0)),
                          mSize(VPointF(0,0)){}
public:
    LOTAnimatable<VPointF>   mPos;
    LOTAnimatable<VPointF>   mSize;
};

class LOTPolystarData : public LOTPath
{
public:
    enum class PolyType {
        Star = 1,
        Polygon = 2
    };
    void accept(LOTDataVisitor *visitor) final
    {visitor->visit(this);}
    LOTPolystarData():LOTPath(LOTData::Type::Polystar),
                          mType(PolyType::Polygon),
                          mPos(VPointF(0,0)),
                          mPointCount(0),
                          mInnerRadius(0),
                          mOuterRadius(0),
                          mInnerRoundness(0),
                          mOuterRoundness(0),
                          mRotation(0){}
public:
    LOTPolystarData::PolyType     mType;
    LOTAnimatable<VPointF>       mPos;
    LOTAnimatable<float>          mPointCount;
    LOTAnimatable<float>          mInnerRadius;
    LOTAnimatable<float>          mOuterRadius;
    LOTAnimatable<float>          mInnerRoundness;
    LOTAnimatable<float>          mOuterRoundness;
    LOTAnimatable<float>          mRotation;
};

class LOTTrimData : public LOTData
{
public:
    void accept(LOTDataVisitor *visitor) final
    {visitor->visit(this);}
    enum class TrimType {
        Simultaneously,
        Individually
    };
    LOTTrimData():LOTData(LOTData::Type::Trim),
                       mStart(0),
                       mEnd(0),
                       mOffset(0),
                       mTrimType(TrimType::Simultaneously){}
public:
    LOTAnimatable<float>             mStart;
    LOTAnimatable<float>             mEnd;
    LOTAnimatable<float>             mOffset;
    LOTTrimData::TrimType            mTrimType;
};

class LOTRepeaterData : public LOTGroupData
{
public:
    void accept(LOTDataVisitor *visitor) final
    {visitor->visit(this); visitor->visitChildren(this);}
    LOTRepeaterData():LOTGroupData(LOTData::Type::Repeater),
                           mCopies(0),
                           mOffset(0){}
public:
    LOTAnimatable<float>             mCopies;
    LOTAnimatable<float>             mOffset;
};

class LOTModel
{
public:
   bool  isStatic() const{return mRoot->isStatic();}
   int frameDuration() {return mRoot->frameDuration();}
   int frameRate() {return mRoot->frameRate();}
   int startFrame() {return mRoot->startFrame();}
public:
    std::shared_ptr<LOTCompositionData> mRoot;
};

#endif // LOTModel_H
