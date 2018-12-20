{single instance priority queue
main parts contributed by Rassim Eminli}

{$INCLUDE switches.pas}

unit Pile;

interface

procedure Create(Size: integer);
procedure Free;
procedure Empty;
function Put(Item, Value: integer): boolean;
function TestPut(Item, Value: integer): boolean;
function Get(var Item, Value: integer): boolean;


implementation

const
MaxSize=9600;

type
TheapItem = record
	Item:	integer;
	Value:	integer;
end;

var
bh: array[0..MaxSize-1] of TheapItem;
Ix: array[0..MaxSize-1] of integer;
n, CurrentSize: integer;
{$IFDEF DEBUG}InUse: boolean;{$ENDIF}


procedure Create(Size: integer);
begin
	{$IFDEF DEBUG}assert(not InUse, 'Pile is a single instance class, '
          +'no multiple usage possible. Always call Pile.Free after use.');{$ENDIF}
	assert(Size<=MaxSize);
	if (n <> 0) or (Size > CurrentSize) then
	begin
		FillChar(Ix, Size*sizeOf(integer), 255);
		n := 0;
	end;
        CurrentSize := Size;
        {$IFDEF DEBUG}InUse:=true;{$ENDIF}
end;

procedure Free;
begin
        {$IFDEF DEBUG}assert(InUse);InUse:=false;{$ENDIF}
end;

procedure Empty;
begin
	if n <> 0 then
	begin
		FillChar(Ix, CurrentSize*sizeOf(integer), 255);
		n := 0;
	end;
end;

//Parent(i) = (i-1)/2.
function Put(Item, Value: integer): boolean; //O(lg(n))
var
	i, j:	integer;
begin
	assert(Item<CurrentSize);
	i := Ix[Item];
	if i >= 0 then
        begin
        	if bh[i].Value <= Value then
		begin
			result := False;
			exit;
		end;
        end
	else
	begin
		i := n;
		Inc(n);
	end;

	while i > 0 do
	begin
		j := (i-1) shr 1;	//Parent(i) = (i-1)/2
		if Value >= bh[j].Value then	break;
		bh[i] := bh[j];
		Ix[bh[i].Item] := i;
		i := j;
	end;
	//	Insert the new Item at the insertion point found.
	bh[i].Value := Value;
	bh[i].Item := Item;
	Ix[bh[i].Item] := i;
	result := True;
end;

function TestPut(Item, Value: integer): boolean;
var
	i: integer;
begin
	assert(Item<CurrentSize);
	i := Ix[Item];
	result := (i < 0) or (bh[i].Value > Value);
end;

//Left(i) = 2*i+1.
//Right(i) = 2*i+2 => Left(i)+1
function Get(var Item, Value: integer): boolean; //O(lg(n))
var
	i, j:	integer;
	last:	TheapItem;
begin
	if n = 0 then
	begin
		result := False;
		exit;
	end;

	Item := bh[0].Item;
	Value := bh[0].Value;

	Ix[Item] := -1;

	dec(n);
	if n > 0 then
	begin
		last := bh[n];
		i := 0;		j := 1;
		while j < n do
		begin
										//	Right(i) = Left(i)+1
			if(j < n-1) and (bh[j].Value > bh[j + 1].Value)then
				inc(j);
			if last.Value <= bh[j].Value then		break;

			bh[i] := bh[j];
			Ix[bh[i].Item] := i;
			i := j;
			j := j shl 1+1;	//Left(j) = 2*j+1
		end;

		// Insert the root in the correct place in the heap.
		bh[i] := last;
		Ix[last.Item] := i;
	end;
	result := True
end;

initialization
	n:=0;
        CurrentSize:=0;
        {$IFDEF DEBUG}InUse:=false;{$ENDIF}
end.

