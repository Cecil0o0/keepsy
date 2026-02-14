import torch
import light_hf_proxy
from transformers import AutoModelForCausalLM, AutoTokenizer
import sys
import requests

model_name = "Qwen/Qwen3-4B-Instruct-2507"

# load the tokenizer and the model
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    dtype="auto",
    device_map="auto"
)

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

def make_memory(text):
    print("\nMaking memory...")
    messages = [
        {"role": "system", "content": r"""
            Memory assistants user for his/her purpose of continuous accumulative task-completing, to make the output of every tasks coherently and consistently.
            We try to make one from user's prompt, here are some rules for memory:
            1. Respond at most 10 tokens for concisely describing a memory.
            2. Start with `The user` to complete the memory.
            3. Respond a null value if you couldn't inference anything valuable.

            Following text is the user's prompt: \n
        """.strip() + text},
    ]
    text = tokenizer.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=True,
    )
    model_inputs = tokenizer([text], return_tensors="pt").to(model.device)
    generated_ids = model.generate(
        **model_inputs,
        max_new_tokens=128
    )
    output_ids = generated_ids[0][len(model_inputs.input_ids[0]):].tolist()
    generated_text = tokenizer.decode(output_ids, skip_special_tokens=True)
    print("Memory made...")
    return generated_text


if sys.stdin.isatty():
    while True:
        # prepare the model input
        prompt = input("You:") or "Hello"
        messages = [
            {"role": "user", "content": prompt}
        ]
        text = tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )
        model_inputs = tokenizer([text], return_tensors="pt").to(model.device)

        streamer = CapturingStreamer(tokenizer)
        # conduct text completion
        generated_ids = model.generate(
            **model_inputs,
            max_new_tokens=16384,
            streamer = streamer,
        )

        memory = make_memory(prompt)

        response = requests.post(
            url = "http://localhost:8000/interpret",
            data=f"insert into memory('uid', 'llm_id', 'content') values ('330937', 'qwen', \"{memory.replace('"', r"'")}\");",
            headers={"Content-Type": "text/plain"}
        )

        print("\n" + response.text)
