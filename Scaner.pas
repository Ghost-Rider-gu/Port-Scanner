unit main;

interface

uses
    Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
    Dialogs, XPMan, ComCtrls, ToolWin, ImgList, StdCtrls, ExtCtrls, MPlayer, WinSock2,
    WinInet, ShlObj, ShellAPI;

// my cursor
const
    MyCursor = 100;

type
    TForm1 = class(TForm)
        XPManifest1: TXPManifest;
        ToolBar1: TToolBar;
        ToolButton1: TToolButton;
        ImageList1: TImageList;
        ToolButton2: TToolButton;
        ToolButton3: TToolButton;
        ToolButton4: TToolButton;
        ToolButton5: TToolButton;
        ToolButton6: TToolButton;
        ToolButton7: TToolButton;
        StatBar: TStatusBar;
        DataScan: TRichEdit;
        Info: TLabel;
        Button1: TButton;
        Label2: TLabel;
        startport: TEdit;
        Endport: TEdit;
        CompName: TEdit;
        Label3: TLabel;
        Label4: TLabel;
        ToolButton8: TToolButton;
        Bevel1: TBevel;
        ToolButton9: TToolButton;
        Media: TMediaPlayer;
        OpenDig: TOpenDialog;
        SaveDig: TSaveDialog;
        PrintDig: TPrintDialog;
        procedure FormCreate(Sender: TObject);
        procedure ToolButton8Click(Sender: TObject);
        procedure Button1Click(Sender: TObject);
        procedure ToolButton6Click(Sender: TObject);
        procedure ToolButton1Click(Sender: TObject);
        procedure ToolButton2Click(Sender: TObject);
        procedure ToolButton3Click(Sender: TObject);
        procedure ToolButton5Click(Sender: TObject);
        procedure ToolButton9Click(Sender: TObject);
    private
        procedure ShowMyHint(Sender: TObject); //обработка хинтов
        function  GetNetWorkConnect: boolean; //проверка локальной сети
        function  GetINetConnect: boolean; //проверка интернета
        function  LookupName(myhost:string): TInAddr; //проверка хоста на корректность
        procedure Scan(MinPort:string; MaxPort:string; Host:string); //сканирование сетевых портов
    public

    end;

const
    NoneConnect     = 'Подключений не обнаружено';
    LocalConnect    = 'Обнаружено подключение к локальной сети';
    NetConnect      = 'Обнаружено подключение к Интернету';
    NetLocalConnect = 'Обнаружено подключение к локальной сети и Интернету';

var
    Form1: TForm1;
    FFileName: String;
    Path: String;

implementation

{$R *.dfm}

//проверяем поключены ли к интернету
function TForm1.GetINetConnect: boolean;
var
    dwConnectionTypes: DWORD;
begin
    dwConnectionTypes := INTERNET_CONNECTION_MODEM+INTERNET_CONNECTION_LAN+INTERNET_CONNECTION_PROXY;
    Result := InternetGetConnectedState(@dwConnectionTypes, 0);
end;

//проверяем подключены ли к локальной сети
function TForm1.GetNetWorkConnect: boolean;
begin
    if (GetSystemMetrics(SM_NETWORK)) AND ($01 = $01) then
        Result:= True
    else
        Result:= False;
end;

//преобразование в IP адрес
function TForm1.LookupName(myhost: string): TInAddr;
var
    HostEnt: PHostEnt;
    InAddr:  TInAddr;
    Error:   DWORD;
    Str:     PAnsiChar;
begin
    if Pos ('.', myhost) > 0 then
        InAddr.s_addr := inet_addr(PChar(myhost))
    else
        begin
            HostEnt := gethostbyname(PChar(myhost));
            Error:=GetLastError;
            if Error = 0 then
                begin
                    Str := HostEnt^.h_addr_list^;
                    InAddr.S_un_b.s_b1 := Byte(Str[0]);
                    InAddr.S_un_b.s_b2 := Byte(Str[1]);
                    InAddr.S_un_b.s_b3 := Byte(Str[2]);
                    InAddr.S_un_b.s_b4 := Byte(Str[3]);
                end;
        end;
    Result := InAddr;
end;

//сканирование сетевых портов
procedure TForm1.Scan(MinPort, MaxPort, Host: string);
var
    i,j,s,opt,index:integer;
    FSocket: array [0..40] of TSOCKET;
    busy: array [0..40] of boolean;
    port: array [0..40] of integer;
    addr: TSockAddr;
    hEvent: THandle;
    fset: TFDSet;
    tec: PServEnt;
    tv:TTimeval;
    PName:string;
    GInitData: TWSADATA;
