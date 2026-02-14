/// This is a cluster definition file for reliable production-level build service.
/// The service is efficient and scalable, it supports `concurrent` mode as default for tens of developers everyday at anytime they want.
const std = @import("std");

const Cluster = struct {
    name: []const u8,
    // `concurrent` mode with multiple computers, like a `act` programming paradigm, every computer has its own ownership and autonomy for delierying outputs.
    // `sequential` mode with one computer
    mode: []const u8,
};
const Computer = struct {
    // ipv4
    ip: []const u8,
    // always 5173
    port: []const u8,
    // belong to a specific cluster
    cluster: Cluster,
    // always `Ubuntu`
    os: []const u8,
    // always `x86_64`
    arch: []const u8,
    // always `unknown`
    vendor: []const u8,
    // always 4 cores
    cpu: u64,
    // always 8 GiB
    memory: u64,
    // always 10GiB, 4GiB for node_modules, 1GiB for logs and other for source code.
    disk: u64,
    // always `node`
    image_name: []const u8,
    // always `22`
    image_tag: []const u8,
    // always be `hub.docker.alibaba-inc.com`
    image_registry: []const u8,
    // always `inner`
    network: []const u8,
};
const Node = struct {
    computer: ?Computer,
    cluster: ?Cluster,
    // if true, means that this node is a leader node
    leader: bool,
    // in milliseconds, a timespan for waiting for a leader node
    election_timeout: u64,
    // in milliseconds, a timespan for sending heartbeat from leader node
    heartbeat_timeout: u64,
};
const BuildJob = struct {
    id: []const u8,
    // Build Job has to be run on a specific computer
    computer: Computer,
    // `pending` or `running` or `done` or `failed`
    status: []const u8,
    // always be true for stability, with stable code.
    with_lock_file: bool,
    // recommend to be a git implementation, other is supported too.
    source_code_url: []const u8,
    // `legacy` or `modern` or `native`
    // `legacy` means that the build job will use `webpack` or its variants to do the job, and with commonjs module system.
    // `modern` means that the build job will use `vite` or its variants to do the job, and with es module system.
    // `native` means that the build job will use entirely `native` module system for your codebase, which is not implemented yet.
    type: []const u8,
    // `web` or `node`
    target: []const u8,
    start_time: u64,
    end_time: u64,
};
const BuildTask = struct {
    id: []const u8,
    build_job: BuildJob,
    // only `app` and `modules` could be built
    // `app` means that it is a web application with an entry file that tyipically is `index.html`.
    // `modules` means that it is a javascript application with an entry files that tyipically are `index.js` or `index.ts`.
    type: []const u8,
    // whether to use jsx or not, if true means that the task will use jsx syntax to process the code in every module.
    // that is to say the `<` and `>` characters will be treated as jsx syntax other than a specific syntax in typescript.
    jsx: bool,
    // the file paths of the entry files, could be one or many
    entry: [][]const u8,
    start_time: u64,
    end_time: u64,
};
const Process = struct {
    // standard output writable stream
    stdout: Stream(u8),
    // standard error writable stream
    stderr: Stream(u8),
    // environment variables for initializing the process
    env: []struct {
        name: []const u8,
        value: []const u8,
    },
};

fn Stream(comptime _: type) type {
    return struct {
        const Self = @This();
        pub const Writer = struct {
            context: *Self,
            writeFn: *const fn (context: *Self, bytes: []const u8) Error!usize,

            pub const Error = error{
                OutOfMemory,
                SystemResources,
            };

            pub fn write(self: Writer, bytes: []const u8) Error!usize {
                return self.writeFn(self.context, bytes);
            }
        };
    };
}
