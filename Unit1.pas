unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls,

  RegExp, XPMan;

type
  TForm1 = class(TForm)
    Panel2: TPanel;
    Button1: TButton;
    CheckBox1: TCheckBox;
    Label5: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label2: TLabel;
    Label1: TLabel;
    Edit1: TEdit;
    Memo1: TMemo;
    CheckBox2: TCheckBox;
    Label6: TLabel;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}


procedure TForm1.Button1Click(Sender: TObject);
var r:TNFA;
    s:TDFA;
    i,k:integer;
    t,t1:cardinal;
    l:integer;
begin
  if(not checkbox2.Checked)then
  begin
    r:=TNFA.Create;
    t:=GetTickCount;
    for i:=0 to 500 do
      r.Expression:=edit1.Text;
    t1:=GetTickCount;
    label3.Caption:=inttostr(t1-t);
    t:=GetTickCount;
    for i:=0 to 100000 do
    r.Match(memo1.text);
    checkbox1.checked:=r.Match(memo1.text);
    t1:=GetTickCount;
    label4.Caption:=inttostr(t1-t);
    r.Free;
  end
  else
  begin
    s:=TDFA.Create;
    t:=GetTickCount;
    for i:=0 to 500 do
      s.Expression:=edit1.Text;
    t1:=GetTickCount;
    label3.Caption:=inttostr(t1-t);
    t:=GetTickCount;
    for i:=0 to 100000 do
      s.Match(memo1.text,l);
    label6.Caption:='Last_char='+inttostr(l);
    checkbox1.checked:=s.Match(memo1.text,l);
    t1:=GetTickCount;
    label4.Caption:=inttostr(t1-t);
    s.Free;
  end;
end;


end.
