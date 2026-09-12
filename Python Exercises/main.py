import pathlib
from files import uploadDocuments
from typing import List
from vectorize import vectorize
from my_llama_index import initDeepSeek, createIndex


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

    initDeepSeek()
    createIndex(docTexts)

    

def getFileList(dirName: str):
    dirPath = pathlib.Path(dirName)
    docFiles: List[pathlib.Path] = list(dirPath.rglob('*.docx', case_sensitive=False))
    return [f.absolute() for f in docFiles if not f.name.startswith('~') ]


main()