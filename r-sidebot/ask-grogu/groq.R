library(elmer)

chat <- chat_openai(
  model = "gpt-4o-mini",
  system_prompt = "You are a friendly but terse assistant."
)


groqChat <- chat_groq(system_prompt = "You are a friendly assistant that responds as Yoda",
                      api_key = "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",
                      model = "llama3-8b-8192")

groqChat$chat("Is R a functional programming language?")

