Unit RegExp;
interface

//Управляющие символы:
//  '?', '+', '*' - квантификаторы (ноль или один, один и более, любое число раз соответственно)
//  '(', ')' - группирующие скобки
//  '|' - оператор ИЛИ
//  '[', ']' - альтернативы
//  '{', '}' - модификаторы (s - пробельные символы справа и слева, r - регистронезависимость)
//  '#' - ввод символа по коду (#20, #120 и т.д.)
//  '.' - любой символ
//  '\' - классы символов и вывод управляющих символов
//  для ввода самого управляющего символа перед ним ставиться '\',
//все символы кроме управляющих представляют сами себя
//Классы символов:
//Альтернативы:

uses SysUtils;

type
TarrayOfInt=array of integer;

//DONE: очистка при исключительной ситуации
//DONE: нормальная обработка #13#10 как двух символов, если потребуется
//TODO: юникод в будущем

TbranchType=(
  BT_EMPTY,    //E branch
  BT_CHAR,     // wqwgnbd
  BT_SPACE,    // \s
  BT_WORD,     // \w
  BT_DIGIT,    // \d
  BT_NEW_LINE, // \n
  BT_TAB,       // \t
  BT_SUBRANGE, // a-z
  BT_NOT_CHAR,   // [^zqw]
  BT_NOT_SPACE,  // \S
  BT_NOT_WORD,   // \W
  BT_NOT_DIGIT,  // \D
  BT_NOT_NEW_LINE, // \N
  BT_NOT_TAB,       // \T
  BT_ANY_CHAR    // .
  );

TcharRange=record
  min,max:byte;
end;

TRegExpSyntaxError=class(Exception)
end;

//состояние автомата
TFANode=class;
Tbranch=record
    branch_type:TbranchType;
    min,max:char;
    target_node:TFANode;
end;

TarrayOfTbranch=array of Tbranch;

TFANode=class(Tobject)
  private
  branches_in,
  branches:TarrayOfTbranch;
  flag:boolean;
  index:integer;
  public
  Constructor Create;
  Destructor Destroy;override;
end;

TarrayOfTFANode=array of TFANode;

//Недетерминированный конечный автомат (finite automoton)

