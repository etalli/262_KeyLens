import os
import subprocess
import json
from openai import OpenAI

# ---- configuration ----

REPO_URL = "https://github.com/etalli/262_KeyLens"
MODEL = "gpt-4.1-mini"


# ---- check API key ----

api_key = os.getenv("OPENAI_API_KEY")
if not api_key:
    print("OPENAI_API_KEY not set")
    exit(1)

client = OpenAI(api_key=api_key)


# ---- get repo file list ----

try:
    files = subprocess.check_output(
        ["git", "ls-files"],
        text=True
    )
except Exception as e:
    print("Failed to read repo files:", e)
    exit(1)


# ---- build AI prompt ----

prompt = f"""
You are reviewing a GitHub repository.

Repository:
{REPO_URL}

Project files:
{files}

Suggest 3 useful GitHub issues that would improve this project.

Return the result strictly as JSON:

[
  {{
    "title": "Issue title",
    "body": "Detailed issue description"
  }},
  {{
    "title": "Issue title",
    "body": "Detailed issue description"
  }},
  {{
    "title": "Issue title",
    "body": "Detailed issue description"
  }}
]
"""


# ---- call AI ----

print("Running AI repository review...")

try:
    response = client.responses.create(
        model=MODEL,
        input=prompt
    )

    text = response.output_text.strip()

except Exception as e:
    print("AI request failed:", e)
    exit(1)


# ---- parse JSON ----

try:
    issues = json.loads(text)
except Exception as e:
    print("Failed to parse AI output as JSON")
    print("AI output was:")
    print(text)
    exit(1)


# ---- create GitHub issues ----

for issue in issues:

    title = issue.get("title", "").strip()
    body = issue.get("body", "").strip()

    if not title:
        continue

    print(f"Creating issue: {title}")

    subprocess.run([
        "gh",
        "issue",
        "create",
        "--title",
        title,
        "--body",
        body
    ])

print("AI issue generation complete.")