import light_hf_proxy
import torch
from transformers import T5ForConditionalGeneration, T5Tokenizer

# Set the number of threads to 1 to avoid threading issues on some systems
torch.set_num_threads(1)

model = T5ForConditionalGeneration.from_pretrained("t5-small")
tokenizer = T5Tokenizer.from_pretrained("t5-small")

input_text = "translate English to German: The weather is nice today."
input_ids = tokenizer(input_text, return_tensors="pt").input_ids

outputs = model.generate(input_ids, max_length=50)
print(tokenizer.decode(outputs[0], skip_special_tokens=True))
# Output: "Das Wetter ist heute schön."