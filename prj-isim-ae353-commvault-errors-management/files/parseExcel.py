import sys
import xlrd
from datetime import datetime
import os.path
import csv

workbookPath = sys.argv[1]
print("Workbook Path:", workbookPath)
errorsType = sys.argv[2]
persFile = sys.argv[3]

if not os.path.isfile(workbookPath):
    print("The file given in the form has not been found.")
    sys.exit(1)

workbook = xlrd.open_workbook(workbookPath)
worksheet = workbook.sheet_by_index(0)

pers_csv = csv.reader(open(persFile, "r", encoding='latin-1'), delimiter=";")

# Get backup's date
cellA1 = worksheet.cell(0, 0).value

if errorsType == "NETWORKER":
    # networker = commvault
    backup_date = cellA1[22:32]
else:
    # sipsir
    backup_date = cellA1[29:39]

# check only one day of data
onlyOneDay = False

try:
    worksheet.cell(3, 5).value
except:
    onlyOneDay = True

if not onlyOneDay:
    print("Only one day of data needs to be provided.")
    sys.exit(1)

if errorsType == "NETWORKER":
    # networker = commvault
    errorType = ["PF", "AD", "WN", "DP", "KT"]
    totalLines = worksheet.nrows - 2 - 3
else:
    # sipsir
    errorType = ["KO", "AT"]
    totalLines = worksheet.nrows - 3

for i in range(totalLines):
    if worksheet.cell(i + 3, 4).value in errorType:

        application = worksheet.cell(i + 3, 0).value
        fanion = worksheet.cell(i + 3, 1).value
        hostname = worksheet.cell(i + 3, 2).value
        error_type = worksheet.cell(i + 3, 4).value
        osi = ""
        prestation = "R_Std"

        with open(persFile, "r", encoding='latin-1') as csvfile:
            pers_csv = csv.reader(csvfile, delimiter=";")
            try:
                for row in pers_csv:
                    if len(row) == 0:
                        continue  # Skip empty lines
                    if len(row) < 66:
                        print(f"Skipping invalid row: {row}")
                        continue

                    if application.upper() == "ARCHIVAGE ET SERVICES":
                        application = "ARCHIVAGE & SERVICES"

                    # Add similar checks for other applications

                    if row[18].upper() == hostname.upper() and row[0].upper() == application.upper():
                        osi = row[5]
                        if row[65] == "Standard":
                            prestation = "R_Std"
                        else:
                            prestation = "R_Renf"

            except csv.Error as e:
                print(f"Error reading CSV: {e}")

        lineToPrint = (
            application
            + ";"
            + fanion
            + ";"
            + hostname
            + ";"
            + error_type
            + ";"
            + backup_date
            + ";"
            + osi
            + ";"
            + prestation
        )
        print(lineToPrint)
