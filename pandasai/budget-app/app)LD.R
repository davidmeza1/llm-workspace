library(shiny)
library(bslib)
library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

# Function to generate sample data for overall budget
generate_sample_data <- function() {
  months <- c("October", "November", "December", "January", "February", 
              "March", "April", "May", "June", "July", "August", "September")
  
  planned <- c(10000, 12000, 15000, 11000, 9000, 
               8500, 9500, 11000, 13000, 14000, 12500, 11500)
  
  set.seed(123)
  actual <- planned + rnorm(12, mean = 0, sd = 500)
  
  data.frame(
    Month = months,
    Planned = planned,
    Actual = actual
  )
}

# Function to generate sample data for detailed items
generate_detailed_sample_data <- function() {
  months <- c("October", "November", "December", "January", "February", 
              "March", "April", "May", "June", "July", "August", "September")
  
  # Create sample budget items
  items <- c("Salaries", "Office Supplies", "Marketing", "IT Equipment", 
             "Utilities", "Rent", "Training", "Travel", "Software Licenses", "Insurance")
  
  # Create a data frame with all combinations of months and items
  detailed_data <- expand.grid(Month = months, Item = items)
  
  # Add planned and actual values with some patterns
  set.seed(123)
  detailed_data$Planned <- case_when(
    detailed_data$Item == "Salaries" ~ 5000 + rnorm(nrow(detailed_data), 0, 100),
    detailed_data$Item == "Rent" ~ 2000 + rnorm(nrow(detailed_data), 0, 50),
    detailed_data$Item == "Marketing" ~ ifelse(detailed_data$Month %in% c("November", "December"), 
                                             2000, 1000) + rnorm(nrow(detailed_data), 0, 100),
    TRUE ~ runif(nrow(detailed_data), 500, 1500)
  )
  
  detailed_data$Actual <- detailed_data$Planned + rnorm(nrow(detailed_data), 0, detailed_data$Planned * 0.1)
  
  return(detailed_data)
}

# Define UI
ui <- page_fluid(
  navset_card_tab(
    full_screen = TRUE,
    nav_panel(
      title = "Overall Budget",
      layout_columns(
        col_widths = c(3),
        fileInput("file", "Upload Budget Excel File",
                accept = c(".xlsx", ".xls"),
                buttonLabel = "Browse...",
                placeholder = "No file selected")
      ),
      layout_columns(
        value_box(
          title = "Total Planned Budget",
          value = textOutput("total_planned"),
          theme = "primary"
        ),
        value_box(
          title = "Total Actual Spent",
          value = textOutput("total_actual"),
          theme = "secondary"
        ),
        value_box(
          title = "Variance",
          value = textOutput("variance"),
          theme = value_box_theme(bg = "rgb(225, 190, 106)")
        ),
        value_box(
          title = "% of Budget Used",
          value = textOutput("budget_used"),
          theme = value_box_theme(bg = "rgb(126, 181, 131)")
        )
      ),
      card(
        card_header("Budget Comparison"),
        plotOutput("budget_plot", height = "400px")
      )
    ),
    nav_panel(
      title = "Detailed Items",
      layout_columns(
        col_widths = c(3),
        fileInput("detailed_file", "Upload Detailed Budget Excel File",
                accept = c(".xlsx", ".xls"),
                buttonLabel = "Browse...",
                placeholder = "No file selected")
      ),
      layout_columns(
        value_box(
          title = "Number of Items",
          value = textOutput("item_count"),
          theme = "primary"
        ),
        value_box(
          title = "Highest Budget Item",
          value = textOutput("highest_item"),
          theme = "secondary"
        ),
        value_box(
          title = "Total Variance",
          value = textOutput("detailed_variance"),
          theme = value_box_theme(bg = "rgb(225, 190, 106)")
        ),
        value_box(
          title = "Average Budget Usage",
          value = textOutput("avg_budget_used"),
          theme = value_box_theme(bg = "rgb(126, 181, 131)")
        )
      ),
      card(
        card_header("Item Selection"),
        layout_columns(
          col_widths = c(6, 6),
          selectInput("selected_item", "Select Budget Item", choices = NULL),
          selectInput("selected_month", "Select Month", 
                     choices = c("All", "October", "November", "December", "January", "February", 
                               "March", "April", "May", "June", "July", "August", "September"))
        )
      ),
      card(
        card_header("Detailed Budget Comparison"),
        plotOutput("detailed_plot", height = "400px")
      )
    )
  )
)

