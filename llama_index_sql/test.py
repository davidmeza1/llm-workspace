# NOTE: This is ONLY necessary in jupyter notebook.
# Details: Jupyter runs an event-loop behind the scenes.
#          This results in nested event-loops when we start an event-loop to make async queries.
#          This is normally not allowed, we use nest_asyncio to allow it for convenience.
import nest_asyncio

nest_asyncio.apply()

import logging
import sys

logging.basicConfig(stream=sys.stdout, level=logging.INFO)
logging.getLogger().addHandler(logging.StreamHandler(stream=sys.stdout))

from llama_index.core import VectorStoreIndex, SQLDatabase
from llama_index.readers.wikipedia import WikipediaReader

# Setting local llm 
from llama_index.llms.ollama import Ollama
Settings.llm = Ollama(model="gemma", request_timeout=30.0)

from sqlalchemy import (
    create_engine,
    MetaData,
    Table,
    Column,
    String,
    Integer,
    select,
    column,
)

engine = create_engine("sqlite:///:memory:", future=True)
metadata_obj = MetaData()

# create city SQL table
table_name = "city_stats"
city_stats_table = Table(
    table_name,
    metadata_obj,
    Column("city_name", String(16), primary_key=True),
    Column("population", Integer),
    Column("country", String(16), nullable=False),
)

metadata_obj.create_all(engine)

# print tables
metadata_obj.tables.keys()

from sqlalchemy import insert

rows = [
    {"city_name": "Toronto", "population": 2930000, "country": "Canada"},
    {"city_name": "Tokyo", "population": 13960000, "country": "Japan"},
    {"city_name": "Berlin", "population": 3645000, "country": "Germany"},
]
for row in rows:
    stmt = insert(city_stats_table).values(**row)
    with engine.begin() as connection:
        cursor = connection.execute(stmt)

with engine.connect() as connection:
    cursor = connection.exec_driver_sql("SELECT * FROM city_stats")
    print(cursor.fetchall())

cities = ["Toronto", "Berlin", "Tokyo"]
wiki_docs = WikipediaReader().load_data(pages=cities)

sql_database = SQLDatabase(engine, include_tables=["city_stats"])

from llama_index.core.query_engine import NLSQLTableQueryEngine

#Use Local embeddings
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from llama_index.core import Settings
from llama_index.core.embeddings import resolve_embed_model

Settings.embed_model = resolve_embed_model("local:BAAI/bge-small-en-v1.5")

sql_query_engine = NLSQLTableQueryEngine(
    sql_database=sql_database,
    tables=["city_stats"],
    llm="None",
)

# build a separate vector index per city
# You could also choose to define a single vector index across all docs, and annotate each chunk by metadata
vector_indices = []
for wiki_doc in wiki_docs:
    vector_index = VectorStoreIndex.from_documents([wiki_doc])
    vector_indices.append(vector_index)

vector_query_engines = [index.as_query_engine() for index in vector_indices]

from llama_index.core.tools import QueryEngineTool


sql_tool = QueryEngineTool.from_defaults(
    query_engine=sql_query_engine,
    description=(
        "Useful for translating a natural language query into a SQL query over"
        " a table containing: city_stats, containing the population/country of"
        " each city"
    ),
)
vector_tools = []
for city, query_engine in zip(cities, vector_query_engines):
    vector_tool = QueryEngineTool.from_defaults(
        query_engine=query_engine,
        description=f"Useful for answering semantic questions about {city}",
    )
vector_tools.append(vector_tool)

from llama_index.core.query_engine import RouterQueryEngine
from llama_index.core.selectors import LLMSingleSelector

query_engine = RouterQueryEngine(
    selector=LLMSingleSelector.from_defaults(),
    query_engine_tools=([sql_tool] + vector_tools),
    llm="None",
)