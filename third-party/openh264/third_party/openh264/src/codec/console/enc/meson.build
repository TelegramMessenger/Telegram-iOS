cpp_sources = [
  'src/welsenc.cpp',
]

encexe = executable('h264enc', cpp_sources,
  include_directories: [inc, console_common_inc, processing_inc, encoder_inc],

  link_with: [libencoder, libcommon, libprocessing, libconsole_common],
  dependencies: [deps])
