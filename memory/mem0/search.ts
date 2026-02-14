import MemoryClient from "mem0ai";

export default function retrieve(client: MemoryClient) {
  const query = "I'm craving some pizza. Any recommendations?";
  client
    .search(query, { user_id: "alex" })
    .then((results) => console.log(results))
    .catch((error) => console.error(error));
}
