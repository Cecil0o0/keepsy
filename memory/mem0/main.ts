import MemoryClient from "mem0ai";
const client = new MemoryClient({
  apiKey: "m0-4leRrpgTNenO3Uzxi0zcvD3ZUIvRP6lgL3whByxr",
});

import("./search").then(({ default: func }) => func(client));
