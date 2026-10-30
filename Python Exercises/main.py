import pathlib
from typing import List

from files import uploadDocuments
from my_llama_index import createIndex, createQueryEngine, initLLM
from vectorize import vectorize


def getFileList(dirName: str) -> List[pathlib.Path]:
    dirPath = pathlib.Path(dirName)
    # Case-insensitive .docx match that works on any Python 3 version
    return [
        f.absolute()
        for f in dirPath.rglob("*")
        if f.suffix.lower() == ".docx" and not f.name.startswith("~")
    ]


def main():
    mydir = input("Enter directory name: ")
    filePaths = getFileList(mydir)
    if not filePaths:
        print("No .docx files found.")
        return

    print(f"Found {len(filePaths)} files:")
    for p in filePaths:
        print(f"  - {p.name}")

    docTexts = uploadDocuments(filePaths)
    print(f"Uploaded {len(docTexts)} documents")

    # Optional: keyword-level view of the corpus (your original TF-IDF step)
    print("TF-IDF matrix shape:", vectorize(docTexts).shape)

    # RAG: index the documents, then answer questions from them
    initLLM()
    index = createIndex(docTexts, [p.name for p in filePaths])
    engine = createQueryEngine(index)

    print("\nAsk questions about your documents (type 'exit' to quit).")
    while True:
        question = input("\nQ: ").strip()
        if question.lower() in {"exit", "quit", ""}:
            break
        response = engine.query(question)
        print(f"\nA: {response}")
        print("\nSources:")
        for node in response.source_nodes:
            name = node.metadata.get("file_name", "?")
            snippet = node.get_content()[:120].replace("\n", " ")
            print(f"  [{node.score:.2f}] {name}: {snippet}...")


if __name__ == "__main__":
    main()
