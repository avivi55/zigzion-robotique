const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;
const LinearFilter = @import("LinearFilter.zig");

fn pgmContrast(image: *Image, allocator: std.mem.Allocator, ignored_interval_pourcentage: u7) !Image {
    if (image.header.image_format != .PGM) return error.NotPGM;

    var histogram: Image = undefined;
    histogram, _, _ = try image.histogram(allocator);
    defer histogram.free(allocator);

    var max_index: f32 = @floatFromInt(histogram.header.width);
    var min_index: f32 = 0;

    for (0..histogram.header.width) |i| {
        if (histogram.data[histogram.header.width - i - 1] != 0) {
            max_index = @floatFromInt(i);
            break;
        }
    }

    for (0..histogram.header.width) |i| {
        if (histogram.data[i] != 0) {
            min_index = @floatFromInt(i);
            break;
        }
    }

    min_index += min_index * @as(f32, @floatFromInt(ignored_interval_pourcentage)) / 100;
    max_index -= max_index * @as(f32, @floatFromInt(ignored_interval_pourcentage)) / 100;

    const n1 = min_index;
    const n2 = max_index;
    if (n1 == n2) return error.ImageEmpty;
    var value: f32 = 0;

    var new_image: Image = try Image.empty(allocator, image.header);
    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        for (0..image.header.width) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };
            const pixel = @as(f32, @floatFromInt(image.getPixel(point).black_and_white));

            if (pixel <= n1) {
                try new_image.setPixel(point, .{ .black_and_white = 0 });
            } else if (pixel >= n2) {
                try new_image.setPixel(point, .{ .black_and_white = image.header.max_color_value });
            } else {
                value = @as(f32, @floatFromInt(image.header.max_color_value)) * ((pixel - n1) / (n2 - n1));
                value = @floor(value);
                try new_image.setPixel(point, .{ .black_and_white = @intFromFloat(value) });
            }
        }
    }
    return new_image;
}

fn ppmContrast(image: *Image, allocator: std.mem.Allocator, ignored_interval_pourcentage: u7) !Image {
    if (image.header.image_format != .PPM) return error.CannotSplitSingleChannel;

    var red_image: Image = undefined;
    var green_image: Image = undefined;
    var blue_image: Image = undefined;

    red_image, green_image, blue_image = try image.splitChannels(allocator);
    defer red_image.free(allocator);
    defer green_image.free(allocator);
    defer blue_image.free(allocator);

    var red_modified = try pgmContrast(&red_image, allocator, ignored_interval_pourcentage);
    var green_modified = try pgmContrast(&green_image, allocator, ignored_interval_pourcentage);
    var blue_modified = try pgmContrast(&blue_image, allocator, ignored_interval_pourcentage);
    defer red_modified.free(allocator);
    defer green_modified.free(allocator);
    defer blue_modified.free(allocator);

    return try Image.mergeChannels(red_modified, green_modified, blue_modified, allocator);
}
test "Contrast" {
    var image = try Image.fromFile("image_bank/LenaHeadBruit.ppm", std.testing.allocator);
    defer image.free(std.testing.allocator);

    var new_image = try ppmContrast(&image, std.testing.allocator, 25);
    defer new_image.free(std.testing.allocator);
    try new_image.toFile("test.ppm", std.testing.allocator);
}
