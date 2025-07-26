const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;

pub fn meanFiltering(image: *Image, allocator: std.mem.Allocator) !Image {
    var new_image: Image = try Image.empty(allocator, image.header);

    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        point.y = @intCast(y);
        point.x = 0;
        new_image.setPixel(point, image.getPixel(point));

        point.x = image.header.width - 1;
        new_image.setPixel(point, image.getPixel(point));
    }

    for (0..image.header.width) |x| {
        point.x = @intCast(x);
        point.y = 0;
        new_image.setPixel(point, image.getPixel(point));

        point.y = image.header.height - 1;
        new_image.setPixel(point, image.getPixel(point));
    }

    var neighbor_point: Coordinates = .default;
    var mean: u32 = 0;
    var red_mean: u32 = 0;
    var green_mean: u32 = 0;
    var blue_mean: u32 = 0;

    for (1..image.header.height - 1) |y| {
        for (1..image.header.width - 1) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };

            for (0..3) |i| {
                for (0..3) |j| {
                    neighbor_point = .{
                        .x = @truncate(point.x + i - 1),
                        .y = @truncate(point.y + j - 1),
                    };
                    const pixel = image.getPixel(neighbor_point);
                    switch (image.header.image_format) {
                        .ASCII_PGM, .PGM => {
                            mean += pixel.black_and_white;
                        },
                        .ASCII_PPM, .PPM => {
                            red_mean += pixel.color.r;
                            green_mean += pixel.color.g;
                            blue_mean += pixel.color.b;
                        },
                    }
                }
            }

            switch (image.header.image_format) {
                .ASCII_PGM, .PGM => {
                    const neighbor_count = 9;
                    mean /= neighbor_count;

                    new_image.setPixel(point, .{ .black_and_white = @intCast(mean) });
                },
                .ASCII_PPM, .PPM => {
                    const neighbor_count = 27;
                    red_mean /= neighbor_count;
                    green_mean /= neighbor_count;
                    blue_mean /= neighbor_count;

                    new_image.setPixel(point, .{ .color = .{ .r = @intCast(red_mean), .g = @intCast(green_mean), .b = @intCast(blue_mean) } });
                },
            }
        }
    }
    return new_image;
}

test "mean filtering" {
    var image = try Image.fromFile("example.ppm", std.testing.allocator);
    defer image.free(std.testing.allocator);

    var new_image = try meanFiltering(&image, std.testing.allocator);
    defer new_image.free(std.testing.allocator);
    try new_image.toFile("test.ppm");
}
