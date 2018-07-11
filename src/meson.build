subdir('vector')
subdir('lottie')

library_deps  = [vector_dep]
library_deps += lottie_dep

lottie_player_lib = shared_library( 'lottie-player',
                                    include_directories : inc,
                                    version             : lottie_player_lib_version,
                                    dependencies        : library_deps,
                                    install             : true
                                  )
