import Foundation

func alignUp(_ value: Int, alignment: Int) -> Int {
    assert(((alignment - 1) & alignment) == 0)

    let alignmentMask = alignment - 1
    return ((value + alignmentMask) & (~alignmentMask))
}