server <- function(input, output, session) {
  # Initialize with sample data
  data <- reactiveVal(generate_sample_data())
  detailed_data <- reactiveVal(generate_detailed_sample_data())
  
  # Update data when files are uploaded
  observeEvent(input$file, {
    df <- read_excel(input$file$datapath)
    data(df)
  })
  
  observeEvent(input$detailed_file, {
    df <- read_excel(input$detailed_file$datapath)
    detailed_data(df)
  })
  
  # Update item choices
  observe({
    items <- unique(detailed_data()$Item)
    updateSelectInput(session, "selected_item", choices = items)
  })
  
  # Process overall budget data
  budget_data <- reactive({
    df <- data()
    month_order <- c("October", "November", "December", "January", "February", 
                    "March", "April", "May", "June", "July", "August", "September")
    df$Month <- factor(df$Month, levels = month_order)
    return(df)
  })
  
  # Overall budget calculations
  total_planned <- reactive({
    sum(budget_data()$Planned, na.rm = TRUE)
  })
  
  total_actual <- reactive({
    sum(budget_data()$Actual, na.rm = TRUE)
  })
  
  # Overall value box outputs
  output$total_planned <- renderText({
    scales::dollar(total_planned())
  })
  
  output$total_actual <- renderText({
    scales::dollar(total_actual())
  })
  
  output$variance <- renderText({
    variance <- total_planned() - total_actual()
    scales::dollar(variance)
  })
  
  output$budget_used <- renderText({
    sprintf("%.1f%%", (total_actual() / total_planned()) * 100)
  })
  
  # Detailed value box outputs
  output$item_count <- renderText({
    length(unique(detailed_data()$Item))
  })
  
  output$highest_item <- renderText({
    detailed_data() %>%
      group_by(Item) %>%
      summarise(total_planned = sum(Planned)) %>%
      arrange(desc(total_planned)) %>%
      slice(1) %>%
      pull(Item)
  })
  
  output$detailed_variance <- renderText({
    variance <- sum(detailed_data()$Planned - detailed_data()$Actual)
    scales::dollar(variance)
  })
  
  output$avg_budget_used <- renderText({
    avg_usage <- mean(detailed_data()$Actual / detailed_data()$Planned * 100)
    sprintf("%.1f%%", avg_usage)
  })
  
  # Overall budget plot
  output$budget_plot <- renderPlot({
    df_long <- budget_data() %>%
      pivot_longer(cols = c("Planned", "Actual"),
                  names_to = "Type",
                  values_to = "Amount")
    
    ggplot(df_long, aes(x = Month, y = Amount, color = Type, group = Type)) +
      geom_line(size = 1.2) +
      geom_point(size = 3) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1),
        legend.position = "top",
        panel.grid.minor = element_blank()
      ) +
      scale_y_continuous(labels = scales::dollar_format()) +
      labs(
        title = "Planned vs Actual Budget Comparison",
        y = "Amount",
        x = "Month"
      ) +
      scale_color_manual(values = c("Planned" = "#4e79a7", "Actual" = "#e15759"))
  })
  
 # Detailed budget plot
output$detailed_plot <- renderPlot({
  req(input$selected_item)
  
  # Set the month order for fiscal year
  month_order <- c("October", "November", "December", "January", "February", 
                  "March", "April", "May", "June", "July", "August", "September")
  
  filtered_data <- detailed_data() %>%
    filter(Item == input$selected_item) %>%
    mutate(Month = factor(Month, levels = month_order))  # Add this line to set month order
  
  if(input$selected_month != "All") {
    filtered_data <- filtered_data %>%
      filter(Month == input$selected_month)
  }
  
  df_long <- filtered_data %>%
    pivot_longer(cols = c("Planned", "Actual"),
                names_to = "Type",
                values_to = "Amount")
  
  ggplot(df_long, aes(x = Month, y = Amount, color = Type, group = Type)) +
    geom_line(size = 1.2) +
    geom_point(size = 3) +
    theme_minimal() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "top",
      panel.grid.minor = element_blank()
    ) +
    scale_y_continuous(labels = scales::dollar_format()) +
    labs(
      title = paste("Budget Comparison for", input$selected_item),
      y = "Amount",
      x = "Month"
    ) +
    scale_color_manual(values = c("Planned" = "#4e79a7", "Actual" = "#e15759"))
})
}

# Run the application
shinyApp(ui = ui, server = server)
