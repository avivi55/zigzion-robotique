//! All this mess is here because I want to support PGM and PPM.
//! But, because of the linearity, to support multiple color channels,
//! we just have to apply the filter to each channel and "remerge" them together.

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

            const gen = struct {
                pub fn inner_filter(i: *Image, a: std.mem.Allocator) Image {
                    return singleFilter(i, a, filterFn) catch {
                        std.log.warn("Error while applying the filter", .{});
                        return i.*;
                    };
                }
            };

            return try image.applyToEachChannel(gen.inner_filter, allocator);
        },
    }
}
