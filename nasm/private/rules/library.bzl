# Copyright (c) 2024 Morgan Wajda-Levie.

"""Rules for assembling object files."""

load("@rules_cc//cc:cc_library.bzl", "cc_library")
load(":common.bzl", "CC_ATTRS", "NASM_ATTRS", "cc_archive", "nasm_assemble")

def _nasm_library_impl(ctx):
    """Implement nasm library object."""

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
        providers = cc_archive(
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

_nasm_library = rule(
    implementation = _nasm_library_impl,
    doc = """\
Assemble an `nasm` source for use as a C++ dependency.

Assembled object files should be usable as C compilation units.
Rather than create a `CcInfo` object directly, we pass the assembled
object file as the src to a `cc_library` rule, which creates a
corresponding provider, and captures any additional dependencies.
""",
    attrs = NASM_ATTRS | CC_ATTRS,
    fragments = ["cpp"],
    toolchains = [
        "//nasm:toolchain_type",
        "@rules_cc//cc:toolchain_type",
    ],
)

def nasm_library(name, **kwargs):
    nasm_args = {}
    for arg in NASM_ATTRS.keys():
        if arg in kwargs:
            nasm_args[arg] = kwargs.pop(arg, None)

    _nasm_library(
        name = name + "_asm",
        tags = ["manual"],
        visibility = ["//visibility:private"],
        **nasm_args
    )
    cc_library(
        name = name,
        srcs = [name + "_asm"],
        **kwargs
    )
