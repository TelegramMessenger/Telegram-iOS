subdir('vector')
subdir('lottie')
subdir('binding')

library_deps  = vector_dep
library_deps += lottie_dep
library_deps += binding_dep

rlottie_lib = shared_library('rlottie',
                             include_directories : inc,
                             version             : meson.project_version(),
                             dependencies        : library_deps,
                             install             : true
                            )
