library(shiny)
library(ggplot2)
library(bslib)
library(dplyr)
library(shinychat)
library(ellmer)
library(promises)
library(future)
library(shinyjs)
library(DBI)
library(duckdb)
plan(multisession)

#ollama_model <- "llama3.2:3b-instruct-q8_0"
ollama_model <- "llama3.3:70b-instruct-q4_K_M"

# Create a DuckDB database and load mtcars data
setup_duckdb <- function() {
  # Create a temporary database file
  db_file <- tempfile(fileext = ".duckdb")

  # Connect to the database
  con <- dbConnect(duckdb::duckdb(), dbdir = db_file)

  # Write mtcars to DuckDB
  dbWriteTable(con, "mtcars", mtcars)

  # Add rownames as a column
  dbExecute(con, "ALTER TABLE mtcars ADD COLUMN car_name VARCHAR")

  # Convert R rownames to a column
  car_names <- data.frame(
    row_id = 1:nrow(mtcars),
    car_name = rownames(mtcars)
  )
  dbWriteTable(con, "car_names", car_names)

  # Update mtcars table with car names
  dbExecute(con, "UPDATE mtcars SET car_name = car_names.car_name FROM car_names WHERE mtcars.row_id = car_names.row_id")

  # Return connection and file path
  return(list(con = con, file_path = db_file))
}

# Initialize DuckDB and keep connection
duckdb_data <- setup_duckdb()
con <- duckdb_data$con

# Define the UI
ui <- page_fluid(
  title = "GGPlot Chatbot with DuckDB",
  theme = bs_theme(bootswatch = "minty"),
  useShinyjs(),  # Initialize shinyjs

  # Header
  card(
    card_header(
      h2("ggplot Chatbot for mtcars Dataset (DuckDB)"),
      "Ask the chatbot to create a visualization using the mtcars dataset from DuckDB"
    )
  ),

  # Main layout with sidebar
  layout_sidebar(
    sidebar = sidebar(
      width = 350,
      h4("Data Preview (from DuckDB)"),
      p("Here's a preview of the mtcars dataset stored in DuckDB:"),
      tableOutput("data_preview"),
      hr(),
      h5("Variables in the dataset:"),
      htmlOutput("variables"),
      hr(),
      p("Examples of what you can ask:"),
      tags$ul(
        tags$li("Create a scatter plot of mpg vs hp"),
        tags$li("Plot a boxplot of cyl"),
        tags$li("Make a histogram of mpg colored by am")
      )
    ),

    # Main Panel with chat and visualization
    card(
      full_screen = TRUE,
      card_body(
        # Using chat_ui for chat interface
        chat_ui("chat", placeholder = "Ask me to create a plot using the mtcars data..."),
        # Add a hidden loading indicator
        div(id = "loading-indicator", "Loading...", style = "display: none;"),
        hr(),
        h4("Generated Visualization"),
        plotOutput("plot", height = "500px")
      )
    )
  )
)

