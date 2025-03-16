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
      value = nrow(data),
      showcase = bsicons::bs_icon("table")
      # TODO add textOutput, remove value
    ),
    value_box(
      title = "Average X",
      value = round(mean(data$x), 2),
      showcase = bsicons::bs_icon("bar-chart")
      # TODO add textOutput, remove value
    ),
    value_box(
      title = "Average Y",
      value = round(mean(data$y), 2),
      showcase = bsicons::bs_icon("graph-up")
      # TODO add textOutput, remove value
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
  #filtered_data <- reactive({
  #  data[data$category == input$category, ]
  #})
  
  # Data table output
  #output$data_table <- renderDT({
  #  datatable(filtered_data(), options = list(pageLength = 5))
  #})
  
  # Scatter plot output
  #output$scatter_plot <- renderPlot({
  #  ggplot(filtered_data(), aes(x = x, y = y)) +
  #    geom_point() +
  #    theme_minimal() +
  #    labs(title = paste("Scatter Plot for Category", input$category))
  #})
  
  # Chat functionality
  chat <- elmer::chat_ollama(model = "mistral:instruct", system_prompt = "You're a helpful assistant for data analysis.")
  
  observeEvent(input$chat_user_input, {
    #stream <- chat$chat(input$chat_user_input)
    chat_append("chat", chat$chat(input$chat_user_input))
  })
}

shinyApp(ui, server)
