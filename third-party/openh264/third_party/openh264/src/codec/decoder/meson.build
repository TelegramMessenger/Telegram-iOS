cpp_sources = [
  'core/src/au_parser.cpp',
  'core/src/bit_stream.cpp',
  'core/src/cabac_decoder.cpp',
  'core/src/deblocking.cpp',
  'core/src/decode_mb_aux.cpp',
  'core/src/decode_slice.cpp',
  'core/src/decoder.cpp',
  'core/src/decoder_core.cpp',
  'core/src/decoder_data_tables.cpp',
  'core/src/error_concealment.cpp',
  'core/src/fmo.cpp',
  'core/src/get_intra_predictor.cpp',
  'core/src/manage_dec_ref.cpp',
  'core/src/memmgr_nal_unit.cpp',
  'core/src/mv_pred.cpp',
  'core/src/parse_mb_syn_cabac.cpp',
  'core/src/parse_mb_syn_cavlc.cpp',
  'core/src/pic_queue.cpp',
  'core/src/rec_mb.cpp',
  'plus/src/welsDecoderExt.cpp',
  'core/src/wels_decoder_thread.cpp',
]

objs_asm = []
if cpu_family in ['x86', 'x86_64']
  asm_sources = [
    'core/x86/dct.asm',
    'core/x86/intra_pred.asm',
  ]
  objs_asm = asm_gen.process(asm_sources)
elif cpu_family == 'arm'
  asm_sources = [
    'core/arm/block_add_neon.S',
    'core/arm/intra_pred_neon.S',
  ]
  if use_asm_gen
    objs_asm = asm_gen.process(asm_sources)
  else
    cpp_sources += asm_sources
  endif
elif cpu_family == 'aarch64'
  asm_sources = [
    'core/arm64/block_add_aarch64_neon.S',
    'core/arm64/intra_pred_aarch64_neon.S',
  ]
  if use_asm_gen
    objs_asm = asm_gen.process(asm_sources)
  else
    cpp_sources += asm_sources
  endif
elif cpu_family in ['loongarch32', 'loongarch64']
  asm_sources = [
    'core/loongarch/mb_aux_lsx.c',
  ]
  cpp_sources += asm_sources
else
  error('Unsupported cpu family @0@'.format(cpu_family))
endif

libdecoder = static_library('decoder', cpp_sources, objs_asm,
  include_directories: [inc, decoder_inc, casm_inc],
  dependencies: deps)
