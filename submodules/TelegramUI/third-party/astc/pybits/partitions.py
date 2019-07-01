def square(x):
    return x*x

def shiftr32(x, y):
    return (x >> y) & (2**32-1)

def shiftl32(x, y):
    return (x << y) & (2**32-1)

def xor32(x, y):
    return x ^ y

def add32(x, y):
    return (x + y) % 2**32

def sub32(x, y):
    return (x - y) % 2**32

def hash52(p):
    p = xor32(p, shiftr32(p, 15))
    p = sub32(p, shiftl32(p, 17))
    p = add32(p, shiftl32(p, 7))
    p = add32(p, shiftl32(p, 4))
    p = xor32(p, shiftr32(p, 5))
    p = add32(p, shiftl32(p, 16))
    p = xor32(p, shiftr32(p, 7))
    p = xor32(p, shiftr32(p, 3))
    p = xor32(p, shiftl32(p, 6))
    p = xor32(p, shiftr32(p, 17))

    assert p >= 0 and p < 2**32

    return p

# Select partion index as defined by ASTC specification.
def select_partition(seed, x, y, z, partition_count, small_block):
    assert seed >= 0 and seed < 2**10
    assert partition_count >= 1 and partition_count <= 4

    if small_block:
        x = x << 1
        y = y << 1
        z = z << 1

    seed += (partition_count - 1) * 1024

    rnum = hash52(seed)

    seed1  = square(rnum & 0xF)
    seed2  = square((rnum >> 4) & 0xF)
    seed3  = square((rnum >> 8) & 0xF)
    seed4  = square((rnum >> 12) & 0xF)
    seed5  = square((rnum >> 16) & 0xF)
    seed6  = square((rnum >> 20) & 0xF)
    seed7  = square((rnum >> 24) & 0xF)
    seed8  = square((rnum >> 28) & 0xF)
    seed9  = square((rnum >> 18) & 0xF)
    seed10 = square((rnum >> 22) & 0xF)
    seed11 = square((rnum >> 26) & 0xF)
    seed12 = square(((rnum >> 30) | (rnum << 2)) & 0xF)

    sh1 = 4 if seed & 2 else 5
    sh2 = 6 if partition_count == 3 else 5

    if not (seed & 1):
        sh1, sh2 = (sh2, sh1)

    sh3 = sh1 if seed & 0x10 else sh2

    seed1  = seed1 >> sh1
    seed2  = seed2 >> sh2
    seed3  = seed3 >> sh1
    seed4  = seed4 >> sh2
    seed5  = seed5 >> sh1
    seed6  = seed6 >> sh2
    seed7  = seed7 >> sh1
    seed8  = seed8 >> sh2
    seed9  = seed9 >> sh3
    seed10 = seed10 >> sh3
    seed11 = seed11 >> sh3
    seed12 = seed12 >> sh3

    a = seed1*x + seed2*y + seed11*z + (rnum >> 14)
    b = seed3*x + seed4*y + seed12*z + (rnum >> 10)
    c = seed5*x + seed6*y + seed9*z + (rnum >> 6)
    d = seed7*x + seed8*y + seed10*z + (rnum >>  2)

    a = a & 0x3F
    b = b & 0x3F if partition_count > 1 else 0
    c = c & 0x3F if partition_count > 2 else 0
    d = d & 0x3F if partition_count > 3 else 0

    if a >= b and a >= c and a >= d:
        return 0
    elif b >= c and b >= d:
        return 1
    elif c >= d:
        return 2
    else:
        return 3

# Convert a list of digits to a number with a specific base.
def digits_to_num(base, lst):
    sum = 0
    power = 0
    for x in lst:
        sum = sum + x * (base**power)
        power = power + 1
    return sum

# Convert a number to a list of digits for a certain base.
def num_to_digits(base, digits, num):
    for x in range(0, digits):
        yield num % base
        num = num // base

