from llama_index.core import Document, Settings, VectorStoreIndex
from llama_index.embeddings.ollama import OllamaEmbedding
from llama_index.llms.ollama import Ollama


def initLLM(llm_model: str = "llama3", embed_model: str = "nomic-embed-text"):
    """Configure the local LLM and embedding model (both served by Ollama)."""
    Settings.llm = Ollama(
        model=llm_model,
        request_timeout=360.0,
        context_window=8000,
    )
    # Without this, LlamaIndex defaults to OpenAI embeddings and needs an API key.
    Settings.embed_model = OllamaEmbedding(model_name=embed_model)

    # Chunking: smaller chunks = more precise retrieval
    Settings.chunk_size = 512
    Settings.chunk_overlap = 50

    # Fail fast if Ollama isn't running or a model is missing
    print(Settings.llm.complete("Reply with the single word: ready"))


def createIndex(texts, sources):
    """Build a vector index. `texts` are plain strings, `sources` are file names."""
    documents = [
        Document(text=text, metadata={"file_name": str(source)})
        for text, source in zip(texts, sources)
    ]
    return VectorStoreIndex.from_documents(documents, show_progress=True)


def createQueryEngine(index, top_k: int = 4):
    """Retrieve the top_k most similar chunks and let the LLM answer from them."""
    return index.as_query_engine(similarity_top_k=top_k)
