project('rlottie',
        'cpp',
        default_options : ['warning_level=3', 'werror=true', 'cpp_std=c++14', 'optimization=s'],
        version : '0.0.1',
        license : 'Apache')

add_project_arguments('-DDEMO_DIR="@0@/example/resource/"'.format(meson.current_source_dir()), language : 'cpp')
add_project_arguments('-DLOT_BUILD', language: 'cpp')

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

