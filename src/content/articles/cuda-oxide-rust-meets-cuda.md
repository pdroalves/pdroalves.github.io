---
title: "cuda-oxide: when Rust meets CUDA"
description: "NVIDIA released a framework for writing CUDA kernels in pure Rust. I took a look."
date: "2026-05-12"
tags: ["rust", "cuda", "gpu", "nvidia", "technical"]
---

If you have ever written CUDA, you know the feeling. You write a kernel, it compiles, it runs, the output looks... wrong. Not obviously wrong, subtly wrong. Off by one in a thread index. A race condition that only shows up at scale. A buffer you forgot to free three refactors ago. The compiler saw nothing. The runtime said nothing. You just shipped a bug that will haunt you in production.

CUDA is remarkable. It made general-purpose GPU computing accessible and kickstarted entire fields: deep learning, scientific simulation, cryptography. But its programming model has always been, let's say, _challenging_. Although recent upgrades to the architecture gave us the ability to work at a higher level, that always cost performance. To squeeze even a ms you need raw pointers everywhere, manual memory management, and thread indexing through magic arithmetic that the compiler happily accepts no matter how wrong it is. It's a powerful tool that can achieve the moon regarding performance, but it trusts you completely, and that trust is not always deserved.

Rust took the opposite bet. The compiler is not your friend, it's your drill sergeant. It will reject your code, sometimes annoyingly so, until you prove that what you wrote is actually correct. And that philosophy has worked absurdly well for systems programming. So the question is: can we bring that same discipline to GPU programming?

