# There are 21 ranges (intervals in math lingo) for endpoint values.
RANGE_2 = 0
RANGE_3 = 1
RANGE_4 = 2
RANGE_5 = 3
RANGE_6 = 4
RANGE_8 = 5
RANGE_10 = 6
RANGE_12 = 7
RANGE_16 = 8
RANGE_20 = 9
RANGE_24 = 10
RANGE_32 = 11
RANGE_40 = 12
RANGE_48 = 13
RANGE_64 = 14
RANGE_80 = 15
RANGE_96 = 16
RANGE_128 = 17
RANGE_160 = 18
RANGE_192 = 19
RANGE_256 = 20
RANGE_MAX = 21

# Table of each range's cardinality, that is the number of representable
# integers in each range.
RANGE_CARDINALITY_TABLE = \
    [
        2,
        3,
        4,
        5,
        6,
        8,
        10,
        12,
        16,
        20,
        24,
        32,
        40,
        48,
        64,
        80,
        96,
        128,
        160,
        192,
        256
    ]

# There are 12 ranges for texel weights.
WEIGHT_RANGE_MAX = 12

def range_lookup(count):
    """
    Find what quantization range an number of elements can be represented with.
    """

    assert type(count) is int
    assert count >= 2 and count <= 256

    for i in range(RANGE_MAX):
        if count <= RANGE_CARDINALITY_TABLE[i]:
            return i

    assert False
