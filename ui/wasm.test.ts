import { existsSync, readFileSync } from "node:fs";
import { strictEqual } from "node:assert";
import { describe, it } from "bun:test";

if (!existsSync("zig-out/bin/keepsy.wasm")) {
  console.log("keepsy.wasm not exists, please run `zig build` first");
} else {
  describe('wasm should be valid', () => {
    it('should be valid', () => {
      strictEqual(WebAssembly.validate(readFileSync("zig-out/bin/keepsy.wasm")), true);
    });
    it('should be instantiated', () => {
      WebAssembly.instantiate(readFileSync("zig-out/bin/keepsy.wasm"), {
        env: {
          print: console.log,
          print_string: console.log
        }
      });
    })
  });
}
