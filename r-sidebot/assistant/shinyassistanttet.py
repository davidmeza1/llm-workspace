library(shiny)
library(bslib)
library(ggplot2)
library(DT)
library(shinychat)
library(elmer)

# Sample data
set.seed(123)
data <- data.frame(
  x = rnorm(100),
  y = rnorm(100),
  category = sample(LETTERS[1:3], 100, replace = TRUE)
)

ui <- page_sidebar(
  title = "Dashboard Example with Chat",
  sidebar = sidebar(
    title = "Controls",
    width = 400,
    textInput("title", "Dashboard Title", "My Dashboard"),
    selectInput("category", "Select Category", choices = LETTERS[1:3]),
    chat_ui("chat", height = "400px", fill = TRUE)
  ),
  layout_column_wrap(
    width = 1/3,
    value_box(
      title = "Total Observations",
      value = textOutput("total_obs"),
      showcase = bsicons::bs_icon("table")
    ),
    value_box(
      title = "Average X",
      value = textOutput("avg_x"),
      showcase = bsicons::bs_icon("bar-chart")
    ),
    value_box(
      title = "Average Y",
      value = textOutput("avg_y"),
      showcase = bsicons::bs_icon("graph-up")
    )
  ),
  layout_column_wrap(
    width = 1/2,
    card(
      full_screen = TRUE,
      card_header("Data Table"),
      DTOutput("data_table")
    ),
    card(
      full_screen = TRUE,
      card_header("Scatter Plot"),
      plotOutput("scatter_plot")
    )
  )
)

server <- function(input, output, session) {
  # Update page title
  observe({
    session$setWindowTitle(input$title)
  })
  
  # Filter data based on selected category
  filtered_data <- reactive({
    data[data$category == input$category, ]
  })
  
  # Value box outputs
  output$total_obs <- renderText({
    nrow(filtered_data())
  })
  
  output$avg_x <- renderText({
    round(mean(filtered_data()$x), 2)
  })
  
  output$avg_y <- renderText({
    round(mean(filtered_data()$y), 2)
  })
  
  # Data table output
  output$data_table <- renderDT({
    datatable(filtered_data(), options = list(pageLength = 5))
  })
  
  # Scatter plot output
  output$scatter_plot <- renderPlot({
    ggplot(filtered_data(), aes(x = x, y = y)) +
      geom_point() +
      theme_minimal() +
      labs(title = paste("Scatter Plot for Category", input$category))
  })
  
  # Chat functionality
  ollama <- Ollama$new(base_url = "http://localhost:11434")
  
  chat_server(
    "chat",
    reporter = function(prompt, chat_history) {
      response <- ollama$generate(
        model = "mistral:instruct",
        prompt = paste0(
          "You're a helpful assistant for data analysis. ",
          "The current data has these columns: x, y, and category. ",
          "The selected category is ", input$category, ". ",
          "User question: ", prompt
        )
      )
      response$response
    }
  )
}

shinyApp(ui, server)
