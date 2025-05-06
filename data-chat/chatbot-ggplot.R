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
# Prepare comprehensive dataset information to include in the prompt
dataset_summary <- capture.output({
  cat("mtcars dataset summary:\n")
  print(summary(mtcars))
  cat("\nVariable correlations:\n")
  print(round(cor(mtcars), 2))
})
# Load system prompt. You can create a more robust sys prompt.
# In the R folder there is a sample prompt-helper.R file with helpful functions
sys_prompt <- paste0("You are a specialized data visualization assistant that creates ggplot2 visualizations for the mtcars dataset. ",
                     "When users ask for plots, ONLY RESPOND with valid R ggplot2 code that can be executed. ",
                     "Do not include any library to install, ",
                     "No explanations or additional text - JUST THE CODE. No markdown code blocks.",
                     "Make sure your response is a complete and valid ggplot2 code snippet with no empty variable names.",
                     "\n\nHere is detailed information about the mtcars dataset that you should use to create better visualizations:\n",
                     paste(dataset_summary, collapse = "\n"),
                     "\n\nThe available variables in mtcars are: mpg, cyl, disp, hp, drat, wt, qsec, vs, am, gear, and carb. ",
                     "Always wrap categorical variables like cyl, vs, am, gear, and carb with as.factor() when appropriate. ",
                     "Always include appropriate labels, titles, and use a theme_minimal() or theme_bw() for clean visualizations. ",
                     "Incorporate appropriate color palettes when needed for better visualization. ",
                     "The code should be valid R code that produces a ggplot2 visualization.",
                     "\n\nFor best results with this dataset:",
                     "\n- For variables like cyl, vs, am, gear: Always treat as factors with as.factor()",
                     "\n- For scatter plots: Consider adding smoothing lines with geom_smooth() when appropriate",
                     "\n- For categorical comparisons: Use boxplots, violin plots, or bar charts",
                     "\n- For distributions: Use histograms or density plots",
                     "\n- Use color and facets strategically to show relationships between multiple variables",
                     "\n\nIMPORTANT: Never use empty variable names in your code. Always make sure all variable references are valid.")

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
        p("Variables in the dataset:"),
        htmlOutput("variables")
      ),
      card_footer(
        "This is the footer"
      )

    ),

    card(
      card_header("Data Preview"),
      tableOutput("data_preview")
    ),

    # Visualization
    card(
      card_header("Visualization"),
      plotOutput("plot", height = "500px")
    ),
  ) # end of Cards layout_columns
) # End of page_sidebar

