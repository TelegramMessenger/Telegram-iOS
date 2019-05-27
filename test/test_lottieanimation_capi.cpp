#include <gtest/gtest.h>
#include "lottieanimation_capi.h"

class AnimationCApiTest : public ::testing::Test {
public:
    void SetUp()
    {
        animationInvalid = lottie_animation_from_file("wrong_file.json");
        std::string filePath = DEMO_DIR;
        filePath +="mask.json";
        animation = lottie_animation_from_file(filePath.c_str());

    }
    void TearDown()
    {
        if (animation) lottie_animation_destroy(animation);
    }
public:
    Lottie_Animation *animationInvalid;
    Lottie_Animation *animation;
};

TEST_F(AnimationCApiTest, loadFromFile_N) {
    ASSERT_FALSE(animationInvalid);
}

TEST_F(AnimationCApiTest, loadFromFile) {
    ASSERT_TRUE(animation);
    ASSERT_EQ(lottie_animation_get_totalframe(animation), 30);
    size_t width, height;
    lottie_animation_get_size(animation, &width, &height);
    ASSERT_EQ(width, 500);
    ASSERT_EQ(height, 500);
}
