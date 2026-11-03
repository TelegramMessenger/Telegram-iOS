# Agent instructions

Read and follow [CLAUDE.md](CLAUDE.md) before making changes in this repository. It is the authoritative project guidance.

This project does not require screenshot testing. When validating the demo app, instrument the relevant behavior temporarily and capture logs or output files for inspection instead of taking screenshots or recording video.

When asked to launch the Demo on K2, finish all builds and tests before launching, then make the
launch the final simulator action. Verify that `org.telegram.CoreListDemo` has a live application
process on the dedicated K2 simulator after the launch. Also verify that Simulator.app is actually
displaying K2: XcodeBuildMCP can launch an app on K2 while Simulator.app remains focused on another
device, and `open_sim` only activates the existing Simulator window without selecting K2. Do not
report that the Demo is visibly launched if either check fails; state the exact process or
visibility issue instead.
