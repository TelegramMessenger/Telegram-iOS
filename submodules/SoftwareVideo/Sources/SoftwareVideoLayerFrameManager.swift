import Foundation
import SwiftSignalKit

public let softwareVideoApplyQueue = Queue()
public let softwareVideoWorkers = ThreadPool(threadCount: 3, threadPriority: 0.2)
