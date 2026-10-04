import sys, os, html
def item(cls, name, source=None, children=(), ref=[0]):
    ref[0]+=1
    r='RBX%08d'%ref[0]
    props=['<string name="Name">%s</string>'%html.escape(name)]
    if source is not None:
        assert ']]>' not in source, name
        props.append('<ProtectedString name="Source"><![CDATA[%s]]></ProtectedString>'%source)
    return '<Item class="%s" referent="%s"><Properties>%s</Properties>%s</Item>'%(cls,r,''.join(props),''.join(children))
D='luau'
core=open(f'{D}/Core.luau').read(); truck=open(f'{D}/TruckNeu.luau').read(); meshd=open(f'{D}/MeshData.luau').read(); main=open(f'{D}/RoadSmooth.luau').read()
x='<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4"><External>null</External><External>nil</External>'
x+=item('ModuleScript','RoadSmooth',main,[item('ModuleScript','Core',core),item('ModuleScript','TruckNeu',truck),item('ModuleScript','MeshData',meshd)])
x+='</roblox>'
out=sys.argv[1]
open(out,'w',encoding='utf-8').write(x)
print(out,len(x))
