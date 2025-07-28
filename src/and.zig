const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;

pub fn pgmPixelwiseAnd(self: Image, other: Image, allocator: std.mem.Allocator) !Image {
    if (self.header.image_format != .PGM) return error.CannotMergeMultipleChannels;
    if (other.header.image_format != .PGM) return error.CannotMergeMultipleChannels;

    if (self.header.width != other.header.width) return error.ImageWidthDoNotMatch;
    if (self.header.height != other.header.height) return error.ImageHeightDoNotMatch;

    var result = Image.empty(allocator, self.header);

    var point: Coordinates = .default;

    for (0..self.header.height) |y| {
        for (0..self.header.width) |x| {
            point = .{ .x = @intCast(x), .y = @intCast(y) };

            const self_pixel = self.getPixel(point).black_and_white;
            const other_pixel = other.getPixel(point).black_and_white;

            if (self_pixel and other_pixel) {
                try result.setPixel(point, .{ .black_and_white = 255 });
            }
        }
    }

    return result;
}

fn ppmPixelwiseAnd(self: *Image, other: Image, allocator: std.mem.Allocator) !Image {
    var red_self: Image = undefined;
    var green_self: Image = undefined;
    var blue_self: Image = undefined;

    red_self, green_self, blue_self = try self.splitChannels(std.testing.allocator);
    defer red_self.free(std.testing.allocator);
    defer green_self.free(std.testing.allocator);
    defer blue_self.free(std.testing.allocator);

    var red_other: Image = undefined;
    var green_other: Image = undefined;
    var blue_other: Image = undefined;

    red_other, green_other, blue_other = try other.splitChannels(std.testing.allocator);
    defer red_other.free(std.testing.allocator);
    defer green_other.free(std.testing.allocator);
    defer blue_other.free(std.testing.allocator);

    var red_and = try pgmPixelwiseAnd(red_self, red_other, allocator);
    var green_and = try pgmPixelwiseAnd(green_self, green_other, allocator);
    var blue_and = try pgmPixelwiseAnd(blue_self, blue_other, allocator);
    defer red_and.free(allocator);
    defer green_and.free(allocator);
    defer blue_and.free(allocator);

    return try Image.mergeChannels(red_and, green_and, blue_and, allocator);
}
