from docx import Document
from docx.table import Table
from docx.text.paragraph import Paragraph

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


main()