package game

// import "core:log"

import gltf "../../third_party/gltf2"

import m "../math"

Joint :: struct {
    name: string,
    node_idx: int,   // From GLTF
    parent:   int,   // From Skeleton.joints
    children: []int, // From Skeleton.joints
    
    undeformed_mat:   m.Mat4, // From GLTF
    inverse_bind_mat: m.Mat4, // From GLTF
    
    deformed_pos:    m.Vec3,
    deformed_rot:    m.Quat,
    deformed_scale:  m.Vec3,
}

// Recursive
load_joint :: proc(model: gltf.Data, skeleton: ^Skeleton, node_idx, parent: int) {
    joint_idx := skeleton.node_to_joint_idx[node_idx]
    joint := &skeleton.joints[joint_idx]
    
    joint.parent = parent
    joint.children = make([]int, len(model.nodes[node_idx].children)) 
    for child_idx, i in model.nodes[node_idx].children {
        joint.children[i] = skeleton.node_to_joint_idx[int(child_idx)]
        load_joint(model, skeleton, int(child_idx), joint_idx)
    }
}

// Recursive
update_joint :: proc(skeleton: ^Skeleton, joint_idx: int) {
    joint := &skeleton.joints[joint_idx]
    
    if joint.parent != -1 {
        skeleton.joint_matrices[joint_idx] = skeleton.joint_matrices[joint.parent] * skeleton.joint_matrices[joint_idx]
    } 
    
    for child in joint.children {
        update_joint(skeleton, child)
    }
}

Skeleton :: struct {
    name:     string,
    joints:   []Joint,
    anims:    []Animation,
    node_to_joint_idx: map[int]int,
    anim_idx: int,
    
    joint_matrices: []m.Mat4
}

Animation :: struct {
    name:         string,
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
    node_idx: int
}

anim_continue :: proc(skeleton: ^Skeleton) {
    anim := &skeleton.anims[skeleton.anim_idx]

    anim.current_time += dt
    if anim.current_time > anim.end {
        anim.current_time = anim.start;
    }

    for channel in anim.channels {
        sampler := anim.samplers[channel.sampler_idx]
        joint_idx := skeleton.node_to_joint_idx[channel.node_idx]
        joint := &skeleton.joints[joint_idx]
        
        for i in 0..<len(sampler.timestamps) - 1 {
            if !(anim.current_time >= sampler.timestamps[i] && anim.current_time <= sampler.timestamps[i + 1]) do continue

            switch sampler.interpolation {
            case .Linear:
                t := (anim.current_time - sampler.timestamps[i]) / (sampler.timestamps[i + 1] - sampler.timestamps[i]);
                switch channel.path {
                case .Translation:
                    joint.deformed_pos = m.lerp(sampler.values[i], sampler.values[i + 1], t).xyz

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

                    joint.deformed_rot = m.lerp(q1, q2, t)

                case .Scale:
                    joint.deformed_scale = m.lerp(sampler.values[i], sampler.values[i + 1], t).xyz
                }
                
            case .Step:
                switch channel.path {
                case .Translation:
                    joint.deformed_pos = sampler.values[i].xyz

                case .Rotation:
                    q: m.Quat
                    q.x = sampler.values[i].x
                    q.y = sampler.values[i].y
                    q.z = sampler.values[i].z
                    q.w = sampler.values[i].w
                    
                    joint.deformed_rot = q

                case .Scale:
                    joint.deformed_scale = sampler.values[i].xyz
                }
            }
        }
    }
    
    // Calculate final_matrix of each joint
    for joint, i in skeleton.joints {
        skeleton.joint_matrices[i] = m.to_matrix(joint.deformed_pos, joint.deformed_rot, joint.deformed_scale)
    }
    
    update_joint(skeleton, 0)
    
    for joint, i in skeleton.joints {
        skeleton.joint_matrices[i] *= joint.inverse_bind_mat
    }
}