#!/usr/bin/env python

from partitions import compute_partitioning_table
import matplotlib.image as mpimg
import numpy as np

def masks_to_image(block_width, block_height, masks):
    colors = [ (1, 0, 0), (0, 0, 1), (0, 1, 0), (1, 1, 1) ]

    xblocks = 32
    yblocks = 32

    img_width = xblocks * (block_width + 1) + 1
    img_height = yblocks * (block_height + 1) + 1

    pixels = np.zeros((img_height, img_width, 3))

    i = 0
    for mask in masks:
        xblock = i % xblocks
        yblock = i // xblocks

        xtopleft = xblock * (block_width + 1) + 1
        ytopleft = yblock * (block_height + 1) + 1

        j = 0
        for partition in mask:
            x = j % block_width
            y = j // block_width
            pixels[ytopleft+y, xtopleft+x] = colors[partition]
            j = j + 1

        i = i + 1

    assert i == 1024

    return pixels

def write_image(partition_count, block_width, block_height):
    table = compute_partitioning_table(
            partition_count = partition_count,
            block_width = block_width,
            block_height = block_height)

    img = masks_to_image(
            block_width = block_width,
            block_height = block_height,
            masks = table)

    path = "/tmp/%dx%d-blocks-%d-partitions.png" % (block_width, block_height, partition_count)
    mpimg.imsave(path, img)

if __name__ == "__main__":
    write_image(2, 4, 4)
    write_image(3, 4, 4)
    write_image(4, 4, 4)
    write_image(4, 6, 12)
    write_image(4, 12, 6)
    write_image(4, 12, 12)
