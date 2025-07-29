const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;

fn pgmMultiThreshold(image: *Image, allocator: std.mem.Allocator, thresholds: []u8) !Image {
    var new_image: Image = try Image.empty(allocator, image.header);

    const MAX_NUMBER_OF_THRESHOLDS = 20;

    if (thresholds.len > MAX_NUMBER_OF_THRESHOLDS) {
        return error.TooManyThresholds;
    }

    var pixel_values: [MAX_NUMBER_OF_THRESHOLDS]u8 = undefined;
    @memset(&pixel_values, 0);

    const gap: f32 = @floatFromInt(image.header.max_color_value / thresholds.len);
    // k * (max/n)
    for (thresholds, 0..) |_, i| {
        const k: f32 = @floatFromInt(i);
        const value = @floor(k * gap);
        pixel_values[i] = @intFromFloat(value);
    }

    var point: Coordinates = .default;

    for (0..image.header.height) |y| {
        for (0..image.header.width) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };
            const pixel = image.getPixel(point).black_and_white;

            var value: u8 = 0;

            for (thresholds, 0..) |th, i| {
                if (i == 0) {
                    if (pixel < th) {
                        value = pixel_values[0];
                        break;
                    }

                    continue;
                }

                if (thresholds[i - 1] <= pixel and pixel < th) {
                    value = pixel_values[i];
                    break;
                }

                // we consider that all the threshold failed
                if (i == thresholds.len - 1) {
                    value = image.header.max_color_value;
                    break;
                }
            }

            try new_image.setPixel(point, .{ .black_and_white = value });
        }
    }
    return new_image;
}

pub const PpmMultiThresholds = struct {
    red: []u8,
    green: []u8,
    blue: []u8,
};

fn ppmMultiThreshold(image: *Image, allocator: std.mem.Allocator, thresholds: PpmMultiThresholds) !Image {
    var red_image: Image = undefined;
    var green_image: Image = undefined;
    var blue_image: Image = undefined;

    red_image, green_image, blue_image = try image.splitChannels(std.testing.allocator);
    defer red_image.free(std.testing.allocator);
    defer green_image.free(std.testing.allocator);
    defer blue_image.free(std.testing.allocator);

    var red_multi_thr = try pgmMultiThreshold(&red_image, allocator, thresholds.red);
    var green_multi_thr = try pgmMultiThreshold(&green_image, allocator, thresholds.green);
    var blue_multi_thr = try pgmMultiThreshold(&blue_image, allocator, thresholds.blue);
    defer red_multi_thr.free(allocator);
    defer green_multi_thr.free(allocator);
    defer blue_multi_thr.free(allocator);

    return try Image.mergeChannels(red_multi_thr, green_multi_thr, blue_multi_thr, allocator);
}

test "pgm" {
    var image = try Image.fromFile("image_bank/Secateur.pgm", std.heap.page_allocator);
    defer image.free(std.heap.page_allocator);

    var ths = [_]u8{ 23, 150, 210 };

    var new_image = try pgmMultiThreshold(&image, std.testing.allocator, &ths);
    defer new_image.free(std.testing.allocator);
    try new_image.toFile("test.ppm", std.testing.allocator);
}

test "ppm" {
    var image = try Image.fromFile("image_bank/LenaHeadBruit.ppm", std.heap.page_allocator);
    defer image.free(std.heap.page_allocator);

    var thsr = [_]u8{ 100, 150 };
    var thsg = [_]u8{ 23, 150, 210 };
    var thsb = [_]u8{ 23, 150, 210 };

    var new_image = try ppmMultiThreshold(&image, std.testing.allocator, .{
        .red = &thsr,
        .green = &thsg,
        .blue = &thsb,
    });

    defer new_image.free(std.testing.allocator);
    try new_image.toFile("test.ppm", std.testing.allocator);
}
