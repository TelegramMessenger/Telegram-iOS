#include "lottiemodel.h"
#include<stack>
#include<cassert>



class LottieRepeaterProcesser : public LOTDataVisitor
{
public:
    LottieRepeaterProcesser():mRepeaterFound(false){}
    void visit(LOTCompositionData *obj) {}
    void visit(LOTLayerData *obj) {}
    void visit(LOTTransformData *) {}
    void visit(LOTShapeGroupData *obj) {}
    void visit(LOTShapeData *) {}
    void visit(LOTRectData *) {}
    void visit(LOTEllipseData *) {}
    void visit(LOTTrimData *) {}
    void visit(LOTRepeaterData *) { mRepeaterFound = true;}
    void visit(LOTFillData *) {}
    void visit(LOTStrokeData *) {}
    void visit(LOTPolystarData *) {}
    void visitChildren(LOTGroupData *obj) {
        for(auto child :obj->mChildren) {
            child.get()->accept(this);
            if (mRepeaterFound) {
                LOTRepeaterData *repeater = static_cast<LOTRepeaterData *>(child.get());
                std::shared_ptr<LOTShapeGroupData> sharedShapeGroup= std::make_shared<LOTShapeGroupData>();
                LOTShapeGroupData *shapeGroup = sharedShapeGroup.get();
                repeater->mChildren.push_back(sharedShapeGroup);
                // copy all the child of the object till repeater and
                // move that in to a group and then add that group to
                // the repeater object.
                for(auto cpChild :obj->mChildren) {
                    if (cpChild == child)
                        break;
                    // there shouldn't be any trim object left in the child list
                    if (cpChild.get()->type() == LOTData::Type::Trim) {
                        assert(0);
                    }
                    shapeGroup->mChildren.push_back(cpChild);
                }
                mRepeaterFound = false;
            }
        }
    }
public:
    bool mRepeaterFound;
};

class LottiePathOperationProcesser : public LOTDataVisitor
{
public:
    LottiePathOperationProcesser():mPathOperator(false), mPathNode(false){}
    void visit(LOTCompositionData *obj) {}
    void visit(LOTLayerData *obj) {}
    void visit(LOTTransformData *) {}
    void visit(LOTShapeGroupData *obj) {}
    void visit(LOTShapeData *) {mPathNode = true;}
    void visit(LOTRectData *) {mPathNode = true;}
    void visit(LOTEllipseData *) { mPathNode = true;}
    void visit(LOTTrimData *) { mPathOperator = true;}
    void visit(LOTRepeaterData *) {}
    void visit(LOTFillData *) {}
    void visit(LOTStrokeData *) {}
    void visit(LOTPolystarData *) { mPathNode = true;}
    void visitChildren(LOTGroupData *obj) {
        int curOpCount = mPathOperationList.size();
        mPathOperator = false;
        mPathNode = false;
        for (auto i = obj->mChildren.rbegin(); i != obj->mChildren.rend(); ++i) {
            auto child = *i;
            child.get()->accept(this);
            if (mPathOperator) {
                mPathOperationList.push_back(child);
                //obj->mChildren.erase(std::next(i).base());
            }
            if (mPathNode) {
               updatePathObject(static_cast<LOTPath *>(child.get()));
            }
            mPathOperator = false;
            mPathNode = false;
        }
        mPathOperationList.erase(mPathOperationList.begin() + curOpCount, mPathOperationList.end());
    }

    void updatePathObject(LOTPath *drawable) {
        for (auto i = mPathOperationList.rbegin(); i != mPathOperationList.rend(); ++i) {
            drawable->mPathOperations.push_back(*i);
        }
    }
public:
    bool mPathOperator;
    bool mPathNode;
    std::vector<std::shared_ptr<LOTData>> mPathOperationList;
};

