const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;

fn pgm_hat(image: *Image, allocator: std.mem.Allocator, low_threshold: u8, high_threshold: u8) !Image {
    var new_image: Image = try Image.empty(allocator, image.header);

    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        for (1..image.header.width - 1) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };

            if (low_threshold <= image.getPixel(point).black_and_white and image.getPixel(point).black_and_white <= high_threshold) {
                try new_image.setPixel(point, .{ .black_and_white = 255 });
            }
        }
    }
    return new_image;
}

fn ppm_threshold(
    image: *Image,
    allocator: std.mem.Allocator,
    low_red_threshold: u8,
    high_red_threshold: u8,
    low_green_threshold: u8,
    high_green_threshold: u8,
    low_blue_threshold: u8,
    high_blue_threshold: u8,
) !Image {
    var new_image: Image = try Image.empty(allocator, image.header);

    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        for (1..image.header.width - 1) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };

            const pixel = image.getPixel(point).color;

            if (
                low_red_threshold <= pixel.r and pixel.r <= high_red_threshold
                and low_green_threshold <= pixel.g and pixel.g <= high_green_threshold
                and low_blue_threshold <= pixel.b and pixel.b <= high_blue_threshold
            ) {
                try new_image.setPixel(point, .{ .black_and_white = 255 });
            }
        }
    }
    return new_image;
}

test "pgm" {
    var image = try Image.fromFile("image_bank/Secateur.pgm", std.heap.page_allocator);
    defer image.free(std.heap.page_allocator);

    var new_image = try pgm_hat(&image, std.testing.allocator, 50, 210);
    defer new_image.free(std.testing.allocator);
    try new_image.toFile("test.ppm", std.testing.allocator);
}

test "ppm" {
    var image = try Image.fromFile("image_bank/LenaHeadBruit.ppm", std.testing.allocator);
    defer image.free(std.testing.allocator);
}
