const Image = @import("Image.zig").Image;
const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const nfd = @import("nfd");

const gui = @import("gui_elements.zig");
const ImageBox = gui.ImageBox;
const SingleThresholdBox = gui.SingleThresholdBox;
const TripleThresholdBox = gui.TripleThresholdBox;
const ThresholdBox = gui.ThresholdBox;

const threshold = @import("threshold.zig");
const kirsh = @import("kirsh.zig");
const gaussian = @import("gaussian.zig");
const mean = @import("mean.zig");
const median = @import("median.zig");
const laplace = @import("laplace.zig");

/// `rl.getColor` only accepts a `u32`. Performing `@intCast` on the return value
/// of `rg.getStyle` invokes checked undefined behavior from Zig when passed to
/// `rl.getColor`, hence the custom implementation here...
fn getColor(hex: i32) rl.Color {
    var color: rl.Color = .black;
    // zig fmt: off
    color.r = @intCast((hex >> 24) & 0xFF);
    color.g = @intCast((hex >> 16) & 0xFF);
    color.b = @intCast((hex >>  8) & 0xFF);
    color.a = @intCast((hex >>  0) & 0xFF);
    // zig fmt: on
    return color;
}

var seuillage_edit: bool = false;
var filtre_edit: bool = false;
var contour_edit: bool = false;
var image_selection_edit: bool = false;

var seuillage_active: i32 = 0;
var filtre_active: i32 = 0;
var contour_active: i32 = 0;
var image_selection_active: i32 = 0;

const seuillage_sel = enum(i32) {
    DEFAULT,
    SIMPLE,
    HAT,
    MULTI,
};

const filtre_sel = enum(i32) {
    DEFAULT,
    MOYEN,
    GAUSSIEN,
    MEDIAN,
};

const contours_sel = enum(i32) {
    DEFAULT,
    KIRSH,
    LAPLACE,
};

fn choose_image(list: *std.ArrayList(*ImageBox), allocator: std.mem.Allocator) !void {
    const dialog_res = try nfd.openFileDialog("ppm,pgm", ".");

    if (dialog_res) |path| {
        const image = try Image.fromFile(path, allocator);

        const image_box = try ImageBox.init(image, .{ .x = 400, .y = 300 }, path, allocator);

        try list.append(image_box);
    }
}

fn get_image_names(images: *std.ArrayList(*ImageBox), allocator: std.mem.Allocator) ![:0]const u8 {
    if (images.items.len == 0) {
        return "Image Selection";
    }

    var names = std.ArrayList([:0]const u8).init(allocator);
    defer names.deinit();
    defer {
        for (names.items) |name| {
            allocator.free(name);
        }
    }

    for (images.items) |image| {
        const filename = std.fs.path.basename(image.title);
        const owned_filename = try allocator.dupeZ(u8, filename);
        try names.append(owned_filename);
    }

    var total_len: usize = 0;
    for (names.items, 0..) |name, i| {
        total_len += name.len;
        if (i < names.items.len - 1) {
            total_len += 1; // For semicolon separator
        }
    }
    const result = try allocator.allocSentinel(u8, total_len, 0);
    var pos: usize = 0;
    for (names.items, 0..) |name, i| {
        @memcpy(result[pos .. pos + name.len], name);
        pos += name.len;

        if (i < names.items.len - 1) {
            result[pos] = ';';
            pos += 1;
        }
    }

    return result;
}

fn show_menu_bar(images: *std.ArrayList(*ImageBox), allocator: std.mem.Allocator) !void {
    if (seuillage_edit or filtre_edit or contour_edit or image_selection_edit) {
        rg.lock();
    }

    // zig fmt: off
    _ = rg.panel(.{ .x = 0, .y = 0, .width = 676, .height = 56 }, null);
    if (rg.button(.{ .x = 8, .y = 8, .width = 128, .height = 40 }, "Ajouter Image")) {
        try choose_image(images, allocator);
    }

    if (0 != rg.dropdownBox(
        .{ .x = 160, .y = 8, .width = 104, .height = 40 }, 
        "Seuillage;Simple;Hat;Multi", 
        &seuillage_active, 
        seuillage_edit
    )) { seuillage_edit = !seuillage_edit; }

    if (0 != rg.dropdownBox(
        .{ .x = 288, .y = 8, .width = 104, .height = 40 }, 
        "Filtre;Moyen;Gaussien;Médian", 
        &filtre_active, 
        filtre_edit
    )) { filtre_edit = !filtre_edit; }

    if (0 != rg.dropdownBox(
        .{ .x = 416, .y = 8, .width = 104, .height = 40 }, 
        "Contours;Kirsh;Laplace", 
        &contour_active, 
        contour_edit
    )) { contour_edit = !contour_edit; }

    if (0 != rg.dropdownBox(
        .{ .x = 544, .y = 8, .width = 124, .height = 40 }, 
        try get_image_names(images, allocator), 
        &image_selection_active, 
        image_selection_edit
    )) { image_selection_edit = !image_selection_edit; }
    // zig fmt: on
}

