import os

from llama_index.llms.deepseek import DeepSeek
from llama_index.core import Settings, VectorStoreIndex


os.environ["DEEPSEEK_API_KEY"] = "sk-37089f72f8f14917860a888a6c0d2aeb"

# Initialize the LLM
llm = DeepSeek(model="deepseek-chat", api_key=os.environ["DEEPSEEK_API_KEY"])

# Use it for completion

def initDeepSeek():
    try:
        response = llm.complete("Explain the concept of RAG in one sentence.")
        print(response)
        Settings.llm = llm
    except Exception as e:
        print(f"An error occured {e}")

def createIndex(documents):
    index = VectorStoreIndex.from_documents(documents)

    
    

