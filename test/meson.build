
test_sources_util = ['ssgtestsuite.cpp',
                     'testsgregion.cpp'
                    ]
test_sources_ftraster = ['testftraster.cpp'
                        ]

test_sources =[]
test_sources += test_sources_util
test_sources += test_sources_ftraster

test_dep = dependency('gtest')

ssg_utest = executable('testexe',
                       test_sources,
                       include_directories : inc,
                       link_with : lottie_player_lib_version,
                       dependencies : test_dep)

test('ssgsuite test', ssg_utest)
