import { serve } from "bun";

const server = serve({
  port: 3000,
  routes: {
    "/": () => {
      return new Response(Bun.file("./src/web-ui/index.html"));
    },
    "/keepsy.wasm": () => {
      return new Response(Bun.file("./zig-out/bin/keepsy.wasm"));
    },
  },
});

console.log(`Listening on http://localhost:${server.port}`)
