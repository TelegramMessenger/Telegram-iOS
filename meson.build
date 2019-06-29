project('rlottie',
        'cpp',
        version : '0.0.1',
        license : 'Apache')

add_global_arguments('-DDEMO_DIR="@0@/example/resource/"'.format(meson.current_source_dir()), language : 'cpp')

compiler_flags = []
compiler_flags_try = ['-std=c++14', '-Os', '-Wall', '-Werror', '-Wextra', '-fno-exceptions', '-fno-rtti',
                      '-fno-unwind-tables' , '-fno-asynchronous-unwind-tables',
                      '-Wnon-virtual-dtor', '-Woverloaded-virtual', '-Wno-unused-parameter', '-fvisibility=hidden']

cc = meson.get_compiler('cpp')
foreach cf: compiler_flags_try
  if cc.has_argument(cf) == true
    compiler_flags += cf
  endif
endforeach


if (build_machine.system() == 'linux')
    compiler_flags += ['-pthread']
    add_global_link_arguments('-pthread', language: 'cpp')
endif

add_global_arguments(compiler_flags, language: 'cpp')

inc = [include_directories('inc')]
config_dir = include_directories('.')
inc += config_dir

config_h = configuration_data()

if get_option('thread') == true
    config_h.set10('LOTTIE_THREAD_SUPPORT', true)
endif

if get_option('module') == true
    config_h.set10('LOTTIE_IMAGE_MODULE_SUPPORT', true)
endif

if get_option('cache') == true
    config_h.set10('LOTTIE_CACHE_SUPPORT', true)
endif

if get_option('log') == true
    config_h.set10('LOTTIE_LOGGING_SUPPORT', true)
endif

if get_option('dumptree') == true
    config_h.set10('LOTTIE_LOGGING_SUPPORT', true)
    config_h.set10('LOTTIE_DUMP_TREE_SUPPORT', true)
endif


configure_file(
  output: 'config.h',
  configuration: config_h
)


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
                  version     : meson.project_version(),
                  name        : 'librlottie',
                  filebase    : 'rlottie',
                  description : 'A Library for rendering lottie files.'
                )
