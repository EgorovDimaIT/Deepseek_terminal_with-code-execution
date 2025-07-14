from openai import OpenAI
client = OpenAI(api_key="e3a37ab6c53b4da5a5f9e7a8f1842f19", base_url="https://api.deepseek.com")
response = client.chat.completions.create(
    model="deepseek-reasoner",
    messages=[{"role": "user", "content": "Explain quantum computing."}]
)
print(response.choices[0].message.content)
