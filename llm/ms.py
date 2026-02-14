from modelscope import AutoModelForCausalLM, AutoTokenizer

model_name = "Qwen/Qwen3-4B-Instruct-2507"

# load the tokenizer and the model
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    dtype="auto",
    device_map="auto"
)

# prepare the model input
prompt = "Give me a short introduction to large language model."
messages = [
    {"role": "user", "content": prompt}
]
text = tokenizer.apply_chat_template(
    messages,
    tokenize=False,
    add_generation_prompt=True,
    enable_thinking=False # Switches between thinking and non-thinking modes. Default is True.
)
model_inputs = tokenizer([text], return_tensors="pt").to(model.device)

class CapturingStreamer:
    def __init__(self, tokenizer):
        self.tokenizer = tokenizer
        self.text = ""
        
    def put(self, value):
        new_text = self.tokenizer.decode(value[0], skip_special_tokens=True)
        self.text += new_text
        print(new_text, end="", flush=True)  # Stream to stdout
        
    def end(self):
        pass

streamer = CapturingStreamer(tokenizer)
# conduct text completion
generated_ids = model.generate(
    **model_inputs,
    max_new_tokens=32768,
    streamer = streamer,
)
output_ids = generated_ids[0][len(model_inputs.input_ids[0]):].tolist() 

# parsing thinking content
try:
    # rindex finding 151668 (</think>)
    index = len(output_ids) - output_ids[::-1].index(151668)
except ValueError:
    index = 0

thinking_content = tokenizer.decode(output_ids[:index], skip_special_tokens=True).strip("\n")
content = tokenizer.decode(output_ids[index:], skip_special_tokens=True).strip("\n")

print("thinking content:", thinking_content)
print("content:", content)