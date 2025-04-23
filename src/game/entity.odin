package game


import m "../math"


EntityVariant :: union {
    Entity_Player,
    Entity_StaticMesh,
    Entity_Camera,
    Entity_Opponent
}


Entity :: struct {
    using transform: m.Transform,
    variant: typeid,
    name: string,
    geometry: Geometry
}

Entity_Player :: struct {
    using entity: Entity,
    inventory: Inventory
}

Entity_StaticMesh :: struct {
    using entity: Entity,
}

Entity_Camera :: struct {
    using entity: Entity,
    target: m.Vec3,
    up: m.Vec3,
    fovy: f32,
    projection: enum { Perspective, Orthographic }
}

Entity_Opponent :: struct {
    using entity: Entity,
}