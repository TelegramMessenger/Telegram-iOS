
common_source  = files('evasapp.cpp')
common_source += files('lottieview.cpp')

demo_sources = files('demo.cpp')
demo_sources += common_source

demo_dep = []
demo_dep+= dependency('elementary')


executable('demo',
           demo_sources,
           include_directories : inc,
           link_with : lottie_player_lib,
           dependencies : demo_dep)

lottieview_test_src  = files('lottieviewtest.cpp')
lottieview_test_src += common_source

executable('lottieviewTest',
           lottieview_test_src,
           include_directories : inc,
           link_with : lottie_player_lib,
           dependencies : demo_dep)

uxsample_test_src  = files('uxsampletest.cpp')
uxsample_test_src += common_source

executable('uxsampleTest',
           uxsample_test_src,
           include_directories : inc,
           link_with : lottie_player_lib,
           dependencies : demo_dep)

lottieviewer_sources = files('lottieviewer.cpp')
lottieviewer_sources += common_source

executable('lottieviewer',
           lottieviewer_sources,
           include_directories : inc,
           link_with : lottie_player_lib,
           dependencies : demo_dep)

executable('vectorTest',
           'vectortest.cpp',
           include_directories : inc,
           dependencies : [library_deps])
