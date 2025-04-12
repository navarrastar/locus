package ui

import "third_party:clay"
import rl "vendor:raylib"

// Define some colors.
COLOR_LIGHT :: clay.Color{224, 215, 210, 255}
COLOR_RED :: clay.Color{168, 66, 28, 255}
COLOR_ORANGE :: clay.Color{225, 138, 50, 255}
COLOR_BLACK :: clay.Color{0, 0, 0, 255}

profile_picture: rl.Texture2D

// Layout config is just a struct that can be declared statically, or inline
sidebar_item_layout := clay.LayoutConfig {
    sizing = {
        width = clay.SizingGrow({}),
        height = clay.SizingFixed(50)
    },
}

// Re-useable components are just normal procs.
sidebar_item_component :: proc(index: u32) {
    if clay.UI()({
        id = clay.ID("SidebarBlob", index),
        layout = sidebar_item_layout,
        backgroundColor = COLOR_ORANGE,
    }) {}
}

// An example function to create your layout tree
create_layout :: proc() -> clay.ClayArray(clay.RenderCommand) {
  // Begin constructing the layout.
  clay.BeginLayout()

  // An example of laying out a UI with a fixed-width sidebar and flexible-width main content
  // NOTE: To create a scope for child components, the Odin API uses `if` with components that have children
  if clay.UI()({
      id = clay.ID("OuterContainer"),
      layout = {
          sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) },
          padding = { 16, 16, 16, 16 },
          childGap = 16,
      },
      backgroundColor = { 250, 250, 255, 255 },
  }) {
      if clay.UI()({
          id = clay.ID("SideBar"),
          layout = {
              layoutDirection = .TopToBottom,
              sizing = { width = clay.SizingFixed(300), height = clay.SizingGrow({}) },
              padding = { 16, 16, 16, 16 },
              childGap = 16,
          },
          backgroundColor = COLOR_LIGHT,
      }) {
          if clay.UI()({
              id = clay.ID("ProfilePictureOuter"),
              layout = {
                  sizing = { width = clay.SizingGrow({}) },
                  padding = { 16, 16, 16, 16 },
                  childGap = 16,
                  childAlignment = { y = .Center },
              },
              backgroundColor = COLOR_RED,
              cornerRadius = { 6, 6, 6, 6 },
          }) {
              if clay.UI()({
                  id = clay.ID("ProfilePicture"),
                  layout = {
                      sizing = { width = clay.SizingFixed(60), height = clay.SizingFixed(60) },
                  },
                  image = {
                      imageData = &profile_picture,
                      sourceDimensions = {
                          width = 60,
                          height = 60,
                      },
                  },
              }) {}

              clay.Text(
                  "Clay - UI Library",
                  clay.TextConfig({ textColor = COLOR_BLACK, fontSize = 16 }),
              )
          }

          // Standard Odin code like loops, etc. work inside components.
          // Here we render 5 sidebar items.
          for i in u32(0)..<5 {
              sidebar_item_component(i)
          }
      }

      if clay.UI()({
          id = clay.ID("MainContent"),
          layout = {
              sizing = { width = clay.SizingGrow({}), height = clay.SizingGrow({}) },
          },
          backgroundColor = COLOR_LIGHT,
      }) {}
  }

  // Returns a list of render commands
  render_commands: clay.ClayArray(clay.RenderCommand) = clay.EndLayout()
  return render_commands
}

RaylibFont :: struct {
    fontId: u16,
    font:   rl.Font,
}

clayColorToRaylibColor :: proc(color: clay.Color) -> rl.Color {
    return rl.Color{cast(u8)color.r, cast(u8)color.g, cast(u8)color.b, cast(u8)color.a}
}

raylibFonts := [10]RaylibFont{}

measureText :: proc "c" (text: clay.StringSlice, config: ^clay.TextElementConfig, userData: rawptr) -> clay.Dimensions {
    // Measure string size for Font
    textSize: clay.Dimensions = {0, 0}

    maxTextWidth: f32 = 0
    lineTextWidth: f32 = 0

    textHeight := cast(f32)config.fontSize
    fontToUse := raylibFonts[config.fontId].font

    for i in 0 ..< int(text.length) {
        if (text.chars[i] == '\n') {
            maxTextWidth = max(maxTextWidth, lineTextWidth)
            lineTextWidth = 0
            continue
        }
        index := cast(i32)text.chars[i] - 32
        if (fontToUse.glyphs[index].advanceX != 0) {
            lineTextWidth += cast(f32)fontToUse.glyphs[index].advanceX
        } else {
            lineTextWidth += (fontToUse.recs[index].width + cast(f32)fontToUse.glyphs[index].offsetX)
        }
    }

    maxTextWidth = max(maxTextWidth, lineTextWidth)

    textSize.width = maxTextWidth / 2
    textSize.height = textHeight

    return textSize
}