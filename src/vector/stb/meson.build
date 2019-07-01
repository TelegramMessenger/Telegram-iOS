
source_file = ['stb_image.cpp']

inc_dir = [include_directories('.')]
inc_dir += config_dir

if get_option('module') == true
    rlottie_image_loader_lib = shared_library('rlottie-image-loader',
                                              source_file,
                                              include_directories : inc_dir,
                                              install : true,
                                              gnu_symbol_visibility : 'hidden',
                                             )
    # dl dependancy for dlopen, dlsym, dlclose symbol
    cc = meson.get_compiler('cpp')
    stb_dep = cc.find_library('dl', required : false)
else
    stb_dep = declare_dependency(
                                  include_directories : inc_dir,
                                  sources : source_file
                                 )
endif


