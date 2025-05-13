package game

// import "core:log"

import gltf "../../third_party/gltf2"

import m "../math"

JointTransform :: struct {
    pos:   m.Vec3,
    rot:   m.Quat,
    scale: m.Vec3
}

Joint :: struct {
    using transform: JointTransform,
    
    name: string,
    node_idx: int,   // From GLTF
    parent:   int,   // From Skeleton.joints
    children: []int, // From Skeleton.joints
    
    undeformed_mat:   m.Mat4, // From GLTF
    inverse_bind_mat: m.Mat4, // From GLTF
    
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
    
    // Set anim_idx directly if you want the anim
    // to immediatly change (no blending)
    anim_idx:      int,
    
    // Set next_anim_idx if you want the current anim
    // to blend into this one 
    next_anim_idx: int,
    
    // Handled by ...?
    _blend_factor:  f32,
    
    joint_matrices: []m.Mat4,
    
    // Should be removed. It's only used
    // during loading in mesh()
    node_to_joint_idx: map[int]int,
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
    
    joint: ^Joint,
    sampler: ^Sampler,
}

skeleton_update :: proc(skeleton: ^Skeleton) {
    anim := &skeleton.anims[skeleton.anim_idx]

    anim.current_time += dt
    if anim.current_time > anim.end {
        anim.current_time = anim.start
    }

    for &channel in anim.channels {
        _anim_update_channel(anim^, &channel)
    }
    
    if skeleton.next_anim_idx == skeleton.anim_idx {
        _anim_set_joint_matrices(skeleton)
        return 
    }
    
    _anim_handle_blending(skeleton)
    _anim_set_joint_matrices(skeleton)
    
    // next_anim := &skeleton.anims[skeleton.next_anim_idx]
    // next_anim.current_time += dt
    // if next_anim.current_time > next_anim.end {
    //     next_anim.current_time = next_anim.start
    // }
    
    // for &channel in next_anim.channels {
    //     _anim_update_channel(next_anim^, &channel)
    // }
}

_anim_handle_blending :: proc(skeleton: ^Skeleton) {
    anim := skeleton.anims[skeleton.next_anim_idx]
    
    joint_transforms := make([]JointTransform, len(skeleton.joints))
    
}

anim_find :: proc(skeleton: Skeleton, name: string) -> int {
    for anim, i in skeleton.anims {
        if anim.name == name {
            return i
        }
    }
    // If not found, look for TPose
    name := name
    name = "TPose"
    for anim, i in skeleton.anims {
        if anim.name == name {
            return i
        }
    }
    panic("")
}

_anim_set_joint_matrices :: proc(skeleton: ^Skeleton) {
    for joint, i in skeleton.joints {
        skeleton.joint_matrices[i] = m.to_matrix(joint.pos, joint.rot, joint.scale)
    }
    
    update_joint(skeleton, 0)
    
    for joint, i in skeleton.joints {
        skeleton.joint_matrices[i] *= joint.inverse_bind_mat
    }
}

_anim_update_channel :: proc(anim: Animation, channel: ^Channel) {
    sampler := channel.sampler
    joint := channel.joint
    
    for i in 0..<len(sampler.timestamps) - 1 {
        if !(anim.current_time >= sampler.timestamps[i] && anim.current_time <= sampler.timestamps[i + 1]) do continue
    
        switch sampler.interpolation {
        case .Linear:
            t := (anim.current_time - sampler.timestamps[i]) / (sampler.timestamps[i + 1] - sampler.timestamps[i]);
            switch channel.path {
            case .Translation:
                joint.pos = m.lerp(sampler.values[i], sampler.values[i + 1], t).xyz
                
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
                
                joint.rot = m.quaternion_slerp(q1, q2, t)
            case .Scale:
                joint.scale = m.lerp(sampler.values[i], sampler.values[i + 1], t).xyz
            }
            
        case .Step:
            switch channel.path {
            case .Translation:
                joint.pos = sampler.values[i].xyz

            case .Rotation:
                q: m.Quat
                q.x = sampler.values[i].x
                q.y = sampler.values[i].y
                q.z = sampler.values[i].z
                q.w = sampler.values[i].w
                
                joint.rot = q

            case .Scale:
                joint.scale = sampler.values[i].xyz
            }
        }
    }
}

// _anim_continue :: proc(anim: ^Animation, joint: ^Joint) {
//     for channel in anim.channels {
//         sampler := anim.samplers[channel.sampler_idx]
//         joint_idx := skeleton.node_to_joint_idx[channel.node_idx]
//         joint := &skeleton.joints[joint_idx]
        
//         for i in 0..<len(sampler.timestamps) - 1 {
//             if !(anim.current_time >= sampler.timestamps[i] && anim.current_time <= sampler.timestamps[i + 1]) do continue

//             switch sampler.interpolation {
//             case .Linear:
//                 t := (anim.current_time - sampler.timestamps[i]) / (sampler.timestamps[i + 1] - sampler.timestamps[i]);
//                 switch channel.path {
//                 case .Translation:
//                     joint.deformed_pos = m.lerp(sampler.values[i], sampler.values[i + 1], t).xyz

//                 case .Rotation:
//                     q1: m.Quat
//                     q1.x = sampler.values[i].x;
//                     q1.y = sampler.values[i].y;
//                     q1.z = sampler.values[i].z;
//                     q1.w = sampler.values[i].w;

//                     q2: m.Quat
//                     q2.x = sampler.values[i + 1].x;
//                     q2.y = sampler.values[i + 1].y;
//                     q2.z = sampler.values[i + 1].z;
//                     q2.w = sampler.values[i + 1].w;
                    
//                     joint.deformed_rot = m.quaternion_slerp(q1, q2, t)
//                 case .Scale:
//                     joint.deformed_scale = m.lerp(sampler.values[i], sampler.values[i + 1], t).xyz
//                 }
                
//             case .Step:
//                 switch channel.path {
//                 case .Translation:
//                     joint.deformed_pos = sampler.values[i].xyz

//                 case .Rotation:
//                     q: m.Quat
//                     q.x = sampler.values[i].x
//                     q.y = sampler.values[i].y
//                     q.z = sampler.values[i].z
//                     q.w = sampler.values[i].w
                    
//                     joint.deformed_rot = q

//                 case .Scale:
//                     joint.deformed_scale = sampler.values[i].xyz
//                 }
//             }
//         }
//     }
   
// }