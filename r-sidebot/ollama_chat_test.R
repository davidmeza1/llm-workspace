library(duckdb)
library(DBI)
library(here)
library(plotly)
library(ggplot2)
library(ggridges)
library(dplyr)
library(elmer)
library(tidyverse)

# Source prompt-helper
source("R/prompt-helper.R", echo=TRUE)

# Import csv to duckdb
library(readr)
#wag <- read_csv("~/Library/CloudStorage/OneDrive-NASA/TSE_data/WAG/WAG_202121_cpp.csv")
#wag_df <-  wag %>%
#  group_by(`Fiscal year`) %>%
#  distinct(ID, .keep_all = TRUE) %>%

wag$education_level_1 <- replace_na(wag$education_level_1, -999)
write_csv(wag, "wag.csv")

wag_data <- dbGetQuery(conn, "SELECT * FROM wag_duckdb")

con <- dbConnect(duckdb(), dbdir = here("wag.duckdb"))

#duckdb_read_csv(con, "wag_duckdb", here("wag.csv"))

dbGetQuery(conn, "SELECT * FROM wag_duckdb")

# Open the duckdb database
#conn <- dbConnect(duckdb(), dbdir = here("tips.duckdb"), read_only = TRUE)
conn <- dbConnect(duckdb(), dbdir = here("wag.duckdb"), read_only = TRUE)
duckdb_read_csv(conn, "wag_duckdb", here("wag.csv"))
# Close the database when the app stops
onStop(\() dbDisconnect(conn))

################################ https://ollama.com/blog/tool-support
#ollama_model <- "llama3.2:3b-instruct-q8_0" # partially works, need to look at tools
ollama_model <- "mistral:instruct"

# prompt-helper.R loads system_prompt and prompt.md
system_prompt_str <- system_prompt(dbGetQuery(conn, "SELECT * FROM wag_duckdb"), "wag_duckdb")

chat <- chat_ollama(model = ollama_model,system_prompt = system_prompt_str )

# Functions for tools

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

# Define the tools

tool_update_dashboard <- ToolDef(
  update_dashboard, #name of function to use
  name = "update_dashboard",
  description = "Modifies the data presented in the data dashboard, based on the given SQL query, and also updates the title.",
  arguments = list(
    query = ToolArg(
      type = "string",
      description = "A DuckDB SQL query; must be a SELECT statement.",
      required = TRUE
    ),
    title = ToolArg(
      type = "string",
      description = "A title to display at the top of the data dashboard, summarizing the intent of the SQL query.",
      required = TRUE
    )
  )
)

tool_query <- ToolDef(
  query,
  name = "query",
  description = "Perform a SQL query on the data, and return the results as JSON.",
  arguments = list(
    query = ToolArg(
      type = "string",
      description = "A DuckDB SQL query; must be a SELECT statement.",
      required = TRUE
    )
  )
)

# Register the tool
chat$register_tool(tool_update_dashboard)
chat$register_tool(tool_query)

# add your question to the chat
chat$chat("what is the count of unique employees grouped by fiscal year?")




