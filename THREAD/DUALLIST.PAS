unit DualList;

interface

uses 
  Windows, Messages, SysUtils, Classes, Graphics, Forms, Dialogs, Controls, StdCtrls, 
  Buttons,eventviewunit, Menus;

type
  TDualListDlg = class(TForm)
    OKBtn: TButton;
    CancelBtn: TButton;
    SrcList: TListBox;
    DstList: TListBox;
    SrcLabel: TLabel;
    DstLabel: TLabel;
    IncludeBtn: TSpeedButton;
    IncAllBtn: TSpeedButton;
    ExcludeBtn: TSpeedButton;
    ExAllBtn: TSpeedButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    CBServerType: TComboBox;
    SBAdd: TSpeedButton;
    SBRemove: TSpeedButton;
    SpeedButton1: TSpeedButton;
    PopupMenu1: TPopupMenu;
    N11: TMenuItem;
    N21: TMenuItem;
    N31: TMenuItem;
    Label3: TLabel;
    procedure IncludeBtnClick(Sender: TObject);
    procedure ExcludeBtnClick(Sender: TObject);
    procedure IncAllBtnClick(Sender: TObject);
    procedure ExcAllBtnClick(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure CancelBtnClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure CBServerTypeChange(Sender: TObject);
    procedure SBAddClick(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure N11Click(Sender: TObject);
    procedure N21Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure MoveSelected(List: TCustomListBox; Items: TStrings);
    procedure SetItem(List: TListBox; Index: Integer);
    function GetFirstSelection(List: TCustomListBox): Integer;
    procedure SetButtons;
  end;

var
  DualListDlg: TDualListDlg;


implementation
uses
  NetworkAPI,DSUtils;
{$R *.dfm}
var
    Path : string;
    CBServerTypeList : TStringList;
    IsModify,IsCBModify : Boolean;
    DN,FN : string;    

procedure TDualListDlg.IncludeBtnClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := GetFirstSelection(SrcList);
  MoveSelected(SrcList, DstList.Items);
  SetItem(SrcList, Index);
end;

procedure TDualListDlg.ExcludeBtnClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := GetFirstSelection(DstList);
  MoveSelected(DstList, SrcList.Items);
  SetItem(DstList, Index);
end;

procedure TDualListDlg.FormActivate(Sender: TObject);
var
  Err : DWORD;
  TmpList: TStringList;
begin
  IsModify := false;
  IsCBModify := false;
  if GetDNSDomainName(DN,FN,err) = ERROR_SUCCESS then
    begin
    Edit1.Text := FN;
    Edit2.Text := DN;
    end;
  Path := GetCurrentDir + '\config\CBServerType.txt';

  CBServerTypeList := TStringList.Create;

  if FileExists(Path) then
    begin
    try
      CBServerTypeList.LoadFromFile(Path);
      CBServerType.Items.Assign(CBServerTypeList);        
    except
      ShowMessage('File CBServerType.txt - is bad');
      eventviewunit.Form1.SourceListFlag:=false;
      DualListDlg.Close
    end;
    end
    else ShowMessage('File CBServerType.txt not found');

//  TmpList := TStringList.Create;
//  GetListOfCompurersFromAD(TmpList);
//  SrcList.Items.Assign(TmpList);
//  TmpList.Free;
end;

procedure TDualListDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if IsModify then CBServerTypeList.SaveToFile(Path);
end;

procedure TDualListDlg.IncAllBtnClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to SrcList.Items.Count - 1 do
    DstList.Items.AddObject(SrcList.Items[I], 
      SrcList.Items.Objects[I]);
  SrcList.Items.Clear;
  SetItem(SrcList, 0);
end;

procedure TDualListDlg.CancelBtnClick(Sender: TObject);
begin
    eventviewunit.Form1.SourceListFlag:=false;
    DualListDlg.Close
end;

procedure TDualListDlg.CBServerTypeChange(Sender: TObject);
begin
  if CBServerType.ItemIndex = -1 then IsCBModify := True
end;

procedure TDualListDlg.ExcAllBtnClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to DstList.Items.Count - 1 do
    SrcList.Items.AddObject(DstList.Items[I], DstList.Items.Objects[I]);
  DstList.Items.Clear;
  SetItem(DstList, 0);
end;

procedure TDualListDlg.MoveSelected(List: TCustomListBox; Items: TStrings);
var
  I: Integer;
begin
  for I := List.Items.Count - 1 downto 0 do
    if List.Selected[I] then
    begin
      Items.AddObject(List.Items[I], List.Items.Objects[I]);
      List.Items.Delete(I);
    end;
end;

procedure TDualListDlg.N11Click(Sender: TObject);
begin
  SrcList.Items.Delimiter:=';';
  SrcList.Items.DelimitedText := GetListOfDCs(DN);
  SrcList.Items.Delete(0);
end;

procedure TDualListDlg.N21Click(Sender: TObject);
var
  TmpList: String;
  Path,Err: string;
begin
  Path := GetLDAPPathFromOU;
    //pszPath видa 'LDAP://OU=Servers,OU=location,DC=org,DC=domain'
  if NextNode_Computer(Path,TmpList,Err) then
    begin
    SrcList.Items.Delimiter:=';';
    SrcList.Items.DelimitedText := TmpList;
    SrcList.Items.Delete(0);
    Label3.Caption := inttostr(SrcList.Items.Count);
    end
  else ShowMessage(Err);

end;

procedure TDualListDlg.OKBtnClick(Sender: TObject);
begin
    eventviewunit.Form1.SourceList.Assign(DstList.Items);
    eventviewunit.Form1.SourceListFlag:=true;
    DualListDlg.Close
end;

procedure TDualListDlg.SBAddClick(Sender: TObject);
begin
  if IsCBModify then
    begin
    CBServerTypeList.Add(trim(CBServerType.Text));
    IsCBModify := not IsCBModify;
    IsModify := not IsModify;
    end;
end;

procedure TDualListDlg.SetButtons;
var
  SrcEmpty, DstEmpty: Boolean;
begin
  SrcEmpty := SrcList.Items.Count = 0;
  DstEmpty := DstList.Items.Count = 0;
  IncludeBtn.Enabled := not SrcEmpty;
  IncAllBtn.Enabled := not SrcEmpty;
  ExcludeBtn.Enabled := not DstEmpty;
  ExAllBtn.Enabled := not DstEmpty;
end;

function TDualListDlg.GetFirstSelection(List: TCustomListBox): Integer;
begin
  for Result := 0 to List.Items.Count - 1 do
    if List.Selected[Result] then Exit;
  Result := LB_ERR;
end;

procedure TDualListDlg.SetItem(List: TListBox; Index: Integer);
var
  MaxIndex: Integer;
begin
  with List do
  begin
    SetFocus;
    MaxIndex := List.Items.Count - 1;
    if Index = LB_ERR then Index := 0
    else if Index > MaxIndex then Index := MaxIndex;
    Selected[Index] := True;
  end;
  SetButtons;
end;

procedure TDualListDlg.SpeedButton1Click(Sender: TObject);
begin
  PopupMenu1.Popup(SpeedButton1.Left + DualListDlg.Left + SpeedButton1.Height-1,
                  SpeedButton1.Top + DualListDlg.Top+SpeedButton1.Height);
end;

end.
