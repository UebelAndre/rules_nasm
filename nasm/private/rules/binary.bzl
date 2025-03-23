# Copyright (c) 2024 Morgan Wajda-Levie.

"""Rule for nasm binary targets."""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load(":common.bzl", "CC_ATTRS", "NASM_ATTRS", "cc_link", "nasm_assemble")

def _nasm_binary_impl(ctx):
    nasm_toolchain = ctx.toolchains["//nasm:toolchain_type"]

    hdrs = depset(ctx.files.hdrs)

    object_files = [
        nasm_assemble(
            ctx = ctx,
            nasm_toolchain = nasm_toolchain,
            src = src,
            hdrs = hdrs,
            copts = ctx.attr.copts,
            preincs = ctx.files.preincs,
            includes = ctx.attr.includes,
        )
        for src in ctx.files.srcs
    ]

    if False:
        providers = cc_link(
            ctx = ctx,
            object_files = depset(object_files),
        )

    providers = [DefaultInfo(
        files = depset(object_files),
    )]

    providers.append(
        OutputGroupInfo(
            nasm_object_files = depset(object_files),
        ),
    )

    return providers

_nasm_binary = rule(
    implementation = _nasm_binary_impl,
    doc = """\
Assemble a source file as an executable.

Assembles an `nasm` source file as an executable binary. The
assembled object file will be linked against the C standard library,
meaning that it must define a starting function with the label
expected by system libraries, can reference C standard library
functions, and must not export labels which conflict with the C
standard library.

*(Standalone binaries which are not linked to standard libraries are
planned for a future release.)*

**NB**: The mangling of function labels is defined by the ABI of the
target platform. Some degree of portability can be ensured by using
a macro to define global labels, and deduce the target platform by
inspecting the target binary format.
""",
    attrs = NASM_ATTRS | CC_ATTRS,
    # executable = True,
    fragments = ["cpp"],
    toolchains = [
        "//nasm:toolchain_type",
        "@rules_cc//cc:toolchain_type",
    ],
)

def nasm_binary(name, **kwargs):
    nasm_args = {}
    for arg in NASM_ATTRS.keys():
        if arg in kwargs:
            nasm_args[arg] = kwargs.pop(arg, None)

    _nasm_binary(
        name = name + "_asm",
        tags = ["manual"],
        visibility = ["//visibility:private"],
        **nasm_args
    )
    cc_binary(
        name = name,
        srcs = [name + "_asm"],
        **kwargs
    )