class LottiePaintOperationProcesser : public LOTDataVisitor
{
public:
    LottiePaintOperationProcesser():mPaintOperator(false), mPathNode(false){}
    void visit(LOTCompositionData *obj) {}
    void visit(LOTLayerData *obj) {}
    void visit(LOTTransformData *) {}
    void visit(LOTShapeGroupData *obj) {}
    void visit(LOTShapeData *) {mPathNode = true;}
    void visit(LOTRectData *) {mPathNode = true;}
    void visit(LOTEllipseData *) { mPathNode = true;}
    void visit(LOTTrimData *) {}
    void visit(LOTRepeaterData *) {}
    void visit(LOTFillData *) { mPaintOperator = true;}
    void visit(LOTStrokeData *) { mPaintOperator = true;}
    void visit(LOTPolystarData *) { mPathNode = true;}
    void visitChildren(LOTGroupData *obj) {
        int curOpCount = mPaintOperationList.size();
        mPaintOperator = false;
        mPathNode = false;
        for (auto i = obj->mChildren.rbegin(); i != obj->mChildren.rend(); ++i) {
            auto child = *i;
            child.get()->accept(this);
            if (mPaintOperator) {
                mPaintOperationList.push_back(child);
                //obj->mChildren.erase(std::next(i).base());
            }
            if (mPathNode) {
               // put it in the list
               updatePathObject(static_cast<LOTPath *>(child.get()));
            }
            mPaintOperator = false;
            mPathNode = false;
        }
        mPaintOperationList.erase(mPaintOperationList.begin() + curOpCount, mPaintOperationList.end());
    }

    void updatePathObject(LOTPath *drawable) {
        for (auto i = mPaintOperationList.begin(); i != mPaintOperationList.end(); ++i) {
            drawable->mPaintOperations.push_back(*i);
        }
    }
public:
    bool mPaintOperator;
    bool mPathNode;
    std::vector<std::shared_ptr<LOTData>> mPaintOperationList;
};

void LOTCompositionData::processRepeaterObjects()
{
    LottieRepeaterProcesser visitor;
    accept(&visitor);
}

void LOTCompositionData::processPathOperatorObjects()
{
    LottiePathOperationProcesser visitor;
    accept(&visitor);
}

void LOTCompositionData::processPaintOperatorObjects()
{
    LottiePaintOperationProcesser visitor;
    accept(&visitor);
}


VMatrix LOTTransformData::matrix(int frameNo) const
{
    if (mStaticMatrix)
        return mCachedMatrix;
    else
        return computeMatrix(frameNo);
}

float LOTTransformData::opacity(int frameNo) const
{
    return mOpacity.value(frameNo)/100.f;
}

void LOTTransformData::cacheMatrix()
{
    mCachedMatrix = computeMatrix(0);
}

VMatrix LOTTransformData::computeMatrix(int frameNo) const
{
    VMatrix m;
    m.translate(mPosition.value(frameNo)).
      rotate(mRotation.value(frameNo)).
      scale(mScale.value(frameNo)/100.f).
      translate(-mAnchor.value(frameNo));
    return m;
}

int LOTStrokeData::getDashInfo(int frameNo, float *array) const
{
    if (!mDash.mDashCount) return 0;
    // odd case
    if (mDash.mDashCount % 2) {
        for (int i = 0; i < mDash.mDashCount; i++) {
            array[i] = mDash.mDashArray[i].value(frameNo);
        }
        return mDash.mDashCount;
    } else { // even case when last gap info is not provided.
        int i;
        for (i = 0; i < mDash.mDashCount-1 ; i++) {
            array[i] = mDash.mDashArray[i].value(frameNo);
        }
        array[i] = array[i-1];
        array[i+1] = mDash.mDashArray[i].value(frameNo);
        return mDash.mDashCount+1;
    }
}

int LOTGStrokeData::getDashInfo(int frameNo, float *array) const
{
    if (!mDash.mDashCount) return 0;
    // odd case
    if (mDash.mDashCount % 2) {
        for (int i = 0; i < mDash.mDashCount; i++) {
            array[i] = mDash.mDashArray[i].value(frameNo);
        }
        return mDash.mDashCount;
    } else { // even case when last gap info is not provided.
        int i;
        for (i = 0; i < mDash.mDashCount-1 ; i++) {
            array[i] = mDash.mDashArray[i].value(frameNo);
        }
        array[i] = array[i-1];
        array[i+1] = mDash.mDashArray[i].value(frameNo);
        return mDash.mDashCount+1;
    }
}

