#include <gtest/gtest.h>
#include "vrect.h"

class VRectFTest : public ::testing::Test {
public:
    void SetUp()
    {
        conersionRect = rect;
    }
    void TearDown()
    {

    }
public:
  VRectF Empty;
  VRectF illigal{0, 0, -100, 200};
  VRectF conersionRect;
  VRect  rect{0, 0, 100, 100};
};

class VRectTest : public ::testing::Test {
public:
    void SetUp()
    {
        conersionRect = rect;
    }
    void TearDown()
    {

    }
public:
  VRect Empty;
  VRect illigal{0, 0, -100, 200};
  VRect conersionRect;
  VRectF  rect{0, 0, 100.5, 100};
};

TEST_F(VRectFTest, construct) {
    VRectF r1{0, 0, 100, 100};
    VRectF r2{0, 0, 100.0, 100};
    VRectF r3 = {0, 0, 100, 100};
    VRectF r4 = {0, 0, 100.0, 100};
    VRectF r6(0, 0, 100, 100);
    VRectF r7(0, 0, 100.0, 100);
    ASSERT_TRUE(Empty.empty());
    ASSERT_TRUE(illigal.empty());
}

TEST_F(VRectTest, construct) {
    VRect r1{0, 0, 100, 100};
    VRect r2{0, 0, 10, 100};
    VRect r3 = {0, 0, 100, 100};
    VRect r4 = {0, 0, 10, 100};
    VRect r6(0, 0, 100, 100);
    VRect r7(0, 0, 10, 100);
    ASSERT_TRUE(Empty.empty());
    ASSERT_TRUE(illigal.empty());
}
