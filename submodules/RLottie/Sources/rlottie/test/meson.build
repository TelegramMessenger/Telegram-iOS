
vector_test_sources  = files('testsuite.cpp')
vector_test_sources += files('test_vpath.cpp')

gtest_dep  = dependency('gtest')

vector_testsuite = executable('vectorTestSuite',
                              vector_test_sources,
                              include_directories : inc,
                              dependencies : [gtest_dep, library_deps])

test('Vector Testsuite', vector_testsuite)


animation_test_sources  = files('testsuite.cpp')
animation_test_sources += files('test_lottieanimation.cpp')
animation_test_sources += files('test_lottieanimation_capi.cpp')

animation_testsuite = executable('animationTestSuite',
                              animation_test_sources,
                              include_directories : inc,
                              link_with : rlottie_lib,
                              dependencies : gtest_dep)

test('Animation Testsuite', animation_testsuite)
