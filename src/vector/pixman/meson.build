
source_file = ['vregion.cpp']

if host_machine.cpu_family() == 'arm'
  source_file += 'pixman-arm-neon-asm.S'
endif

pixman_dep = declare_dependency(
                                 include_directories : include_directories('.'),
                                  sources : source_file
                                 )
