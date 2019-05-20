
source_file  = files('vregion.cpp')

if host_machine.cpu_family() == 'arm' or host_machine.cpu_family() == 'aarch64'
  source_file +=  files('pixman-arm-neon-asm.S')
endif

pixman_dep = declare_dependency(
                                 include_directories : include_directories('.'),
                                  sources : source_file
                                 )
