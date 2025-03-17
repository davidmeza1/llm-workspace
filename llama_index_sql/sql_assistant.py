import tempfile
import streamlit as st
import os
import pandas as pd
import plotly.express as px  
from llama_index.core import SQLDatabase, ServiceContext
from llama_index.llms import openai
#from llama_index.indices.struct_store.sql_query import NLSQLTableQueryEngine
from llama_index.core.query_engine import NLSQLTableQueryEngine
import sqlite3
from sqlalchemy import inspect
import sqlalchemy
st.set_page_config(page_title="SQL Assistant")
st.title("SQL Assistant")

# Authentication
authed = False
if "name" not in st.session_state:
  st.session_state["name"] = st.text_input("Enter your name:")
else:
  st.write(f"Welcome back {st.session_state['name']}!") 
  authed = True

engine = None  # Initialize to None at the start
db = None  # Initialize db to None at the start

if authed:
    uploaded_file = st.file_uploader("Choose a SQLite database file", type=["sqlite", "db"])
    if uploaded_file is not None:
        # Create a temporary file and save the uploaded database there
        tfile = tempfile.NamedTemporaryFile(delete=False) 
        tfile.write(uploaded_file.read())
        tfile.flush()
        # Create SQLAlchemy engine using the temporary file
        
        engine = sqlalchemy.create_engine(f'sqlite:///{tfile.name}')
        st.success("Database uploaded!")
    # Use SQLAlchemy's inspector to get table names
if engine is not None:
   
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    
    # Create SQLDatabase
    db = SQLDatabase(engine)

# Use db only if it's not None
if db is not None:
  # Database upload
  if db:
    query = st.text_input("Enter a query:")
    if query:
    
      # Initialize LLMs  
      os.environ["OPENAI_API_KEY"] = "sk-yourkey"
      llm = OpenAI(model="gpt-3.5-turbo")
      service_context = ServiceContext.from_defaults(llm=llm)
      
      # Create engine
      # Create your NLSQLTableQueryEngine
      engine = NLSQLTableQueryEngine(db, tables=tables, service_context=service_context)      
      # Execute query
      response = engine.query(query)
      
      # Display results
      if response.metadata["result"]:
        
        df = pd.DataFrame(response.metadata["result"])
        st.dataframe(df)
      if len(df.columns) > 1:
        fig = px.bar(df, x=df.columns[0], y=df.columns[1])
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.warning("Not enough columns in the DataFrame to create a bar chart.")

    # Only try to display the SQL query if 'response' is initialized

if 'response' in locals():
    st.code(response.metadata["sql_query"], language="sql")
else:
    st.warning("No query has been executed yet.")

if "query_history" not in st.session_state:
  
   st.session_state["query_history"].append(query)  
# Show previous queries  
with st.expander("Previous Queries"):
    prev_queries = st.session_state["query_history"][-5:]
    for q in prev_queries:
        st.code(q)