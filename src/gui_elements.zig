const std = @import("std");
const Image = @import("Image.zig").Image;
const rl = @import("raylib");
const rg = @import("raygui");
const threshold = @import("threshold.zig");

const WINDOW_BOX_HEADER_HEIGHT = 23;

pub const ImageBox = struct {
    const MAX_WIDTH = 500;
    const MAX_HEIGHT = 500;

    image: *Image,
    drag: bool = false,
    offset: rl.Vector2,
    bounds: rl.Rectangle,
    scale: f32,
    title: [:0]const u8,
    texture: rl.Texture2D,

    pub fn show(self: *ImageBox) bool {
        const mouse_pos = rl.getMousePosition();

        if (rl.isMouseButtonPressed(.left) and !self.drag) {
            if (rl.checkCollisionPointRec(mouse_pos, .{ .x = self.bounds.x, .y = self.bounds.y, .width = self.bounds.width, .height = 20 })) {
                self.drag = true;
                self.offset.x = mouse_pos.x - self.bounds.x;
                self.offset.y = mouse_pos.y - self.bounds.y;

                self.bounds.x = mouse_pos.x + self.offset.x;
                self.bounds.y = mouse_pos.y + self.offset.y;
            }
        }

        if (self.drag) {
            self.bounds.x = (mouse_pos.x - self.offset.x);
            self.bounds.y = (mouse_pos.y - self.offset.y);

            if (rl.isMouseButtonReleased(.left)) {
                self.drag = false;
            }
        }

        const res = rg.windowBox(self.bounds, self.title);
        rl.drawTextureEx(self.texture, .{ .x = self.bounds.x, .y = self.bounds.y + WINDOW_BOX_HEADER_HEIGHT }, 0.0, self.scale, rl.Color.white);

        return 0 == res;
    }

    pub fn reloadTexture(self: *ImageBox, allocator: std.mem.Allocator) !void {
        rl.unloadTexture(self.texture);
        self.texture = try self.image.getRaylibTexture(allocator);
    }

    pub fn init(image: *Image, position: rl.Vector2, title: [:0]const u8, allocator: std.mem.Allocator) !*ImageBox {
        const texture = try image.getRaylibTexture(allocator);
        const wh_ratio: f32 = @as(f32, @floatFromInt(image.header.width)) / @as(f32, @floatFromInt(image.header.height));

        var bounds: rl.Rectangle = .{ .x = position.x, .y = position.y, .width = 1, .height = 1 };
        if (image.header.width >= image.header.height) {
            bounds.width = MAX_WIDTH;
            bounds.height = bounds.width / wh_ratio;
        } else {
            bounds.height = MAX_HEIGHT;
            bounds.width = bounds.height * wh_ratio;
        }

        const scale: f32 = bounds.width / @as(f32, @floatFromInt(image.header.width));

        const box = ImageBox{
            .image = image,
            .offset = .{ .x = 0, .y = 0 },
            .bounds = bounds,
            .scale = scale,
            .title = title,
            .texture = texture,
        };

        const res = try allocator.create(ImageBox);
        res.* = box;

        return res;
    }

    fn freeInner(self: *ImageBox, allocator: std.mem.Allocator) void {
        rl.unloadTexture(self.texture);
        self.image.free(allocator);
    }

    pub fn free(self: *ImageBox, allocator: std.mem.Allocator) void {
        self.freeInner(allocator);
        allocator.destroy(self);
    }
};

pub const ThresholdBox = union(enum) {
    simple: SingleThresholdBox,
    triple: TripleThresholdBox,

    pub fn show(self: *ThresholdBox) !bool {
        switch (self.*) {
            .simple => return self.simple.show(),
            .triple => return self.triple.show(),
        }
    }
};

pub const SpinnerSlider = struct {
    has_changed: bool = false,

    spinner_edit: bool = false,
    spinner_val: i32 = 127,
    slider_val: f32 = 127,
    old_spinner_val: i32 = 127,
    old_slider_val: f32 = 127,

    pub fn show(self: *SpinnerSlider, x: f32, y: f32) void {
        _ = rg.slider(.{ .x = x, .y = y, .width = 136, .height = 24 }, "", "", &self.slider_val, 0, 255);
        if (0 != rg.spinner(.{ .x = x + 146, .y = y, .width = 80, .height = 24 }, "", &self.spinner_val, 0, 255, self.spinner_edit)) {
            self.spinner_edit = !self.spinner_edit;
        }

        self.has_changed = true;

        if (self.slider_val > 255) {
            self.slider_val = 255;
        }

        if (self.spinner_val > 255) {
            self.spinner_val = 255;
        }

        if (self.slider_val != self.old_slider_val) {
            self.spinner_val = @intFromFloat(self.slider_val);
        } else if (self.spinner_val != self.old_spinner_val) {
            self.slider_val = @floatFromInt(self.spinner_val);
        } else {
            self.has_changed = false;
        }

        self.old_slider_val = self.slider_val;
        self.old_spinner_val = self.spinner_val;
    }
};

