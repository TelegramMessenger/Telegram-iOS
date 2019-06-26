from bise import compute_bise_bitcount
from endpointmodes import *
from range import *

# Count the number of set bits in a number.
def count_bits(x):
    assert type(x) is int
    assert x >= 0 # negative integers are undefined behaviour

    count = 0
    while x != 0:
        if x & 1:
            count = count + 1
        x = x >> 1

    return count

# Calculate the number of bits used for config data, texel weight data and
# color endpoint data for an ASTC block.
def data_size(
        partitions,
        single_cem,
        block_width,
        block_height,
        block_depth,
        dual_plane,
        weight_range):

    assert partitions >= 1 and partitions <= 4
    assert isinstance(single_cem, bool), single_cem
    assert block_width >= 1 and block_width <= 12
    assert block_height >= 1 and block_height <= 12
    assert block_depth >= 1 and block_depth <= 12
    assert isinstance(dual_plane, bool)
    assert weight_range < WEIGHT_RANGE_MAX

    if partitions == 4 and dual_plane:
        raise ValueError("illegal encoding with 4 partitions and dual planes")

    config_bits = 17
    if partitions > 1:
        if single_cem:
            config_bits = 29
        else:
            config_bits = 24 + 3 * partitions

    weights = block_width * block_height * block_depth

    if weights > 64:
        raise ValueError("illegal encoding with {} (> 64) weights".format(weights))

    if dual_plane:
        config_bits += 2
        weights *= 2

    weight_bits = compute_bise_bitcount(weights, weight_range)

    if weight_bits < 24:
        raise ValueError("illegal encoding with {} (< 24) weight bits".format(weight_bits))

    if weight_bits > 96:
        raise ValueError("illegal encoding with {} (> 96) weight bits".format(weight_bits))

    remaining_bits = 128 - config_bits - weight_bits

    return config_bits, weight_bits, remaining_bits

# Define the class for every color endpoint mode. Used to derive the range for
# color endpoint encoding.
CEM_VALUE_COUNT_TABLE = \
    [
        2, 2, 2, 2,
        4, 4, 4, 4,
        6, 6, 6, 6,
        8, 8, 8, 8
    ]

# Count the number of encoded color endpoint values we are storing.
def cem_values_count(cem, partitions):
    assert cem < CEM_MAX

    # The ASTC specification derives this count from the CEM class and a value
    # they call extra_CEM_bits. I do not understand what extra_CEM_bits is
    # referring to, I use the CEM_VALUE_COUNT_TABLE instead and assume that
    # there is one set of endpoint values for each partition.
    return CEM_VALUE_COUNT_TABLE[cem] * partitions

# Calculate the range for color endpoint encoding for a given number of
# remaining bits.
def color_endpoint_range(cem, remaining_bits, partitions):
    assert cem < CEM_MAX

    cem_values = cem_values_count(cem, partitions)

    if cem_values > 18:
        raise ValueError("illegal encoding with {} (> 18) integers for color endpoints".format(cem_values))

    # Brute-force search for the biggest range which fits in the remaining
    # bits.
    for ce_range in reversed(range(RANGE_MAX)):
        cem_bits = compute_bise_bitcount(cem_values, ce_range)

        if cem_bits <= remaining_bits:
            return ce_range

    raise ValueError("illegal encoding with not enough bits for cem {}".format(remaining_bits))

def color_endpoint_range_table(block_width, block_height):
    def handle_except(partitions, cem, weight_range):
        assert weight_range < WEIGHT_RANGE_MAX
        try:
            _, _, remaining_bits = data_size(
                partitions = partitions,
                single_cem = True,
                block_width = block_width,
                block_height = block_height,
                block_depth = 1,
                dual_plane = False,
                weight_range = weight_range)
            return color_endpoint_range(cem, remaining_bits, partitions)
        except ValueError:
            return -1

    return \
        [
            [
                [
                    handle_except(partitions, cem, weight_range)
                    for cem in range(CEM_MAX)
                ]
                for weight_range in range(WEIGHT_RANGE_MAX)
            ]
            for partitions in [1, 2]
        ]

if __name__ == "__main__":
    print(color_endpoint_range_table(4, 4))
