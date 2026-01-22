const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const t = target.result;
    const glfw_dep = b.dependency("glfw", .{});
    const volk_dep = b.dependency("volk", .{});
    const vulkan_headers_dep = b.dependency("vulkan_headers", .{});
    const stb_dep = b.dependency("stb", .{});
    const tracy_dep = b.dependency("tracy", .{});

    const lib_name = b.fmt("farhorizons_deps_{s}-{s}-{s}", .{
        @tagName(t.cpu.arch),
        @tagName(t.os.tag),
        @tagName(t.abi),
    });

    // Copy headers step
    const headers_step = b.step("headers", "Copy headers");

    // GLFW headers
    const install_glfw_headers = b.addInstallDirectory(.{
        .source_dir = glfw_dep.path("include"),
        .install_dir = .{ .custom = "include" },
        .install_subdir = "",
    });
    headers_step.dependOn(&install_glfw_headers.step);

    // Volk header
    const install_volk_header = b.addInstallFile(volk_dep.path("volk.h"), "include/volk.h");
    headers_step.dependOn(&install_volk_header.step);

    // Vulkan headers
    const install_vulkan_headers = b.addInstallDirectory(.{
        .source_dir = vulkan_headers_dep.path("include"),
        .install_dir = .{ .custom = "include" },
        .install_subdir = "",
    });
    headers_step.dependOn(&install_vulkan_headers.step);

    // stb_image header
    const install_stb_header = b.addInstallFile(stb_dep.path("stb_image.h"), "include/stb_image.h");
    headers_step.dependOn(&install_stb_header.step);

    // shaderc headers (from pre-built shaderc directory)
    const install_shaderc_headers = b.addInstallDirectory(.{
        .source_dir = b.path("shaderc/include"),
        .install_dir = .{ .custom = "include" },
        .install_subdir = "",
    });
    headers_step.dependOn(&install_shaderc_headers.step);

    // FastNoise2 headers (from pre-built fastnoise2 directory)
    const install_fastnoise2_headers = b.addInstallDirectory(.{
        .source_dir = b.path("fastnoise2/include"),
        .install_dir = .{ .custom = "include" },
        .install_subdir = "",
    });
    headers_step.dependOn(&install_fastnoise2_headers.step);

    // Tracy headers (public/ directory contains Tracy.hpp and tracy/ subdirectory)
    const install_tracy_headers = b.addInstallDirectory(.{
        .source_dir = tracy_dep.path("public"),
        .install_dir = .{ .custom = "include" },
        .install_subdir = "",
    });
    headers_step.dependOn(&install_tracy_headers.step);

    // Create module for GLFW
    const glfw_module = b.createModule(.{
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
    });

    glfw_module.addIncludePath(glfw_dep.path("include"));
    glfw_module.addIncludePath(glfw_dep.path("src"));

    // Common sources
    const common_sources = &[_][]const u8{
        "context.c",
        "init.c",
        "input.c",
        "monitor.c",
        "platform.c",
        "vulkan.c",
        "window.c",
        "egl_context.c",
        "osmesa_context.c",
        "null_init.c",
        "null_monitor.c",
        "null_window.c",
        "null_joystick.c",
    };

    // Platform-specific flags and sources
    if (t.os.tag == .windows) {
        glfw_module.addCSourceFiles(.{
            .root = glfw_dep.path("src"),
            .files = common_sources,
            .flags = &.{ "-D_GLFW_WIN32", "-D_UNICODE", "-DUNICODE" },
        });
        const win_sources = &[_][]const u8{
            "win32_init.c",
            "win32_joystick.c",
            "win32_module.c",
            "win32_monitor.c",
            "win32_thread.c",
            "win32_time.c",
            "win32_window.c",
            "wgl_context.c",
        };
        glfw_module.addCSourceFiles(.{
            .root = glfw_dep.path("src"),
            .files = win_sources,
            .flags = &.{ "-D_GLFW_WIN32", "-D_UNICODE", "-DUNICODE" },
        });
    } else if (t.os.tag == .linux) {
        // Add system include path for X11 headers
        glfw_module.addSystemIncludePath(.{ .cwd_relative = "/usr/include" });

        glfw_module.addCSourceFiles(.{
            .root = glfw_dep.path("src"),
            .files = common_sources,
            .flags = &.{ "-D_GLFW_X11", "-D_POSIX_C_SOURCE=200809L" },
        });
        const linux_sources = &[_][]const u8{
            "posix_module.c",
            "posix_poll.c",
            "posix_thread.c",
            "posix_time.c",
            "linux_joystick.c",
            "xkb_unicode.c",
            "x11_init.c",
            "x11_monitor.c",
            "x11_window.c",
            "glx_context.c",
        };
        glfw_module.addCSourceFiles(.{
            .root = glfw_dep.path("src"),
            .files = linux_sources,
            .flags = &.{ "-D_GLFW_X11", "-D_POSIX_C_SOURCE=200809L" },
        });
    }

    const glfw_lib = b.addLibrary(.{
        .name = "glfw",
        .root_module = glfw_module,
        .linkage = .static,
    });

    const install_glfw_lib = b.addInstallArtifact(glfw_lib, .{
        .dest_sub_path = b.fmt("{s}/libglfw.a", .{lib_name}),
    });

    // Create module for volk
    const volk_module = b.createModule(.{
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
    });

    // Add Vulkan headers include path
    volk_module.addIncludePath(vulkan_headers_dep.path("include"));

    // volk needs VK_NO_PROTOTYPES since it loads functions dynamically
    // Don't define VK_USE_PLATFORM_* - volk loads all platforms dynamically
    const volk_flags: []const []const u8 = &.{"-DVK_NO_PROTOTYPES"};

    volk_module.addCSourceFiles(.{
        .root = volk_dep.path(""),
        .files = &.{"volk.c"},
        .flags = volk_flags,
    });

    const volk_lib = b.addLibrary(.{
        .name = "volk",
        .root_module = volk_module,
        .linkage = .static,
    });

    const install_volk_lib = b.addInstallArtifact(volk_lib, .{
        .dest_sub_path = b.fmt("{s}/libvolk.a", .{lib_name}),
    });

    // Create module for stb_image
    const stb_module = b.createModule(.{
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
    });

    // stb_image is header-only, so we create an implementation file
    const stb_impl = b.addWriteFiles();
    _ = stb_impl.add("stb_image_impl.c",
        \\#define STB_IMAGE_IMPLEMENTATION
        \\#include "stb_image.h"
    );

    stb_module.addIncludePath(stb_dep.path(""));
    stb_module.addCSourceFiles(.{
        .root = stb_impl.getDirectory(),
        .files = &.{"stb_image_impl.c"},
        .flags = &.{},
    });

    const stb_lib = b.addLibrary(.{
        .name = "stb_image",
        .root_module = stb_module,
        .linkage = .static,
    });

    const install_stb_lib = b.addInstallArtifact(stb_lib, .{
        .dest_sub_path = b.fmt("{s}/libstb_image.a", .{lib_name}),
    });

    // Install pre-built shaderc library
    // The library should be placed in shaderc/lib/{platform}/
    // All platforms use GNU ar format (libshaderc_combined.a)
    const shaderc_src_name = "libshaderc_combined.a";
    const shaderc_dst_name = "libshaderc_combined.a";
    const shaderc_lib_path = b.fmt("shaderc/lib/{s}-{s}-{s}/{s}", .{
        @tagName(t.cpu.arch),
        @tagName(t.os.tag),
        @tagName(t.abi),
        shaderc_src_name,
    });
    const install_shaderc_lib = b.addInstallFileWithDir(
        b.path(shaderc_lib_path),
        .lib,
        b.fmt("{s}/{s}", .{ lib_name, shaderc_dst_name }),
    );

    // Install pre-built FastNoise2 library
    // The library should be placed in fastnoise2/lib/{platform}/
    const fastnoise2_src_name = "libFastNoise.a";
    const fastnoise2_dst_name = "libFastNoise.a";
    const fastnoise2_lib_path = b.fmt("fastnoise2/lib/{s}-{s}-{s}/{s}", .{
        @tagName(t.cpu.arch),
        @tagName(t.os.tag),
        @tagName(t.abi),
        fastnoise2_src_name,
    });
    const install_fastnoise2_lib = b.addInstallFileWithDir(
        b.path(fastnoise2_lib_path),
        .lib,
        b.fmt("{s}/{s}", .{ lib_name, fastnoise2_dst_name }),
    );

    // Create module for Tracy profiler client
    const tracy_module = b.createModule(.{
        .target = target,
        .optimize = .ReleaseFast,
        .link_libc = true,
        .link_libcpp = true, // Tracy is C++
    });

    tracy_module.addIncludePath(tracy_dep.path("public"));

    // Tracy compile flags - use static array for simplicity
    const tracy_flags_common: []const []const u8 = &.{
        "-DTRACY_ENABLE", // Enable Tracy profiling
        "-DTRACY_ON_DEMAND", // Only profile when profiler is connected
    };

    const tracy_flags_windows: []const []const u8 = &.{
        "-DTRACY_ENABLE",
        "-DTRACY_ON_DEMAND",
        "-D_WIN32_WINNT=0x0602", // Windows 8+
        "-DWINVER=0x0602",
    };

    const tracy_flags = if (t.os.tag == .windows) tracy_flags_windows else tracy_flags_common;

    tracy_module.addCSourceFiles(.{
        .root = tracy_dep.path("public"),
        .files = &.{"TracyClient.cpp"},
        .flags = tracy_flags,
    });

    const tracy_lib = b.addLibrary(.{
        .name = "tracy",
        .root_module = tracy_module,
        .linkage = .static,
    });

    const install_tracy_lib = b.addInstallArtifact(tracy_lib, .{
        .dest_sub_path = b.fmt("{s}/libtracy.a", .{lib_name}),
    });

    b.default_step.dependOn(headers_step);
    b.default_step.dependOn(&install_glfw_lib.step);
    b.default_step.dependOn(&install_volk_lib.step);
    b.default_step.dependOn(&install_stb_lib.step);
    b.default_step.dependOn(&install_shaderc_lib.step);
    b.default_step.dependOn(&install_fastnoise2_lib.step);
    b.default_step.dependOn(&install_tracy_lib.step);
}