/**
 * Both the color stops and opacity stops are in the same array.
 * There are {@link #colorPoints} colors sequentially as:
 * [
 *     ...,
 *     position,
 *     red,
 *     green,
 *     blue,
 *     ...
 * ]
 *
 * The remainder of the array is the opacity stops sequentially as:
 * [
 *     ...,
 *     position,
 *     opacity,
 *     ...
 * ]
 */
void LOTGradient::populate(VGradientStops &stops, int frameNo)
{
    LottieGradient gradData = mGradient.value(frameNo);
    int size = gradData.mGradient.size();
    float *ptr = gradData.mGradient.data();
    int colorPoints = mColorPoints;
    if (colorPoints == -1 ) { // for legacy bodymovin (ref: lottie-android)
        colorPoints = size / 4;
    }
    int opacityArraySize = size - colorPoints * 4;
    float *opacityPtr = ptr + (colorPoints * 4);
    stops.clear();
    int j = 0;
    for (int i = 0; i < colorPoints ; i++) {
        float colorStop = ptr[0];
        LottieColor color = LottieColor(ptr[1], ptr[2], ptr[3]);
        if (opacityArraySize) {
            if (j == opacityArraySize) {
                // already reached the end
                float stop1 = opacityPtr[j-4];
                float op1 = opacityPtr[j-3];
                float stop2 = opacityPtr[j-2];
                float op2 = opacityPtr[j-1];
                if (colorStop > stop2) {
                    stops.push_back(std::make_pair(colorStop, color.toColor(op2)));
                } else {
                    float progress = (colorStop - stop1) / (stop2 - stop1);
                    float opacity = op1 + progress * (op2 - op1);
                    stops.push_back(std::make_pair(colorStop, color.toColor(opacity)));
                }
                continue;
            }
            for (; j < opacityArraySize ; j += 2) {
                float opacityStop = opacityPtr[j];
                if (opacityStop < colorStop) {
                    // add a color using opacity stop
                    stops.push_back(std::make_pair(opacityStop, color.toColor(opacityPtr[j+1])));
                    continue;
                }
                // add a color using color stop
                if (j == 0) {
                    stops.push_back(std::make_pair(colorStop, color.toColor(opacityPtr[j+1])));
                } else {
                    float progress = (colorStop - opacityPtr[j-2]) / (opacityPtr[j] - opacityPtr[j-2]);
                    float opacity = opacityPtr[j-1] + progress * (opacityPtr[j+1] - opacityPtr[j-1]);
                    stops.push_back(std::make_pair(colorStop, color.toColor(opacity)));
                }
                j += 2;
                break;
            }
        } else {
            stops.push_back(std::make_pair(colorStop, color.toColor()));
        }
        ptr += 4;
    }
}

void LOTGradient::update(std::unique_ptr<VGradient> &grad, int frameNo)
{
    bool init = false;
    if (!grad) {
        if (mGradientType == 1)
            grad = std::unique_ptr<VLinearGradient>(new VLinearGradient(0,0,0,0));
        else
            grad = std::unique_ptr<VRadialGradient>(new VRadialGradient(0,0,0,0,0,0));
        grad->mSpread = VGradient::Spread::Pad;
        init = true;
    }

    if (!mGradient.isStatic() || init) {
        populate(grad->mStops, frameNo);
    }

    if (mGradientType == 1) { //linear gradient
        VPointF start = mStartPoint.value(frameNo);
        VPointF end = mEndPoint.value(frameNo);
        grad->linear.x1 = start.x();
        grad->linear.y1 = start.y();
        grad->linear.x2 = end.x();
        grad->linear.y2 = end.y();
    } else { // radial gradient
        VPointF start = mStartPoint.value(frameNo);
        VPointF end = mEndPoint.value(frameNo);
        grad->radial.cx = start.x();
        grad->radial.cy = start.y();
        grad->radial.fx = end.x();
        grad->radial.fy = end.y();
    }
}


