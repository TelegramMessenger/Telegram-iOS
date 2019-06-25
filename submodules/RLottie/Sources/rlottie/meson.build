project('rlottie library',
        'cpp',
        license : 'Apache')

rlottie_lib_version = '0.0.1'

add_global_arguments('-DDEMO_DIR="@0@/example/resource/"'.format(meson.current_source_dir()), language : 'cpp')

compiler_flags = ['-std=c++14', '-Os', '-Wall', '-Werror', '-Wextra', '-fno-exceptions', '-fno-rtti',
                   '-fno-unwind-tables' , '-fno-asynchronous-unwind-tables',
                  '-Wnon-virtual-dtor', '-Woverloaded-virtual', '-Wno-unused-parameter', '-fvisibility=hidden']


if (build_machine.system() == 'linux')
    compiler_flags += ['-pthread']
    add_global_link_arguments('-pthread', language: 'cpp')
endif

add_global_arguments(compiler_flags, language: 'cpp')

inc = include_directories('inc')

subdir('inc')
subdir('src')

if get_option('example') == true
    subdir('example')
endif

if get_option('test') == true
   subdir('test')
endif

pkg_mod = import('pkgconfig')

pkg_mod.generate( libraries   : rlottie_lib,
                  version     : rlottie_lib_version,
                  name        : 'librlottie',
                  filebase    : 'rlottie',
                  description : 'A Library for rendering lottie files.'
                )
