
override_default = ['warning_level=2', 'werror=false']

common_source  = files('evasapp.cpp')
common_source += files('lottieview.cpp')

demo_sources = files('demo.cpp')
demo_sources += common_source

executable('lottie2gif',
           'lottie2gif.cpp',
           include_directories : inc,
           override_options : override_default,
           link_with : rlottie_lib)

executable('vectorTest',
           'vectortest.cpp',
           include_directories : inc,
           dependencies : [rlottie_lib_dep])

demo_dep = dependency('elementary', required : false)

if (demo_dep.found())
    executable('demo',
               demo_sources,
               include_directories : inc,
               override_options : override_default,
               link_with : rlottie_lib,
               dependencies : demo_dep)

    lottieview_test_src  = files('lottieviewtest.cpp')
    lottieview_test_src += common_source

    executable('lottieviewTest',
               lottieview_test_src,
               include_directories : inc,
               override_options : override_default,
               link_with : rlottie_lib,
               dependencies : demo_dep)

    uxsample_test_src  = files('uxsampletest.cpp')
    uxsample_test_src += common_source

    executable('uxsampleTest',
               uxsample_test_src,
               include_directories : inc,
               override_options : override_default,
               link_with : rlottie_lib,
               dependencies : demo_dep)

    lottieviewer_sources = files('lottieviewer.cpp')
    lottieviewer_sources += common_source

    executable('lottieviewer',
               lottieviewer_sources,
               include_directories : inc,
               override_options : override_default,
               link_with : rlottie_lib,
               dependencies : demo_dep)

if (meson.get_compiler('cpp').has_header('elementary-1/efl_ui_animation_view.h'))
    executable('efl_animview',
               'efl_animview.cpp',
               include_directories : inc,
               link_with : rlottie_lib,
               override_options : override_default,
               dependencies : demo_dep)
endif

endif
