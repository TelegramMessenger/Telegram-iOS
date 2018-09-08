#include <gtest/gtest.h>
#include "vpath.h"

class VPathTest : public ::testing::Test {
public:
    void SetUp()
    {
        pathRect.addRect({-10, -20, 100, 100});
        pathRoundRect.addRoundRect({0, 0, 100, 100}, 5, 5);
        pathRoundRectZeroCorner.addRoundRect({0, 0, 100, 100}, 0, 0);
        pathRoundRectHalfCircle.addRoundRect({0, 0, 100, 100}, 60, 60);
        pathOval.addOval({0,0,100,50});
        pathOvalCircle.addOval({0,0,100,100});
        pathCircle.addCircle(0, 0, 100);
        pathPolygon.addPolygon(10, 50, 5, 0, 0, 0);
    }
    void TearDown()
    {

    }
public:
  VPath pathEmpty;
  VPath pathRect;
  VPath pathRoundRect;
  VPath pathRoundRectZeroCorner;
  VPath pathRoundRectHalfCircle;
  VPath pathOval;
  VPath pathOvalCircle;
  VPath pathCircle;
  VPath pathPolygon;
};

TEST_F(VPathTest, emptyPath) {
    ASSERT_EQ(sizeof(pathEmpty), sizeof(void *));
    ASSERT_TRUE(pathEmpty.empty());
    ASSERT_FALSE(pathEmpty.segments());
    ASSERT_EQ(pathEmpty.segments() , 0);
    ASSERT_EQ(pathEmpty.elements().size() , 0);
    ASSERT_EQ(pathEmpty.elements().capacity() , pathEmpty.elements().size());
    ASSERT_EQ(pathEmpty.points().size() , 0);
    ASSERT_EQ(pathEmpty.points().capacity() , pathEmpty.points().size());
}

TEST_F(VPathTest, reset) {
    pathRect.reset();
    ASSERT_TRUE(pathRect.empty());
    ASSERT_EQ(pathRect.segments() , 0);
    ASSERT_GE(pathRect.points().capacity(), 1);
    ASSERT_GE(pathRect.elements().capacity(), 1);
}

TEST_F(VPathTest, reserve) {
    pathEmpty.reserve(10, 10);
    ASSERT_EQ(pathEmpty.points().capacity(), 10);
    ASSERT_GE(pathEmpty.elements().capacity(), 10);
    ASSERT_EQ(pathEmpty.segments() , 0);
    ASSERT_EQ(pathEmpty.points().size(), 0);
    ASSERT_GE(pathEmpty.elements().size(), 0);
}

TEST_F(VPathTest, clone) {
    VPath pathClone;
    pathClone.clone(pathOval);
    ASSERT_EQ(pathClone.segments(), pathOval.segments());
    ASSERT_EQ(pathClone.points().size(), pathOval.points().size());
    ASSERT_NE(pathClone.points().data(), pathOval.points().data());
    ASSERT_EQ(pathClone.elements().size(), pathOval.elements().size());
    ASSERT_NE(pathClone.elements().data(), pathOval.elements().data());
}

TEST_F(VPathTest, copyOnWrite) {
    VPath pathCopy;
    pathCopy = pathOval;
    ASSERT_EQ(pathCopy.segments(), pathOval.segments());
    ASSERT_EQ(pathCopy.points().size(), pathOval.points().size());
    ASSERT_EQ(pathCopy.points().data(), pathOval.points().data());
    ASSERT_EQ(pathCopy.elements().size(), pathOval.elements().size());
    ASSERT_EQ(pathCopy.elements().data(), pathOval.elements().data());
}

TEST_F(VPathTest, addRect) {
    ASSERT_FALSE(pathRect.empty());
    ASSERT_EQ(pathRect.segments() , 1);
    ASSERT_EQ(pathRect.elements().capacity() , pathRect.elements().size());
    ASSERT_EQ(pathRect.points().capacity() , pathRect.points().size());
}

TEST_F(VPathTest, addRect_N) {
    pathEmpty.addRect({});
    ASSERT_TRUE(pathEmpty.empty());
    ASSERT_EQ(pathEmpty.segments() , 0);
}

TEST_F(VPathTest, addRoundRect) {
    ASSERT_FALSE(pathRoundRect.empty());
    ASSERT_EQ(pathRoundRect.segments() , 1);
    ASSERT_EQ(pathRoundRect.elements().capacity() , pathRoundRect.elements().size());
    ASSERT_EQ(pathRoundRect.points().capacity() , pathRoundRect.points().size());
}

TEST_F(VPathTest, addRoundRectZeoCorner) {
    ASSERT_FALSE(pathRoundRectZeroCorner.empty());
    ASSERT_EQ(pathRoundRectZeroCorner.segments() , 1);
    ASSERT_EQ(pathRoundRectZeroCorner.elements().size() , pathRect.elements().size());
    ASSERT_EQ(pathRoundRectZeroCorner.elements().capacity() , pathRoundRectZeroCorner.elements().size());
    ASSERT_EQ(pathRoundRectZeroCorner.points().size() , pathRect.points().size());
    ASSERT_EQ(pathRoundRectZeroCorner.points().capacity() , pathRoundRectZeroCorner.points().size());
}

TEST_F(VPathTest, addRoundRectHalfCircle) {
    ASSERT_FALSE(pathRoundRectHalfCircle.empty());
    ASSERT_EQ(pathRoundRectHalfCircle.segments() , 1);
    ASSERT_EQ(pathRoundRectHalfCircle.elements().capacity() , pathRoundRectHalfCircle.elements().size());
    ASSERT_EQ(pathRoundRectHalfCircle.points().capacity() , pathRoundRectHalfCircle.points().size());
}

TEST_F(VPathTest, addOval) {
    ASSERT_FALSE(pathOval.empty());
    ASSERT_EQ(pathOval.segments() , 1);
    ASSERT_EQ(pathOval.elements().capacity() , pathOval.elements().size());
    ASSERT_EQ(pathOval.points().capacity() , pathOval.points().size());
}

TEST_F(VPathTest, addOvalCircle) {
    ASSERT_FALSE(pathOvalCircle.empty());
    ASSERT_EQ(pathOvalCircle.segments() , 1);
    ASSERT_EQ(pathOvalCircle.elements().size() , pathOval.elements().size());
    ASSERT_EQ(pathOvalCircle.elements().capacity() , pathOvalCircle.elements().size());
    ASSERT_EQ(pathOvalCircle.points().size() , pathOval.points().size());
    ASSERT_EQ(pathOvalCircle.points().capacity() , pathOvalCircle.points().size());
}

TEST_F(VPathTest, addCircle) {
    ASSERT_FALSE(pathCircle.empty());
    ASSERT_EQ(pathCircle.segments() , 1);
    ASSERT_EQ(pathCircle.elements().size() , pathOval.elements().size());
    ASSERT_EQ(pathCircle.elements().capacity() , pathCircle.elements().size());
    ASSERT_EQ(pathCircle.points().size() , pathOval.points().size());
    ASSERT_EQ(pathCircle.points().capacity() , pathCircle.points().size());
}

TEST_F(VPathTest, addPolygon) {
    ASSERT_FALSE(pathPolygon.empty());
    ASSERT_EQ(pathPolygon.segments() , 1);
    ASSERT_EQ(pathPolygon.elements().size() , pathPolygon.elements().capacity());
    ASSERT_EQ(pathPolygon.points().size() , pathPolygon.points().capacity());
}