Well, NVIDIA just released [cuda-oxide](https://github.com/NVlabs/cuda-oxide).

## What is cuda-oxide?

cuda-oxide is NVIDIA's official Rust-native CUDA framework. You write GPU kernels in pure Rust: no C++, no NVCC, no FFI glue, no separate compilation step. Host code and device code live in the same `.rs` file, in the same language, built with `cargo oxide`. Under the hood, a custom `rustc` codegen backend compiles your Rust down to PTX and embeds the device code directly into your binary.

That alone would be interesting. But what got me excited is what Rust's type system brings to the CUDA table.

## Why this is a big deal

Let's start with the classic CUDA footgun: thread indexing. In CUDA C, you compute your global thread ID with something like `blockIdx.x * blockDim.x + threadIdx.x`, cast it around, and hope you got it right. If you need something more complex, like 2D indexing or mixing that with offsets and strides, you hope harder. The compiler cannot tell you if thread 47 is about to stomp on thread 48's memory (or if that memory piece is even allocated). That's your problem.

In cuda-oxide, thread indices are opaque witness types:

```rust
let idx = thread::index_1d(); // ThreadIndex<'kernel, Index1D>
```

You cannot construct a `ThreadIndex` yourself. You cannot copy it. You cannot share it between threads. It cannot outlive the kernel. The only way to get one is to ask the runtime, and the type system ensures you use it correctly. Data races on output buffers? The compiler catches them. Not at runtime, at _compile time_.

`DisjointSlice` builds on top of this. It's the type for output buffers that multiple threads write to in parallel. You can only get a mutable reference to an element by presenting your `ThreadIndex`, and bounds checking happens automatically:

```rust
#[kernel]
pub fn add_one(input: &[f32], mut output: DisjointSlice<f32>) {
    let idx = thread::index_1d();
    if let Some(out) = output.get_mut(idx) {
        *out = input[idx.get()] + 1.0;
    }
}
```

Each thread can only touch its own slot. Try to write somewhere else and the compiler will stop you. That's not a runtime check, it's a type-level guarantee.

Memory management follows the same idea. `DeviceBuffer<T>` wraps allocations with RAII[^1] semantics: memory is freed automatically when the buffer goes out of scope, just like any other Rust value. No `cudaFree` to forget. No leaks to chase. And error handling uses `Result<T, DriverError>` instead of the `cudaError_t` codes that, let's be honest, most CUDA engineers ignore.

```rust
let input = DeviceBuffer::from_host(&stream, &host_data)?;
let mut output = DeviceBuffer::<f32>::zeroed(&stream, n)?;
// ...
let result = output.to_host_vec(&stream)?;
// input and output freed automatically here
```

Rust developers will recognize all of this as standard patterns, nothing new. But we never had them in GPU programming, where getting it wrong means silent data corruption instead of a nice segfault. That's a meaningful difference.

## What else is in the box

This is not a toy or a proof of concept. cuda-oxide covers the full surface of modern GPU programming. Generic kernels with monomorphization (write once, instantiate for `f32`, `f64`, whatever). Shared memory with `SharedArray` and `DynamicSharedArray`. Warp-level operations like shuffles, votes, and reductions. Cooperative groups. Scoped atomics with explicit memory ordering. Async GPU work composition that integrates with Rust's `async`/`await`.

It also has first-class support for the latest hardware features. Thread block clusters on Hopper. TMA (Tensor Memory Accelerator) for hardware-accelerated async copies. If you're working with H100s or B200s, cuda-oxide is ready for you.

## Demo: pairwise reduction, two ways

To make this concrete, let's look at a real task: pairwise reduction of N arrays. We have 32 arrays of 2048 elements each, all filled with 1s, and we want to reduce them into a single array by summing pairs in a tree. The expected output is an array where every element equals 32.

I wrote two versions ([full code here](https://github.com/pdroalves/cuda-oxide-demo)). The first one will feel familiar if you come from CUDA C/C++. The second shows what happens when you lean into Rust's type system instead of fighting it.

### The C++ way (with `unsafe`)

This version does in-place reduction. A single buffer holds all the data, and each kernel step reads two chunks at a stride distance and writes the sum back to the first. Classic tree reduction.

The problem: `DisjointSlice` is write-only by design (no safe read method), so to read and write the same buffer you have to drop down to raw pointers. The kernel also needs manual D2D copies to set up and extract results.

```rust
#[kernel]
pub fn step_reduce<T: Copy + Add<Output = T>>(
    mut data: DisjointSlice<T>,
    chunk_len: usize,
    stride: usize,
    num_pairs: usize,
) {
    let tid = thread::index_1d();
    let pair_id = tid.get() / chunk_len;
    let coeff_id = tid.get() % chunk_len;

    if pair_id >= num_pairs {
        return;
    }

    let left_offset = 2 * pair_id * stride * chunk_len;
    let right_offset = left_offset + stride * chunk_len;

    unsafe {
        let left_val = *data.as_mut_ptr().add(left_offset + coeff_id);
        let right_val = *data.as_mut_ptr().add(right_offset + coeff_id);

        *data.get_unchecked_mut(left_offset + coeff_id) = left_val + right_val;
    }
}
```

On the host side, we copy the input into a working buffer, run the reduction loop doubling the stride at each step, and then extract the first `l` elements with another D2D copy:

```rust
unsafe {
    memory::memcpy_dtod_async(
        d_work.cu_deviceptr(),
        d_input.cu_deviceptr(),
        d_input.len() * std::mem::size_of::<u32>(),
        stream.cu_stream(),
    )
    .expect("D2D copy failed");
}

for i in 0..n.ilog2() {
    let stride = 1usize << i;
    let num_pairs = n / (2 * stride);
    let num_threads = num_pairs * l;
    module
        .step_reduce(
            &stream,
            LaunchConfig::for_num_elems(num_threads as u32),
            &mut d_work, l, stride, num_pairs,
        )
        .expect("Kernel launch failed");
}
```

It works. But there's a lot of `unsafe`, raw pointer math, and manual offset calculations that the compiler cannot verify. One wrong index and you get silent corruption. 

Rust engineers are surely crying after reading that code.

### The Rustacean way (no `unsafe` in the kernel)

Same algorithm, different philosophy. Instead of mutating a buffer in place, we ping-pong between two buffers: each step reads from `&[T]` (safe, bounds-checked) and writes via `DisjointSlice<T>` (safe, one-write-per-thread). No raw pointers needed.

The indexing logic moves into a `Payload` struct with named methods, so the kernel reads almost like pseudocode:

```rust
#[derive(Copy, Clone)]
struct Payload {
    chunk_len: usize,
}

// SAFETY: Payload contains only usize, which is DeviceCopy.
unsafe impl DeviceCopy for Payload {}

impl Payload {
    fn pair_id(&self, tid: usize) -> usize { tid / self.chunk_len }
    fn coeff_id(&self, tid: usize) -> usize { tid % self.chunk_len }
    fn left_idx(&self, pair_id: usize, coeff_id: usize) -> usize {
        2 * pair_id * self.chunk_len + coeff_id
    }
    fn right_idx(&self, pair_id: usize, coeff_id: usize) -> usize {
        (2 * pair_id + 1) * self.chunk_len + coeff_id
    }
}

#[kernel]
pub fn step_reduce<T: Copy + Add<Output = T>>(
    input: &[T],
    mut output: DisjointSlice<T>,
    payload: Payload,
) {
    let tid = thread::index_1d();
    let pair_id = payload.pair_id(tid.get());
    let coeff_id = payload.coeff_id(tid.get());

    if let Some(out) = output.get_mut(tid) {
        *out = input[payload.left_idx(pair_id, coeff_id)]
            + input[payload.right_idx(pair_id, coeff_id)];
    }
}
```

The host code is also cleaner. No D2D copies, just buffer swapping:

```rust
let mut buf_a = DeviceBuffer::from_host(&stream, &h_data).expect("Failed to allocate buf_a");
let mut buf_b = DeviceBuffer::<u32>::zeroed(&stream, n * l).expect("Failed to allocate buf_b");

let steps = n.ilog2();
for i in 0..steps {
    let num_pairs = (n >> i) / 2;
    let config = LaunchConfig::for_num_elems((num_pairs * l) as u32);

    if i % 2 == 0 {
        module.step_reduce::<u32>(&stream, config, &buf_a, &mut buf_b, payload)
            .expect("Kernel launch failed");
    } else {
        module.step_reduce::<u32>(&stream, config, &buf_b, &mut buf_a, payload)
            .expect("Kernel launch failed");
    }
}
```

The only `unsafe` left in the entire program is the `DeviceCopy` impl for `Payload`, because there's no derive macro for it yet (it's just a `usize`). Everything else is checked by the compiler.

Same result, same performance, far fewer ways to shoot yourself in the foot.

## Looking ahead

cuda-oxide is still young. It requires Rust nightly, runs on Linux, and targets CUDA Toolkit 12.x+. The ecosystem around it is just getting started and surely not ready for production. But the direction is clear: GPU programming doesn't have to be a high-wire act without a safety net.

For those of us who write CUDA for a living, who have spent more hours than we'd like to admit chasing race conditions and memory leaks that no tool caught, this is worth paying attention to. Not because it makes GPU programming easy (it doesn't), but because it makes a whole class of bugs impossible to write in the first place. The compiler becomes your ally instead of a rubber stamp.

We may be finally witnessing a quality-of-life revolution for CUDA engineers.

Pedro Alves

[^1]: [Resource Acquisition Is Initialization](https://en.cppreference.com/w/cpp/language/raii), a pattern from C++ where a resource's lifetime is tied to an object's scope: acquired in the constructor, released in the destructor.
