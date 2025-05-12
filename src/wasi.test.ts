import { existsSync, readFileSync } from "node:fs";
import { strictEqual } from "node:assert";

if (!existsSync("zig-out/bin/keepsy.wasm")) {
  console.log("keepsy.wasm not exists, please run `zig build` first");
} else {
  strictEqual(WebAssembly.validate(readFileSync("zig-out/bin/keepsy.wasm")), true);
}
