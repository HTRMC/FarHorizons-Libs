const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const t = target.result;
    const glfw_dep = b.dependency("glfw", .{});

    const lib_name = b.fmt("farhorizons_deps_{s}-{s}-{s}", .{
        @tagName(t.cpu.arch),
        @tagName(t.os.tag),
        @tagName(t.abi),
    });

    // Copy headers step
    const headers_step = b.step("headers", "Copy GLFW headers");
    const install_headers = b.addInstallDirectory(.{
        .source_dir = glfw_dep.path("include"),
        .install_dir = .{ .custom = "include" },
        .install_subdir = "",
    });
    headers_step.dependOn(&install_headers.step);

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

    const install_lib = b.addInstallArtifact(glfw_lib, .{
        .dest_sub_path = b.fmt("{s}/libglfw.a", .{lib_name}),
    });

    b.default_step.dependOn(headers_step);
    b.default_step.dependOn(&install_lib.step);
}
