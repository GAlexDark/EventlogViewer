unit StrRepl;

interface

type
    TReplaceFlag = set of (rfReplaceAll, rfIgnoreCase);

function _max(A,B: word): word; inline;

function StringReplaceOpt(const Text, What, ReplaceTo: string;
  Flags: TReplaceFlag): string;
//procedure WStringReplaceOpt(var Text: PWideChar; const What, ReplaceTo: PWideChar;
//  Flags: TReplaceFlag);


procedure WStrCopy( Dest, Src: PWideChar );
//function WPosEx(const SubStr, S: PWideChar; Offset: Integer = 0): Integer;
function ParseString(const Delimiter: WideChar; var S: string;  var StartIndex: integer) : string;

implementation
uses
  SysUtils, StrUtils,windows,dialogs;
//=========================================================================
function _max(A,B: word): word; inline;
begin
  if A >= B then Result := A else Result := B
end;
//=========================================================================
function StringReplaceOpt(const Text, What, ReplaceTo: string;
  Flags: TReplaceFlag): string;
var
  SearchStr, Patt, NewStr: string;
  Offset: Integer;
begin
{
rfReplaceAll - �������� ��� ���������
rfIgnoreCase - ���������� ������� ��� ������
}
  if rfIgnoreCase in Flags then
    begin
      SearchStr := AnsiUpperCase(Text);
      Patt := AnsiUpperCase(What);
      {������� AnsiUpperCase(MixedString) ������� ����� MixedString �� ����� ���������
      ���������������� � ������� �������}
    end
  else //������� ����� �����������
    begin
    SearchStr := Text;  //������� ������
    Patt := What;       //%%1234
    end;

  NewStr := Text; //������� ������
  Result := '';
  while SearchStr <> '' do //���� �� ��������� ������� ������
    begin
    Offset := Pos(Patt, SearchStr);
    if Offset = 0 then
      begin
      Result := Result + NewStr;
      Break;
      end;
    if Offset > 1 then //����������� �������, ��� ����������� � ������ ������
      begin //����������� � �������� ������
      Result := Result + Copy(NewStr, 1, Offset - 1) + ReplaceTo;
      end
    else
      Result := Result + ReplaceTo; //����������� � ����� ������ ������
    NewStr := Copy(NewStr, Offset + Length(What), MaxInt);

    //����������� ������ �� ����� Length(Patt) = (%%1234) = 6
    if not (rfReplaceAll in Flags) then
      begin
      Result := Result + NewStr;
      Break;
      end;
    SearchStr := Copy(SearchStr, Offset + Length(Patt), MaxInt);
    //����������� ������ �� ����� Length(Patt) = (%%1234) = 6
  end; //while

end;
//=============================================================================
procedure WStrCopy(Dest, Src: PWideChar);
asm
        PUSH    EDI
        PUSH    ESI
        MOV     ESI,EAX
        MOV     EDI,EDX
        OR      ECX, -1
        XOR     EAX, EAX
        REPNE   SCASW
        NOT     ECX
        MOV     EDI,ESI
        MOV     ESI,EDX
        REP     MOVSW
        POP     ESI
        POP     EDI
end;

//procedure _copy(Dest,Src: PwideChar; Index:Integer);
//var
//  Offset: PWideChar;
//begin
//  Offset := Src;
//  inc(Offset,Index);
//  WStrCopy(Dest,Offset);
//end;

//=============================================================================

//function WPosEx(const SubStr, S: PWideChar; Offset: Integer = 0): Integer;
//var
//  i: integer;
//  Res: PWideChar;
//  Len1,Len2 : integer;
//begin
//  Res := S;
//  Result := - 1;
//  inc(Res,offset);
//  len1:= StrLen(S);
//  len2:= StrLen(SubStr);
//  for I := 0 to Len1-len2 - offset  do
//    begin
//    if CompareMem(pointer(Res),pointer(SubStr),Len2) then
//      begin
//      Result := i + offset;
//      break;
//      end;
//    inc (Res);
//    end;
//end;

