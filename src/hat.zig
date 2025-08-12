const std = @import("std");
const Image = @import("Image.zig").Image;
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;
const And = @import("and.zig");

fn pgmHat(image: Image, allocator: std.mem.Allocator, low_threshold: u8, high_threshold: u8) !*Image {
    var new_image = try Image.empty(allocator, image.header);

    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        for (0..image.header.width) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };

            if (low_threshold <= image.getPixel(point).black_and_white and image.getPixel(point).black_and_white <= high_threshold) {
                try new_image.setPixel(point, .{ .black_and_white = 255 });
            }
        }
    }
    return new_image;
}

fn ppmHat(
    image: Image,
    allocator: std.mem.Allocator,
    low_red_threshold: u8,
    high_red_threshold: u8,
    low_green_threshold: u8,
    high_green_threshold: u8,
    low_blue_threshold: u8,
    high_blue_threshold: u8,
) !*Image {
    var new_image = try Image.empty(allocator, image.header);

    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        for (0..image.header.width) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };

            const pixel = image.getPixel(point).color;

            // zig fmt: off
            if (
                low_red_threshold <= pixel.r and pixel.r <= high_red_threshold 
                and low_green_threshold <= pixel.g and pixel.g <= high_green_threshold 
                and low_blue_threshold <= pixel.b and pixel.b <= high_blue_threshold
            ) {
                try new_image.setPixel(point, .{ .black_and_white = 255 });
            }
            // zig fmt: on
        }
    }
    return new_image;
}
