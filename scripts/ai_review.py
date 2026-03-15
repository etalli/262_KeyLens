import os
import subprocess
import json
from openai import OpenAI

# ------------------------------
# Configuration
# ------------------------------

REPO_URL = "https://github.com/etalli/262_KeyLens"
MODEL = "gpt-4.1-mini"


# ------------------------------
# Check API key
# ------------------------------

api_key = os.getenv("OPENAI_API_KEY")

if not api_key:
    print("ERROR: OPENAI_API_KEY not set")
    exit(1)

client = OpenAI(api_key=api_key)


# ------------------------------
# Get repository file list
# ------------------------------

try:
    files = subprocess.check_output(
        ["git", "ls-files"],
        text=True
    )
except Exception as e:
    print("ERROR: Failed to read repo files:", e)
    exit(1)


# ------------------------------
# Build AI prompt
# ------------------------------

prompt = f"""
You are reviewing a GitHub repository.

Repository:
{REPO_URL}

Project files:
{files}

Suggest 3 useful GitHub issues that would improve this project.

Return JSON only (no markdown), like this:

[
  {{
    "title": "Issue title",
    "body": "Detailed issue description"
  }}
]
"""


# ------------------------------
# Call AI
# ------------------------------

print("Running AI repository review...")

try:
    response = client.responses.create(
        model=MODEL,
        input=prompt
    )

    text = response.output_text.strip()

except Exception as e:
    print("ERROR: AI request failed:", e)
    exit(1)


# ------------------------------
# Remove markdown code fences
# ------------------------------

if text.startswith("```"):
    lines = text.split("\n")
    lines = lines[1:]

    if lines[-1].startswith("```"):
        lines = lines[:-1]

    text = "\n".join(lines)


# ------------------------------
# Parse JSON
# ------------------------------

try:
    issues = json.loads(text)

except Exception as e:
    print("ERROR: Failed to parse AI output as JSON")
    print("AI output was:")
    print(text)
    exit(1)


# ------------------------------
# Create GitHub issues
# ------------------------------

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