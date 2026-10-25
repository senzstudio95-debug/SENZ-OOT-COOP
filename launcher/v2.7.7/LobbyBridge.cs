using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Collections.Concurrent;
using System.Collections.Generic;
// One remote session remains alive while the native game attaches locally.
// No polling of native gameplay on the WPF/UI thread.
public sealed class SenzLobby : IDisposable {
    TcpClient remote, game; TcpListener listener; Thread worker;
    volatile bool stopped, connected, gameReady;
    public bool Connected { get { return connected && !stopped; } }
    public bool GameConnected { get { return gameReady; } }
    public string Error { get; private set; }
    public int LocalPort { get; private set; }
    readonly ConcurrentQueue<string> events = new ConcurrentQueue<string>();
    readonly ConcurrentQueue<string> outgoing = new ConcurrentQueue<string>();
    readonly Dictionary<string,string> deltas = new Dictionary<string,string>();
    string allState, roomState, lobbyState;
    public void SetIdentity(int id) { lobbyState=idRx.Replace(lobbyState,"\"clientId\":"+id,1); }
    static readonly Regex typeRx = new Regex("\"type\"\\s*:\\s*\"([^\"]+)\"");
    static readonly Regex idRx = new Regex("\"clientId\"\\s*:\\s*(\\d+)");
    sealed class Frames {
        readonly List<byte> bytes = new List<byte>();
        public void Pump(TcpClient client, Action<string> receive) {
            byte[] buffer = new byte[65536]; int budget=1048576;
            while(client.Available>0 && budget>0) {
                int n=client.GetStream().Read(buffer,0,Math.Min(buffer.Length,client.Available));
                if(n==0)throw new Exception("Sambungan ditutup."); budget-=n;
                for(int i=0;i<n;i++) {
                    if(buffer[i]==0) { receive(Encoding.UTF8.GetString(bytes.ToArray())); bytes.Clear(); }
                    else { bytes.Add(buffer[i]); if(bytes.Count>16777216)throw new Exception("Paket melebihi had 16 MB."); }
                }
            }
        }
    }
    static bool Alive(TcpClient c) { return c!=null && c.Connected && !(c.Client.Poll(0,SelectMode.SelectRead)&&c.Available==0); }
    static void Write(TcpClient c,string json) { var b=Encoding.UTF8.GetBytes(json+"\0"); c.GetStream().Write(b,0,b.Length); }
    static void Tune(TcpClient c) { c.NoDelay=true; c.GetStream().WriteTimeout=3000; }
    public void Start(string host,int port,string handshake,string idleState) {
        if(worker!=null)throw new InvalidOperationException("Sesi sudah bermula.");
        lobbyState=idleState;
        listener=new TcpListener(IPAddress.Loopback,0);listener.Start(1);
        LocalPort=((IPEndPoint)listener.LocalEndpoint).Port;
        worker=new Thread(()=>Run(host,port,handshake));worker.IsBackground=true;worker.Start();
    }
    public void Send(string json) { outgoing.Enqueue(json); }
    public string[] Read() { var list=new List<string>();string s;while(events.TryDequeue(out s))list.Add(s);return list.ToArray(); }
    void Notify(string s) { if(events.Count>2048)throw new Exception("Terlalu banyak kemas kini lobi.");events.Enqueue(s); }
    void DropGame() { gameReady=false;if(game!=null){game.Close();game=null;} }
    void ToGame(string raw) { if(!gameReady)return;try{Write(game,raw);}catch{DropGame();Write(remote,lobbyState);} }
    void Run(string host,int port,string handshake) {
        try {
            remote=new TcpClient();var result=remote.BeginConnect(host,port,null,null);
            try { if(!result.AsyncWaitHandle.WaitOne(8000))throw new TimeoutException("Relay Singapura tidak dapat dicapai. Semak internet/firewall.");remote.EndConnect(result); }
            finally {result.AsyncWaitHandle.Close();}
            Tune(remote);Write(remote,handshake);connected=true;
            var remoteFrames=new Frames();var gameFrames=new Frames();var lastBeat=DateTime.UtcNow;
            while(!stopped) {
                if(!Alive(remote))throw new Exception("Sambungan ke relay Singapura terputus. Buka semula bilik.");
                remoteFrames.Pump(remote,raw=>{
                    string type=typeRx.Match(raw).Groups[1].Value;
                    if(type=="ALL_CLIENT_STATE") {allState=raw;deltas.Clear();Notify(raw);}
                    else if(type=="UPDATE_ROOM_STATE") {roomState=raw;Notify(raw);}
                    else if(type=="UPDATE_CLIENT_STATE") {string id=idRx.Match(raw).Groups[1].Value;if(id.Length>0)deltas[id]=raw;Notify(raw);}
                    else if(type=="DISABLE_ANCHOR") {Notify(raw);throw new Exception("Relay menolak sesi Anchor.");}
                    ToGame(raw);
                });
                if(listener.Pending()) {
                    var next=listener.AcceptTcpClient();Tune(next);
                    if(game!=null)next.Close();else{game=next;gameFrames=new Frames();gameReady=false;}
                }
                if(game!=null) {
                    if(!Alive(game)){DropGame();Write(remote,lobbyState);}
                    else {
                        try {
                            gameFrames.Pump(game,raw=>{
                                string type=typeRx.Match(raw).Groups[1].Value;
                                if(type=="HANDSHAKE") {
                                    if(allState==null||roomState==null)throw new Exception("Lobi belum disahkan.");
                                    // Replay the server's identity and room before forwarding gameplay.
                                    Write(game,allState);Write(game,roomState);
                                    foreach(var delta in deltas.Values)Write(game,delta);
                                    gameReady=true;
                                    string update=typeRx.Replace(raw,"\"type\":\"UPDATE_CLIENT_STATE\"",1);
                                    update=Regex.Replace(update,"\"clientState\"\\s*:","\"state\":");
                                    Write(remote,update);
                                } else if(gameReady)Write(remote,raw);
                            });
                        } catch {DropGame();Write(remote,lobbyState);}
                    }
                }
                string message;while(outgoing.TryDequeue(out message))Write(remote,message);
                if((DateTime.UtcNow-lastBeat).TotalSeconds>=10){Write(remote,"{\"type\":\"HEARTBEAT\",\"quiet\":true}");lastBeat=DateTime.UtcNow;}
                Thread.Sleep(3);
            }
        } catch(Exception e) {if(!stopped)Error=e.Message;}
        finally {connected=false;DropGame();if(remote!=null)remote.Close();if(listener!=null)listener.Stop();}
    }
    public void Dispose() {stopped=true;connected=false;if(remote!=null)remote.Close();if(listener!=null)listener.Stop();if(worker!=null)worker.Join(1000);}
}
