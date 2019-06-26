from bitset import bitset
from range import *

def unquantize_color(i, quant):
    assert i >= 0 and i < RANGE_CARDINALITY_TABLE[quant]
    assert quant >= RANGE_2 and quant <= RANGE_256

    def unquant(a, b, c, d):
        """
        This is the magic bit twiddling hack ARM uses in the ASTC decoder
        specification to avoid full-width multipliers.

        T = D * C + B;
        T = T ^ A;
        T = (A & 0x80) | (T >> 2);
        """
        return (a & 0x80) | (((d*c + b) ^ a) >> 2)

    def bit_only(lst):
        return bitset.from_list(lst).number()

    def trit_quint(A, B, C, D):
        return unquant(
            bitset.from_list(A).number(),
            bitset.from_list(B).number(),
            C,
            bitset.from_list(D).number())

    bits = bitset(8, i)
    a = bits.get(0)
    b = bits.get(1)
    c = bits.get(2)
    d = bits.get(3)
    e = bits.get(4)
    f = bits.get(5)
    g = bits.get(6)
    h = bits.get(7)

    if quant == RANGE_2:
        return bit_only([a,a,a,a,a,a,a,a])
    elif quant == RANGE_3:
        return [0, 128, 255][i]
    elif quant == RANGE_4:
        return bit_only([b,a,b,a,b,a,b,a])
    elif quant == RANGE_5:
        return [0, 64, 128, 192, 255][i]
    elif quant == RANGE_6:
        return trit_quint([a,a,a,a,a,a,a,a,a], [0,0,0,0,0,0,0,0,0], 204, [c,b])
    elif quant == RANGE_8:
        return bit_only([c,b,a,c,b,a,c,b])
    elif quant == RANGE_10:
        return trit_quint([a,a,a,a,a,a,a,a,a], [0,0,0,0,0,0,0,0,0], 113, [d,c,b])
    elif quant == RANGE_12:
        return trit_quint([a,a,a,a,a,a,a,a,a], [b,0,0,0,b,0,b,b,0], 93, [d,c])
    elif quant == RANGE_16:
        return bit_only([d,c,b,a,d,c,b,a])
    elif quant == RANGE_20:
        return trit_quint([a,a,a,a,a,a,a,a,a], [b,0,0,0,0,b,b,0,0], 54, [e,d,c])
    elif quant == RANGE_24:
        return trit_quint([a,a,a,a,a,a,a,a,a], [c,b,0,0,0,c,b,c,b], 44, [e,d])
    elif quant == RANGE_32:
        return bit_only([e,d,c,b,a,e,d,c])
    elif quant == RANGE_40:
        return trit_quint([a,a,a,a,a,a,a,a,a], [c,b,0,0,0,0,c,b,c], 26, [f,e,d])
    elif quant == RANGE_48:
        return trit_quint([a,a,a,a,a,a,a,a,a], [d,c,b,0,0,0,d,c,b], 22, [f,e])
    elif quant == RANGE_64:
        return bit_only([f,e,d,c,b,a,f,e])
    elif quant == RANGE_80:
        return trit_quint([a,a,a,a,a,a,a,a,a], [d,c,b,0,0,0,0,d,c], 13, [g,f,e])
    elif quant == RANGE_96:
        return trit_quint([a,a,a,a,a,a,a,a,a], [e,d,c,b,0,0,0,e,d], 11, [g,f])
    elif quant == RANGE_128:
        return bit_only([g,f,e,d,c,b,a,g])
    elif quant == RANGE_160:
        return trit_quint([a,a,a,a,a,a,a,a,a], [e,d,c,b,0,0,0,0,e], 6, [h,g,f])
    elif quant == RANGE_192:
        return trit_quint([a,a,a,a,a,a,a,a,a], [f,e,d,c,b,0,0,0,f], 5, [h,g])
    elif quant == RANGE_256:
        return bit_only([h,g,f,e,d,c,b,a])

    assert False

def find_closest(unquantized, value):
    assert isinstance(unquantized, list)
    assert len(unquantized) > 0
    assert isinstance(value, int)

    class Item:
        def __init__(self, index):
            self.index = index
            self.cost = abs(value - unquantized[self.index])

        def __lt__(self, other):
            return self.cost < other.cost

    return min(map(Item, range(len(unquantized)))).index

def color_quantize_table(color_unquantize_table):
    return \
        [
            [
                find_closest(color_unquantize_table[quant], i)
                for i in range(256)
            ]
            for quant in range(RANGE_MAX)
        ]

def color_unquantize_table():
    return \
        [
            [
                unquantize_color(i, quant)
                for i in range(RANGE_CARDINALITY_TABLE[quant])
            ]
            for quant in range(RANGE_MAX)
        ]

if __name__ == "__main__":
    unquantize_table = color_unquantize_table()
    quantize_table = color_quantize_table(unquantize_table)
    print(unquantize_table)
    print(quantize_table)
