cpp_sources = [
  'src/common_tables.cpp',
  'src/copy_mb.cpp',
  'src/cpu.cpp',
  'src/crt_util_safe_x.cpp',
  'src/deblocking_common.cpp',
  'src/expand_pic.cpp',
  'src/intra_pred_common.cpp',
  'src/mc.cpp',
  'src/memory_align.cpp',
  'src/sad_common.cpp',
  'src/utils.cpp',
  'src/welsCodecTrace.cpp',
  'src/WelsTaskThread.cpp',
  'src/WelsThread.cpp',
  'src/WelsThreadLib.cpp',
  'src/WelsThreadPool.cpp',
]

objs_asm = []
if cpu_family in ['x86', 'x86_64']
  asm_sources = [
    'x86/cpuid.asm',
    'x86/dct.asm',
    'x86/deblock.asm',
    'x86/expand_picture.asm',
    'x86/intra_pred_com.asm',
    'x86/mb_copy.asm',
    'x86/mc_chroma.asm',
    'x86/mc_luma.asm',
    'x86/satd_sad.asm',
    'x86/vaa.asm',
  ]
  objs_asm += asm_gen.process(asm_sources)
elif cpu_family == 'arm'
  asm_sources = [
    'arm/copy_mb_neon.S',
    'arm/deblocking_neon.S',
    'arm/expand_picture_neon.S',
    'arm/intra_pred_common_neon.S',
    'arm/mc_neon.S',
  ]
  if use_asm_gen
    objs_asm = asm_gen.process(asm_sources)
  else
    cpp_sources += asm_sources
  endif
elif cpu_family == 'aarch64'
  asm_sources = [
    'arm64/copy_mb_aarch64_neon.S',
    'arm64/deblocking_aarch64_neon.S',
    'arm64/expand_picture_aarch64_neon.S',
    'arm64/intra_pred_common_aarch64_neon.S',
    'arm64/mc_aarch64_neon.S',
  ]
  if use_asm_gen
    objs_asm = asm_gen.process(asm_sources)
  else
    cpp_sources += asm_sources
  endif
else
  error('Unsupported cpu_family @0@'.format(cpu_family))
endif

libcommon = static_library('common', cpp_sources, objs_asm,
  include_directories: [inc, casm_inc],
  dependencies: deps)
