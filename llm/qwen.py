from transformers import AutoModelForCausalLM, AutoTokenizer, TextStreamer
import time
import math
import sys

model_name = "Qwen/Qwen3-4B-Instruct-2507"

# load the tokenizer and the model
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    dtype="auto",
    device_map="auto"
)

if sys.stdin.isatty():
    while True:
        # prepare the model input
        prompt = input("You: ") or "Hello World!"
        messages = [
            {"role": "system", "content": "You are a software engineer who is building a data engine."},
            {"role": "user", "content": prompt}
        ]
        text = tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )
        model_inputs = tokenizer([text], return_tensors="pt").to(model.device)

        print("Qwen: ", end="", flush=True)
        streamer = TextStreamer(tokenizer, skip_prompt=True, skip_special_tokens=True)
        # conduct text completion
        generated_ids = model.generate(
            **model_inputs,
            max_new_tokens=16384,
            streamer=streamer,
        )
