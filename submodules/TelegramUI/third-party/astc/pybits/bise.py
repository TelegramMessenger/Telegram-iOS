from bitset import bitset
from range import *
import math

# Define the number of trits, quints and bits used for an encoded range, this
# table is indexed by N-1 where N is the number of elements in a range.
TRITS_QUINTS_BITS_TABLE = \
    [
        (0, 0, 1), # RANGE_2
        (1, 0, 0), # RANGE_3
        (0, 0, 2), # RANGE_4
        (0, 1, 0), # RANGE_5
        (1, 0, 1), # RANGE_6
        (0, 0, 3), # RANGE_8
        (0, 1, 1), # RANGE_10
        (1, 0, 2), # RANGE_12
        (0, 0, 4), # RANGE_16
        (0, 1, 2), # RANGE_20
        (1, 0, 3), # RANGE_24
        (0, 0, 5), # RANGE_32
        (0, 1, 3), # RANGE_40
        (1, 0, 4), # RANGE_48
        (0, 0, 6), # RANGE_64
        (0, 1, 4), # RANGE_80
        (1, 0, 5), # RANGE_96
        (0, 0, 7), # RANGE_128
        (0, 1, 5), # RANGE_160
        (1, 0, 6), # RANGE_192
        (0, 0, 8)  # RANGE_256
    ]

def bits_bise_bitcount(items, bits):
    """
    Compute the number of bits needed for regular binary encoding.
    """

    assert items > 0 and bits > 0
    return items * bits

def trits_bise_bitcount(items, bits):
    """
    Compute the number of bits needed for trit-based encoding.
    """

    assert items > 0 and bits >= 0
    #return math.ceil((8.0 + 5.0*bits) * items / 5.0)
    return math.ceil(8.0*items / 5.0 + bits*items)

def quints_bise_bitcount(items, bits):
    """
    Compute the number of bits needed for quint-based encoding.
    """

    assert items > 0 and bits >= 0
    #return math.ceil((7.0 + 3.0*bits) * items / 3.0)
    return math.ceil(7.0*items / 3.0 + bits*items)

def compute_bise_bitcount(items, quant):
    """
    Compute the number of bits needed for the BISE stream.
    """
    assert type(items) is int
    assert type(quant) is int
    assert items > 0
    assert quant >= RANGE_2 and quant <= RANGE_256

    trits, quints, bits = TRITS_QUINTS_BITS_TABLE[quant]

    if trits == 0 and quints == 0:
        return bits_bise_bitcount(items, bits)
    elif trits != 0:
        return trits_bise_bitcount(items, bits)
    elif quints != 0:
        return quints_bise_bitcount(items, bits)
    else:
        assert False

def last_index(lst, a):
    last = -1
    for i in range(len(lst)):
        if a == lst[i]:
            last = i
    if last == -1:
        raise ValueError("%s is not in the list" % repr(a))
    return last

# From ASTC specification, decode the a encoded set of 5 trits.
def decode_trits(T):
    assert isinstance(T, bitset)
    assert T.size() == 8

    t4 = -1
    t3 = -1
    t2 = -1
    t1 = -1

    C = bitset(5, 0)
    if T.substr(4, 2) == bitset(3, 0b111):
        C.set(4, T.get(7))
        C.set(3, T.get(6))
        C.set(2, T.get(5))
        C.set(1, T.get(1))
        C.set(0, T.get(0))
        t4 = 2
        t3 = 2
    else:
        C = T.substr(4, 0)
        if T.substr(6, 5) == bitset(2, 0b11):
            t4 = 2
            t3 = T.get(7)
        else:
            t4 = T.get(7)
            t3 = T.substr(6, 5).number()

    if C.substr(1, 0) == bitset(2, 0b11):
        t2 = 2
        t1 = C.get(4)
        t0 = bitset.from_args(C.get(3), C.get(2) & (not C.get(3))).number()
    elif C.substr(3, 2) == bitset(2, 0b11):
        t2 = 2
        t1 = 2
        t0 = C.substr(1, 0).number()
    else:
        t2 = C.get(4)
        t1 = C.substr(3, 2).number()
        t0 = bitset.from_args(C.get(1), C.get(0) & (not C.get(1))).number()

    assert t4 >= 0 and t4 <= 2, t4
    assert t3 >= 0 and t3 <= 2, t3
    assert t2 >= 0 and t2 <= 2, t2
    assert t1 >= 0 and t1 <= 2, t1
    assert t0 >= 0 and t0 <= 2, t0

    return (t0, t1, t2, t3, t4)

# From ASTC specification, decode a encoded set of 3 quints.
def decode_quints(Q):
    assert Q.size() == 7

    q2 = -1
    q1 = -1
    q0 = -1

    if Q.substr(2, 1) == bitset(2, 0b11) and Q.substr(6, 5) == bitset(2, 0b00):
        q2 = bitset.from_args(
            Q.get(0), Q.get(4) & (not Q.get(0)), Q.get(3) & (not Q.get(0))).number()
        q1 = 4
        q0 = 4
    else:
        C = None
        if Q.substr(2, 1) == bitset(2, 0b11):
            q2 = 4
            C = bitset.from_args(
                Q.get(4),
                Q.get(3),
                not Q.get(6),
                not Q.get(5),
                Q.get(0))
        else:
            q2 = Q.substr(6, 5).number()
            C  = Q.substr(4, 0)

        if C.substr(2, 0) == bitset(3, 0b101):
            q1 = 4
            q0 = C.substr(4, 3).number()
        else:
            q1 = C.substr(4, 3).number()
            q0 = C.substr(2, 0).number()

    assert q2 >= 0 and q2 <= 4, q2
    assert q1 >= 0 and q1 <= 4, q1
    assert q0 >= 0 and q0 <= 4, q0

    return (q0, q1, q2)

# Generate table for trit decoding for all possible 8 bit numbers, [0, 255].
def trits_from_integer_table():
    return [decode_trits(bitset(8, i)) for i in range(256)]

# Generate table for trit decoding by brute force searching the encoding table.
# Exhaustive search solution works because the search space is small.
def integer_from_trits_table(trits):
    return \
        [
            [
                [
                    [
                        [
                            last_index(trits, (t0, t1, t2, t3, t4))
                            for t0 in range(3)
                        ]
                        for t1 in range(3)
                    ]
                    for t2 in range(3)
                ]
                for t3 in range(3)
            ]
            for t4 in range(3)
        ]

# Generate table for quint encoding for all possible 7 bit numbers, [0, 127].
def quints_from_integer_table():
    return [decode_quints(bitset(7, i)) for i in range(128)]

# Generate table for quint decoding by brute force searching the encoding
# table. Exhaustive search solution works because the search space is small.
def integer_from_quints_table(quints):
    return \
        [
            [
                [
                    last_index(quints, (q0, q1, q2))
                    for q0 in range(5)
                ]
                for q1 in range(5)
            ]
            for q2 in range(5)
        ]

if __name__ == "__main__":
    trits_from_integer = trits_from_integer_table()
    integer_from_trits = integer_from_trits_table(trits_from_integer)
    quints_from_integer = quints_from_integer_table()
    integer_from_quints = integer_from_quints_table(quints_from_integer)

    print(trits_from_integer)
    print(integer_from_trits)
    print(quints_from_integer)
    print(integer_from_quints)
