const std = @import("std");
const ImageFormat = enum(u3) { ASCII_PPM = 3, PPM = 6, ASCII_PGM = 2, PGM = 5 };

/// For our `max_color_value`,
/// the max should be 16bytes(per the specs of PNM format)
/// but we will consider 255 as the max.
pub const Header = packed struct {
    image_format: ImageFormat,
    width: u32,
    height: u32,
    max_color_value: u8,

    pub const default = Header{
        .image_format = .PPM,
        .width = 0,
        .height = 0,
        .max_color_value = 255,
    };
};

pub const Coordinates = struct {
    x: usize,
    y: usize,

    pub const default = Coordinates{
        .x = 0,
        .y = 0,
    };
};

pub const Pixel = union(enum) {
    black_and_white: u8,
    color: struct {
        r: u8,
        g: u8,
        b: u8,
    },
};

pub const Image = struct {
    data: []u8,
    header: Header,

    fn readHeader(file: std.fs.File, allocator: std.mem.Allocator) !Header {
        var width: u32 = 0;
        var height: u32 = 0;
        var image_format: ImageFormat = .PPM;

        var line = std.ArrayList(u8).init(allocator);
        defer line.deinit();

        file.reader().streamUntilDelimiter(line.writer(), '\n', 3) catch |err| switch (err) {
            error.StreamTooLong => {
                std.log.err("Too many characters on the magic number line", .{});
                return err;
            },
            else => return err,
        };

        const first_line = try line.toOwnedSlice();
        defer allocator.free(first_line);

        line.clearRetainingCapacity();

        if (first_line.len < 2 or first_line[0] != 'P') {
            return error.InvalidImageFormat;
        }

        switch (first_line[1]) {
            '3' => return error.ASCIIFormatNotSupported, //image_format = .ASCII_PPM,
            '6' => image_format = .PPM,
            '2' => return error.ASCIIFormatNotSupported, //image_format = .ASCII_PGM,
            '5' => image_format = .PGM,
            else => return error.InvalidImageFormat,
        }

        while (true) {
            file.reader().streamUntilDelimiter(line.writer(), '\n', null) catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };

            if (line.items[0] != '#') { // we hit the first non-comment line
                var parts = std.mem.splitScalar(u8, line.items, ' ');

                width = try std.fmt.parseInt(u32, parts.next().?, 10);
                height = try std.fmt.parseInt(u32, parts.next().?, 10);
                break;
            }

            line.clearRetainingCapacity();
        }

        line.clearRetainingCapacity();

        file.reader().streamUntilDelimiter(line.writer(), '\n', 4) catch |err| switch (err) {
            error.StreamTooLong => {
                std.log.err("Too many characters on the color max line", .{});
                return err;
            },
            else => return err,
        };

        const max_color_line = try line.toOwnedSlice();
        defer allocator.free(max_color_line);

        const max_color_value = try std.fmt.parseInt(@FieldType(Header, "max_color_value"), max_color_line, 10);

        return .{
            .image_format = image_format,
            .width = width,
            .height = height,
            .max_color_value = max_color_value,
        };
    }

    pub fn free(self: *Image, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
        allocator.destroy(self);
    }

    pub fn fromFile(path: []const u8, allocator: std.mem.Allocator) !*Image {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const header = try readHeader(file, allocator);

        var line = std.ArrayList(u8).init(allocator);
        defer line.deinit();

        try file.reader().readAllArrayList(&line, std.math.maxInt(usize));

        const image = Image{
            .header = header,
            .data = try line.toOwnedSlice(),
        };

        const res = try allocator.create(Image);
        res.* = image;

        return res;
    }

    pub fn toBytes(self: *Image, allocator: std.mem.Allocator) ![]u8 {
        var array = std.ArrayList(u8).init(allocator);
        defer array.deinit();

        try array.writer().print("P{d}\n{d} {d}\n{d}\n", .{
            @intFromEnum(self.header.image_format),
            self.header.width,
            self.header.height,
            self.header.max_color_value,
        });

        try array.writer().writeAll(self.data);

        return array.toOwnedSlice();
    }

    pub fn toFile(self: *Image, path: []const u8, allocator: std.mem.Allocator) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const bytes = try self.toBytes(allocator);
        defer allocator.free(bytes);

        try file.writer().writeAll(bytes);
    }

    pub fn empty(allocator: std.mem.Allocator, header: Header) !*Image {
        const data_size = switch (header.image_format) {
            .ASCII_PPM, .PPM => 3 * header.width * header.height,
            .ASCII_PGM, .PGM => header.width * header.height,
        };

        const data = try allocator.alloc(u8, data_size);
        for (0..data_size) |i| {
            data[i] = 0;
        }

        const image = Image{
            .header = header,
            .data = data,
        };

        const res = try allocator.create(Image);
        res.* = image;

        return res;
    }

    pub fn clone(self: *Image, allocator: std.mem.Allocator) !*Image {
        const cloned_image = try Image.empty(allocator, self.header);
        @memcpy(cloned_image.data, self.data);
        return cloned_image;
    }

    pub fn splitChannels(self: *Image, allocator: std.mem.Allocator) !std.meta.Tuple(&.{ *Image, *Image, *Image }) {
        if (self.header.image_format != .PPM) return error.CannotSplitSingleChannel;

        var new_header = self.header;
        new_header.image_format = .PGM;

        var red_channel = try Image.empty(allocator, new_header);
        var green_channel = try Image.empty(allocator, new_header);
        var blue_channel = try Image.empty(allocator, new_header);

        for (self.data, 0..) |byte, i| {
            if (i % 3 == 0) {
                red_channel.data[i / 3] = byte; // R channel
            } else if (i % 3 == 1) {
                green_channel.data[i / 3] = byte; // G channel
            } else {
                blue_channel.data[i / 3] = byte; // B channel (i % 3 == 2)
            }
        }

        return .{ red_channel, green_channel, blue_channel };
    }

    pub fn mergeChannels(red_channel: *Image, green_channel: *Image, blue_channel: *Image, allocator: std.mem.Allocator) !*Image {
        if (red_channel.header.image_format != .PGM) return error.CannotMergeMultipleChannels;
        if (green_channel.header.image_format != .PGM) return error.CannotMergeMultipleChannels;
        if (blue_channel.header.image_format != .PGM) return error.CannotMergeMultipleChannels;

        if (red_channel.header.width != green_channel.header.width or red_channel.header.width != blue_channel.header.width or green_channel.header.width != blue_channel.header.width) {
            return error.ImageWidthDoNotMatch;
        }

        if (red_channel.header.height != green_channel.header.height or red_channel.header.height != blue_channel.header.height or green_channel.header.height != blue_channel.header.height) {
            return error.ImageHeightDoNotMatch;
        }

        var new_header = red_channel.header;
        new_header.image_format = .PPM;

        var merged_image = try Image.empty(allocator, new_header);

        for (0..red_channel.data.len) |i| {
            merged_image.data[i * 3] = red_channel.data[i];
            merged_image.data[1 + i * 3] = green_channel.data[i];
            merged_image.data[2 + i * 3] = blue_channel.data[i];
        }

        return merged_image;
    }

    pub fn applyToEachChannel(self: *Image, comptime applyFn: fn (*Image, std.mem.Allocator) *Image, allocator: std.mem.Allocator) !*Image {
        if (self.header.image_format != .PPM) return error.CannotSplitSingleChannel;

        var red_self: *Image = undefined;
        var green_self: *Image = undefined;
        var blue_self: *Image = undefined;

        red_self, green_self, blue_self = try self.splitChannels(allocator);
        defer red_self.free(allocator);
        defer green_self.free(allocator);
        defer blue_self.free(allocator);

        var red_modified = applyFn(red_self, allocator);
        var green_modified = applyFn(green_self, allocator);
        var blue_modified = applyFn(blue_self, allocator);
        defer red_modified.free(allocator);
        defer green_modified.free(allocator);
        defer blue_modified.free(allocator);

        return try mergeChannels(red_modified, green_modified, blue_modified, allocator);
    }

    pub fn getPixel(self: *Image, coords: Coordinates) Pixel {
        switch (self.header.image_format) {
            .ASCII_PPM, .PPM => {
                const red_data_address = 3 * (coords.x + self.header.width * coords.y);
                const green_data_address = red_data_address + 1;
                const blue_data_address = red_data_address + 2;

                return .{ .color = .{
                    .r = self.data[red_data_address],
                    .g = self.data[green_data_address],
                    .b = self.data[blue_data_address],
                } };
            },
            .ASCII_PGM, .PGM => return .{ .black_and_white = self.data[coords.x + self.header.width * coords.y] },
        }
    }

    pub fn setPixel(self: *Image, coords: Coordinates, pixel: Pixel) !void {
        if (coords.x >= self.header.width or coords.y >= self.header.height) {
            std.log.err("Coordinates out of bounds: ({}, {})", .{ coords.x, coords.y });
            return error.OutOfBounds;
        }

        switch (self.header.image_format) {
            .ASCII_PPM, .PPM => {
                const red_data_address = 3 * (coords.x + self.header.width * coords.y);
                const green_data_address = red_data_address + 1;
                const blue_data_address = red_data_address + 2;

                self.data[red_data_address] = pixel.color.r;
                self.data[green_data_address] = pixel.color.g;
                self.data[blue_data_address] = pixel.color.b;
            },
            .ASCII_PGM, .PGM => {
                self.data[coords.x + self.header.width * coords.y] = pixel.black_and_white;
            },
        }
    }

    pub fn histogram(self: *Image, allocator: std.mem.Allocator) !std.meta.Tuple(&.{ Image, ?Image, ?Image }) {
        switch (self.header.image_format) {
            .ASCII_PPM, .PPM => {
                var histogram_red_data = [_]u32{0} ** 256;
                var histogram_green_data = [_]u32{0} ** 256;
                var histogram_blue_data = [_]u32{0} ** 256;

                for (0..self.header.width) |x| {
                    for (0..self.header.height) |y| {
                        const coords: Coordinates = .{ .x = x, .y = y };
                        const pixel = self.getPixel(coords).color;
                        histogram_red_data[pixel.r] += 1;
                        histogram_green_data[pixel.g] += 1;
                        histogram_blue_data[pixel.b] += 1;
                    }
                }

                const max_red_value: u32 = std.sort.max(u32, &histogram_red_data, {}, std.sort.asc(u32)).?;
                const max_green_value: u32 = std.sort.max(u32, &histogram_green_data, {}, std.sort.asc(u32)).?;
                const max_blue_value: u32 = std.sort.max(u32, &histogram_blue_data, {}, std.sort.asc(u32)).?;

                const histogram_header: Header = .{
                    .image_format = .PPM,
                    .width = histogram_red_data.len,
                    .height = 300,
                    .max_color_value = 255,
                };

                var histogram_red_image = try Image.empty(allocator, histogram_header);

                for (histogram_red_data, 0..) |data, i| {
                    const normalized_height: u32 = @intCast((data * histogram_red_image.header.height) / max_red_value);
                    for (0..normalized_height) |h| {
                        const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_red_image.header.height - 1 - h) };
                        try histogram_red_image.setPixel(coords, .{ .color = .{
                            .r = 255,
                            .g = 0,
                            .b = 0,
                        } });
                    }
                }

                var histogram_green_image = try Image.empty(allocator, histogram_header);

                for (histogram_green_data, 0..) |data, i| {
                    const normalized_height: u32 = @intCast((data * histogram_green_image.header.height) / max_green_value);
                    for (0..normalized_height) |h| {
                        const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_green_image.header.height - 1 - h) };
                        try histogram_green_image.setPixel(coords, .{ .color = .{
                            .r = 0,
                            .g = 255,
                            .b = 0,
                        } });
                    }
                }

                var histogram_blue_image = try Image.empty(allocator, histogram_header);

                for (histogram_blue_data, 0..) |data, i| {
                    const normalized_height: u32 = @intCast((data * histogram_blue_image.header.height) / max_blue_value);
                    for (0..normalized_height) |h| {
                        const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_blue_image.header.height - 1 - h) };
                        try histogram_blue_image.setPixel(coords, .{ .color = .{
                            .r = 0,
                            .g = 0,
                            .b = 255,
                        } });
                    }
                }

                return .{ histogram_red_image, histogram_green_image, histogram_blue_image };
            },
            .ASCII_PGM, .PGM => {
                var histogram_data = [_]u32{0} ** 256;

                for (self.data) |byte| {
                    histogram_data[byte] += 1;
                }

                const max_value: u32 = std.sort.max(u32, &histogram_data, {}, std.sort.asc(u32)).?;

                var histogram_image = try Image.empty(allocator, .{
                    .image_format = .PGM,
                    .width = histogram_data.len,
                    .height = 300,
                    .max_color_value = 255,
                });

                for (histogram_data, 0..) |data, i| {
                    const normalized_height: u32 = @intCast((data * histogram_image.header.height) / max_value);
                    for (0..normalized_height) |h| {
                        const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_image.header.height - 1 - h) };
                        try histogram_image.setPixel(coords, .{ .black_and_white = 255 });
                    }
                }

                return .{ histogram_image, null, null };
            },
        }
    }

    pub fn logHistogram(self: *Image, allocator: std.mem.Allocator) !std.meta.Tuple(&.{ Image, ?Image, ?Image }) {
        switch (self.header.image_format) {
            .ASCII_PPM, .PPM => {
                var histogram_red_data = [_]u32{0} ** 256;
                var histogram_green_data = [_]u32{0} ** 256;
                var histogram_blue_data = [_]u32{0} ** 256;

                for (0..self.header.width) |x| {
                    for (0..self.header.height) |y| {
                        const coords: Coordinates = .{ .x = x, .y = y };
                        const pixel = self.getPixel(coords).color;
                        histogram_red_data[pixel.r] += 1;
                        histogram_green_data[pixel.g] += 1;
                        histogram_blue_data[pixel.b] += 1;
                    }
                }

                const max_red_value: u32 = std.sort.max(u32, &histogram_red_data, {}, std.sort.asc(u32)).?;
                const max_green_value: u32 = std.sort.max(u32, &histogram_green_data, {}, std.sort.asc(u32)).?;
                const max_blue_value: u32 = std.sort.max(u32, &histogram_blue_data, {}, std.sort.asc(u32)).?;

                const histogram_header: Header = .{
                    .image_format = .PPM,
                    .width = histogram_red_data.len,
                    .height = 300,
                    .max_color_value = 255,
                };

                var histogram_red_image = try Image.empty(allocator, histogram_header);

                for (histogram_red_data, 0..) |data, i| {
                    const normalized_height: u32 = @intFromFloat((std.math.log10(@as(f64, @floatFromInt(1 + data))) * @as(f64, @floatFromInt(histogram_red_image.header.height))) / std.math.log10(@as(f64, @floatFromInt(max_red_value + 1))));
                    for (0..normalized_height) |h| {
                        const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_red_image.header.height - 1 - h) };
                        try histogram_red_image.setPixel(coords, .{ .color = .{
                            .r = 255,
                            .g = 0,
                            .b = 0,
                        } });
                    }
                }

                var histogram_green_image = try Image.empty(allocator, histogram_header);

                for (histogram_green_data, 0..) |data, i| {
                    const normalized_height: u32 = @intFromFloat((std.math.log10(@as(f64, @floatFromInt(1 + data))) * @as(f64, @floatFromInt(histogram_green_image.header.height))) / std.math.log10(@as(f64, @floatFromInt(max_green_value + 1))));
                    for (0..normalized_height) |h| {
                        const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_green_image.header.height - 1 - h) };
                        try histogram_green_image.setPixel(coords, .{ .color = .{
                            .r = 0,
                            .g = 255,
                            .b = 0,
                        } });
                    }
                }

                var histogram_blue_image = try Image.empty(allocator, histogram_header);

                for (histogram_blue_data, 0..) |data, i| {
                    const normalized_height: u32 = @intFromFloat((std.math.log10(@as(f64, @floatFromInt(1 + data))) * @as(f64, @floatFromInt(histogram_blue_image.header.height))) / std.math.log10(@as(f64, @floatFromInt(max_blue_value + 1))));
                    for (0..normalized_height) |h| {
                        const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_blue_image.header.height - 1 - h) };
                        try histogram_blue_image.setPixel(coords, .{ .color = .{
                            .r = 0,
                            .g = 0,
                            .b = 255,
                        } });
                    }
                }

                return .{ histogram_red_image, histogram_green_image, histogram_blue_image };
            },
            .ASCII_PGM, .PGM => {
                var histogram_data = [_]u32{0} ** 256;

                for (self.data) |byte| {
                    histogram_data[byte] += 1;
                }

                const max_value: u32 = std.sort.max(u32, &histogram_data, {}, std.sort.asc(u32)).?;

                var histogram_image = try Image.empty(allocator, .{
                    .image_format = .PGM,
                    .width = histogram_data.len,
                    .height = 300,
                    .max_color_value = 255,
                });

                for (histogram_data, 0..) |data, i| {
                    const normalized_height: u32 = @intFromFloat((std.math.log10(@as(f64, @floatFromInt(1 + data))) * @as(f64, @floatFromInt(histogram_image.header.height))) / std.math.log10(@as(f64, @floatFromInt(max_value + 1))));
                    for (0..normalized_height) |h| {
                        const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_image.header.height - 1 - h) };
                        try histogram_image.setPixel(coords, .{ .black_and_white = 255 });
                    }
                }

                return .{ histogram_image, null, null };
            },
        }
    }

    const rl = @import("raylib");
    const rg = @import("raygui");

    /// Don't forget rl.unloadTexture();
    pub fn getRaylibTexture(self: *Image, allocator: std.mem.Allocator) !rl.Texture2D {
        const image_bytes = try self.toBytes(allocator);
        defer allocator.free(image_bytes);

        const r_image = switch (self.header.image_format) {
            .ASCII_PGM, .PGM => try rl.loadImageFromMemory(".pgm", image_bytes),
            .ASCII_PPM, .PPM => try rl.loadImageFromMemory(".ppm", image_bytes),
        };
        defer rl.unloadImage(r_image);

        return try rl.loadTextureFromImage(r_image);
    }
};
