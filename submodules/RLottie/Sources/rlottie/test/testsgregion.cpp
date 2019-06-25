#include <gtest/gtest.h>
#include"vregion.h"
#include"vdebug.h"
#include"vpoint.h"
class VRegionTest : public ::testing::Test {
public:
    VRegionTest():rgn1(-10, -10, 20, 20)
    {
    }
    void SetUp()
    {
        rect1 = VRect(-10, -10, 20, 20);
        rect2 = VRect(-15, 5, 10, 10);
        rgn2 += rect2;
        rgn3 = rgn1;
    }
    void TearDown()
    {

    }
public:
    VRegion emptyRgn;
    VRegion rgn1;
    VRegion rgn2;
    VRegion rgn3;
    VRect rect1;
    VRect rect2;
    VRect rect3;

};

TEST_F(VRegionTest, constructor) {
    ASSERT_EQ(rgn1.rectCount() , 1);
    ASSERT_TRUE(rgn1.rectAt(0) == rect1);
    ASSERT_TRUE(rgn1==rgn3);
    ASSERT_TRUE(rgn1!=rgn2);
}

TEST_F(VRegionTest, moveSemantics) {
    // move assignment

    rgn1 = rect1;
    VRegion tmp;
    tmp = std::move(rgn1);
    ASSERT_TRUE(rgn1.empty());

    // move construction
    rgn1 = rect1;
    VRegion mvrgn = std::move(rgn1);
    ASSERT_TRUE(rgn1.empty());
    ASSERT_TRUE(mvrgn == rect1);
}
TEST_F(VRegionTest, isEmpty) {
    ASSERT_TRUE(emptyRgn.empty());
    ASSERT_TRUE(emptyRgn == VRegion());
    ASSERT_TRUE(emptyRgn.rectCount() == 0);
    ASSERT_TRUE(emptyRgn.boundingRect() == VRect());
}

TEST_F(VRegionTest, boundingRect) {
    {
        VRect rect;
        VRegion region(rect);
        ASSERT_TRUE(region.boundingRect() == rect);
    }
    {
        VRect rect(10, -20, 30, 40);
        VRegion region(rect);
        ASSERT_TRUE(region.boundingRect() == rect);
    }
    {
        VRect rect(15,25,10,10);
        VRegion region(rect);
        ASSERT_TRUE(region.boundingRect() == rect);
    }
}

TEST_F(VRegionTest, swap) {
    VRegion r1(VRect(0, 0,10,10));
    VRegion r2(VRect(10,10,10,10));
    std::swap(r1 ,r2);
    ASSERT_TRUE(r1.rectAt(0) == VRect(10,10,10,10));
    ASSERT_TRUE(r2.rectAt(0) == VRect(0, 0,10,10));
}

TEST_F(VRegionTest, substracted) {
    VRegion r1(VRect(0, 0,20,20));
    VRegion r2 = r1.subtracted(VRect(5,5,5,5));
    VRegion expected;
    expected += VRect(0,0,20,5);
    expected += VRect(0,5,5,5);
    expected += VRect(10,5,10,5);
    expected += VRect(0,10,20,10);
    ASSERT_TRUE(r2.rectCount() == expected.rectCount());
    ASSERT_TRUE(r2 == expected);
    r2 += VRect(5,5,5,5);
    ASSERT_TRUE(r2 == r1);
}

TEST_F(VRegionTest, translate) {
    VRegion r1(VRect(0, 0,20,20));
    VPoint offset(10,10);
    VRegion r2 =  r1.translated(offset);
    r1.translate(offset);
    ASSERT_TRUE(r2 == r2);
}

TEST_F(VRegionTest, intersects) {
    VRegion r1(VRect(0, 0,20,20));
    VRegion r2(VRect(20, 20,10,10));
    ASSERT_FALSE(r1.intersects(r2));
    r2 += VRect(5, 0,20,20);
    ASSERT_TRUE(r1.intersects(r2));
}

TEST_F(VRegionTest, contains) {
    VRegion r1(VRect(0, 0,20,20));
    ASSERT_TRUE(r1.contains(VRect(5,5,10,10)));
    ASSERT_FALSE(r1.contains(VRect(11,5,10,10)));
}
