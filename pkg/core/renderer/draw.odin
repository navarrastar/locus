#+private
package renderer

import "core:fmt"
import "core:mem"
import "core:log"
import "core:strings"
import "core:math"
import rl "vendor:raylib"

import "third_party:clay"

import w "pkg:core/world"
import m "pkg:core/math"
import "pkg:core/window"
import ui "pkg:core/ui"



draw_world :: proc () {
    for entity in w.entities {
        #partial switch variant in entity {
            case w.Entity_Player:
                using e := entity.(w.Entity_Player)
                rl.DrawModel(e.model, entity.pos, entity.scale, rl.PINK)
            
            case w.Entity_StaticMesh:
                using e := entity.(w.Entity_StaticMesh)
                rl.DrawModel(e.model, entity.pos, entity.scale, rl.BLACK)
        }
    }
}

draw_ui :: proc (commands: ^clay.ClayArray(clay.RenderCommand), allocator := context.temp_allocator) {
    for i in 0..<commands.length {
        command := clay.RenderCommandArray_Get(commands, i)
    
        boundingBox := command.boundingBox
        switch (command.commandType) {
        case clay.RenderCommandType.None:
            {}
        case clay.RenderCommandType.Text:
            config := command.renderData.text
            // Raylib uses standard C strings so isn't compatible with cheap slices, we need to clone the string to append null terminator
            text := string(config.stringContents.chars[:config.stringContents.length])
            cloned := strings.clone_to_cstring(text, allocator)
            fontToUse: rl.Font = ui.raylibFonts[config.fontId].font
            rl.DrawTextEx (
                fontToUse,
                cloned,
                rl.Vector2{boundingBox.x, boundingBox.y},
                cast(f32)config.fontSize,
                cast(f32)config.letterSpacing,
                ui.clayColorToRaylibColor(config.textColor),
            )
        case clay.RenderCommandType.Image:
            config := command.renderData.image
            tintColor := config.backgroundColor
            if (tintColor.rgba == 0) {
                tintColor = { 255, 255, 255, 255 }
            }
            // TODO image handling
            imageTexture := cast(^rl.Texture2D)config.imageData
            rl.DrawTextureEx(imageTexture^, rl.Vector2{boundingBox.x, boundingBox.y}, 0, boundingBox.width / cast(f32)imageTexture.width, ui.clayColorToRaylibColor(tintColor))
        case clay.RenderCommandType.ScissorStart:
            rl.BeginScissorMode(
                cast(i32)math.round(boundingBox.x),
                cast(i32)math.round(boundingBox.y),
                cast(i32)math.round(boundingBox.width),
                cast(i32)math.round(boundingBox.height),
            )
        case clay.RenderCommandType.ScissorEnd:
            rl.EndScissorMode()
        case clay.RenderCommandType.Rectangle:
            config := command.renderData.rectangle
            if (config.cornerRadius.topLeft > 0) {
                radius: f32 = (config.cornerRadius.topLeft * 2) / min(boundingBox.width, boundingBox.height)
                rl.DrawRectangleRounded(rl.Rectangle{boundingBox.x, boundingBox.y, boundingBox.width, boundingBox.height}, radius, 8, ui.clayColorToRaylibColor(config.backgroundColor))
            } else {
                rl.DrawRectangle(cast(i32)boundingBox.x, cast(i32)boundingBox.y, cast(i32)boundingBox.width, cast(i32)boundingBox.height, ui.clayColorToRaylibColor(config.backgroundColor))
            }
        case clay.RenderCommandType.Border:
            config := command.renderData.border
            // Left border
            if (config.width.left > 0) {
                rl.DrawRectangle(
                    cast(i32)math.round(boundingBox.x),
                    cast(i32)math.round(boundingBox.y + config.cornerRadius.topLeft),
                    cast(i32)config.width.left,
                    cast(i32)math.round(boundingBox.height - config.cornerRadius.topLeft - config.cornerRadius.bottomLeft),
                    ui.clayColorToRaylibColor(config.color),
                )
            }
            // Right border
            if (config.width.right > 0) {
                rl.DrawRectangle(
                    cast(i32)math.round(boundingBox.x + boundingBox.width - cast(f32)config.width.right),
                    cast(i32)math.round(boundingBox.y + config.cornerRadius.topRight),
                    cast(i32)config.width.right,
                    cast(i32)math.round(boundingBox.height - config.cornerRadius.topRight - config.cornerRadius.bottomRight),
                    ui.clayColorToRaylibColor(config.color),
                )
            }
            // Top border
            if (config.width.top > 0) {
                rl.DrawRectangle(
                    cast(i32)math.round(boundingBox.x + config.cornerRadius.topLeft),
                    cast(i32)math.round(boundingBox.y),
                    cast(i32)math.round(boundingBox.width - config.cornerRadius.topLeft - config.cornerRadius.topRight),
                    cast(i32)config.width.top,
                    ui.clayColorToRaylibColor(config.color),
                )
            }
            // Bottom border
            if (config.width.bottom > 0) {
                rl.DrawRectangle(
                    cast(i32)math.round(boundingBox.x + config.cornerRadius.bottomLeft),
                    cast(i32)math.round(boundingBox.y + boundingBox.height - cast(f32)config.width.bottom),
                    cast(i32)math.round(boundingBox.width - config.cornerRadius.bottomLeft - config.cornerRadius.bottomRight),
                    cast(i32)config.width.bottom,
                    ui.clayColorToRaylibColor(config.color),
                )
            }
            if (config.cornerRadius.topLeft > 0) {
                rl.DrawRing(
                    rl.Vector2{math.round(boundingBox.x + config.cornerRadius.topLeft), math.round(boundingBox.y + config.cornerRadius.topLeft)},
                    math.round(config.cornerRadius.topLeft - cast(f32)config.width.top),
                    config.cornerRadius.topLeft,
                    180,
                    270,
                    10,
                    ui.clayColorToRaylibColor(config.color),
                )
            }
            if (config.cornerRadius.topRight > 0) {
                rl.DrawRing(
                    rl.Vector2{math.round(boundingBox.x + boundingBox.width - config.cornerRadius.topRight), math.round(boundingBox.y + config.cornerRadius.topRight)},
                    math.round(config.cornerRadius.topRight - cast(f32)config.width.top),
                    config.cornerRadius.topRight,
                    270,
                    360,
                    10,
                    ui.clayColorToRaylibColor(config.color),
                )
            }
            if (config.cornerRadius.bottomLeft > 0) {
                rl.DrawRing(
                    rl.Vector2{math.round(boundingBox.x + config.cornerRadius.bottomLeft), math.round(boundingBox.y + boundingBox.height - config.cornerRadius.bottomLeft)},
                    math.round(config.cornerRadius.bottomLeft - cast(f32)config.width.top),
                    config.cornerRadius.bottomLeft,
                    90,
                    180,
                    10,
                    ui.clayColorToRaylibColor(config.color),
                )
            }
            if (config.cornerRadius.bottomRight > 0) {
                rl.DrawRing(
                    rl.Vector2 {
                        math.round(boundingBox.x + boundingBox.width - config.cornerRadius.bottomRight),
                        math.round(boundingBox.y + boundingBox.height - config.cornerRadius.bottomRight),
                    },
                    math.round(config.cornerRadius.bottomRight - cast(f32)config.width.bottom),
                    config.cornerRadius.bottomRight,
                    0.1,
                    90,
                    10,
                    ui.clayColorToRaylibColor(config.color),
                )
            }
        case clay.RenderCommandType.Custom:
        // Implement custom element rendering here
        }
    }
}


