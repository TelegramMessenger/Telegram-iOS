
subdir('freetype')
subdir('pixman')
subdir('stb')

source_file = [
    'vdasher.cpp',
    'vbrush.cpp',
    'vbitmap.cpp',
    'vpainter.cpp',
    'vcompositionfunctions.cpp',
    'vdrawhelper.cpp',
    'vdrawhelper_sse2.cpp',
    'vdrawhelper_neon.cpp',
    'vdrawable.cpp',
    'vrect.cpp',
    'vrle.cpp',
    'vpath.cpp',
    'vpathmesure.cpp',
    'vmatrix.cpp',
    'velapsedtimer.cpp',
    'vdebug.cpp',
    'vinterpolator.cpp',
    'vbezier.cpp',
    'vraster.cpp',
    'vimageloader.cpp',
]

vector_dep = declare_dependency( include_directories : include_directories('.'),
                                  sources             : source_file,
                                  dependencies        : [freetype_dep, pixman_dep, stb_dep],
                                )


