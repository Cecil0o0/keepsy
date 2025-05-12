import { existsSync, readFileSync } from "node:fs";
import { strictEqual } from "node:assert";

if (!existsSync("zig-out/bin/keepsy.wasm")) {
  console.log("keepsy.wasm not exists, please run `zig build` first");
} else {
  const result = await WebAssembly.instantiate(readFileSync("zig-out/bin/keepsy.wasm"), {
    wasi_snapshot_preview1: {
      proc_exit: (code: number) => {
        console.log(`proc_exit: ${code}`);
      },
      fd_write: (fd: number, iovs: number, iovs_len: number, nwritten: number) => {
        console.log(`fd_write: ${fd} ${iovs} ${iovs_len} ${nwritten}`);
      },
      fd_read: (fd: number, iovs: number, iov) => {}
    }
  })
  console.log(result.instance.exports);
  strictEqual(WebAssembly.validate(readFileSync("zig-out/bin/keepsy.wasm")), true);
}
