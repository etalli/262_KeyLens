from openai import OpenAI
client = OpenAI()

response = client.audio.speech.create(
    model="gpt-4o-mini-tts",   # TTS model
    voice="alloy",             # voice
    input="Hello, this is a test of text to speech."
)

# ファイル保存
with open("output.mp3", "wb") as f:
    f.write(response.content)
