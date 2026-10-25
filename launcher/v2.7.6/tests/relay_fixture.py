"""Local protocol fixture matching Anchor's null-delimited room/client semantics.
Not a live Railway or Windows gameplay test.
"""
import socketserver,json,threading,sys
rooms={};counter=0;lock=threading.RLock()
def send(c,p):
 try:c['socket'].sendall(json.dumps(p).encode()+b'\0')
 except OSError:pass
def broadcast(room):
 for c in room['clients'].values():
  if c['online']:
   states=[dict(x['state'],clientId=i,online=x['online'],self=(i==c['id'])) for i,x in room['clients'].items()]
   send(c,{'type':'ALL_CLIENT_STATE','state':states})
class Client(socketserver.BaseRequestHandler):
 def handle(self):
  global counter
  c=None;room=None;buf=b''
  try:
   while True:
    data=self.request.recv(65536)
    if not data:break
    buf+=data
    while b'\0' in buf:
     raw,buf=buf.split(b'\0',1);p=json.loads(raw)
     with lock:
      if c is None:
       assert p['type']=='HANDSHAKE'
       counter+=1;cid=p.get('clientId') or counter
       room=rooms.setdefault(p['roomId'],{'state':dict(p['roomState'],ownerClientId=cid),'clients':{}})
       c={'socket':self.request,'state':p['clientState'],'id':cid,'online':True};room['clients'][cid]=c
       broadcast(room);send(c,{'type':'UPDATE_ROOM_STATE','state':room['state']})
      else:
       if p['type']=='UPDATE_CLIENT_STATE':c['state']=dict(p['state'],clientId=c['id']);c['online']=p['state']['online']
       for other in room['clients'].values():
        if other['id']!=c['id'] and other['online']:send(other,p)
  finally:
   if c:
    with lock:c['online']=False;broadcast(room)
class Server(socketserver.ThreadingTCPServer):
 allow_reuse_address=True;daemon_threads=True
s=Server(('127.0.0.1',0),Client)
open(sys.argv[1],'w').write(str(s.server_address[1]));s.serve_forever()
