package game



import sdl "vendor:sdl3"





MaterialType :: enum {
    Default,
    Capsule,
    Grid,
}

Material :: struct {
    pipeline: ^sdl.GPUGraphicsPipeline,
}