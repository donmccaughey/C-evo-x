#ifndef aimainh
#define aimainh

#include "protocol.h"
#include "aiclasses.h"

//This structure I found useful in keeping track of 
//miscellaneous unit data.  "Moves" is used for the 
//AI pathfinding, "MoveIndex" keeps track of which step
//it's on the path.  Index is which location the unit is
//in the AI's built-in unit array, but since indices change all 
//the time, you need to use the "ID" (a unique ID for every unit)
//to make sure that the index is correct.
struct UnitData
{
	int Index;
	TMoveAdviceData Moves;
	int MoveIndex;
	unsigned short ID;
};

/*

Add function headers for your user-made functions that don't go into AIHelpers.h here

*/

//Don't really mess with the rest of this stuff, unless you really know what you're doing.
void DoTurn(int Player);
void DoNegotiation(int Player);

//The Client function
//extern = export
extern "C" void __stdcall client(int Command, int Player, void* Data);

#endif //ifndef aimainh