pub const TripleThresholdBox = struct {
    offset: rl.Vector2,
    bounds: rl.Rectangle,
    title: [:0]const u8,
    has_changed: bool = false,

    drag: bool = false,

    red_spinner_slider: SpinnerSlider,
    green_spinner_slider: SpinnerSlider,
    blue_spinner_slider: SpinnerSlider,

    pub fn init(position: rl.Vector2, title: [:0]const u8) TripleThresholdBox {
        const bounds: rl.Rectangle = .{ .x = position.x, .y = position.y, .width = 240, .height = 130 };

        return TripleThresholdBox{
            .offset = .{ .x = 0, .y = 0 },
            .bounds = bounds,
            .title = title,
            .red_spinner_slider = SpinnerSlider{},
            .green_spinner_slider = SpinnerSlider{},
            .blue_spinner_slider = SpinnerSlider{},
        };
    }

    pub fn show(self: *TripleThresholdBox) !bool {
        const mouse_pos = rl.getMousePosition();

        if (rl.isMouseButtonPressed(.left) and !self.drag) {
            if (rl.checkCollisionPointRec(mouse_pos, .{ .x = self.bounds.x, .y = self.bounds.y, .width = self.bounds.width, .height = 20 })) {
                self.drag = true;
                self.offset.x = mouse_pos.x - self.bounds.x;
                self.offset.y = mouse_pos.y - self.bounds.y;

                self.bounds.x = mouse_pos.x + self.offset.x;
                self.bounds.y = mouse_pos.y + self.offset.y;
            }
        }

        if (self.drag) {
            self.bounds.x = (mouse_pos.x - self.offset.x);
            self.bounds.y = (mouse_pos.y - self.offset.y);

            if (rl.isMouseButtonReleased(.left)) {
                self.drag = false;
            }
        }

        const res = rg.windowBox(self.bounds, self.title);

        self.red_spinner_slider.show(self.bounds.x + 8, self.bounds.y + 40);
        self.green_spinner_slider.show(self.bounds.x + 8, self.bounds.y + 65);
        self.blue_spinner_slider.show(self.bounds.x + 8, self.bounds.y + 90);

        return 0 == res;
    }
};

pub const SingleThresholdBox = struct {
    offset: rl.Vector2,
    bounds: rl.Rectangle,
    title: [:0]const u8,

    drag: bool = false,
    spinner_slider: SpinnerSlider,

    pub fn init(position: rl.Vector2, title: [:0]const u8) SingleThresholdBox {
        const bounds: rl.Rectangle = .{ .x = position.x, .y = position.y, .width = 240, .height = 80 };

        return SingleThresholdBox{
            .offset = .{ .x = 0, .y = 0 },
            .bounds = bounds,
            .title = title,
            .spinner_slider = SpinnerSlider{},
        };
    }

    pub fn show(self: *SingleThresholdBox) !bool {
        const mouse_pos = rl.getMousePosition();

        if (rl.isMouseButtonPressed(.left) and !self.drag) {
            if (rl.checkCollisionPointRec(mouse_pos, .{ .x = self.bounds.x, .y = self.bounds.y, .width = self.bounds.width, .height = 20 })) {
                self.drag = true;
                self.offset.x = mouse_pos.x - self.bounds.x;
                self.offset.y = mouse_pos.y - self.bounds.y;

                self.bounds.x = mouse_pos.x + self.offset.x;
                self.bounds.y = mouse_pos.y + self.offset.y;
            }
        }

        if (self.drag) {
            self.bounds.x = (mouse_pos.x - self.offset.x);
            self.bounds.y = (mouse_pos.y - self.offset.y);

            if (rl.isMouseButtonReleased(.left)) {
                self.drag = false;
            }
        }

        const res = rg.windowBox(self.bounds, self.title);

        self.spinner_slider.show(self.bounds.x + 8, self.bounds.y + 40);

        return 0 == res;
    }
};

pub const ThresholdControl = struct {
    base_image: *Image,
    control: ThresholdBox,
    modified_image_box: *ImageBox,

    pub fn init(base_image: *Image, control: ThresholdBox, allocator: std.mem.Allocator) !*ThresholdControl {
        const res = try allocator.create(ThresholdControl);
        var modified_image = try base_image.clone(allocator);
        modified_image.header.image_format = .PGM;

        const new_image_box = try ImageBox.init(modified_image, .{ .x = 50, .y = 50 }, "Threshold", allocator);

        res.base_image = base_image;
        res.control = control;
        res.modified_image_box = new_image_box;
        return res;
    }

    pub fn show(self: *ThresholdControl, allocator: std.mem.Allocator) !bool {
        const modified: *Image = switch (self.base_image.header.image_format) {
            .PGM => try threshold.pgmThreshold(self.base_image, allocator, @intCast(self.control.simple.spinner_slider.spinner_val)),
            .PPM => try threshold.ppmThreshold(
                self.base_image,
                allocator,
                @intCast(self.control.triple.red_spinner_slider.spinner_val),
                @intCast(self.control.triple.green_spinner_slider.spinner_val),
                @intCast(self.control.triple.blue_spinner_slider.spinner_val),
            ),
            else => unreachable,
        };
        const old = self.modified_image_box.image;

        // we can safely do that because the modified image is a clone of the base image
        // thus, it has the same dimensions and same format
        @memcpy(old.data, modified.data);

        modified.free(allocator);

        const control_x_buton_pressed = try self.control.show();

        switch (self.control) {
            .simple => {
                if (self.control.simple.spinner_slider.has_changed) {
                    try self.modified_image_box.reloadTexture(allocator);
                }
            },
            .triple => {
                if (self.control.triple.red_spinner_slider.has_changed or self.control.triple.green_spinner_slider.has_changed or self.control.triple.blue_spinner_slider.has_changed) {
                    try self.modified_image_box.reloadTexture(allocator);
                }
            },
        }

        const image_x_buton_pressed = self.modified_image_box.show();

        return control_x_buton_pressed and image_x_buton_pressed;
    }

    pub fn free(self: *ThresholdControl, allocator: std.mem.Allocator) void {
        self.modified_image_box.free(allocator);
        allocator.destroy(self);
    }
};
