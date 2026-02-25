import tiktoken
enc = tiktoken.get_encoding("cl100k_base")

with open('control-plane.txt', 'r') as f:
    content = f.read()
    encoded_content = enc.encode(content)
    print(encoded_content)
    print("Does the decoded content match the original content?", enc.decode(encoded_content) == content)

print(enc.encode("香蕉"), enc.encode("水果"), enc.encode("卡车"))
