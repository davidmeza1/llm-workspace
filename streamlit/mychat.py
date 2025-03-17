# https://blog.streamlit.io/build-a-chatbot-with-custom-data-sources-powered-by-llamaindex/
import streamlit as st
from llama_index.core import VectorStoreIndex, ServiceContext, Document, Settings, SimpleDirectoryReader
# My Additions
from llama_index.llms.ollama import Ollama
#import weaviate
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from llama_index.embeddings.ollama import OllamaEmbedding

#3.2. Initialize message history
#Set your OpenAI API key from the app's secrets.
#Add a heading for your app.
#Use session state to keep track of your chatbot's message history.
#Initialize the value of st.session_state.messages to include the chatbot's starting message, 
# such as, "Ask me a question about Streamlit's open-source Python library!"

#openai.api_key = st.secrets.openai_key
st.header("Chat with the Streamlit docs 💬 📚")

if "messages" not in st.session_state.keys(): # Initialize the chat message history
    st.session_state.messages = [
        {"role": "assistant", "content": "Ask me a question about Streamlit's open-source Python library!"}
    ]

# Load and Index data
@st.cache_resource(show_spinner=False)
def load_data():
    with st.spinner(text="Loading and indexing the Streamlit docs – hang tight! This should take 1-2 minutes."):
        # ollama
        # bge-base embedding model
        #Settings.embed_model = HuggingFaceEmbedding(model_name="BAAI/bge-base-en-v1.5")
        Settings.embed_model = OllamaEmbedding(model_name="mxbai-embed-large:latest", base_url="http://localhost:11434", ollama_additional_kwargs={"mirostat": 0},)
        Settings.llm = Ollama(model="qwen2.5:14b-instruct-q2_K", request_timeout=30.0)
        reader = SimpleDirectoryReader(input_dir="./data", recursive=True)
        docs = reader.load_data()
        index = VectorStoreIndex.from_documents(docs)
        #service_context = ServiceContext.from_defaults(llm=Ollama(model="qwen2.5:14b-instruct-q2_K", request_timeout=30.0, system_prompt="You are an expert on the Streamlit Python library and your job is to answer technical questions. Assume that all questions are related to the Streamlit Python library. Keep your answers technical and based on facts – do not hallucinate features."))
        #service_context = ServiceContext.from_defaults(llm=OpenAI(model="gpt-3.5-turbo", temperature=0.5, system_prompt="You are an expert on the Streamlit Python library and your job is to answer technical questions. Assume that all questions are related to the Streamlit Python library. Keep your answers technical and based on facts – do not hallucinate features."))
        #index = VectorStoreIndex.from_documents(docs, service_context=service_context)
        return index

index = load_data()

# Create the chat engine
# options condense_qeustion, context, react, openai
chat_engine = index.as_chat_engine(chat_mode="condense_question", verbose=True)

# prompt for user input and display message history
if prompt := st.chat_input("Your question"): # Prompt for user input and save to chat history
    st.session_state.messages.append({"role": "user", "content": prompt})

for message in st.session_state.messages: # Display the prior chat messages
    with st.chat_message(message["role"]):
        st.write(message["content"])

# pass query to chat engine and display response
# If last message is not from assistant, generate a new response
if st.session_state.messages[-1]["role"] != "assistant":
    with st.chat_message("assistant"):
        with st.spinner("Thinking..."):
            response = chat_engine.chat(prompt)
            st.write(response.response)
            message = {"role": "assistant", "content": response.response}
            st.session_state.messages.append(message) # Add response to message history