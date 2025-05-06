library(shiny)
library(ggplot2)
library(bslib)
library(dplyr)
library(tidyverse)
library(shinychat)
library(ellmer)
library(promises)
library(future)
library(shinyjs)  # Added for showElement
library(fontawesome)
library(reactable) # for table
library(here)
library(gt)
library(gtsummary)
plan(multisession)

# Use smaller model when running local ollama
#ollama_model <- "llama3.2:3b-instruct-q8_0"
ollama_model <- "llama3.3:70b-instruct-q4_K_M"
# Load system prompt. You can create a more robust sys prompt.
# In the R folder there is a sample prompt-helper.R file with helpful functions
sys_prompt <- paste0("You are a friendly chat that answers like Yoda. ",
                     "Finish allrepsonses with, How else may I help, young Padawan! ",
                     "If they say Good bye, or any similar version, respond with, May the Force be With you. Include some final Jedi wisdom. ")
system_prompt_str <- sys_prompt
# This is the greeting that should initially appear in the sidebar when the app
# loads.
greeting <- paste(readLines(here("greeting.md")), collapse = "\n")

# Define the UI
ui <- page_sidebar(
  style = "background-color: rgb(248, 248, 248);",
  title = "Chat Bot for Data Template",
  includeCSS(here("styles.css")), # Modify file to suit your needs
  sidebar = sidebar(
    width = 500,
    style = "height: 100%;",
    chat_ui("chat", height = "100%", fill = TRUE)
  ),
  useBusyIndicators(),

  # Header
  #textOutput("show_title", container = h3),
  #verbatimTextOutput("show_query") |>
  #  tagAppendAttributes(style = "max-height: 100px; overflow: auto;"),

  # Value Boxes
  # icons are from Font Awesome free list
  layout_columns(
    fill = FALSE,
    value_box(
      showcase = fa_i("wolf-pack-battalion"),
      "Metric 1",
      value = 1

    ),
    value_box(
      showcase = fa_i("shuttle-space"),
      "Metric 2",
      value = 2

    ),
    value_box(
      showcase = fa_i("user-astronaut"),
      "Metric 3",
      value = 3

    ),
  ), # end of Value boxes layout_columns

  # Cards
  layout_columns(
    style = "min-height: 450px;",
    col_widths = c(12, 12, 12),

    # Data Preview Table
    card(
      card_header("Analysis Overview"),
      card_body(
        p("This is the body."),
        p("This is still the body.")
      ),
      card_footer(
        "This is the footer"
      )

    ),

    card(
      card_header("Data Preview")

    ),

    # Visualization
    card(
      card_header("Visualization")
    ),
  ) # end of Cards layout_columns
) # End of page_sidebar

server <- function(input, output, session) {
  # 🔄 Reactive state/computation --------------------------------------------



  # 🏷️ Header outputs --------------------------------------------------------



  # 🎯 Value box outputs -----------------------------------------------------




  # 🔍 Analysis Overview Card -------------------------------------------------




  # 🔍 Data Preview Card ------------------------------------------------------




  # 🔍 Visualiztion Card ------------------------------------------------------




  # ✨ Sidebot ✨ -------------------------------------------------------------

  # Create Chat stream
  # Uncomment to connect to local Ollama, make sure you selected the right model
  #chat <- chat_ollama(model= ollama_model, system_prompt = system_prompt_str)
  chat <- chat_ollama(model= ollama_model, system_prompt = system_prompt_str, base_url = "http://131.110.210.167:443")

  # Uncomment to use Tools
  # # Create a tool for the llm to use, see ellmer documentation
  #   update_dashboard <- tool(
  #     update_dashboard,
  #     "Modifies the data presented in the data dashboard, based on the given SQL query, and also updates the title.",
  #     query = type_string("A DuckDB SQL query; must be a SELECT statement.", required = TRUE),
  #     title = type_string("A title to display at the top of the data dashboard, summarizing the intent of the SQL query.", required = TRUE)
  #   )
  #
  #   query <- tool(
  #     query,
  #     "Perform a SQL query on the data, and return the results as JSON.",
  #     query = type_string("A DuckDB SQL query; must be a SELECT statement.", required = TRUE)
  #   )
  #
  #   # Register the tool
  #   chat$register_tool(update_dashboard)
  #   chat$register_tool(query)
  ##################################################################

  # Prepopulate the chat UI with a welcome message that appears to be from the
  # chat model (but is actually hard-coded). This is just for the user, not for
  # the chat model to see.
  chat_append("chat", greeting)

  # Handle user input
  observeEvent(input$chat_user_input, {
    # Add user message to the chat history
    #############################################
    chat_append("chat", chat$stream_async(input$chat_user_input))
    # use if async not working with model
    #chat_append("chat", chat$chat(input$chat_user_input))
    #############################################
  })

} # end of server code

shinyApp(ui, server)
