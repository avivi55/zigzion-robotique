const std = @import("std");
const Image = @import("Image.zig").Image;
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;

pub fn pgmThreshold(image: *Image, allocator: std.mem.Allocator, threshold: u8) !*Image {
    var new_image: *Image = try Image.empty(allocator, image.header);

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

pub fn ppmThreshold(
    image: *Image,
    allocator: std.mem.Allocator,
    red_threshold: u8,
    green_threshold: u8,
    blue_threshold: u8,
) !*Image {
    std.debug.assert(image.header.image_format == .PPM);

    var new_image = try Image.empty(allocator, image.header);
    new_image.header.image_format = .PGM;

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
