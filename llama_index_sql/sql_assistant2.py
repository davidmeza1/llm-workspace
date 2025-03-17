#import tempfile
import streamlit as st
import os
import pandas as pd
import plotly.express as px  
from llama_index.core import SQLDatabase, ServiceContext
from llama_index.llms import openai
from llama_index.core.query_engine import NLSQLTableQueryEngine
#import sqlite3
from sqlalchemy import inspect
import sqlalchemy
###############
# Connecting to SQL
from llama_index.core import VectorStoreIndex, SQLDatabase, ServiceContext
#from llama_index.core.tools import QueryEngineTool
#from llama_index.core.query_engine import RouterQueryEngine
#from llama_index.core.selectors import LLMSingleSelector
from llama_index.llms import openai
import sqlalchemy
from sqlalchemy import insert, text, create_engine, MetaData
from llama_index.core.query_engine import NLSQLTableQueryEngine
from llama_index.core.query_engine import SQLTableRetrieverQueryEngine
from llama_index.core.objects import SQLTableNodeMapping, ObjectIndex, SQLTableSchema
# Setting local llm amd lLocal embeddings
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from llama_index.core import Settings
from llama_index.core.embeddings import resolve_embed_model
from llama_index.llms.ollama import Ollama
Settings.llm = Ollama(model="llama2", request_timeout=30.0)
Settings.embed_model = resolve_embed_model("local:BAAI/bge-small-en-v1.5")
#############
st.set_page_config(page_title="SQL Assistant")
st.title("SQL Assistant")

# Authentication
authed = False
if "name" not in st.session_state:
  st.session_state["name"] = st.text_input("Enter your name:")
else:
  st.write(f"Welcome back {st.session_state['name']}!") 
  authed = True

# DB conncection information
server = "alteryxwkr.ndc.nasa.gov"
port = "1433"
db = "OCHCO"
driver = "ODBC+Driver+18+for+SQL+Server"
schema = "pdw_dev_trusted"
db_uri = f"mssql://{server}/{db}?driver={driver}&port={port}&trusted_connection=yes&options={{'schema':{schema}}}"
#Create the engine
engine = create_engine(db_uri)
#engine = None  # Initialize to None at the start
#db = None  # Initialize db to None at the start

#if authed:
#    uploaded_file = st.file_uploader("Choose a SQLite database file", type=["sqlite", "db"])
#    if uploaded_file is not None:
        # Create a temporary file and save the uploaded database there
        #tfile = tempfile.NamedTemporaryFile(delete=False) 
        #tfile.write(uploaded_file.read())
#        tfile.flush()
        # Create SQLAlchemy engine using the temporary file
        

        #engine = sqlalchemy.create_engine(f'sqlite:///{tfile.name}')
        #st.success("Database uploaded!")
    # Use SQLAlchemy's inspector to get table names
if engine is not None:
   
    #inspector = inspect(engine)
    #tables = inspector.get_table_names()
    # load all table definitions
    metadata_obj = MetaData()
    metadata_obj.reflect(engine)

    sql_database = SQLDatabase(engine)

    table_node_mapping = SQLTableNodeMapping(sql_database)

    table_schema_objs = []
    for table_name in metadata_obj.tables.keys():
        table_schema_objs.append(SQLTableSchema(table_name=table_name))

    # We dump the table schema information into a vector index. The vector index is stored within the context builder for future use.
    obj_index = ObjectIndex.from_objects(
        table_schema_objs,
        table_node_mapping,
        VectorStoreIndex,
    )
    # Create SQLDatabase
    sql_database = SQLDatabase(engine)

# Use db only if it's not None
if sql_database is not None:
  # Database upload
  if sql_database:
    query = st.text_input("Enter a query:")
    if query:
    
      # Initialize LLMs  
      # See above. The LLM and embedding initialized above
      
      # Create engine
      # Create your NLSQLTableQueryEngine
      #engine = NLSQLTableQueryEngine(db, tables=tables, service_context=service_context) 
      # We construct a SQLTableRetrieverQueryEngine. 
      # Note that we pass in the ObjectRetriever so that we can dynamically retrieve the table during query-time.
      # ObjectRetriever: A retriever that retrieves a set of query engine tools.
      query_engine = SQLTableRetrieverQueryEngine(
        sql_database,
        obj_index.as_retriever(similarity_top_k=1),
    #   service_context=service_context,
)     
      # Execute query
      #response = engine.query(query)
      response = query_engine.query(query)
      
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
   st.session_state["query_history"] = []
else:  
   st.session_state["query_history"].append(query)  
# Show previous queries  
with st.expander("Previous Queries"):
    prev_queries = st.session_state["query_history"][-5:]
    for q in prev_queries:
        st.code(q)