# ----------------------------r-sidebot--------------------------------------------------------
# This is a demonstration of using an LLM to enhance a data dashboard written in R Shiny.
# https://github.com/jcheng5/r-sidebot/tree/main
# To run it, you'll need an Ollama server running locally.
# To download and run the server, see https://github.com/ollama/ollama
# To install the Ollama Python client, see https://github.com/ollama/ollama-python
# -


library(shiny)
library(bslib)
library(fastmap)
library(duckdb)
library(DBI)
library(fontawesome)
library(reactable)
library(here)
library(plotly)
library(ggplot2)
library(ggridges)
library(dplyr)
library(ellmer)
library(shinychat)
library(gt)
library(gtsummary)

# Open the duckdb database
#conn <- dbConnect(duckdb(), dbdir = here("tips.duckdb"), read_only = TRUE)
conn <- dbConnect(duckdb(), dbdir = here("drp.duckdb"), read_only = TRUE)
# Close the database when the app stops
onStop(\() dbDisconnect(conn))

# gpt-4o does much better than gpt-4o-mini, especially at interpreting plots
#openai_model <- "gpt-4o"

################################ https://ollama.com/blog/tool-support
#ollama_model <- "llama3.2:3b-instruct-q8_0" # partially works, need to look at tools
#ollama_model <- "mistral:instruct" # provides answers but does not update dashboard, look at tools
#ollama_model <- "llama3-groq-tool-use"
ollama_model <- "llama3.3:70b-instruct-q4_K_M"
#ollama_model <- "gemma3:4b" # local Model
#ollama_model <- "gemma3:27b" # used when connected to Ollama server
#ollama_model <- "mistral:7b-instruct-q4_0" # does not support tools

#ollama_model <- "mistral-nemo" # seems to work but not completing the tasks

#ollama_model <- "codegemma:instruct" #codegemma:instruct does not support tools
#ollama_model <- "codellama:7b-instruct" #codellama:7b-instruct does not support tools
#ollama_model <- "dolphin-mistral" # dolphin-mistral does not support tools
#ollama_model <- "deepseek-coder-v2" #deepseek-coder-v2 does not support tools

################################


# Dynamically create the system prompt, based on the real data. For an actually
# large database, you wouldn't want to retrieve all the data like this, but
# instead either hand-write the schema or write your own routine that is more
# efficient than system_prompt().
#system_prompt_str <- system_prompt(dbGetQuery(conn, "SELECT * FROM tips"), "tips")
system_prompt_str <- system_prompt(dbGetQuery(conn, "SELECT * FROM drp"), "drp")
# This is the greeting that should initially appear in the sidebar when the app
# loads.
greeting <- paste(readLines(here("greeting.md")), collapse = "\n")

icon_explain <- tags$img(src = "stars.svg")

ui <- page_sidebar(
  style = "background-color: rgb(248, 248, 248);",
  title = "Restaurant tipping",
  includeCSS(here("styles.css")),
  sidebar = sidebar(
    width = 500,
    style = "height: 100%;",
    chat_ui("chat", height = "100%", fill = TRUE)
  ),
  useBusyIndicators(),

  # 🏷️ Header
  textOutput("show_title", container = h3),
  verbatimTextOutput("show_query") |>
    tagAppendAttributes(style = "max-height: 100px; overflow: auto;"),

  # 🎯 Value boxes
  layout_columns(
    fill = FALSE,
    value_box(
      showcase = fa_i("user"),
      "Total DRP",
      textOutput("total_drpers", inline = TRUE)
    ),
    value_box(
      showcase = fa_i("wallet"),
      "Average Years Experience",
      textOutput("average_exp_years", inline = TRUE)
    ),
    value_box(
      showcase = fa_i("dollar-sign"),
      "Retirement Eligible",
      textOutput("average_retirement", inline = TRUE)
    ),
  ),

  layout_columns(
    style = "min-height: 450px;",
    col_widths = c(6, 6, 12),

    # 🔍 Data table
    card(
      style = "height: 500px;",
      card_header("DRP data"),
      reactableOutput("table", height = "100%")
    ),

    # 📊 Scatter plot
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center",
        "Grade by Employee Age",
        span(
          actionLink(
            "interpret_scatter",
            icon_explain,
            class = "me-3 text-decoration-none",
            aria_label = "Explain scatter plot"
          ),
          popover(
            title = "Add a color variable", placement = "top",
            fa_i("ellipsis"),
            radioButtons(
              "scatter_color",
              NULL,
              c("none", "center", "mseo_code", "oic_org", "retirement_status"),
              inline = TRUE
            )
          )
        )
      ),
      plotlyOutput("scatterplot")
    ),

    # 📊 Ridge plot
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center",
        "DRP Count by Center and MSEO",
        span(
          actionLink(
            "interpret_ridge",
            icon_explain,
            class = "me-3 text-decoration-none",
            aria_label = "Explain ridgeplot"
          ),
          popover(
            title = "Split ridgeplot", placement = "top",
            fa_i("ellipsis"),
            radioButtons(
              "tip_perc_y",
              "Split by",
              c("sex", "smoker", "day", "time"),
              "day",
              inline = TRUE
            )
          )
        )
      ),
      #plotOutput("tip_perc")
      gt_output("drp_count")
    ),
  )
)

