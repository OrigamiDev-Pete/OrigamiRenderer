package OrigamiRenderer

Resource_Pool :: struct($T:typeid) {
    data: []T,
    available_handles: []Resource_Handle,
    available_handles_head: int,
    capacity: int,
}

Resource_Handle :: distinct u32

create_resource_pool :: proc($T: typeid) -> (pool: ^Resource_Pool) {
    pool = new(Resource_Pool(T))
    return
}

init_resource_pool :: proc(pool: ^Resource_Pool($T), capacity: int) {
    pool.data = make([]T, capacity)
    pool.available_handles = make([]Resource_Handle, capacity)
    pool.capacity = capacity

    for i in 0..<capacity {
        pool.available_handles[i] = auto_cast i
    }
}

deinit_resource_pool :: proc(pool: ^Resource_Pool($T)) {
    delete(pool.data)
    delete(pool.available_handles)
}

resource_pool_free_all :: proc(pool: ^Resource_Pool($T)) {
    pool.available_handles_head = 0

    for i in 0..<pool.capacity {
        pool.available_handles[i] = i
    }
}

resource_pool_allocate :: proc(using pool: ^Resource_Pool($T)) -> (handle: Resource_Handle, resource: ^T) {
    handle = available_handles[available_handles_head]
    available_handles_head += 1
    resource = &data[handle]
    return
}

resource_pool_release :: proc(using pool: ^Resource_Pool($T), handle: Resource_Handle) {
    available_handles_head -= 1
    available_handles[available_handles_head] = handle
}

resource_pool_get :: proc(using pool: Resource_Pool($T), handle: Resource_Handle) -> ^T {
    return &data[handle]
}