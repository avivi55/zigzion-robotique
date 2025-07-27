const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;

fn pgm_threshold(image: *Image, allocator: std.mem.Allocator, threshold: u8) !Image {
    var new_image: Image = try Image.empty(allocator, image.header);

    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        for (1..image.header.width - 1) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };

            if (image.getPixel(point).black_and_white >= threshold) {
                try new_image.setPixel(point, .{ .black_and_white = 255 });
            }
        }
    }
    return new_image;
}

fn ppm_threshold(
    image: *Image,
    allocator: std.mem.Allocator,
    red_threshold: u8,
    green_threshold: u8,
    blue_threshold: u8,
) !Image {
    var new_image: Image = try Image.empty(allocator, image.header);

    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        for (1..image.header.width - 1) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };

            const pixel = image.getPixel(point).color;

            if (pixel.r >= red_threshold and pixel.g >= green_threshold and pixel.b >= blue_threshold) {
                try new_image.setPixel(point, .{ .black_and_white = 255 });
            }
        }
    }
    return new_image;
}

test "pgm" {
    var image = try Image.fromFile("image_bank/Secateur.pgm", std.heap.page_allocator);
    defer image.free(std.heap.page_allocator);

    var new_image = try pgm_threshold(&image, std.testing.allocator, 210);
    defer new_image.free(std.testing.allocator);
    try new_image.toFile("test.ppm", std.testing.allocator);
}

test "ppm" {
    var image = try Image.fromFile("image_bank/LenaHeadBruit.ppm", std.testing.allocator);
    defer image.free(std.testing.allocator);
}
