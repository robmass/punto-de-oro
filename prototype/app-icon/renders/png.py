import zlib, struct, sys

def read_png(p):
    d = open(p,'rb').read(); assert d[:8]==b'\x89PNG\r\n\x1a\n'
    i=8; idat=b''; w=h=bd=ct=None; pal=None
    while i < len(d):
        ln,typ = struct.unpack('>I4s', d[i:i+8]); ch=d[i+8:i+8+ln]; i+=12+ln
        if typ==b'IHDR': w,h,bd,ct = struct.unpack('>IIBB', ch[:10])
        elif typ==b'IDAT': idat+=ch
        elif typ==b'PLTE': pal=ch
        elif typ==b'IEND': break
    raw = zlib.decompress(idat)
    nch = {0:1,2:3,3:1,4:2,6:4}[ct]; assert bd==8, bd
    stride = w*nch; out=bytearray(); prev=bytearray(stride); pos=0
    for y in range(h):
        f = raw[pos]; pos+=1; line=bytearray(raw[pos:pos+stride]); pos+=stride
        for x in range(stride):
            a = line[x-nch] if x>=nch else 0; b = prev[x]; c = prev[x-nch] if x>=nch else 0
            if f==1: line[x]=(line[x]+a)&255
            elif f==2: line[x]=(line[x]+b)&255
            elif f==3: line[x]=(line[x]+(a+b)//2)&255
            elif f==4:
                pp=a+b-c; pa=abs(pp-a); pb=abs(pp-b); pc=abs(pp-c)
                pr = a if (pa<=pb and pa<=pc) else (b if pb<=pc else c)
                line[x]=(line[x]+pr)&255
        out+=line; prev=line
    px=[]
    for y in range(h):
        row=[]
        for x in range(w):
            o=(y*stride)+x*nch; v=out[o:o+nch]
            if ct==6: row.append(tuple(v[:3]))
            elif ct==2: row.append(tuple(v))
            elif ct==3: row.append(tuple(pal[v[0]*3:v[0]*3+3]))
            else: row.append((v[0],)*3)
        px.append(row)
    return w,h,px

def write_png(p,w,h,px):
    raw=b''.join(b'\x00'+bytes(c for pix in row for c in pix) for row in px)
    def ch(t,d): 
        x=struct.pack('>I',len(d))+t+d; return x+struct.pack('>I', zlib.crc32(t+d)&0xffffffff)
    open(p,'wb').write(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))
        +ch(b'IDAT',zlib.compress(raw,9))+ch(b'IEND',b''))

def upscale(px,n):
    return [[c for c in row for _ in range(n)] for row in px for _ in range(n)]
