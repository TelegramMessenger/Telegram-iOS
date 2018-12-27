
subdir('freetype')
subdir('pixman')

vector_dep = [freetype_dep]
vector_dep += pixman_dep

source_file   = files('vdasher.cpp')
source_file  += files('vbrush.cpp')
source_file  += files('vbitmap.cpp')
source_file  += files('vpainter.cpp')
source_file  += files('vcompositionfunctions.cpp')
source_file  += files('vdrawhelper.cpp')
source_file  += files('vdrawhelper_sse2.cpp')
source_file  += files('vdrawable.cpp')


source_file  += files('vrle.cpp')
source_file  += files('vpath.cpp')
source_file  += files('vpathmesure.cpp')
source_file  += files('vmatrix.cpp')
source_file  += files('velapsedtimer.cpp')
source_file  += files('vdebug.cpp')
source_file  += files('vinterpolator.cpp')
source_file  += files('vbezier.cpp')
source_file  += files('vraster.cpp')

vector_dep += declare_dependency( include_directories : include_directories('.'),
                                  sources             : source_file
                                )


