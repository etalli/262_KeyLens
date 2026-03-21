import os
import subprocess
import json
from openai import OpenAI

# ------------------------------
# Configuration
# ------------------------------

REPO_URL = "https://github.com/etalli/262_KeyLens"
MODEL = "gpt-4.1-mini"

# Max chars per file and total source budget to stay within token limits.
# gpt-4.1-mini has a 1M token context; ~100k chars ≈ 25k tokens — well within budget.
MAX_CHARS_PER_FILE = 8_000
MAX_TOTAL_CHARS    = 100_000


# ------------------------------
# Check API key
# ------------------------------

api_key = os.getenv("OPENAI_API_KEY")

if not api_key:
    print("ERROR: OPENAI_API_KEY not set")
    exit(1)

client = OpenAI(api_key=api_key)


# ------------------------------
# Read Swift source files
# ------------------------------

try:
    swift_files = subprocess.check_output(
        ["git", "ls-files", "Sources/", "Tests/", "--", "*.swift"],
        text=True
    ).splitlines()
except Exception as e:
    print("ERROR: Failed to list Swift files:", e)
    exit(1)

source_sections = []
total_chars = 0

for path in sorted(swift_files):
    if total_chars >= MAX_TOTAL_CHARS:
        source_sections.append(f"// ... (remaining files omitted — budget reached)")
        break
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read(MAX_CHARS_PER_FILE)
        truncated = len(content) == MAX_CHARS_PER_FILE
        header = f"// FILE: {path}" + (" [truncated]" if truncated else "")
        section = f"{header}\n{content}"
        source_sections.append(section)
        total_chars += len(section)
    except Exception:
        pass  # skip unreadable files

source_dump = "\n\n".join(source_sections)
print(f"Source code loaded: {len(swift_files)} files, {total_chars:,} chars")


# ------------------------------
# Fetch open GitHub issues
# ------------------------------

try:
    issues_json = subprocess.check_output(
        ["gh", "issue", "list", "--state", "open", "--limit", "100",
         "--json", "number,title"],
        text=True
    )
    open_issues = json.loads(issues_json)
    open_issues_text = "\n".join(
        f"#{i['number']}: {i['title']}" for i in open_issues
    )
except Exception as e:
    print("WARNING: Failed to fetch open issues:", e)
    open_issues_text = "(unavailable)"

print(f"Open issues fetched: {len(open_issues)} issues")


# ------------------------------
# Build AI prompt
# ------------------------------

prompt = f"""You are a senior engineer reviewing a macOS Swift application called KeyLens.
It is a menu-bar app that monitors keystrokes and mouse activity and displays statistics.

Repository: {REPO_URL}

---
## EXISTING OPEN ISSUES (do NOT suggest duplicates or near-duplicates of these)

{open_issues_text}

---
## SOURCE CODE

{source_dump}

---
## TASK

Read the source code above carefully. Based on what is actually implemented (or missing),
suggest exactly 1 GitHub issue that would meaningfully improve the project.

Rules:
- Base your suggestion on concrete evidence from the source code.
- Do NOT suggest something that is already implemented.
- Do NOT duplicate any existing open issue listed above.
- Prefer actionable bugs, missing features, or real UX gaps over vague "add X support" ideas.

Return JSON only (no markdown), like this:

[
  {{
    "title": "Issue title",
    "body": "Detailed issue description referencing specific files or functions",
    "label": "enhancement"
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
    usage = response.usage

    if usage:
        input_tokens = usage.input_tokens
        output_tokens = usage.output_tokens
        total_tokens = usage.total_tokens

        print("---- AI Usage ----")
        print(f"Input tokens : {input_tokens}")
        print(f"Output tokens: {output_tokens}")
        print(f"Total tokens : {total_tokens}")

        # gpt-4.1-mini cost: $0.15 per 1M input tokens, $0.60 per 1M output tokens
        input_cost = input_tokens / 1_000_000 * 0.15
        output_cost = output_tokens / 1_000_000 * 0.60
        cost = input_cost + output_cost

        print(f"Estimated cost: ${cost:.6f}")
        print("------------------")

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
    label = issue.get("label", "enhancement").strip()

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
        body,
        "--label",
        label
    ])


print("AI issue generation complete.")
