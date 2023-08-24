# Bazel toolchain configurations for RBE

This directory contains Bazel toolchain configurations for RBE grouped by operating system.

It might be necessary to rebuild these configurations when the RBE toolchain container image
for a specific operating system is updated, or when a new Bazel version is released.

## Linux

Directories `linux-bazel-<BAZEL VERSION>` contain Bazel toolchain configurations for Linux RBE
builds. Multiple such directories may exist to ease migrating from one Bazel version to the next.

### Toolchain configuration regeneration instructions

The Linux RBE toolchain configuration must be regenerated whenever the Linux RBE toolchain
container image changes, or when upgrading to a new Bazel version.

#### Step 1

Clone the [bazel-toolchains](https://github.com/bazelbuild/bazel-toolchains) repository, build the
`rbe_configs_gen` binary, and put it in your `$PATH`:

```
$ git clone https://github.com/bazelbuild/bazel-toolchains

$ cd bazel-toolchains

# This assumes that $HOME/bin is in your $PATH.
$ go build -o $HOME/bin/rbe_configs_gen ./cmd/rbe_configs_gen/rbe_configs_gen.go
```

#### Step 2

Generate a new `//bazel/rbe/linux-bazel-<BAZEL VERSION>` directory with the
`rbe_configs_gen` CLI tool:

```
# Replace the <PLACEHOLDERS> as needed.
$ rbe_configs_gen \
      --bazel_version=<BAZEL VERSION> \
      --toolchain_container=gcr.io/skia-public/rbe-container-skcms-linux@sha256:<HASH OF MOST RECENT IMAGE> \
      --output_src_root=<PATH TO REPOSITORY CHECKOUT> \
      --output_config_path=bazel/rbe/linux-bazel-<BAZEL VERSION> \
      --generate_java_configs=false \
      --exec_os=linux \
      --target_os=linux
```

If `rbe_configs_gen` fails, try deleting all files under
`//bazel/rbe/linux-bazel-<BAZEL VERSION>` (if it exists) and re-run `rbe_configs_gen`.

#### Step 3

Add an empty `//bazel/rbe/linux-bazel-<BAZEL VERSION>/WORKSPACE` file.

#### Step 4

Open file `//bazel/rbe/linux-bazel-<BAZEL VERSION>/config/BUILD`, look for the `toolchain`
rule named `cc-toolchain`, and change the `toolchain` attribute as follows:

```
# Before.
toolchain(
    name = "cc-toolchain",
    ...
    toolchain = "//bazel/rbe/linux-bazel-4.2.1/cc:cc-compiler-k8",
    ...
)

# After.
toolchain(
    name = "cc-toolchain",
    ...
    toolchain = "//cc:cc-compiler-k8",
    ...
)
```

#### Step 5

Open file `//bazel/rbe/linux-bazel-<BAZEL VERSION>/config/BUILD`, look for the `platform`
rule named `platform`, and make change the `exec_properties` attribute as follows:

```
# Before.
platform(
    name = "platform",
    ...
    exec_properties = {
        ...
    },
    ...
)

# After.
platform(
    name = "platform",
    ...
    exec_properties = {
        ...
        "dockerAddCapabilities": "SYS_PTRACE",
    },
    ...
)
```

This is necessary to run tests on Linux RBE with `--config=asan` (details
[here](https://github.com/google/sanitizers/issues/916)).

(As an alternative, we could disable memory leak detection by setting the environment variable
`ASAN_OPTIONS=detect_leaks=1` via the `--action_env` Bazel flag.)

#### Step 6

Update the paths in `//WORKSPACE` as needed.

## Windows

Directories `windows-bazel-<BAZEL VERSION>` contain Bazel toolchain configurations for Windows RBE
builds. Multiple such directories may exist to ease migrating from one Bazel version to the next.

### Toolchain configuration regeneration instructions

The Windows RBE toolchain configuration must be regenerated whenever the Windows RBE toolchain
container image changes, or when upgrading to a new Bazel version.

The instructions to regenerate the Windows RBE toolchain are the same as for the Linux RBE
toolchain, with the following differences:

- Any paths should be changed as needed.

- In Step 2, run the following command instead:

```
# Replace the <PLACEHOLDERS> as needed.
$ rbe_configs_gen.exe \
      --bazel_version=<BAZEL VERSION> \
      --toolchain_container=gcr.io/skia-public/rbe-container-skia-windows@sha256:<HASH OF MOST RECENT IMAGE> \
      --output_src_root=<PATH TO REPOSITORY CHECKOUT> \
      --output_config_path=bazel/rbe/windows-bazel-<BAZEL VERSION> \
      --generate_java_configs=false \
      --exec_os=windows \
      --target_os=windows
```

- Step 5 can be omitted.

## macOS

TODO(lovisolo)
