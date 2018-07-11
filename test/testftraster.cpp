#include <gtest/gtest.h>
#include "vpath.h"
#include "vraster.h"

class VRasterTest : public ::testing::Test {
public:
    void SetUp()
    {
        path.moveTo(VPointF(0,0));
        path.lineTo(VPointF(10,0));
        path.lineTo(VPointF(10,10));
        path.lineTo(VPointF(0,10));
        path.close();
        pathRect = VRect(0,0,10,10);
    }
    void TearDown()
    {

    }
public:
  VPath path;
  VRect pathRect;
};


TEST_F(VRasterTest, constructor) {
    FTOutline *outline = VRaster::toFTOutline(path);
    ASSERT_TRUE(outline != nullptr);
    VRaster::deleteFTOutline(outline);
}
