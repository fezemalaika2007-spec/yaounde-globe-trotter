from pathlib import Path
p=Path(r"c:\Users\jbc\OneDrive\Desktop\yaounde travel assistance\yaounde-globe-trotter\frontend\lib\screens\destination_details_screen.dart")
s=p.read_text()
counts={'(':0,')':0,'[':0,']':0,'{':0,'}':0}
for ch in s:
    if ch in counts: counts[ch]+=1
print(counts)
# check cumulative per line
cum={'(':0,'[':0,'{':0}
for idx,line in enumerate(s.splitlines(),1):
    for c in line:
        if c=='(': cum['(']+=1
        elif c==')': cum['(']-=1
        if c=='[': cum['[']+=1
        elif c==']': cum['[']-=1
        if c=='{': cum['{']+=1
        elif c=='}': cum['{']-=1
    if cum['(']<0 or cum['[']<0 or cum['{']<0:
        print('Negative at line',idx, cum)
        break
# find line where cum '(' is maximal
max_cum = -999
max_line = None
for i,line in enumerate(s.splitlines(),1):
    # recompute up to this line
    c={'(' : 0}
    for l in s.splitlines()[:i]:
        for ch in l:
            if ch=='(': c['(']+=1
            elif ch==')': c['(']-=1
    if c['('] > max_cum:
        max_cum = c['(']
        max_line = i
print('max_open_paren_count', max_cum, 'at line', max_line)
# print lines where cum('(') > 0
cum={'(' : 0, '[': 0, '{':0}
for idx,line in enumerate(s.splitlines(),1):
    for ch in line:
        if ch=='(': cum['(']+=1
        elif ch==')': cum['(']-=1
        if ch=='[': cum['[']+=1
        elif ch==']': cum['[']-=1
        if ch=='{': cum['{']+=1
        elif ch=='}': cum['{']-=1
    if cum['(']>0 or cum['[']>0 or cum['{']>0:
        print('line',idx,'cum',cum)
print('final cum',cum)