//=============================================================================

//procedure WStringReplaceOpt(var Text: PWideChar; const What, ReplaceTo: PWideChar;
//  Flags: TReplaceFlag);
//var
//  SearchStr, Patt, NewStr,Res,Buffer: PWideChar;
//  Offset,Index,
//  PattLen,ReplaceToLen,
//  Len: Integer;
//begin
//{
//rfReplaceAll - �������� ��� ���������
//rfIgnoreCase - ���������� ������� ��� ������
//}
//  if rfIgnoreCase in Flags then
//    begin
//      SearchStr := StrAlloc(StrLen(Text))+1;
//      SearchStr := StrUpper(Text);
//      Patt := StrAlloc(StrLen(What))+1;
//      Patt := StrUpper(What);
//      {������� StrUpper(MixedString) ������� ����� MixedString �� ����� ���������
//      ���������������� � ������� �������}
//    end
//  else //������� ����� �����������
//    begin
//    SearchStr := Text;  //������� ������
//    Patt := What;       //%%1234
//    end;
//
//
//  NewStr := Text; //������� ������
//
//  GetMem(Buffer,4096);
//  FillChar(Buffer^, 4096, 0);
//  Res:= Buffer;
//  index :=0;
//  PattLen := StrLen(Patt);
//  ReplaceToLen := StrLen(ReplaceTo);
//
//  while (True) do
//    begin
//    Offset := WPosEx(Patt, SearchStr,Index);
//    index := Offset + PattLen;
//    if Offset = -1 then
//      begin
//      //Result := Result + NewStr;
//      len := strlen(Buffer);
//      inc(Res,len);
//      //wstrcopy(Res,NewStr);
//      StrCopy(Res,NewStr);
//      //wstrcopy(Text,Buffer);
//      StrCopy(Text,Buffer);
//      FreeMem(Buffer);
//      Break;
//      end;
//    if Offset > 0 then
//      begin //����������� � �������� ������
//      //Result := Result + Copy(NewStr, 0, Offset - 2) + ReplaceTo;
//      len:= strlen(Buffer);
//      inc(Res,len);
//      //wstrcopy(Res,pwidechar(Copy(NewStr, 0, Offset)));
//      StrCopy(Res,pwidechar(Copy(NewStr, 0, Offset)));
//      inc(Res,Offset);
//      //wstrcopy(res,ReplaceTo);
//      StrCopy(res,ReplaceTo);
//      inc(Res,ReplaceToLen);
//      end
//    else //����������� � ����� ������ ������ [0]
//      begin
//      //Result := Result + ReplaceTo;
//      len := strlen(Buffer);
//      inc(Res,len);
//      //wstrcopy(Res,ReplaceTo);
//      StrCopy(Res,ReplaceTo);
//      inc(Res,ReplaceToLen); //��������� � ����� Result
//      end;
//
//    //NewStr := pwidechar(Copy(NewStr, index+1, MaxInt));
//    inc(NewStr,index);
//    //����������� ������ �� ����� PattLen = Length(Patt) = (%%1234) = 6
//
//    if not (rfReplaceAll in Flags) then
//      begin
//      //Result := Result + NewStr;
//      //wstrcopy(Res,NewStr);
//      StrCopy(Res,NewStr);
//      //wstrcopy(Text,Buffer);
//      StrCopy(Text,Buffer);
//      FreeMem(Buffer);
//      Break;
//      end;
//  end; //while
//
//end;

//=============================================================================

function ParseString(const Delimiter: WideChar; var S: string;  var StartIndex: integer) : string;
var
  Index: Integer;
begin
  Index := pos(Delimiter,S);
  if Index <> 0 then
    begin
    Result := copy(S,1,index-1);
    s := copy(S,Index+1,MaxInt)
    end
  //else Result := copy(S,1,MaxInt);
  else Result := s;
  StartIndex := index
end;

end.

