
override_default = ['warning_level=2', 'werror=false']

gtest_dep  = dependency('gtest')

vector_test_sources = [
    'testsuite.cpp',
    'test_vrect.cpp',
    'test_vpath.cpp',
    ]

vector_testsuite = executable('vectorTestSuite',
                              vector_test_sources,
                              include_directories : inc,
                              override_options : override_default,
                              dependencies : [gtest_dep, rlottie_lib_dep],
                              )

test('Vector Testsuite', vector_testsuite)


animation_test_sources = [
    'testsuite.cpp',
    'test_lottieanimation.cpp',
    'test_lottieanimation_capi.cpp'
    ]

animation_testsuite = executable('animationTestSuite',
                              animation_test_sources,
                              include_directories : inc,
                              override_options : override_default,
                              link_with : rlottie_lib,
                              dependencies : gtest_dep,
                              )

test('Animation Testsuite', animation_testsuite)
