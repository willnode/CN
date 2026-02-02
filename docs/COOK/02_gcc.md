# GCC Bootstrap

Last update: Feb 2026

When I tell you about GCC bootstrap, I mean GCC used for cross compiling. This is unique problem because how do you create a compiler for the OS while the OS itself has no compiler to compile into?

The GCC bootstrap script was written in `mk/prefix.mk`. In the past, it is made as as exactly as the [OSDev Wiki told you](https://wiki.osdev.org/GCC_Cross-Compiler), build GCC twice, with in the middle building your own Libc.

I find building GCC twice it's not really nice. So I improved it to build once, plus I made it build inside the cookbook. They have some strings attached too though.

## Step 1: Dependencies to Build GCC

Here's the deps needed to build GCC:

```toml
[build]
template = "custom"
dependencies = [
    "libgmp",
    "libmpfr",
    "mpc",
# TODO: this zlib get linked when boostrapping gcc
#    "zlib"
]
```

Those three deps is an absolute requirement: `libgmp`, `libmpfr`, `mpc`. Why `zlib` is commented out? Because I said, it will linked. Now why linking them is a problem? Because those libs wil not be copied to your OS `/usr/lib`. So when the cookbook build for GCC compiler (aka. `make host:gcc13`), those tree are linked _with your distro libraries_, which is why installing three of them is a requirement. Fortunately, GCC bundles zlib if it not found anywhere so that's why I just comment it out.

### Step 2: Binutils

TODO: