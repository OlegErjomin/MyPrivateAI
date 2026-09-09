import os
import pathlib
from typing import List, Generator
from docx import Document
from docx.table import Table
from docx.text.paragraph import Paragraph


def main():
    mydir = input('Enter Dirname:')
    print(f'List of files in {mydir}')
    
    #print(docFiles)
    print('--------------------------------------------')
    filePaths = getFileList(mydir)

    print(filePaths)
    uploadDocuments(filePaths)

def getFileList(dirName: str):
    dirPath = pathlib.Path(dirName)
    docFiles: List[pathlib.Path] = list(dirPath.rglob('*.docx', case_sensitive=False))
    return [f.absolute() for f in docFiles if not f.name.startswith('~') ]

def uploadDocuments(fileList):
    #
    for path in fileList:
        text = extract_all_text_from_docx(path)
        print(text)

    pass
    
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

main()