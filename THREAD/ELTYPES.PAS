unit ELTypes;

interface
uses
    Windows,RTCache,EventLog;
type
  {����������� ���������}
  PTMR = ^TMR;
  TMR = record
    Version : string; {��������������� ��� ����������� ���������� ������ ���������}
    //�������� ���������
    ServerName : string;      //for create
    SourceName : string;
    Direction : TDirection;   //for create
    Cashe : TSIDCache;        //for create
    OutputProc : TOutputProc;

    //����� ���� ��������� ��������
    EventTypeFilter : Word;
    EventIDarr : array of Dword;
    Length : DWORD;

  end;

implementation

end.
