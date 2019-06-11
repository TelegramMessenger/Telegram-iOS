import Foundation

public enum Either<Left, Right> {
    case left(value: Left)
    case right(value: Right)
}
