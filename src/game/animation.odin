package game

import m "../math"

Joint :: m.Transform

Skin :: struct {
    name:   string,
    joints: []Joint, // joints[0] is the root (mixamorig:Hips)
    ibm:    []m.Mat4,
    anim:   Animation
}

Animation :: struct {
    samplers:     []Sampler,
    channels:     []Channel,
	current_time: f32,
	time_scale:   f32, // Default 1
	weight:       f32, // Default 1
	start:        f32, // Default max(float)
	end:          f32, // Default min(float)
}

Sampler :: struct {
    interpolation: enum {
        Linear,
        Step,
        // CubicSpline
    },
    timestamps: []f32,
    values:     []m.Vec4
}

Channel :: struct {
    path: enum {
        Translation,
        Rotation,
        Scale,
    },
    sampler_idx: u32,
    joint_idx: u32
}

animation_continue :: proc(base: ^EntityBase) {
    skin, ok := base.geom.skin.?
    if !ok do return

    skin.anim.current_time += dt
    if skin.anim.current_time > skin.anim.end {
        skin.anim.current_time -= skin.anim.end;
    }

    for channel in skin.anim.channels {
        sampler := skin.anim.samplers[channel.sampler_idx]
        for timestamp, i in sampler.timestamps {
            if !(skin.anim.current_time >= timestamp && skin.anim.current_time <= sampler.timestamps[i + 1]) do continue

            switch sampler.interpolation {
            case .Linear:
                t := (skin.anim.current_time - timestamp) / (sampler.timestamps[i + 1] - timestamp);
                switch channel.path {
                case .Translation:
                    skin.joints[channel.joint_idx].pos = m.lerp(sampler.values[i], sampler.values[i + 1], t).xyz

                case .Rotation:
                    q1: m.Quat
                    q1.x = sampler.values[i].x;
                    q1.y = sampler.values[i].y;
                    q1.z = sampler.values[i].z;
                    q1.w = sampler.values[i].w;

                    q2: m.Quat
                    q2.x = sampler.values[i + 1].x;
                    q2.y = sampler.values[i + 1].y;
                    q2.z = sampler.values[i + 1].z;
                    q2.w = sampler.values[i + 1].w;

                    skin.joints[channel.joint_idx].rot = m.euler(m.lerp(q1, q2, t))

                case .Scale:
                    skin.joints[channel.joint_idx].scale = m.lerp(sampler.values[i], sampler.values[i + 1], t).x
                }
                
            case .Step:
                switch channel.path {
                case .Translation:
                    skin.joints[channel.joint_idx].pos = sampler.values[i].xyz

                case .Rotation:
                    q: m.Quat
                    q.x = sampler.values[i].x
                    q.y = sampler.values[i].y
                    q.z = sampler.values[i].z
                    q.w = sampler.values[i].w
                    
                    skin.joints[channel.joint_idx].rot = m.euler(q)

                case .Scale:
                    skin.joints[channel.joint_idx].scale = sampler.values[i].x
                }
            }
        }
    }
}