TNFA=class(Tobject)
  private
  expr:string;
  expr_length:integer;
  curr_char:integer;
  //состояния детерминированного автомата
  nodes:TarrayOfTFANode;
  nodes_high:integer;
  start,finish:TFANode;
  //текущий уровень вложенности скобок
  parenthnes_level:integer;
  //битовый вектор и два массива для моделирования работы автомата (Move, EClosure)
  result_bit_vector:array of boolean;
  curr_states,
  result_states:TarrayOfTFANode;
  curr_states_high,
  result_states_high:integer;
  //
  procedure AddBranch(node:TFANode;use_target:TFANode;
    use_branch_type:TbranchType=BT_EMPTY;
    use_min:char=#0;use_max:char=#0);
  procedure ReplaceBranch(var branches:TarrayOfTbranch;branch:TFANode;new_val:Tbranch);overload;
  procedure ReplaceBranch(var branches:TarrayOfTbranch;branch,new_val:TFANode);        overload;
  procedure GetAllNodes(node:TFANode);
  function CreateNode:TFANode;
  //
  procedure PrepareBitVector;
  procedure BuildAlternatives(start,finish:TFANode);
  procedure AddAlternativeRegister(start,finish:TFANode);
  procedure AddNodeAlternativeRegister(node,finish:TFANode);
  procedure BuildNFA(start,finish:TFANode;level:integer);
  procedure EClosure(except_unimportant_nodes:boolean=false);
  function  Move(a:char):boolean;
  procedure GetTerm(alternatives_mode:boolean;var btype:TbranchType;var val:char);
  procedure Optimize;
  procedure Clean;
  public
  procedure SetExpression(s:string);
  property Expression:string read expr write SetExpression;
  function Match(s:string):boolean;
  Destructor Destroy;override;
end;

//Детерминированный конечный автомат

TDFA=class(Tobject)
  private
  nfa:TNFA;
  expr:string;
  curr_char:integer;
  //состояния детерминированного автомата
  nodes:TarrayOfTFANode;
  nodes_high:integer;
  //множества комбинаций текущих состояний НКА для построения ДКА
  nodes_nfa_states:array of
  record
    states:TarrayOfTFANode;
    checked:boolean;
  end;
  //
  start:TFANode;
  //
  procedure BuildDFAFromNFA;
  procedure Clean;
  procedure AddBranch(source,dest:integer;use_min,use_max:char);
  public
  procedure SetExpression(s:string);
  property Expression:string read expr write SetExpression;
  function Match(s:string;var last_char:integer;first_char:integer=1):boolean;
  Destructor Destroy;override;
end;

implementation

//--LOCAL FUNCTIONS-----------------------------------------------------------//

Procedure InitRange(var range:TcharRange;use_min,use_max:char);
begin
  with range do
  begin
    min:=ord(use_min);
    max:=ord(use_max);
  end;
end;

procedure InitBranch(var branch:Tbranch;use_branch_type:TbranchType;use_min,use_max:char;use_target:TFANode);
begin
  with branch do
  begin
    branch_type:=use_branch_type;
    min:=use_min;
    max:=use_max;
    target_node:=use_target;
  end;
end;

procedure TNFA.AddBranch(node:TFANode;use_target:TFANode;
    use_branch_type:TbranchType=BT_EMPTY;
    use_min:char=#0;use_max:char=#0);
var h:integer;
    temp:TFANode;
begin
  if (use_branch_type=BT_SUBRANGE)and(use_min=use_max) then
    use_branch_type:=BT_CHAR;
  assert((use_branch_type<>BT_NOT_NEW_LINE)and (use_branch_type<>BT_NOT_SPACE));
  //символ перевода строки является последовательностью двух символов
  if use_branch_type=BT_NEW_LINE then
  begin
    temp:=CreateNode;
    AddBranch(node,temp,BT_CHAR,#13);
    AddBranch(temp,use_target,BT_CHAR,#10);
  end
  else if use_branch_type=BT_SPACE then
  begin
    temp:=CreateNode;
    AddBranch(node,temp,BT_CHAR,#13);
    AddBranch(temp,use_target,BT_CHAR,#10);
    AddBranch(node,use_target,BT_CHAR,#9);
    AddBranch(node,use_target,BT_CHAR,' ');
  end
  //
  else
  begin
    with node do
    begin
      h:=High(branches)+1;
      SetLength(branches,h+1);
      InitBranch(branches[h],use_branch_type,use_min,use_max,use_target);
    end;
    with use_target do
    begin
      h:=High(branches_in)+1;
      SetLength(branches_in,h+1);
      InitBranch(branches_in[h],use_branch_type,use_min,use_max,node);
    end;
  end;
end;

procedure ClearFlag(var nodes:TarrayOfTFANode);
var i:integer;
begin
  for i:=0 to High(nodes) do nodes[i].flag:=false;
end;

procedure Swap(var v1,v2:TarrayOfTbranch);
var temp:TarrayOfTbranch;
begin
  temp:=v1;v1:=v2;v2:=temp;
end;

function Compare(var v1,v2:TarrayOfTFANode;h:integer):boolean;
var i,k:integer;
label end_search;
begin
  result:=false;
  for i:=0 to h do
  begin
    for k:=0 to h do if v1[i]=v2[k] then goto end_search;
    Exit;
    end_search:
  end;
  result:=true;
end;

procedure CopyFromTo(var v1,v2:TarrayOfTFANode;h:integer);
var i:integer;
begin
  for i:=0 to h do v2[i]:=v1[i];
end;

//--TFANode-------------------------------------------------------------------//

constructor TFANode.Create;
begin
  inherited;
  flag:=false;
end;

destructor TFANode.Destroy;
begin
  SetLength(branches_in,0);
  SetLength(branches,0);
  inherited;
end;

//----------------------------------------------------------------------------//

//--TNFA----------------------------------------------------------------------//

function TNFA.CreateNode:TFANode;
begin
  result:=TFANode.Create;
  inc(nodes_high);
  SetLength(nodes,nodes_high+1);
  nodes[nodes_high]:=result;
end;

procedure TNFA.GetTerm(alternatives_mode:boolean;var btype:TbranchType;var val:char);
var t:integer;
begin
  val:=#0;
  case expr[curr_char] of
    '?','+','*','(',')','|','[',']','{','}':
      raise TRegExpSyntaxError.Create('Ошибка в выражении!');
    '#':
    begin
      t:=0;
      if (curr_char<expr_length)and(expr[curr_char+1] in['0'..'9']) then
      begin
        inc(curr_char);
        while (curr_char<=expr_length)and(expr[curr_char] in['0'..'9'])do
        begin
          t:=t*10+(ord(expr[curr_char])-ord('0'));
          inc(curr_char);
        end;
      end
      else raise TRegExpSyntaxError.Create('Неожиданный конец выражения после "#"!');
      btype:=BT_CHAR;
      val:=char(t);
      if t=13 then raise TRegExpSyntaxError.Create('Сивол #13 используется только в "\n" и "\N"!');
    end;
    '.':
    begin
      if alternatives_mode then
      begin
         btype:=BT_CHAR;
         val:='.';
      end
      else btype:=BT_ANY_CHAR;
      inc(curr_char);
    end;
    '\':
    begin
      inc(curr_char);
      if alternatives_mode and(expr[curr_char] in['S','W','D','N','T'])then
        raise TRegExpSyntaxError.Create('Классы символов \S, \W, \D, \N, \T нельзя использовать в качестве альтернатив!');
      if (curr_char<=expr_length) then
      begin
        case expr[curr_char] of
          'S':btype:=BT_NOT_SPACE;
          'W':btype:=BT_NOT_WORD;
          'D':btype:=BT_NOT_DIGIT;
          'N':btype:=BT_NOT_NEW_LINE;
          'T':btype:=BT_NOT_TAB;
          's':btype:=BT_SPACE;
          'w':btype:=BT_WORD;
          'd':btype:=BT_DIGIT;
          'n':btype:=BT_NEW_LINE;
          't':btype:=BT_TAB;
          '\','.','?','+','*','(',')','|','[',']','#','{','}','''':
            begin
              btype:=BT_CHAR;
              val:=expr[curr_char];
            end;
        else raise TRegExpSyntaxError.Create('Неизвестный символ после "\"!');
        end;
        inc(curr_char);
      end
      else raise TRegExpSyntaxError.Create('Неожиданный конец выражения после "\"!');
    end;
  else
    begin
      btype:=BT_CHAR;
      val:=expr[curr_char];
      inc(curr_char);
    end;
  end;
end;

procedure GetRanges(var subranges:array of TcharRange;btype:TbranchType;
                    last:integer;min:char;max:char=#0);
var val_temp:char;
begin
  case btype of
    BT_CHAR,
    BT_NEW_LINE,
    BT_TAB:
    begin
      case btype of
        BT_CHAR:val_temp:=min;
        BT_NEW_LINE:val_temp:=#13;
        BT_TAB:val_temp:=#9;
      else val_temp:=#0;
      end;
      InitRange(subranges[last],val_temp,val_temp);
    end;
    BT_SPACE:
    begin
      InitRange(subranges[last-2],' ',' ');
      InitRange(subranges[last-1],#9,#9);
      InitRange(subranges[last],#13,#13);
    end;
    BT_WORD:
    begin
      InitRange(subranges[last-4]  ,'0','9');
      InitRange(subranges[last-3],'A','Z');
      InitRange(subranges[last-2],'a','z');
      InitRange(subranges[last-1],'А','Я');
      InitRange(subranges[last],'а','я');
    end;
    BT_DIGIT:
      InitRange(subranges[last]  ,'0','9');
    BT_SUBRANGE:
    begin
      assert(byte(max)>byte(min));
      InitRange(subranges[last]  ,min,max);
    end;
    BT_ANY_CHAR:
      InitRange(subranges[last]  ,#0,#255);
    BT_NOT_CHAR:
    begin
      if (min>#0)  then InitRange(subranges[last-1],#0,char(ord(min)-1));
      if (min<#255)then InitRange(subranges[last],char(ord(min)+1),#255);
    end;
  else
    assert(false);
  end;
end;

function GetRangesCount(btype:TbranchType;min:char=#1;max:char=#0):integer;
begin
  case btype of
    BT_CHAR,
    BT_NEW_LINE,
    BT_TAB: result:=1;
    BT_SPACE: result:=3;
    BT_WORD: result:=5;
    BT_DIGIT: result:=1;
    BT_SUBRANGE: result:=1;
    BT_ANY_CHAR: result:=1;
    BT_NOT_CHAR: if (min=#255)or(min=#0)then result:=1 else result:=2;
  else
    assert(false);
    result:=-1;
  end;
  assert(not((btype=BT_SUBRANGE)and (integer(max)-integer(min)+1=0)));
end;

procedure TNFA.BuildAlternatives(start,finish:TFANode);
var btype:TbranchType;
    val1,val2,val_temp:char;
    not_alternative,need_search:boolean;
    subranges:array of TcharRange;// используется для получения инвертирования группы диапазонов ( not(r1 or r2 or ... rn)
    subranges_high,curr_min,curr_max,i:integer;
    temp:TFANode;
    add_new_line_alt:boolean;
begin
  add_new_line_alt:=false;
  inc(curr_char);
  if (curr_char<=expr_length)and(expr[curr_char]='^') then
  begin
    not_alternative:=true;
    inc(curr_char);
  end else not_alternative:=false;
  //считываем все альтернативы в subranges, преобразуем в диапазоны и оптимизируем при not_alternative
  subranges_high:=-1;
  try
    while (curr_char<=expr_length) and (expr[curr_char]<>']') do
    begin
      GetTerm(true,btype,val1);
      //Если диапазон символов
      if(curr_char<=expr_length)and(expr[curr_char]='-')then
      begin
        if btype<>BT_CHAR then
          raise TRegExpSyntaxError.Create('Оператор диапазона "-" применяется только к символам!');
        inc(curr_char);
        if (curr_char>expr_length) or (expr[curr_char]=']') then
          raise TRegExpSyntaxError.Create('Отсутствует второй операнд оператора "-"!');
        GetTerm(true,btype,val2);
        if btype<>BT_CHAR then
          raise TRegExpSyntaxError.Create('Оператор диапазона "-" применяется только к символам!');
        if ord(val1)>ord(val2) then
        begin val_temp:=val1;val1:=val2;val2:=val_temp; end;
        //Если отрицательная альтернатива
        if not_alternative then
        begin
          inc(subranges_high);
          setlength(subranges,subranges_high+1);
          InitRange(subranges[subranges_high],val1,val2);
        end
        //Если не отрицательная альтернатива
        else AddBranch(start,finish,BT_SUBRANGE,val1,val2);
      end
      //Если не диапазон и отрицательная альтернатива"[^"
      else if not_alternative then
      begin
        if (btype=BT_NEW_LINE)or(btype=BT_SPACE) then add_new_line_alt:=true;
        inc(subranges_high,GetRangesCount(btype));
        setlength(subranges,subranges_high+1);
        GetRanges(subranges,btype,subranges_high,val1);
      end
      //Если не диапазон и не отрицательная альтернатива
      else AddBranch(start,finish,btype,val1);
    end;
    //subranges содержит запрещенные диапазоны символов
    //поэтому находим не запрещенные участки и добавляем в переходы
    if not_alternative then
    begin
      curr_min:=0;
      curr_max:=255;
      while(curr_min<=255)do
      begin
        need_search:=true;
        while(need_search)do
        begin
          need_search:=false;
          for i:=0 to subranges_high do
            if (curr_min>=subranges[i].min) and (curr_min<=subranges[i].max) then
            begin
              curr_min:=subranges[i].max+1;
              need_search:=true;
            end;
        end;
        if(curr_min=256)then break;
        for i:=0 to subranges_high do
          if (subranges[i].min>curr_min) and (subranges[i].min<=curr_max) then
            curr_max:=subranges[i].min-1;
        //добавляем диапазон в branch
        if curr_min= curr_max then
          AddBranch(start,finish,BT_CHAR,char(curr_min))
        else
          AddBranch(start,finish,BT_SUBRANGE,char(curr_min),char(curr_max));
        curr_min:=curr_max+1;
        curr_max:=255;
      end;
      //т.к. перевод строки представляется двумя символами(#13#10),
      //то сначала проверяем не запрещен ли уже #13, а затем добавляем обработку #10
      if add_new_line_alt then
      begin
        temp:=CreateNode;
        AddBranch(start,temp,BT_CHAR,#13);
        AddBranch(temp,finish,BT_NOT_CHAR,#10);
      end;
    end;
  finally
    SetLength(subranges,0);
  end;
  //
end;

procedure TNFA.AddAlternativeRegister(start,finish:TFANode);
begin
  AddNodeAlternativeRegister(start,finish);
  ClearFlag(nodes);
end;

//TODO: преобразование регистров для русских букв
function GetAlternativeRegister(c1,c2:char;var res1,res2:char;to_upper:boolean):boolean;overload;
var t1,t2:char;
begin
  assert(c1<c2);
  result:=false;
  if(to_upper)then
  begin
    if c1<'a' then t1:='a' else t1:=c1;
    if c2>'z' then t2:='z' else t2:=c2;
    if (t1<=t2) then
    begin
      result:=true;
      res1:=char(ord(t1)-ord('a')+ord('A'));
      res2:=char(ord(t2)-ord('a')+ord('A'));
    end
  end
  else
  begin
    if c1<'A' then t1:='A' else t1:=c1;
    if c2>'Z' then t2:='Z' else t2:=c2;
    if (t1<=t2) then
    begin
      result:=true;
      res1:=char(ord(t1)+ord('a')-ord('A'));
      res2:=char(ord(t2)+ord('a')-ord('A'));
    end
  end;
end;

function GetAlternativeRegister(c:char;var res:char):boolean;overload;
begin
  result:=true;
  case c of
  'a'..'z':res:=char(ord(c)-ord('a')+ord('A'));
  'A'..'Z':res:=char(ord(c)+ord('a')-ord('A'));
  'а'..'я':res:=char(ord(c)-ord('я')+ord('Я'));
  'А'..'Я':res:=char(ord(c)+ord('я')-ord('Я'));
  else result:=false;
  end;
end;

procedure TNFA.AddNodeAlternativeRegister(node,finish:TFANode);
var i,h:integer;
    c1,c2:char;
begin
  if(node.flag or (node=finish))then Exit
  else
  begin
    node.flag:=true;
    h:=High(node.branches);
    for i:=0 to h do
    begin
      with node.branches[i] do
      case branch_type of
      BT_CHAR:
        if GetAlternativeRegister(min,c1) then
          AddBranch(node,target_node,BT_CHAR,c1);
      BT_SUBRANGE:
        begin
          if GetAlternativeRegister(min,max,c1,c2,false) then
            AddBranch(node,target_node,BT_SUBRANGE,c1,c2);
          if GetAlternativeRegister(min,max,c1,c2,true) then
            AddBranch(node,target_node,BT_SUBRANGE,c1,c2);
        end;
      end;
      AddNodeAlternativeRegister(node.branches[i].target_node,finish);
    end;
  end;
end;

procedure TNFA.BuildNFA(start,finish:TFANode;level:integer);
var temp,temp1,temp2,temp3:TFANode;
    btype:TbranchType;
    val1:char;
begin
  case level of
  0://оператор |
    begin
      BuildNFA(start,finish,1);
      while (curr_char<=expr_length)and(expr[curr_char]='|') do
      begin
        inc(curr_char);
        BuildNFA(start,finish,1);
      end;
    end;
  1://конкатезация
    begin
      //прерывается если встречается более низкий по приоритету оператор или закрывающая скобка
      while (curr_char<=expr_length)and(expr[curr_char]<>'|')and (expr[curr_char]<>')') do
      begin
        temp:=CreateNode;
        BuildNFA(start,temp,2);
        start:=temp;
      end;
      if(curr_char<=expr_length)and(expr[curr_char]=')')and(parenthnes_level=0)then
        raise TRegExpSyntaxError.Create('Лишняя закрывающая круглая скобка!');
      AddBranch(start,finish);
    end;
  2:// операторы * + ?
    begin
      temp:=CreateNode;
      temp1:=CreateNode;
      temp2:=CreateNode;
      temp3:=CreateNode;
      AddBranch(temp,temp2);
      AddBranch(temp2,finish);
      AddBranch(start,temp3);
      AddBranch(temp3,temp1);
      BuildNFA(temp1,temp,3);
      if (curr_char<=expr_length)then
      begin
        case expr[curr_char] of
          '*':                                 //                _______________
          begin                                //               \/              |    e
            inc(curr_char);                    //(s)->temp3-> (temp1) ..... (temp) --> temp2 -> (f)
            AddBranch(temp1,temp2);            //               |                      /\
            AddBranch(temp,temp1);             //               |_______________________|
          end;                                 //                   e
          '+':
          begin
            inc(curr_char);
            AddBranch(temp,temp1);
          end;
          '?':
          begin
            inc(curr_char);
            AddBranch(temp1,temp2);
          end;
          '{':
          begin
            inc(curr_char);
            while (curr_char<=expr_length)and((expr[curr_char]='r')or(expr[curr_char]='s')) do
            case expr[curr_char] of
              's':
                begin
                  inc(curr_char);
                  AddBranch(temp3,temp3,BT_SPACE);
                  AddBranch(temp2,temp2,BT_SPACE);
                end;
              'r':
                begin
                  inc(curr_char);
                  AddAlternativeRegister(temp1,temp2);
                end;
            end;
            if(curr_char>expr_length)or(expr[curr_char]<>'}')then
              raise TRegExpSyntaxError.Create('Ожидалась закрывающая фигурная скобка!');
            inc(curr_char);
          end;
        end;
      end;
    end;
  3:
    begin
      if (curr_char<=expr_length) then
      begin
        //
        case expr[curr_char] of
          '['://альтернативы []
          begin
            BuildAlternatives(start,finish);
            if (curr_char<=expr_length) and (expr[curr_char]=']') then inc(curr_char)
            else raise TRegExpSyntaxError.Create('Ожидалась закрывающая квадратная скобка!');
          end;
          '('://скобки ()
          begin
            inc(parenthnes_level);
            inc(curr_char);
            BuildNFA(start,finish,0);
            if (curr_char<=expr_length) and (expr[curr_char]=')') then inc(curr_char)
            else raise TRegExpSyntaxError.Create('Ожидалась закрывающая круглая скобка!');
            dec(parenthnes_level);
          end;
        else
          begin
            GetTerm(false,btype,val1);
            if btype=BT_NOT_SPACE then
            begin
              temp:=CreateNode;
              AddBranch(start,finish,BT_SUBRANGE,#0,#8);
              AddBranch(start,finish,BT_SUBRANGE,#10,#12);
              AddBranch(start,finish,BT_SUBRANGE,#14,#31);
              AddBranch(start,finish,BT_SUBRANGE,#33,#255);
              AddBranch(start,temp,BT_CHAR,#13);
              AddBranch(temp,finish,BT_NOT_CHAR,#10);
            end
            else if btype=BT_NOT_NEW_LINE then
            begin
              temp:=CreateNode;
              AddBranch(start,finish,BT_NOT_CHAR,#13);
              AddBranch(start,temp,BT_CHAR,#13);
              AddBranch(temp,finish,BT_NOT_CHAR,#10);
            end
            else AddBranch(start,finish,btype,val1);
          end
        end;
        //
      end;
    end;
  end;
end;

function TNFA.Move(a:char):boolean;
//##############################################################################
//TNFA.Move вычисляет все состояния автомата после чтения входного символа
//in:
//  a - входной символ
//  curr_states - текущие состояния автомата
//out:
//  curr_states - состояния после чтения
//temp:
//  result_states, result_bit_vector
//##############################################################################
var i,k,h:integer;
    temp:TarrayOfTFANode;
    r:boolean;
begin
  result_states_high:=-1;
  result:=true;
  for i:=0 to curr_states_high do
    with curr_states[i] do
    begin
      h:=High(branches);
      for k:=0 to h do
      begin
        r:=false;
        case branches[k].branch_type of
          BT_CHAR: r:= a=branches[k].min;
          BT_WORD: r:= a in ['0'..'9','A'..'Z','a'..'z','А'..'Я','а'..'я'];
          BT_DIGIT:r:= a in ['0'..'9'];
          BT_SUBRANGE: r:= ord(a) in [ord(branches[k].min)..ord(branches[k].max)];
          BT_NOT_CHAR: r:= a<>branches[k].min;
          BT_NOT_WORD: r:= not (a in ['0'..'9','A'..'Z','a'..'z','А'..'Я','а'..'я']);
          BT_NOT_DIGIT: r:= not(a in ['0'..'9']);
          BT_ANY_CHAR: r:=true;
          BT_TAB: r:= a=#9;
          BT_EMPTY: r:=false;
          else Assert(false);
        end;
        if r and (not result_bit_vector[branches[k].target_node.index]) then
        begin
          inc(result_states_high);
          result_states[result_states_high]:=branches[k].target_node;
          result_bit_vector[branches[k].target_node.index]:=true;
        end;
      end;
    end;
  if result_states_high=-1 then
  begin
    result:=false;
    exit;
  end;
  temp:=curr_states;curr_states:=result_states;result_states:=temp;
  curr_states_high:=result_states_high;
  fillchar(result_bit_vector[0],(nodes_high+1),#0);
end;

procedure TNFA.EClosure(except_unimportant_nodes:boolean=false);
//##############################################################################
//TNFA.EClosure вычисляет E замыкание автомата
//in:
//  curr_states - текущие состояния автомата
//out:
//  curr_states - состояния после E замыкания
//temp:
//  result_states, result_bit_vector
//##############################################################################
var i,k:integer;
    temp:TarrayOfTFANode;
    t,b:TFANode;
label end_search;
begin
  fillchar(result_bit_vector[0],(nodes_high+1),#0);
  //
  for i:=0 to curr_states_high do
    result_bit_vector[curr_states[i].index]:=true;
  //
  for i:=0 to curr_states_high do result_states[i]:=curr_states[i];
  result_states_high:=curr_states_high;
  while curr_states_high>=0 do
  begin
    t:=curr_states[curr_states_high];
    dec(curr_states_high);
    with t do
      for i:=0 to high(branches) do
        if branches[i].branch_type=BT_EMPTY then
        begin
          b:=branches[i].target_node;
          if not result_bit_vector[b.index] then
          begin
            inc(curr_states_high);
            curr_states[curr_states_high]:=b;
            inc(result_states_high);
            result_states[result_states_high]:=b;
            result_bit_vector[b.index]:=true;
          end
        end;
  end;
  //
  fillchar(result_bit_vector[0],(nodes_high+1),#0);
  //
  temp:=curr_states;curr_states:=result_states;result_states:=temp;
  curr_states_high:=result_states_high;
  //
  if(except_unimportant_nodes)then
  //этот блок исользуется в ДКА для исключения неважных состояний
  begin
    result_states_high:=-1;
    for i:=0 to curr_states_high do with curr_states[i] do
    begin
      //конечное состояние пропускаем без проверки
      if(curr_states[i]=finish)then goto end_search;
      //
      for k:=0 to High(branches) do
        if branches[k].branch_type<>BT_EMPTY then goto end_search;
      continue;
      end_search:
      inc(result_states_high);
      result_states[result_states_high]:=curr_states[i];
    end;
    temp:=curr_states;curr_states:=result_states;result_states:=temp;
    curr_states_high:=result_states_high;
  end;
end;

function TNFA.Match(s:string):boolean;
var i:integer;
label end_search;
begin
  result:=false;
  if(length(s)=0)or(start=nil)then exit;
  curr_char:=1;
  fillchar(result_bit_vector[0],(nodes_high+1),#0);
  //
  curr_states_high:=0;
  curr_states[0]:=start;
  EClosure;
  while curr_char<=Length(s) do
  begin
    if not Move(s[curr_char]) then
    begin
      result:=false;
      exit;
    end;
    EClosure;
    inc(curr_char);
  end;
  for i:=0 to curr_states_high do
    if curr_states[i]=finish then
    begin
      result:=true;
      Exit;
    end;
end;

procedure TNFA.ReplaceBranch(var branches:TarrayOfTbranch;branch:TFANode;new_val:Tbranch);
var t:integer;
begin
    for t:=0 to High(branches) do
      if branches[t].target_node=branch then
        branches[t]:=new_val;
end;

procedure TNFA.ReplaceBranch(var branches:TarrayOfTbranch;branch,new_val:TFANode);
var t:integer;
begin
    for t:=0 to High(branches) do
      if branches[t].target_node=branch then
        branches[t].target_node:=new_val;
end;

procedure TNFA.Optimize;
var i,t,e:integer;
    n:TFANode;
label end_search1,end_search2;
begin
  for i:=0 to nodes_high do
  begin
    with nodes[i] do
      //Входящий и исходящий переход пуст (является E переходом)
      if(High(branches_in)=0) and (High(branches)=0)
        and (branches_in[0].branch_type=BT_EMPTY)
        and (branches[0].branch_type=   BT_EMPTY)then
      begin
        ReplaceBranch(branches_in[0].target_node.branches,nodes[i],
          branches[0].target_node);
        ReplaceBranch(branches[0].target_node.branches_in,nodes[i],
          branches_in[0].target_node);
        nodes[i].Free;
      end
      else
      if(High(branches_in)=0) and (branches_in[0].branch_type=BT_EMPTY)and(High(branches)>=0)then
      begin
        for t:=0 to High(branches) do
          if branches[t].branch_type=BT_EMPTY then goto end_search1;
        //Входной переход пуст, а все исходящие переходы не пусты
        for t:=0 to High(branches) do
          ReplaceBranch(branches[t].target_node.branches_in,nodes[i],
            branches_in[0].target_node);
        ReplaceBranch(branches_in[0].target_node.branches,nodes[i],
            branches[0]);
        n:=branches_in[0].target_node;
        e:=Length(n.branches);
        SetLength(n.branches,e+High(branches));
        for t:=1 to High(branches) do
          n.branches[e+t-1]:=branches[t];
        nodes[i].Free;
        end_search1:
      end
      else
      //Все входные переходы не пусты, а единственный исходящий переход пуст
      if(High(branches)=0) and (branches[0].branch_type=BT_EMPTY)and(High(branches_in)>=0)then
      begin
        for t:=0 to High(branches_in) do
          if branches_in[t].branch_type=BT_EMPTY then goto end_search2;
        for t:=0 to High(branches_in) do
          ReplaceBranch(branches_in[t].target_node.branches,nodes[i],
            branches[0].target_node);
        ReplaceBranch(branches[0].target_node.branches_in,nodes[i],
            branches_in[0]);
        n:=branches[0].target_node;
        e:=Length(n.branches_in);
        SetLength(n.branches_in,e+High(branches_in));
        for t:=1 to High(branches_in) do
          n.branches_in[e+t-1]:=branches_in[t];
        nodes[i].Free;
        end_search2:
      end;
  end;
end;

procedure TNFA.GetAllNodes(node:TFANode);
var i,h:integer;
begin
  with node do
  begin
    if flag then exit;
    flag:=true;
    inc(nodes_high);
    SetLength(nodes,nodes_high+1);
    nodes[nodes_high]:=node;
    h:=High(branches);
    for i:=0 to h do GetAllNodes(branches[i].target_node);
  end;
end;

procedure TNFA.PrepareBitVector;
var i,h:integer;
begin
  h:=High(nodes);
  for i:=0 to h do nodes[i].index:=i;
end;

procedure TNFA.Clean;
var i:integer;
begin
  if start=nil then exit;
  start:=nil;
  finish:=nil;
  for i:=0 to High(nodes) do nodes[i].Free;
  SetLength(nodes,0);
  SetLength(curr_states,0);
  SetLength(result_states,0);
  SetLength(result_bit_vector,0);
end;

procedure TNFA.SetExpression(s:string);
var l:integer;
begin
  if (start<>nil)then
    Clean;
  expr:=s;
  expr_length:=length(expr);
  curr_char:=1;
  nodes_high:=-1;
  try
    start:=CreateNode;
    finish:=CreateNode;
    parenthnes_level:=0;
    BuildNFA(start,finish,0);
    Optimize;
    nodes_high:=-1;    //
    SetLength(nodes,0);//после оптимизации некоторые nodes могут стать удаленными
    GetAllNodes(start);//поэтому получаем список всех nodes заново
    ClearFlag(nodes);  //
    l:=nodes_high+1;
    SetLength(curr_states,l);
    SetLength(result_states,l);
    SetLength(result_bit_vector,l);
    PrepareBitVector;
  except
    on e:TRegExpSyntaxError do
    begin
      Clean;
      raise;
    end;
  end;
  curr_states_high:=-1;
  result_states_high:=-1;
end;

Destructor TNFA.Destroy;
begin
  Clean;
  inherited;
end;

//----------------------------------------------------------------------------//

//--TDFA----------------------------------------------------------------------//

procedure TDFA.Clean;
var i:integer;
begin
  start:=nil;
  for i:=0 to High(nodes) do nodes[i].Free;
  SetLength(nodes,0);
  nodes:=nil;
  if nodes_nfa_states<>nil then
    for i:=0 to High(nodes_nfa_states) do
      setLength(nodes_nfa_states[i].states,0);
  SetLength(nodes_nfa_states,0);
  nodes_nfa_states:=nil;
end;

Destructor TDFA.Destroy;
begin
  Clean;
  inherited;
end;

procedure TDFA.SetExpression(s:string);
begin
  if (start<>nil)then
    Clean;
  expr:=s;
  curr_char:=1;
  nfa:=TNFA.Create;
  try
    nfa.SetExpression(expr);
    BuildDFAFromNFA;
  except
    on e:TRegExpSyntaxError do
    begin
      Clean;
      raise;
    end;
  end;
  nfa.Free;
  nfa:=nil;
end;

procedure TDFA.AddBranch(source,dest:integer;use_min,use_max:char);
var h:integer;
    branch_type:TBranchType;
begin
  if use_min=use_max then branch_type:=BT_CHAR
  else branch_type:=BT_SUBRANGE;
  begin
    with nodes[source] do
    begin
      h:=High(branches)+1;
      SetLength(branches,h+1);
      InitBranch(branches[h],branch_type,use_min,use_max,nodes[dest]);
    end;
    with nodes[dest] do
    begin
      h:=High(branches_in)+1;
      SetLength(branches_in,h+1);
      InitBranch(branches_in[h],branch_type,use_min,use_max,nodes[source]);
    end;
  end;
end;


function TDFA.Match(s:string;var last_char:integer;first_char:integer=1):boolean;
var i:integer;
    t:TFANode;
label end_search;
begin
  if(length(s)=0)or(start=nil)then exit;
  result:=start.flag;
  last_char:=first_char-1;
  curr_char:=first_char;
  t:=start;
  while curr_char<=Length(s) do
    with t do
    begin
      for i:=0 to High(branches) do
        case branches[i].branch_type of
        BT_SUBRANGE:
          if s[curr_char]in[branches[i].min..branches[i].max] then
          begin
            t:=branches[i].target_node;
            goto end_search;
          end;
        BT_CHAR:
          if s[curr_char]=branches[i].min then
          begin
            t:=branches[i].target_node;
            goto end_search;
          end;
        else assert(false);
        end;
      Exit;
      end_search:
      if(t.flag)then
      begin
        last_char:=curr_char;
        result:=true;
      end;
      inc(curr_char);
    end;
  result:=t.flag;
end;


procedure TDFA.BuildDFAFromNFA;
var alphabet:array of TcharRange;
    alphabet_high,
    i,k,t,n,h,curr_min:integer;
    curr_char:integer;
    exist_not_checked,empty_flag:boolean;
label end_cycle,end_start_search;
begin
  //инициализируем первое состояние ДКА и обозначаем его не помеченым
  nfa.curr_states_high:=0;
  nfa.curr_states[0]:=nfa.start;
  nfa.EClosure;
  nodes_high:=0;
  SetLength(nodes,1);
  SetLength(nodes_nfa_states,1);
  nodes[0]:=TFANode.Create;
  nodes_nfa_states[0].checked:=false;
  SetLength(nodes_nfa_states[0].states,nfa.curr_states_high+1);
  CopyFromTo(nfa.curr_states,nodes_nfa_states[0].states,nfa.curr_states_high);
  //
  exist_not_checked:=true;
  while(exist_not_checked)do
  begin
    exist_not_checked:=false;
    for i:=0 to nodes_high do
      with nodes_nfa_states[i] do
        if (not checked) then
        begin
          exist_not_checked:=true;
          checked:=true;
          //Формируем алфавит для данного состояния ДКА
          alphabet_high:=-1;
          SetLength(alphabet,0);
          for t:=0 to High(states) do
            for k:=0 to High(states[t].branches) do
              with states[t].branches[k] do if branch_type<>BT_EMPTY then
              begin
                inc(alphabet_high,GetRangesCount(branch_type,min,max));
                SetLength(alphabet,alphabet_high+1);
                GetRanges(alphabet,branch_type,alphabet_high,min,max);
              end;
          //Для каждого символа алфавита получаем новое множество состояний НКА
          curr_min:=-1;
          while(curr_min<255)do
          begin
            //
            curr_char:=256;
            //Определяем наименьший диапазон содержащий одинаковые символы
            for t:=0 to alphabet_high do with alphabet[t] do
              if (min>curr_min) and (min<=curr_char) then curr_char:=min-1
              else
              if (max>=curr_min) and (max<curr_char) then curr_char:=max;
            //Определяем является ли этот диапазон не пустым
            empty_flag:=true;
            for t:=0 to alphabet_high do with alphabet[t] do
              if (curr_char>=min)and(curr_char<=max)then
              begin
                empty_flag:=false;
                break;
              end;
            if curr_char=256 then break;
            if (curr_min=-1) or empty_flag then
            begin
              curr_min:=curr_char+1;
              continue;
            end;
            if empty_flag then continue;
            //Получаем новое множество состояний НКА
            nfa.curr_states_high:=High(nodes_nfa_states[i].states);
            CopyFromTo(nodes_nfa_states[i].states,nfa.curr_states,nfa.curr_states_high);
            if not nfa.Move(char(curr_char))then assert(false);
            nfa.EClosure(true);
            n:=-1;
            //Определяем, имеется ли новое множество состояний в nodes_nfa_states
            for k:=0 to nodes_high do
            begin
              h:=High(nodes_nfa_states[k].states);
              if((h=nfa.curr_states_high)and Compare(nodes_nfa_states[k].states,nfa.curr_states,h))then
              begin
                n:=k;
                break;
              end;
            end;
            //Если новое множество состояний раньше не обрабатывалось, то добаляем как необработанное
            if n=-1 then
            begin
              inc(nodes_high);
              n:=nodes_high;
              SetLength(nodes,nodes_high+1);
              SetLength(nodes_nfa_states,nodes_high+1);
              nodes[nodes_high]:=TFANode.Create;
              with nodes_nfa_states[nodes_high] do
              begin
                checked:=false;
                SetLength(states,nfa.curr_states_high+1);
                CopyFromTo(nfa.curr_states,states,nfa.curr_states_high);
              end;
            end;
            AddBranch(i,n,char(curr_min),char(curr_char));
            //
            curr_min:=curr_char+1;
          end;
        end;
  end;
  //
  start:=nil;
  for i:=0 to nodes_high do with nodes_nfa_states[i] do
  begin
    h:=High(states);
    if(start=nil)then
    begin
        for k:=0 to h do
          if (states[k]=nfa.start)then
          begin
            start:=nodes[i];
            break;
          end;
    end;
    for k:=0 to h do
      if (states[k]=nfa.finish)then
      begin
        nodes[i].flag:=true;
        break;
      end;
  end;
end;

//----------------------------------------------------------------------------//

end.
