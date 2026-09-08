import os
import pathlib

def getFileList(dirName):
    dirPath = pathlib.Path(dirName)
    docFiles = list(dirPath.rglob('*.docx', case_sensitive=False))
    return [f.name for f in docFiles]

def main():
    mydir = input('Enter Dirname:')
    print(f'List of files in {mydir}')

    
    #print(docFiles)
    print('--------------------------------------------')
    fileNames = getFileList(mydir)

    print(fileNames)


    

main()