pub fn main() !void {
    rl.setConfigFlags(.{ .window_resizable = true });
    rl.initWindow(1900, 1200, "Zigzion Robotique");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var image_boxes = std.ArrayList(*ImageBox).init(allocator);
    defer {
        for (image_boxes.items) |image_box| {
            image_box.free(allocator);
        }
        image_boxes.deinit();
    }

    var controls = std.ArrayList(*gui.ThresholdControl).init(allocator);
    defer controls.deinit();

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(getColor(rg.getStyle(.default, .{ .default = .background_color })));

        try show_menu_bar(&image_boxes, allocator);
        defer {
            seuillage_active = 0;
            filtre_active = 0;
            contour_active = 0;
            // image_selection_active = 0;
        }

        if (image_boxes.items.len > 0) {
            const selected_image = image_boxes.items[@intCast(image_selection_active)].image;

            switch (seuillage_active) {
                @intFromEnum(seuillage_sel.SIMPLE) => {
                    const control_box = switch (selected_image.header.image_format) {
                        .PGM => ThresholdBox{ .simple = SingleThresholdBox.init(.{ .x = 100, .y = 500 }, "Simple") },
                        .PPM => ThresholdBox{ .triple = TripleThresholdBox.init(.{ .x = 100, .y = 500 }, "Simple") },
                        else => unreachable,
                    };

                    const control = try gui.ThresholdControl.init(selected_image, control_box, allocator);

                    try controls.append(control);
                },
                else => {},
            }

            switch (filtre_active) {
                @intFromEnum(filtre_sel.GAUSSIEN) => {
                    const modified_image = try gaussian.gaussianFiltering(selected_image, allocator);
                    const image_box = try ImageBox.init(modified_image, .{ .x = 400, .y = 300 }, "Gaussien", allocator);
                    try image_boxes.append(image_box);
                },
                @intFromEnum(filtre_sel.MOYEN) => {
                    const modified_image = try mean.meanFiltering(selected_image, allocator);
                    const image_box = try ImageBox.init(modified_image, .{ .x = 400, .y = 300 }, "Moyen", allocator);
                    try image_boxes.append(image_box);
                },
                @intFromEnum(filtre_sel.MEDIAN) => {
                    const modified_image = try median.medianFiltering(selected_image, allocator);
                    const image_box = try ImageBox.init(modified_image, .{ .x = 400, .y = 300 }, "Médian", allocator);
                    try image_boxes.append(image_box);
                },
                else => {},
            }

            switch (contour_active) {
                @intFromEnum(contours_sel.KIRSH) => {
                    const modified_image = try kirsh.kirsh(selected_image, allocator);
                    const image_box = try ImageBox.init(modified_image, .{ .x = 400, .y = 300 }, "Kirsh", allocator);
                    try image_boxes.append(image_box);
                },
                @intFromEnum(contours_sel.LAPLACE) => {
                    const modified_image = try laplace.laplaceFiltering(selected_image, allocator);
                    const image_box = try ImageBox.init(modified_image, .{ .x = 400, .y = 300 }, "Laplace", allocator);
                    try image_boxes.append(image_box);
                },
                else => {},
            }
        }

        for (controls.items, 0..) |control, i| {
            if (!try control.show(allocator)) {
                _ = controls.swapRemove(i);
            }
        }

        for (image_boxes.items, 0..) |image_box, i| {
            if (!image_box.show()) {
                const to_remove = image_boxes.swapRemove(i);
                to_remove.free(allocator);
            }
        }

        rg.unlock();
    }
}
