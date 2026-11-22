#if canImport(Darwin)
  import Darwin
#endif

/// Raises a debug breakpoint if a debugger is attached.
@inline(__always)
@usableFromInline
func breakpoint(_ message: @autoclosure () -> String = "") {
  #if canImport(Darwin)
    // https://github.com/bitstadium/HockeySDK-iOS/blob/c6e8d1e940299bec0c0585b1f7b86baf3b17fc82/Classes/BITHockeyHelper.m#L346-L370
    var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    var info: kinfo_proc = kinfo_proc()
    var info_size = MemoryLayout<kinfo_proc>.size

    let isDebuggerAttached =
      sysctl(&name, 4, &info, &info_size, nil, 0) != -1
      && info.kp_proc.p_flag & P_TRACED != 0

    if isDebuggerAttached {
      fputs(
        """
        \(message())

        Caught debug breakpoint. Type "continue" ("c") to resume execution.

        """,
        stderr
      )
      raise(SIGTRAP)
    }
  #else
    assertionFailure(message())
  #endif
}