server <- function(input, output, session) {
  # 🔄 Reactive state/computation --------------------------------------------

  current_title <- reactiveVal(NULL)
  current_query <- reactiveVal("")

  # This object must always be passed as the `.ctx` argument to query(), so that
  # tool functions can access the context they need to do their jobs; in this
  # case, the database connection that query() needs.
  ctx <- list(conn = conn)

  # The reactive data frame. Either returns the entire dataset, or filtered by
  # whatever Sidebot decided.
  drp_data <- reactive({
    sql <- current_query()
    if (is.null(sql) || sql == "") {
      #sql <- "SELECT * FROM tips;"
      sql <- "SELECT * FROM drp;"
    }
    dbGetQuery(conn, sql)
  })



  # 🏷️ Header outputs --------------------------------------------------------

  output$show_title <- renderText({
    current_title()
  })

  output$show_query <- renderText({
    current_query()
  })



  # 🎯 Value box outputs -----------------------------------------------------

  output$total_drpers <- renderText({
    nrow(drp_data())
  })

  output$average_exp_years <- renderText({
    z <- mean(drp_data()$years_of_service_federal, na.rm = TRUE)
    #paste0(formatC(x, format = "f", digits = 1, big.mark = ","), "%")
  })

  output$average_retirement <- renderText({
    #x <- mean(drp_data()$total_bill)
    #paste0("$", formatC(x, format = "f", digits = 2, big.mark = ","))
    y <- drp_data() |> count(retirement_status, sort = TRUE)
    numerator <- y |> filter(retirement_status != "Not Eligible")  |> count(sum(n)) |> select(`sum(n)`)
    denominator <- y |> count(sum(n)) |> select(`sum(n)`)
    x <- (numerator / denominator) * 100
    paste0(formatC(x$`sum(n)`, format = "f", digits = 1, big.mark = ","), "%")
  })



  # 🔍 Data table ------------------------------------------------------------

  output$table <- renderReactable({
    reactable(drp_data(),
              pagination = FALSE, bordered = TRUE
    )
  })



  # 📊 Scatter plot ----------------------------------------------------------

  scatterplot <- reactive({
    req(nrow(drp_data()) > 0)

    color <- input$scatter_color

    data <- drp_data()

    p <- plot_ly(data, x = ~grade, y = ~employee_age_in_yrs, type = "scatter", mode = "markers")

    if (color != "none") {
      p <- plot_ly(data,
                   x = ~grade, y = ~employee_age_in_yrs, color = as.formula(paste0("~", color)),
                   type = "scatter", mode = "markers"
      )
    }

    p <- p |> add_lines(
      x = ~grade, y = fitted(loess(employee_age_in_yrs ~ grade, data = data)),
      line = list(color = "rgba(255, 0, 0, 0.5)"),
      name = "LOESS", inherit = FALSE
    )

    p <- p |> layout(showlegend = FALSE)

    return(p)
  })

  output$scatterplot <- renderPlotly({
    scatterplot()
  })

  observeEvent(input$interpret_scatter, {
    explain_plot(chat, scatterplot(), model = ollama_model, .ctx = ctx)
  })



  # 📊 Ridge plot ------------------------------------------------------------

  #tip_perc <- reactive({
  #  req(nrow(drp_data()) > 0)

  #  df <- drp_data() |> mutate(percent = tip / total_bill)

  #  ggplot(df, aes_string(x = "percent", y = input$tip_perc_y, fill = input$tip_perc_y)) +
  #    geom_density_ridges(scale = 3, rel_min_height = 0.01, alpha = 0.6) +
  #    scale_fill_viridis_d() +
  #    theme_ridges() +
  #    labs(x = "Percent", y = NULL, title = "Tip Percentages by Day") +
  #    theme(legend.position = "none")
  #})

  #output$tip_perc <- renderPlot({
  #  tip_perc()
  #})

  #observeEvent(input$interpret_ridge, {
  #  explain_plot(chat, tip_perc(), model = openai_model, .ctx = ctx)
  #})

  drp_count <- reactive({
    req(nrow(drp_data()) > 0)

    drp_data() |>
      tbl_cross(
        row = center,
        col = mseo_code,
        percent = "cell"
      ) |>
      as_gt()
  })

  output$drp_count <- render_gt({
    drp_count()
  })

  observeEvent(input$interpret_ridge, {
    explain_plot(chat, drp_count(), model = ollama_model, .ctx = ctx)
  })


  # ✨ Sidebot ✨ -------------------------------------------------------------

  update_dashboard <- function(query, title) {
    if (!is.null(query)) {
      current_query(query)
    }
    if (!is.null(title)) {
      current_title(title)
    }
  }

  query <- function(query) {
    df <- dbGetQuery(conn, query)
    df |> jsonlite::toJSON(auto_unbox = TRUE)
  }

  # Preload the conversation with the system prompt. These are instructions for
  # the chat model, and must not be shown to the end user.

  #chat <- chat_openai(model = openai_model, system_prompt = system_prompt_str)

  ##########################################
  #chat <- chat_ollama(model= ollama_model, system_prompt = system_prompt_str)
  chat <- chat_ollama(model= ollama_model, system_prompt = system_prompt_str, base_url = "http://131.110.210.167:443")
  ##########################################

  #############################################
  # chat <- chat_groq(system_prompt = "system_prompt_str",
  #                      api_key = "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",
  #                     model = "llama3-groq-8b-8192-tool-use-preview")
  ##############################################
  chat$register_tool(tool(
    update_dashboard,
    #name = "update_dashboard",
    #description =
    "Modifies the data presented in the data dashboard, based on the given SQL query, and also updates the title.",
    query = type_string("A DuckDB SQL query; must be a SELECT statement.", required = TRUE),
    title = type_string("A title to display at the top of the data dashboard, summarizing the intent of the SQL query.", required = TRUE)
    #arguments = list(
    #  query = ToolArg(
    #    type = "string",
    #    description = "A DuckDB SQL query; must be a SELECT statement.",
    #    required = TRUE
    #  ),
    #  title = ToolArg(
    #    type = "string",
    #    description = "A title to display at the top of the data dashboard, summarizing the intent of the SQL query.",
    #   required = TRUE
    #  )
  )
  )
  chat$register_tool(tool(
    query,
    #name = "query",
    #description =
    "Perform a SQL query on the data, and return the results as JSON.",
    query = type_string("A DuckDB SQL query; must be a SELECT statement.", required = TRUE)
    #arguments = list(
    #  query = ToolArg(
    #    type = "string",
    #    description = "A DuckDB SQL query; must be a SELECT statement.",
    #    required = TRUE
  )
  )

  # Prepopulate the chat UI with a welcome message that appears to be from the
  # chat model (but is actually hard-coded). This is just for the user, not for
  # the chat model to see.
  chat_append("chat", greeting)

  # Handle user input
  observeEvent(input$chat_user_input, {
    # Add user message to the chat history
    #############################################
    #chat_append("chat", chat$stream_async(input$chat_user_input))
    chat_append("chat", chat$chat(input$chat_user_input))
    #############################################
  })
}

shinyApp(ui, server)
