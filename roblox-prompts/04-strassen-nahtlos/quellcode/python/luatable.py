import re
TOK=re.compile(r'\s*(?:(--\[\[.*?\]\])|(--[^\n]*)|("(?:[^"\\]|\\.)*")|(-?\d+\.?\d*(?:e-?\d+)?)|([A-Za-z_][A-Za-z0-9_]*)|(\[|\]|\{|\}|=|,|;))',re.S)
def tokens(s):
    pos=0; out=[]
    while pos<len(s):
        m=TOK.match(s,pos)
        if not m:
            if s[pos:].strip()=='' : break
            raise ValueError(s[pos:pos+50])
        pos=m.end()
        if m.group(1) or m.group(2): continue
        if m.group(3): out.append(('s',m.group(3)[1:-1]))
        elif m.group(4): out.append(('n',float(m.group(4))))
        elif m.group(5): out.append(('i',m.group(5)))
        else: out.append(('p',m.group(6)))
    return out
def parse(s):
    i=s.find('return'); toks=tokens(s[i+6:]); k=[0]
    def val():
        t=toks[k[0]]
        if t==('p','{'): return table()
        k[0]+=1
        if t[0]=='i': return {'true':True,'false':False,'nil':None}.get(t[1],t[1])
        return t[1]
    def table():
        k[0]+=1; arr=[]; d={}
        while toks[k[0]]!=('p','}'):
            t=toks[k[0]]
            if t[0]=='i' and toks[k[0]+1]==('p','='):
                k[0]+=2; d[t[1]]=val()
            elif t==('p','['):
                k[0]+=1; key=val(); k[0]+=1; k[0]+=1; d[key]=val()
            else: arr.append(val())
            if toks[k[0]] in (('p',','),('p',';')): k[0]+=1
        k[0]+=1
        if d and arr: d['_arr']=arr; return d
        return d if d else arr
    return val()