server <- function(input, output, session) {


  # 🔄 Reactive state/computation --------------------------------------------



  # 🏷️ Header outputs --------------------------------------------------------



  # 🎯 Value box outputs -----------------------------------------------------




  # 🔍 Analysis Overview Card -------------------------------------------------

  output$variables <- renderUI({
    vars <- names(mtcars)
    description <- c(
      "mpg: Miles per gallon",
      "cyl: Number of cylinders",
      "disp: Displacement (cu.in.)",
      "hp: Gross horsepower",
      "drat: Rear axle ratio",
      "wt: Weight (1000 lbs)",
      "qsec: 1/4 mile time",
      "vs: Engine (0 = V-shaped, 1 = straight)",
      "am: Transmission (0 = automatic, 1 = manual)",
      "gear: Number of forward gears",
      "carb: Number of carburetors"
    )
    HTML(paste(description, collapse = "<br>"))
  })


  # 🔍 Data Preview Card ------------------------------------------------------
  output$data_preview <- renderTable({
    head(mtcars, 5)
  })

  # 🔍 Visualization Card ------------------------------------------------------
  # Initialize the plot with a default visualization
  plot_data <- reactiveVal(
    ggplot(mtcars, aes(x = mpg, y = hp)) +
      geom_point(aes(color = as.factor(cyl), size = wt)) +
      geom_smooth(method = "lm", se = TRUE, alpha = 0.3) +
      labs(title = "Default Plot: MPG vs Horsepower",
           subtitle = "Ask me to create a different plot!",
           x = "Miles per Gallon",
           y = "Horsepower",
           color = "Cylinders",
           size = "Weight") +
      theme_minimal() +
      theme(legend.position = "right")
  )
  output$plot <- renderPlot({
    plot_data()
  })

  # Helper code
  # Helper function to clean and process code from LLM
  clean_llm_code <- function(code) {
    # Remove any markdown code block markers
    code <- gsub("^```r?\\s*|```$", "", code)

    # Remove any leading/trailing whitespace
    code <- trimws(code)

    # Add data reference if needed
    if (!grepl("mtcars", code)) {
      # If the code doesn't reference mtcars, assume it needs to be added
      code <- paste0("ggplot(mtcars, ", sub("^ggplot\\s*\\(", "", code))
    }

    return(code)
  }

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
    req(input$chat_user_input)
    # Get user message
    user_message <- input$chat_user_input
    # Add user message to the chat history
    #############################################
    chat_append("chat", chat$stream_async(input$chat_user_input))
    # use if async not working with model
    #chat_append("chat", chat$chat(input$chat_user_input))
    #############################################

    # Process asynchronously to not block the UI
    future_promise({
      # Get response from the LLM
      chat$chat(user_message, echo = FALSE)
    }) %...>%
      (function(response) {
        # Add the AI response to the chat history
        #chat_append("chat", response, role = "assistant", )

        # Hide loading indicator
        shinyjs::hideElement(id = "loading-indicator")

        # Process the response to generate plot
        tryCatch({
          # Clean and process the code
          cleaned_code <- clean_llm_code(response)

          # Print code to console for debugging
          message("Evaluating code: ", substr(cleaned_code, 1, 100), "...")

          # Parse and evaluate the code to generate a plot
          expr <- tryCatch(
            parse(text = cleaned_code),
            error = function(e) {
              message("Parse error: ", e$message)
              NULL
            }
          )

          # Check if parsed successfully
          if (!is.null(expr) && length(expr) > 0) {
            # Create a new environment with mtcars data accessible
            plot_env <- new.env(parent = globalenv())
            plot_env$mtcars <- mtcars

            # Evaluate in the controlled environment
            new_plot <- tryCatch(
              eval(expr, envir = plot_env),
              error = function(e) {
                message("Eval error: ", e$message)
                if (grepl("zero-length variable name", e$message)) {
                  return("empty_var_error")
                }
                return(NULL)
              }
            )
            # Handle specific errors
            if (identical(new_plot, "empty_var_error")) {
              plot_data(
                ggplot() +
                  annotate("text", x = 0, y = 0,
                           label = "Error: The code contains an empty variable name.\nPlease try rephrasing your request.") +
                  theme_void()
              )
            }
            # Update the plot if it's a valid ggplot object
            else if (inherits(new_plot, "gg")) {
              plot_data(new_plot)
            } else {
              # If result is not a ggplot, show an error message
              plot_data(
                ggplot() +
                  annotate("text", x = 0, y = 0,
                           label = "Error: Generated code did not produce a valid ggplot object") +
                  theme_void()
              )
            }
          } else {
            # No valid expressions in the response
            plot_data(
              ggplot() +
                annotate("text", x = 0, y = 0,
                         label = "Error: Could not parse the generated code") +
                theme_void()
            )
          }
        }, error = function(e) {
          # If there's an error in the code, show an error message
          plot_data(
            ggplot() +
              annotate("text", x = 0, y = 0,
                       label = paste("Error executing code:", e$message)) +
              theme_void()
          )
          # Log the error
          message("Error in plot code: ", e$message)
        })
      }) %...!%
      (function(error) {
        # Handle API/network errors
        shinyjs::hideElement(id = "loading-indicator")
        chat_append("chat", paste("Error:", error$message), role = "assistant")
        message("API Error:", error$message)
      })
  })
} # end of server code

shinyApp(ui, server)
