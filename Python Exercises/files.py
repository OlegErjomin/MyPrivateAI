import os
import pathlib
from typing import List, Generator
from docx import Document
from docx.table import Table
from docx.text.paragraph import Paragraph

from sklearn.feature_extraction.text import TfidfVectorizer
import pandas as pd

def main():
    mydir = input('Enter Dirname:')
    print(f'List of files in {mydir}')
    
    #print(docFiles)
    print('--------------------------------------------')
    filePaths = getFileList(mydir)

    #print(filePaths)
    docTexts = uploadDocuments(filePaths)
    print(f'Uploaded {len(docTexts)} documents')

    TFIDF = vectorize(docTexts) 
    print ("TF-IDF matrix")
    print(TFIDF)

def getFileList(dirName: str):
    dirPath = pathlib.Path(dirName)
    docFiles: List[pathlib.Path] = list(dirPath.rglob('*.docx', case_sensitive=False))
    return [f.absolute() for f in docFiles if not f.name.startswith('~') ]

def uploadDocuments(fileList):
    # Convert documents to plaintext
    return [extract_all_text_from_docx(path) for path in fileList]
    
def extract_all_text_from_docx(file_path):
    doc = Document(file_path)
    full_text = []

    # Use iter_inner_content() to get paragraphs AND tables in order
    for block in doc.iter_inner_content():
        if isinstance(block, Paragraph):
            text = block.text.strip()
            if text:
                full_text.append(text)
        elif isinstance(block, Table):
            # Extract text from each cell in the table
            for row in block.rows:
                row_text = []
                for cell in row.cells:
                    cell_text = " ".join(cell.text.split())
                    if cell_text:
                        row_text.append(cell_text)
                if row_text:
                    full_text.append(" | ".join(row_text))  # Join cells with a pipe

    return '\n'.join(full_text)

def vectorize(docs):
    vectorizer = TfidfVectorizer()
    X = vectorizer.fit_transform(docs)
    tfidf_data = pd.DataFrame(X.toarray(), columns=vectorizer.get_feature_names_out(), index=[f'{i+1}' for i in range(len(docs))])
    return tfidf_data

main()