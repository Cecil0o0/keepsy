import tiktoken
enc = tiktoken.get_encoding("cl100k_base")

with open('control-plane.txt', 'r') as f:
    content = f.read()
    encoded_content = enc.encode(content)
    print(encoded_content  )
    print(enc.decode(encoded_content))
