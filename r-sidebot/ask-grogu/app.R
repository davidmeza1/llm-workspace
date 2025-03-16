# ------------------------------------------------------------------------------------
# A basic R Shiny Chat example powered by Ollama.
# To run it, you'll need an Ollama server running locally.
# To download and run the server, see https://github.com/ollama/ollama
# To install the Ollama Python client, see https://github.com/ollama/ollama-python
# ------------------------------------------------------------------------------------


library(shiny)
library(bslib)
library(ggplot2)
library(DT)
library(shinychat)
library(elmer)

ollama_model <- "mistral:instruct"

ui <- bslib::page_fluid(
  chat_ui("chat")
)

server <- function(input, output, session) {
  #chat <- elmer::chat_openai(system_prompt = "You're a trickster who answers in riddles")
  #chat <- elmer::chat_ollama(model = ollama_model, system_prompt = "You're a helpful assistant Jedi who answers as Yoda would.")
  #chat <- elmer::chat_ollama(model = ollama_model,base_url = "http://131.110.210.169:443/v1", system_prompt = "You're a trickster who answers in riddles")
  chat <- chat_groq(system_prompt = "You are a friendly assistant that responds as Yoda would",
                        api_key = "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",
                        model = "llama3-8b-8192")
  observeEvent(input$chat_user_input, {
    stream <- chat$chat(input$chat_user_input)
    chat_append("chat", stream)
  })
}

shinyApp(ui, server)
