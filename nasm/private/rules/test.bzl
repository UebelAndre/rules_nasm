# Copyright (c) 2024 Morgan Wajda-Levie.

"""Rule for nasm test targets."""

load("@rules_cc//cc:cc_test.bzl", "cc_test")
load(":common.bzl", "CC_ATTRS", "NASM_ATTRS", "cc_link", "nasm_assemble")

def _nasm_test_impl(ctx):
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

_nasm_test_ = rule(
    implementation = _nasm_test_impl,
    doc = "Assemble and execute a test assembly program.",
    attrs = NASM_ATTRS | CC_ATTRS,
    # test = True,
    fragments = ["cpp"],
    toolchains = [
        "//nasm:toolchain_type",
        "@rules_cc//cc:toolchain_type",
    ],
)

def nasm_test(name, **kwargs):
    nasm_args = {}
    for arg in NASM_ATTRS.keys():
        if arg in kwargs:
            nasm_args[arg] = kwargs.pop(arg, None)

    _nasm_test_(
        name = name + "_asm",
        tags = ["manual"],
        visibility = ["//visibility:private"],
        **nasm_args
    )
    cc_test(
        name = name,
        srcs = [name + "_asm"],
        **kwargs
    )
