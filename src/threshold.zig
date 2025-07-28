const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;

fn pgmThreshold(image: *Image, allocator: std.mem.Allocator, threshold: u8) !Image {
    var new_image: Image = try Image.empty(allocator, image.header);

    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        for (0..image.header.width) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };

            if (image.getPixel(point).black_and_white >= threshold) {
                try new_image.setPixel(point, .{ .black_and_white = 255 });
            }
        }
    }
    return new_image;
}

fn ppmThreshold(
    image: *Image,
    allocator: std.mem.Allocator,
    red_threshold: u8,
    green_threshold: u8,
    blue_threshold: u8,
) !Image {
    var new_image: Image = try Image.empty(allocator, image.header);

    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        for (0..image.header.width) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };

            const pixel = image.getPixel(point).color;

            if (pixel.r >= red_threshold and pixel.g >= green_threshold and pixel.b >= blue_threshold) {
                try new_image.setPixel(point, .{ .black_and_white = 255 });
            }
        }
    }
    return new_image;
}