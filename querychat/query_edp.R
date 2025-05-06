library(shiny)
library(bslib)
library(DBI)
library(dplyr)
library(odbc)

ui <- page_sidebar(
  title = "SQL Server Explorer",
  sidebar = sidebar(
    title = "Database Navigation",

    # These selects will be populated after connection
    selectInput("schema", "Select Schema", choices = NULL),
    selectInput("table", "Select Table", choices = NULL),
    selectInput("column", "Select Column", choices = NULL),

    hr(),

    helpText("Note: Connected to SQL Server database")
  ),

  # Main panel
  card(
    card_header("Database Explorer"),
    card_body(
      uiOutput("connection_status"),
      hr(),
      h4("Preview Data"),
      tableOutput("data_preview")
    )
  )
)

server <- function(input, output, session) {
  # Reactive value to store the connection
  con <- reactiveVal(NULL)

  # Connect to database on app startup - using a different approach without 'once = TRUE'
  connection_trigger <- reactiveVal(0)

  observe({
    # This will only run once because connection_trigger never changes after initialization
    connection_trigger()

    # Show a notification that connection is in progress
    id <- showNotification("Connecting to database...", type = "message", duration = NULL)

    # Database connection parameters - hardcoded for this app
    server_name <- "edpmssql.ndc.nasa.gov"    # Replace with your actual server
    database_name <- "OCHCO"     # Replace with your actual database
    #username <- "your_username"          # Replace with your actual username
    #password <- "your_password"          # Replace with your actual password

    # Try to establish the connection
    tryCatch({
      connection <- dbConnect(odbc::odbc(),
                              Driver = "ODBC Driver 18 for SQL Server",  # Adjust driver if needed
                              Server = server_name,
                              Database = database_name,
                              #UID = username,
                              #PWD = password,
                              Port = 1433,  # Default SQL Server port
                              trusted_connection = "yes",
                              timeout = 10)

      # Store the connection
      con(connection)

      # Remove the connecting notification
      removeNotification(id)

      # Show success notification
      showNotification("Connected successfully!", type = "message")

      # Populate schema dropdown after successful connection
      updateSelectInput(session, "schema",
                        choices = dbGetQuery(connection,
                                             "SELECT DISTINCT schema_name FROM information_schema.schemata
                                           ORDER BY schema_name")$schema_name)

    }, error = function(e) {
      # Remove the connecting notification
      removeNotification(id)

      # Show error notification
      showNotification(paste("Connection error:", e$message), type = "error", duration = NULL)
      con(NULL)
    })
  })

  # Update tables based on selected schema
  observeEvent(input$schema, {
    conn <- con()
    req(conn, input$schema)

    query <- paste0("SELECT table_name FROM information_schema.tables
                    WHERE table_schema = '", input$schema, "'
                    ORDER BY table_name")

    tables <- dbGetQuery(conn, query)$table_name

    updateSelectInput(session, "table", choices = tables)
  })

  # Update columns based on selected table
  observeEvent(input$table, {
    conn <- con()
    req(conn, input$schema, input$table)

    query <- paste0("SELECT column_name FROM information_schema.columns
                    WHERE table_schema = '", input$schema, "'
                    AND table_name = '", input$table, "'
                    ORDER BY ordinal_position")

    columns <- dbGetQuery(conn, query)$column_name

    updateSelectInput(session, "column", choices = columns)
  })

  # Display connection status
  output$connection_status <- renderUI({
    if (is.null(con())) {
      div(
        class = "alert alert-warning",
        icon("exclamation-triangle"),
        "Not connected to database. There was an error establishing a connection."
      )
    } else {
      div(
        class = "alert alert-success",
        icon("check-circle"),
        "Connected to database successfully"
      )
    }
  })

  # Preview data when schema and table are selected
  output$data_preview <- renderTable({
    conn <- con()
    req(conn, input$schema, input$table)

    tryCatch({
      query <- paste0("SELECT TOP 10 * FROM [", input$schema, "].[", input$table, "]")
      dbGetQuery(conn, query)
    }, error = function(e) {
      data.frame(Error = paste("Could not fetch data:", e$message))
    })
  })

  # Clean up the connection when the session ends
  onSessionEnded(function() {
    if (!is.null(con())) {
      dbDisconnect(con())
    }
  })
}

shinyApp(ui, server)
