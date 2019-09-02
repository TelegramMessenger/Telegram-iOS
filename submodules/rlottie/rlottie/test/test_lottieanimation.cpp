#include <gtest/gtest.h>
#include "rlottie.h"

class AnimationTest : public ::testing::Test {
public:
    void SetUp()
    {
        animationInvalid = rlottie::Animation::loadFromFile("wrong_file.json");
        std::string filePath = DEMO_DIR;
        filePath +="mask.json";
        animation = rlottie::Animation::loadFromFile(filePath);

    }
    void TearDown()
    {

    }
public:
    std::unique_ptr<rlottie::Animation> animationInvalid;
    std::unique_ptr<rlottie::Animation> animation;
};

TEST_F(AnimationTest, loadFromFile_N) {
    ASSERT_FALSE(animationInvalid);
}

TEST_F(AnimationTest, loadFromFile) {
    ASSERT_TRUE(animation != nullptr);
    ASSERT_EQ(animation->totalFrame(), 30);
    size_t width, height;
    animation->size(width, height);
    ASSERT_EQ(width, 500);
    ASSERT_EQ(height, 500);
}
