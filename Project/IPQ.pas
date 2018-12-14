{binary heap priority queue
code contributed by Rassim Eminli}

{$INCLUDE switches.pas}

unit IPQ;

interface

type

TIntegerArray = array[0..$40000000 div sizeof(integer)] of integer;
PIntegerArray = ^TIntegerArray;

TheapItem = record
	Item:	integer;
	Value:	integer;
end;

TItemArray = array[0..$40000000 div sizeof(TheapItem)] of TheapItem;
PItemArray = ^TItemArray;

TIPQ = class
	constructor Create(max: integer);
	destructor Destroy; override;
	procedure Empty;
	function Put(Item, Value: integer): boolean;
	function TestPut(Item, Value: integer): boolean;
	function Get(var Item, Value: integer): boolean;
private
// n - is the size of the heap.
// fmax - is the max size of the heap.
	n, fmax:	integer;

// bh - stores (Value, Item) pairs of the heap.
// Ix - stores the positions of pairs in the heap bh.
	bh:			PItemArray;
	Ix:			PIntegerArray;
  end;


implementation

constructor TIPQ.Create(max: integer);
begin
	inherited Create;
	fmax := max;
	GetMem(bh, fmax*SizeOf(TheapItem));
	GetMem(Ix, fmax*SizeOf(integer));
	n:=-1;
	Empty
end;

destructor TIPQ.Destroy;
begin
	FreeMem(bh);
	FreeMem(Ix);
	inherited Destroy;
end;

procedure TIPQ.Empty;
begin
	if n <> 0 then
	begin
		FillChar(Ix^, fmax*sizeOf(integer), 255);
		n := 0;
	end;
end;

//Parent(i) = (i-1)/2.
function TIPQ.Put(Item, Value: integer): boolean; //O(lg(n))
var
	i, j:	integer;
	lbh:	PItemArray;
	lIx:	PIntegerArray;
begin
	lIx := Ix;
	lbh := bh;
	i := lIx[Item];
	if i >= 0 then
        begin
        	if lbh[i].Value <= Value then
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
		if Value >= lbh[j].Value then	break;
		lbh[i] := lbh[j];
		lIx[lbh[i].Item] := i;
		i := j;
	end;
	//	Insert the new Item at the insertion point found.
	lbh[i].Value := Value;
	lbh[i].Item := Item;
	lIx[lbh[i].Item] := i;
	result := True;
end;

function TIPQ.TestPut(Item, Value: integer): boolean;
var
	i: integer;
begin
	i := Ix[Item];
	result := (i < 0) or (bh[i].Value > Value);
end;

//Left(i) = 2*i+1.
//Right(i) = 2*i+2 => Left(i)+1
function TIPQ.Get(var Item, Value: integer): boolean; //O(lg(n))
var
	i, j:	integer;
	last:	TheapItem;
	lbh:	PItemArray;
begin
	if n = 0 then
	begin
		result := False;
		exit;
	end;

	lbh := bh;
	Item := lbh[0].Item;
	Value := lbh[0].Value;

	Ix[Item] := -1;

	dec(n);
	if n > 0 then
	begin
		last := lbh[n];
		i := 0;		j := 1;
		while j < n do
		begin
										//	Right(i) = Left(i)+1
			if(j < n-1) and (lbh[j].Value > lbh[j + 1].Value)then
				inc(j);
			if last.Value <= lbh[j].Value then		break;

			lbh[i] := lbh[j];
			Ix[lbh[i].Item] := i;
			i := j;
			j := j shl 1+1;	//Left(j) = 2*j+1
		end;

		// Insert the root in the correct place in the heap.
		lbh[i] := last;
		Ix[last.Item] := i;
	end;
	result := True
end;

end.