class partitioning:
    bit_masks = [0x1, 0x1, 0x3, 0x3]
    shift_counts = [1, 1, 2, 2]

    def __init__(self, partition_count, block_width, block_height, partition_mask):
        assert isinstance(partition_mask, int)
        assert partition_count >= 1 and partition_count <= 4

        self.block_width = block_width
        self.block_height = block_height
        self.texel_count = block_width * block_height
        self.partition_count = partition_count
        self.partition_mask = partition_mask

        self.bit_mask = partitioning.bit_masks[partition_count-1]
        self.shift_count = partitioning.shift_counts[partition_count-1]

    def __eq__(self, other):
        return \
            self.partition_count == other.partition_count and \
            self.block_width == other.block_width and \
            self.block_height == other.block_height and \
            self.partition_mask == other.partition_mask

    def __iter__(self):
        return num_to_digits(
                self.partition_count,
                self.texel_count,
                self.partition_mask)

    def __str__(self):
        return "%#x" % self.partition_mask

    def __repr__(self):
        return "partitioning({}, {}, {}, [{}])".format(
                self.partition_count,
                self.block_width,
                self.block_height,
                ",".join((str(x) for x in self)))

def invert(part):
    assert isinstance(part, partitioning)
    assert part.partition_count == 2

    return partitioning(
            part.partition_count,
            part.block_width,
            part.block_height,
            part.partition_mask ^ (2**part.texel_count-1))

def distance(a, b):
    assert isinstance(a, partitioning)
    assert isinstance(b, partitioning)
    assert a.partition_count == b.partition_count
    assert a.block_width == b.block_width
    assert a.block_height == b.block_height

    def cost(m, n):
        return 0 if m == n else 1

    return sum((cost(m, n) for (m, n) in zip(a, b)))

# Create human readable format for a partition mask.
def show_ascii(part):
    assert isinstance(part, partitioning)

    s = ""
    i = 0
    j = 0
    for p in part:
        s = s + str(p)
        i = i + 1

        if i == part.block_width and j < part.block_height-1:
            s = s + "\n"
            i = 0
            j = j + 1

    return s

# Compute the partition bitmask for a given block size, partition count and
# seed. The bitmask is a list of numbers in range [0, partition count-1]
# starting in top left corner of the block in row major order.
def compute_partitioning(partition_count, block_width, block_height, seed):
    width_range = range(0, block_width)
    height_range = range(0, block_height)

    def f(x, y):
        return select_partition(seed, x, y, 0, partition_count, True)

    return partitioning(
            partition_count,
            block_width,
            block_height,
            digits_to_num(
                partition_count,
                (f(x, y) for y in height_range for x in width_range)))

# Compute the table that maps partition seeds to partition block masks for a
# given block size and partition count.
def compute_partitioning_table(partition_count, block_width, block_height):
    def f(seed):
        return compute_partitioning(
                partition_count = partition_count,
                block_width = block_width,
                block_height = block_height,
                seed = seed)

    return (f(seed) for seed in range(0, 2**10))

# Compute the lookup table from a partition mask to a matching partition index.
# Matching is done according to the edit distance between the partitioning and
# all availible partitions.
def compute_partitioning_lookup_table(table):
    assert len(table) == 1024

    partition_count = 2
    block_width = 4
    block_height = 4

    for ideal in range(0, 2**16):
        ideal_part = partitioning(
                partition_count = partition_count,
                block_width = block_width,
                block_height = block_height,
                partition_mask = ideal)
        ideal_inverted_part = invert(ideal_part)

        best_score = 100000
        best_indices = []
        for index, actual_part in enumerate(table):
            score = min(
                    distance(ideal_part, actual_part),
                    distance(ideal_inverted_part, actual_part))
            if score < 2:
                if score == best_score:
                    best_indices.append(index)
                elif score < best_score:
                    best_score = score
                    best_indices = [index]

        yield best_indices

def compute_partitioning_lookup_table_equality(table):
    assert len(table) == 1024

    partition_count = 2
    block_width = 4
    block_height = 4

    for ideal in range(0, 2**16):
        ideal_part = partitioning(
                partition_count = partition_count,
                block_width = block_width,
                block_height = block_height,
                partition_mask = ideal)
        ideal_inverted_part = invert(ideal_part)

        for index, actual_part in enumerate(table):
            if ideal_part == actual_part or ideal_inverted_part == actual_part:
                yield index

        yield -1


if __name__ == "__main__":
    table = list(compute_partitioning_table(
        partition_count=2,
        block_width=4,
        block_height=4))
    print([list(part) for part in table])
    lookup_table = compute_partitioning_lookup_table(table)
    print(list(lookup_table))
