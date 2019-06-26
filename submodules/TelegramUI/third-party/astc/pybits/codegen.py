#!/usr/bin/env python

import bise
import datasize
import partitions
import quantize
import sys


def safe_head(lst, default):
    try:
        return lst[0]
    except:
        return default


def compute_dimensions(array):
    if isinstance(array, list):
        yield len(array)
        yield from compute_dimensions(array[-1])


def pretty_array(element, fmt):
    if isinstance(element, int):
        return fmt % element
    elif isinstance(element, tuple) or isinstance(element, list):
        return pretty_array(iter(element), fmt)
    else:
        first = next(element)

        out = "{"
        out += pretty_array(first, fmt)
        for x in element:
            out += ","
            out += pretty_array(x, fmt)
        out += "}"
        return out


def pretty_dimensions(dimensions):
    out = ""
    for dimension in dimensions:
        out += "[" + str(dimension) + "]"
    return out

header_template = """#ifndef {guard}
#define {guard}

{content}

#endif
"""

array_template = "const {type} {name}{dimensions} = {array};"


def build_header(guard, content):
    return header_template.format(guard=guard, content=content)


def build_array(type, name, array):
    return array_template.format(
        name=name,
        type=type,
        dimensions=pretty_dimensions(compute_dimensions(array)),
        array=pretty_array(array, "%d"),
    )


def print_bise_tables(file):
    trits_from_integer = bise.trits_from_integer_table()
    integer_from_trits = bise.integer_from_trits_table(trits_from_integer)
    quints_from_integer = bise.quints_from_integer_table()
    integer_from_quints = bise.integer_from_quints_table(quints_from_integer)

    file.write(build_header(
        "ASTC_TABLES_INTEGER_SEQUENCE_ENCODING_H_",
        build_array("uint8_t", "integer_from_trits", integer_from_trits) +
        '\n' +
        build_array("uint8_t", "integer_from_quints", integer_from_quints)
    ))


def print_partitions_tables(file):
    table = list(partitions.compute_partitioning_table(
        partition_count=2,
        block_width=4,
        block_height=4))
    lookup_table = partitions.compute_partitioning_lookup_table(table)

    file.write(build_header(
        "ASTC_TABLES_PARTITIONS_H_",
        build_array(
            "uint16_t",
            "partition_2_4x4_mask_table",
            [part.partition_mask for part in table]
        ) + '\n' +
        build_array(
            "int16_t",
            "partition_2_4x4_lookup_table",
            [safe_head(parts, -1) for parts in lookup_table]
        )
    ))


def print_data_size_table(file, block_width, block_height):
    table = datasize.color_endpoint_range_table(block_width, block_height)
    file.write(build_header(
        "ASTC_TABLES_DATA_SIZE_H_",
        build_array("int8_t", "color_endpoint_range_table", table)
    ))


def print_color_quantization_tables(file):
    unquantize_table = quantize.color_unquantize_table()
    quantize_table = quantize.color_quantize_table(unquantize_table)

    file.write(build_header(
        "ASTC_TABLES_COLOR_QUANTIZATION_H_",
        build_array("uint8_t", "color_unquantize_table", unquantize_table) +
        '\n' +
        build_array("uint8_t", "color_quantize_table", quantize_table)
    ))


def print_usage(prog):
    sys.stderr.write(
        ("Usage: %s COMMAND\n"
         "  Commands:\n"
         "    bise\n"
         "    partitions\n"
         "    datasize\n"
         "    quantize\n") % prog)


def main(kind, path):
    file = open(path, 'w') if path != '-' else sys.stdout
    if kind == "bise":
        print_bise_tables(file)
    elif kind == "partitions":
        print_partitions_tables(file)
    elif kind == "datasize":
        print_data_size_table(file, 4, 4)
    elif kind == "quantize":
        print_color_quantization_tables(file)
    else:
        sys.stderr.write("Error: unknown mode {}\n".format(kind))
        sys.exit(1)


if len(sys.argv) != 3:
    print_usage(sys.argv[0])
else:
    main(sys.argv[1], sys.argv[2])
