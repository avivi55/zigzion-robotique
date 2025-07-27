const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;

pub fn filter(image: *Image, allocator: std.mem.Allocator, comptime filterFn: fn (img: *Image, pnt: Coordinates) Pixel) !Image {
    var new_image: Image = try Image.empty(allocator, image.header);

    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        point.y = @intCast(y);
        point.x = 0;
        try new_image.setPixel(point, image.getPixel(point));

        point.x = image.header.width - 1;
        try new_image.setPixel(point, image.getPixel(point));
    }

    for (0..image.header.width) |x| {
        point.x = @intCast(x);
        point.y = 0;
        try new_image.setPixel(point, image.getPixel(point));

        point.y = image.header.height - 1;
        try new_image.setPixel(point, image.getPixel(point));
    }

    for (1..image.header.height - 1) |y| {
        for (1..image.header.width - 1) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };
            try new_image.setPixel(point, filterFn(image, point));
        }
    }
    return new_image;
}
