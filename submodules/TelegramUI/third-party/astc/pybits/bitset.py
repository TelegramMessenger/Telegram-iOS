# A bitset represents a fixed number of bits and have some helper methods for
# manipulating them.
class bitset:
    def __init__(self, n, val):
        assert n > 0
        assert val < pow(2, n) # number should fit within the available bits

        self.n    = n
        self.data = val

    def size(self):
        return self.n

    def get(self, i):
        assert i >= 0 and i < self.n
        return (self.data >> i) & 1

    def get_msb(self):
        return self.get(self.n-1)

    def get_lsb(self):
        return self.get(0)

    def set(self, i, x):
        assert isinstance(x, bool) or isinstance(x, int)
        assert i >= 0 and i < self.n
        self.data ^= (-x ^ self.data) & (1 << i)

    def substr(self, msb, lsb):
        assert msb >= lsb
        assert lsb >= 0
        assert msb < self.n

        count = msb - lsb + 1
        newdata = self.data >> lsb & ((1 << count) - 1)
        return bitset(count, newdata)

    def number(self):
        return self.data

    def bits(self):
        return [self.get(i) for i in range(self.n-1, -1, -1)]

    def __eq__(self, other):
        assert isinstance(other, bitset)

        return self.n == other.n and self.data == other.data

    def __str__(self):
        return ''.join('1' if x else '0' for x in self.bits())

    def __repr__(self):
        return "bitset(%d, 0b%s)" % (self.n, self.__str__())

    @staticmethod
    def from_list(lst):
        num = 0
        n = len(lst) - 1
        for x in lst:
            assert x >= 0 and x <= 1
            num = num | (x << n)
            n = n - 1

        return bitset(len(lst), num)

    @staticmethod
    def from_args(*args):
        return bitset.from_list(list(args))

    @staticmethod
    def join(a, b):
        assert isinstance(a, bitset)
        assert isinstance(b, bitset)

        count  = a.size()+b.size()
        number = b.number() | (a.number() << b.size())
        return bitset(count, number)
