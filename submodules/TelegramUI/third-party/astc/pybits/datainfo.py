from bise import compute_bise_bitcount
from datasize import data_size, cem_values_count, color_endpoint_range
from range import RANGE_CARDINALITY_TABLE
import sys


def print_data_size_info(block_width, block_height, cem, partitions,
                         weight_range):
    config_bits, weight_bits, remaining_bits = data_size(
            partitions=partitions,
            single_cem=True,
            block_width=block_width,
            block_height=block_height,
            block_depth=1,
            dual_plane=False,
            weight_range=weight_range
        )

    ce_values = cem_values_count(cem, partitions)
    ce_range = color_endpoint_range(cem, remaining_bits, partitions)
    cem_bits = compute_bise_bitcount(ce_values, ce_range)

    print("block width:", block_width)
    print("block height:", block_height)
    print("config bits:", config_bits)
    print("weight count:", block_width * block_height)
    print("weight range:", RANGE_CARDINALITY_TABLE[weight_range])
    print("weight bits:", weight_bits)
    print("remaining bits:", remaining_bits)
    print("color endpoint values:", ce_values)
    print("color endpoint range:", RANGE_CARDINALITY_TABLE[ce_range])
    print("color endpoint bits:", cem_bits)
    print("unused bits:", remaining_bits - cem_bits)


if len(sys.argv) != 6:
    sys.stderr.write(
        "Usage: {} BLOCKWIDTH BLOCKHEIGHT CEM PARTITIONS WEIGHTRANGE\n".format(
            sys.argv[0]))
else:
    print_data_size_info(
        int(sys.argv[1]),
        int(sys.argv[2]),
        int(sys.argv[3]),
        int(sys.argv[4]),
        int(sys.argv[5]))
