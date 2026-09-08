import os
import pathlib

def main():
    mydir = input('Enter Dirname:')
    print(f'List of files in {mydir}')

    dirPath = pathlib.Path(mydir)
    docFiles = list(dirPath.rglob('*.docx'))

    #print(docFiles)
    print('--------------------------------------------')
    for f in docFiles:
        print(f.name)

main()