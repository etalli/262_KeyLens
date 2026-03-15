import os
import subprocess
import json
from openai import OpenAI

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

files = subprocess.check_output(["git", "ls-files"], text=True)

prompt = f"""
You are reviewing a GitHub repository.

Repository: https://github.com/etalli/262_KeyLens

Files:
{files}

Return 3 GitHub issues in JSON format:

[
  {{
    "title": "Issue title",
    "body": "Detailed description"
  }}
]
"""

response = client.responses.create(
    model="gpt-4.1-mini",
    input=prompt
)

text = response.output_text.strip()

issues = json.loads(text)

for issue in issues:
    print(issue["title"])
    print("----")
    print(issue["body"])
    print("====")