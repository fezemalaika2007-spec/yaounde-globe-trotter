from pathlib import Path
p=Path(r"c:\Users\jbc\OneDrive\Desktop\yaounde travel assistance\yaounde-globe-trotter\frontend\lib\screens\destination_details_screen.dart")
lines=p.read_text().splitlines()
for i in range(788,809):
    print(i+1, lines[i])
