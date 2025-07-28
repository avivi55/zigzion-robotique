const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;

pub fn singleFilter(image: *Image, allocator: std.mem.Allocator, comptime filterFn: fn (img: *Image, pnt: Coordinates) Pixel) !Image {
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

pub fn filter(image: *Image, allocator: std.mem.Allocator, comptime filterFn: fn (img: *Image, pnt: Coordinates) Pixel) !Image {
    switch (image.header.image_format) {
        .ASCII_PGM, .PGM => {
            return singleFilter(image, allocator, filterFn);
        },
        .ASCII_PPM, .PPM => {
            var red_image: Image = undefined;
            var green_image: Image = undefined;
            var blue_image: Image = undefined;

            red_image, green_image, blue_image = try image.splitChannels(std.testing.allocator);
            defer red_image.free(std.testing.allocator);
            defer green_image.free(std.testing.allocator);
            defer blue_image.free(std.testing.allocator);

            var red_filtered = try singleFilter(&red_image, allocator, filterFn);
            var green_filtered = try singleFilter(&green_image, allocator, filterFn);
            var blue_filtered = try singleFilter(&blue_image, allocator, filterFn);
            defer red_filtered.free(allocator);
            defer green_filtered.free(allocator);
            defer blue_filtered.free(allocator);

            return try Image.mergeChannels(red_filtered, green_filtered, blue_filtered, allocator);
        },
    }
}