# Define the server
server <- function(input, output, session) {
  # Create a reactive to store the mtcars data from DuckDB
  mtcars_data <- reactive({
    # Query data from DuckDB
    dbGetQuery(con, "SELECT * FROM mtcars")
  })

  # Prepare comprehensive dataset information to include in the prompt
  dataset_summary <- reactive({
    # Get mtcars data from DuckDB
    df <- mtcars_data()

    # Generate summary statistics
    sum_stats <- capture.output({
      cat("mtcars dataset summary (from DuckDB):\n")
      print(summary(df))
      cat("\nVariable correlations:\n")
      cor_matrix <- cor(df[, sapply(df, is.numeric)])
      print(round(cor_matrix, 2))
    })

    return(paste(sum_stats, collapse = "\n"))
  })

  # System prompt with dataset info
  system_prompt <- reactive({
    paste0(
      "You are a specialized data visualization assistant that creates ggplot2 visualizations for the mtcars dataset. ",
      "When users ask for plots, ONLY RESPOND with valid R ggplot2 code that can be executed. ",
      "Do not include any library to install, ",
      "No explanations or additional text - JUST THE CODE. No markdown code blocks.",
      "Make sure your response is a complete and valid ggplot2 code snippet with no empty variable names.",
      "\n\nHere is detailed information about the mtcars dataset that you should use to create better visualizations:\n",
      dataset_summary(),
      "\n\nThe available variables in mtcars are: mpg, cyl, disp, hp, drat, wt, qsec, vs, am, gear, carb, and car_name. ",
      "Always wrap categorical variables like cyl, vs, am, gear, and carb with as.factor() when appropriate. ",
      "Always include appropriate labels, titles, and use a theme_minimal() or theme_bw() for clean visualizations. ",
      "Incorporate appropriate color palettes when needed for better visualization. ",
      "The code should be valid R code that produces a ggplot2 visualization.",
      "\n\nThe data is stored in a variable called 'df', so make sure to use df instead of mtcars in your ggplot code.",
      "\n\nFor best results with this dataset:",
      "\n- For variables like cyl, vs, am, gear: Always treat as factors with as.factor()",
      "\n- For scatter plots: Consider adding smoothing lines with geom_smooth() when appropriate",
      "\n- For categorical comparisons: Use boxplots, violin plots, or bar charts",
      "\n- For distributions: Use histograms or density plots",
      "\n- Use color and facets strategically to show relationships between multiple variables",
      "\n- You can use the car_name column to label points in scatter plots",
      "\n\nIMPORTANT: Never use empty variable names in your code. Always make sure all variable references are valid."
    )
  })

  # Create chat instance with Ollama
  chat <- reactive({
    chat_ollama(
      model = ollama_model,
      system_prompt = system_prompt(),
      base_url = "http://131.110.210.167:443"
    )
  })

  # Show data preview from DuckDB
  output$data_preview <- renderTable({
    head(mtcars_data(), 5)
  })

  # Display available variables
  output$variables <- renderUI({
    df <- mtcars_data()
    vars <- names(df)
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
      "carb: Number of carburetors",
      "car_name: Name of the car"
    )
    HTML(paste(description, collapse = "<br>"))
  })

  # Initialize the plot with a default visualization
  plot_data <- reactiveVal(NULL)

  # Set the initial default plot once we have data
  observe({
    df <- mtcars_data()
    if (is.null(plot_data())) {
      default_plot <- ggplot(df, aes(x = mpg, y = hp)) +
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

      plot_data(default_plot)
    }
  })

  # Render the plot
  output$plot <- renderPlot({
    req(plot_data())
    plot_data()
  })

  # Helper function to clean and process code from LLM
  clean_llm_code <- function(code) {
    # Remove any markdown code block markers
    code <- gsub("^```r?\\s*|```$", "", code)

    # Remove any leading/trailing whitespace
    code <- trimws(code)

    # Replace mtcars with df if necessary
    code <- gsub("\\bmtcars\\b", "df", code)

    # Add data reference if needed
    if (!grepl("\\bdf\\b", code)) {
      # If the code doesn't reference df, assume it needs to be added
      code <- paste0("ggplot(df, ", sub("^ggplot\\s*\\(", "", code))
    }

    return(code)
  }

  # Manual implementation to replace chat_server
  # Handle user input from chat_ui
  observeEvent(input$chat_user_input, {
    req(input$chat_user_input)

    # Get user message
    user_message <- input$chat_user_input

    # Add to chat history - the user message
    chat_append("chat", user_message, role = "user")

    # Set loading state
    shinyjs::showElement(id = "loading-indicator")

    # Process asynchronously to not block the UI
    future_promise({
      # Get response from the LLM
      chat$chat(user_message, echo = FALSE)
    }) %...>%
      (function(response) {
        # Add the AI response to the chat history
        chat_append("chat", response, role = "assistant")

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
}

# Run the application
shinyApp(ui = ui, server = server)