begin
    WSAStartup(MAKEWORD(2,0),GInitData);

    i := StrToInt(MinPort);

    addr.sin_family := AF_INET;
    addr.sin_addr.S_addr := INADDR_ANY;
    addr.sin_addr := LookupName(Host);

    DataScan.SelAttributes.Color := clRed;
    DataScan.Lines.Add('СКАНИРОВАНИЕ . . .');

    index := 40;

    hEvent := WSACreateEvent();
    while i < StrToInt(MaxPort) do
    begin
        for j := 0 to index do
            busy[j] := false;
        for j := 0 to index do
        begin
            if i > StrToInt(MaxPort) then
            begin
                index := j-1;
                break;
            end;
            FSocket[j]:=socket(AF_INET,SOCK_STREAM,IPPROTO_IP);
            WSAEventSelect(FSocket[j],hEvent, FD_WRITE+FD_CONNECT);
            addr.sin_port:=htons(i);
            connect(FSocket[j], @addr, sizeof(addr));
            Application.ProcessMessages;
            if WSAGetLastError()=WSAEINPROGRESS then
            begin
                closesocket (FSocket[j]);
                busy[j]:=true;
            end;
            port[j]:=i;
            i:=i+1;
        end;
        FD_Zero(fset);
        for j := 0 to index do
        begin
            if busy[j] <> true then
                FD_SET (FSocket[j], fset);
        end;
        Application.ProcessMessages;
        tv.tv_sec := 1;
        tv.tv_usec := 0;
        s:=select (I, nil, @fset, nil, @tv);
        Application.ProcessMessages;
        for j := 0 to index do
        begin
            if busy[j] then continue;
            if FD_ISSET (FSocket[j], fset) then
            begin
                s:=Sizeof(Opt);
                opt:=1;
                getsockopt(FSocket[j], SOL_SOCKET, SO_ERROR, @opt, s);
                if opt=0 then
                begin
                    tec := getservbyport(htons(Port[j]),'TCP');
                    if tec=nil then
                        PName:='Unknown'
                    else
                    begin
                        PName:=tec.s_name;
                    end;
                    Media.Play;
                    DataScan.Lines.Add('Хост:'+CompName.Text+': порт :'+IntToStr(Port[j])+' '+Pname+' '+' открыт ') ;
                end;
            end;
            closesocket(FSocket[j]);
        end;
    end;
    WSACloseEvent(hEvent);
    DataScan.SelAttributes.Color:=clRed;
    DataScan.Lines.Add ('СКАНИРОВАНИЕ ЗАВЕРШЕНО . . .');

end;

//показываем в статус баре хинты программы
procedure TForm1.ShowMyHint(Sender: TObject);
begin
    StatBar.Panels[1].Text:=Application.Hint;
end;

//установка начальных данных и другие настройки программы
procedure TForm1.FormCreate(Sender: TObject);
begin
    Application.OnHint:=ShowMyHint;

    Screen.Cursors[MyCursor]:=LoadCursorFromFile('resources\Cursor.ani');
    Form1.Cursor:=MyCursor;
    DataScan.Cursor:=MyCursor;
    StatBar.Cursor:=MyCursor;
    ToolBar1.Cursor:=MyCursor;
    Button1.Cursor:=MyCursor;
    Label2.Cursor:=MyCursor;
    Label3.Cursor:=MyCursor;
    Label4.Cursor:=MyCursor;
    Info.Cursor:=MyCursor;
    StartPort.Cursor:=MyCursor;
    EndPort.Cursor:=MyCursor;
    CompName.Cursor:=MyCursor;

    GetDir(0,Path);
    Media.FileName:=Path+'\resources\openport.wav';

    if (GetINetConnect) and (GetNetWorkConnect) then
    begin
        info.Caption:=NetLocalConnect;
        StatBar.Panels[0].Text:='Вы можете сканировать порты удаленного компьютера';
    end;
    if (not GetINetConnect) and (not GetNetWorkConnect) then
    begin
        info.Caption:=NoneConnect;
        StatBar.Panels[0].Text:='Вы можете сканировать только порты локального компьютера';
    end;
    if (GetINetConnect) and (not GetNetWorkConnect) then
    begin
        info.Caption:=NetConnect;
        StatBar.Panels[0].Text:='Вы можете сканировать порты удаленного компьютера';
    end;
    if (not GetINetConnect) and (GetNetWorkConnect) then
    begin
        info.Caption:=LocalConnect;
        StatBar.Panels[0].Text:='Вы можете сканировать порты компьютера локальной сети';
    end;
end;

//Закрываем приложение
procedure TForm1.ToolButton8Click(Sender: TObject);
begin
    Application.Terminate;
end;

//Сканирование заданных портов
procedure TForm1.Button1Click(Sender: TObject);
begin
    if (startport.Text='') and (endport.Text='') and (compname.Text='') then
    begin
        ShowMessage('Не заполнено одно из полей. Пожайлуста заполните все поля перед сканированием');
        Exit;
    end;

    Scan(startport.Text, endport.Text, CompName.Text);
end;

//Отправить письмо автору
procedure TForm1.ToolButton6Click(Sender: TObject);
begin
    ShellExecute(Handle,'OPEN','MailTo:ghostrider.gu@gmail.com',nil,nil,SW_SHOWNORMAL);
end;

//Открыть ранее сохраненный документ
procedure TForm1.ToolButton1Click(Sender: TObject);
begin
    if OpenDig.Execute then
    begin
        DataScan.Lines.LoadFromFile(OpenDig.FileName);
        FFileName:=OpenDig.FileName;
    end;
end;

//Сохранить документ
procedure TForm1.ToolButton2Click(Sender: TObject);
begin
    if SaveDig.Execute then
    begin
        DataScan.Lines.SaveToFile(SaveDig.FileName);
        FFileName:=SaveDig.FileName;
    end;
end;

//Распечатать документ
procedure TForm1.ToolButton3Click(Sender: TObject);
begin
    if FFileName='' then
    begin
        ShowMessage('Сохраните Ваши данные перед распечаткой');
        Exit;
    end;

    if PrintDig.Execute then
    begin
        DataScan.Print(FFileName);
    end;
end;

//О программе
procedure TForm1.ToolButton5Click(Sender: TObject);
begin
    Form2.ShowModal;
end;

//Окошко HelpManual
procedure TForm1.ToolButton9Click(Sender: TObject);
begin
    Form3.Show;
end;

end.
