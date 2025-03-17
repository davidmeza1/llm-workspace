library(shiny)
library(shinychat)

ui <- bslib::page_fluid(
  chat_ui("chat")
)

server <- function(input, output, session) {
  #ollama_model <- "mistral:instruct" 
  ollama_model <- "llama3.3:70b-instruct-q4_K_M"
  #chat <- ellmer::chat_ollama(system_prompt = "You're a trickster who answers in riddles", base_url = "http://localhost:11434", model = ollama_model )
  chat <- ellmer::chat_ollama(system_prompt = "You are a data scientist using R and the tidyverse", base_url = "http://131.110.210.167:443", model = ollama_model )
  observeEvent(input$chat_user_input, {
    stream <- chat$stream_async(input$chat_user_input)
    chat_append("chat", stream)
  })
}

shinyApp(ui, server)