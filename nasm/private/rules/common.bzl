# Copyright (c) 2024 Morgan Wajda-Levie.

"""Common utilities for nasm rules."""

load("@rules_cc//cc:find_cc_toolchain.bzl", find_rules_cc_toolchain = "find_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def nasm_assemble(
        *,
        ctx,
        nasm_toolchain,
        src,
        copts,
        hdrs,
        preincs,
        includes):
    """Spawn a `NasmAssemble` action to convert an assembly source file to an object file.

    Args:
        ctx (ctx): The rule's context object
        nasm_toolchain (nasm_toolchain): The current nasm toolchain
        src (File): The source file to compile
        copts (list[str]): Additional compile flags to use.
        hdrs (depset[file]): Headers to include.
        preincs (list[file]): Pre include files.
        includes (list[str]): Include flags.

    Returns:
        File: The compiled object file.
    """
    basename, _, _ = src.basename.rpartition(".")
    out = ctx.actions.declare_file("{}/_obj/{}/{}.o".format(
        ctx.label.package,
        ctx.label.name,
        basename,
    ))

    workspace_root = src.owner.workspace_root
    if workspace_root:
        workspace_root = workspace_root + "/"
    package_path = workspace_root + src.owner.package

    args = ctx.actions.args()
    args.add_all(nasm_toolchain.args)
    args.add("-I", src.dirname + "/")

    if workspace_root:
        args.add("-I", workspace_root)

    args.add_all(
        [
            "%s/%s" % (package_path, inc)
            for inc in includes
        ],
        before_each = "-I",
    )
    args.add("-o", out)
    args.add_all(preincs, before_each = "-p")
    args.add_all(copts)
    args.add(src)

    inputs = depset([src] + preincs, transitive = [hdrs])

    ctx.actions.run(
        mnemonic = "NasmAssemble",
        executable = nasm_toolchain.compiler,
        arguments = [args],
        inputs = inputs,
        outputs = [out],
    )

    return out

UNSUPPORTED_FEATURES = []

def _find_cc_toolchain(ctx, extra_unsupported_features = tuple()):
    """Extracts a CcToolchain from the current target's context

    Args:
        ctx (ctx): The current target's rule context object
        extra_unsupported_features (sequence of str): Extra featrures to disable

    Returns:
        tuple: A tuple of (CcToolchain, FeatureConfiguration)
    """
    cc_toolchain = find_rules_cc_toolchain(ctx)

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = UNSUPPORTED_FEATURES + ctx.disabled_features +
                               list(extra_unsupported_features),
    )
    return cc_toolchain, feature_configuration

def cc_link(*, ctx, object_files):
    """_summary_

    Args:
        ctx (_type_): _description_
        object_files (_type_): _description_

    Returns:
        _type_: _description_
    """
    cc_toolchain, feature_configuration = _find_cc_toolchain(ctx)

    compilation_outputs = cc_common.create_compilation_outputs(
        objects = object_files,
        pic_objects = None,
    )

    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        user_link_flags = ctx.attr.linkopts,
    )

    linking_context = cc_common.create_linking_context(
        linker_inputs = depset([linker_input]),
    )

    linking_outputs = cc_common.link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        linking_contexts = [linking_context],
        compilation_outputs = compilation_outputs,
        name = ctx.label.name,
        stamp = 0,
        output_type = "executable",
    )

    return [DefaultInfo(
        files = depset([linking_outputs.executable]),
        executable = linking_outputs.executable,
    )]

def cc_archive(*, ctx, object_files):
    """_summary_

    Args:
        ctx (_type_): _description_
        object_files (_type_): _description_

    Returns:
        _type_: _description_
    """
    cc_toolchain, feature_configuration = _find_cc_toolchain(ctx)

    compilation_outputs = cc_common.create_compilation_outputs(
        objects = object_files,
        pic_objects = None,
    )

    linker_input = cc_common.create_linker_input(
        owner = ctx.label,
        user_link_flags = ctx.attr.linkopts,
    )

    (
        linking_context,
        linking_outputs,
    ) = cc_common.create_linking_context_from_compilation_outputs(
        actions = ctx.actions,
        name = ctx.label.name,
        compilation_outputs = compilation_outputs,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        alwayslink = False,
        disallow_dynamic_library = True,
        linking_contexts = [cc_common.create_linking_context(
            linker_inputs = depset([linker_input]),
        )],
    )

    static_lib = linking_outputs.library_to_link.static_library
    if not static_lib:
        static_lib = linking_outputs.library_to_link.pic_static_library

    return [
        DefaultInfo(
            files = depset([static_lib]),
        ),
        CcInfo(
            compilation_context = cc_common.create_compilation_context(),
            linking_context = linking_context,
        ),
    ]

NASM_EXTENSIONS = [".asm", ".nasm", ".s", ".i"]

NASM_ATTRS = {
    "copts": attr.string_list(
        doc = "Additional compilation flags to `nasm`.",
    ),
    "hdrs": attr.label_list(
        allow_files = NASM_EXTENSIONS,
        doc = (
            "Other assembly sources which may be included by `src`. " +
            "Must have an extension of %s." % (
                ", ".join(NASM_EXTENSIONS)
            )
        ),
    ),
    "includes": attr.string_list(
        doc = ("Directories which will be added to the search path for include files."),
    ),
    "preincs": attr.label_list(
        allow_files = NASM_EXTENSIONS,
        doc = (
            "Assembly sources which will be included and processed before the source file. " +
            "Sources will be included in the order listed. Must have an extension of %s." % (
                ", ".join(NASM_EXTENSIONS)
            )
        ),
    ),
    "srcs": attr.label_list(
        allow_files = NASM_EXTENSIONS,
        doc = "The assembly source file. Must have an extension of %s." % (
            ", ".join(NASM_EXTENSIONS)
        ),
    ),
}

CC_ATTRS = {
    "linkopts": attr.string_list(
        doc = "Extra flags to pass to the linker.",
    ),
}
