tables_color_quantization = custom_target(
    'gen-color-quantization',
    input: [],
    output: ['tables_color_quantization.h'],
    command: [codegen, 'quantize', '@OUTPUT0@']
)

tables_data_size = custom_target(
    'gen-data-size',
    input: [],
    output: ['tables_data_size.h'],
    command: [codegen, 'datasize', '@OUTPUT0@']
)

tables_integer_sequence_encoding = custom_target(
    'gen-integer_sequence_encoding-tables',
    input: [],
    output: ['tables_integer_sequence_encoding.h'],
    command: [codegen, 'bise', '@OUTPUT0@']
)

astc_sources = [
    'bitmanip.h',
    'colors.h',
    'compress_block.cc',
    'compress_block.h',
    'compress_texture.cc',
    'compress_texture.h',
    'constants.h',
    'data_size.h',
    'dcheck.h',
    'endpoints.h',
    'endpoints_bounding_box.h',
    'endpoints_encode.h',
    'endpoints_min_max.h',
    'endpoints_principal_components.cc',
    'endpoints_principal_components.h',
    'endpoints_quantize.h',
    'integer_sequence_encoding.h',
    'matrix.cc',
    'matrix.h',
    'misc.h',
    'range.h',
    'store_block.h',
    'vector.h',
    'weights_quantize.h',
    'weights_quantize_table.h',
    tables_color_quantization,
    tables_data_size,
    tables_integer_sequence_encoding,
]

astc = static_library(
    'astc',
    sources: astc_sources,
    include_directories: incdir
)
