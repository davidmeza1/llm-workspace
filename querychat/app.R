library(shiny)
library(bslib)
library(querychat)

# 1. Configure querychat. This is where you specify the dataset and can also
#    override options like the greeting message, system prompt, model, etc.
#querychat_config <- querychat_init(mtcars)
ollama_model <- "llama3.3:70b-instruct-q4_K_M"
ollama_model2 <- "llama3.2:3b-instruct-q8_0"

webtads <- as_data_frame(webtads_df)
querychat_config <- querychat_init(webtads,
                                   #mtcars,
                                   greeting = readLines("greeting.md"),
                                   data_description = readLines("webtads_data_description.md"),
                                   #data_description = readLines("data_description.md"),
                                   create_chat_func = purrr::partial(ellmer::chat_ollama, model = ollama_model,  base_url = "http://131.110.210.167:443")
                                   #create_chat_func = purrr::partial(ellmer::chat_ollama, model = ollama_model2)
)
ui <- page_sidebar(
  # 2. Use querychat_sidebar(id) in a bslib::page_sidebar.
  #    Alternatively, use querychat_ui(id) elsewhere if you don't want your
  #    chat interface to live in a sidebar.
  sidebar = querychat_sidebar("chat", width = 500),
  DT::DTOutput("dt")
)

server <- function(input, output, session) {

  # 3. Create a querychat object using the config from step 1.
  querychat <- querychat_server("chat", querychat_config)

  output$dt <- DT::renderDT({
    # 4. Use the filtered/sorted data frame anywhere you wish, via the
    #    querychat$df() reactive.
    DT::datatable(querychat$df())
  })
}

shinyApp(ui, server)
