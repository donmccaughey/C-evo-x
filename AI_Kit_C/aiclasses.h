/*The Civ II Evolution Project
AI programming source
Compiler: Microsoft Visual C++

This file is PD
Note your changes, include credits

Project home: www.c-evo.org/

Update for Civ Evo 0.14 January 26th 2005 by Charles Nadolski
Addition of some functions initially in protocol.pas to aiclasses.*
Bugfixes to some server calls

Update for Civ Evo 0.12 Oct 29th 2003 by Charles Nadolski
 Update to match with protocol.h and aiclasses.pas

Update for Civ Evo 0.11 March 9th 2003 by Charles Nadolski
 Update to match with protocol.h and aiclasses.pas

Update for Civ Evo 0.10 November 23rd 2002 by Charles Nadolski
 Removed redundant classes but kept their functions.
 Added and removed functions for compatibility
 with the newest version of aiclasses.pas

Update for Civ Evo 0.8 by Thomas Kay.
 Made TTribe consistent with AIClasses.pas.

Update for Civ Evo 0.8 20th March prototype by Thomas Kay.
 Some functions have become methods.
 Added support for diplomacy.

Actualization to V 0.7.0 by Matvej Soloviev ("blackhole89")
Changes:
 -CLocation(and all classes implementing it) has an overload-operator int, 
  which returns the location code(so you can use it as an integer)
 -Added AIHELPERS.H : Some server functions which aren't re-implemented in AICLASSES.H
  and some useful tool functions (!you must include it in AIMAIN.CPP, not included here!)
 -RO Structure changed

Port to C++ by Thomas Kay from AIClasses.pas 0.6.5
Changes:
 CUn.Common returns a reference not a pointer
 types called "PX" changed to "pX" which is Windows naming format for pointers.
 all types simplified as I couldn't make work!
 NatBuilt index is imp-28
 Using structs and classes for Delphi objects and classes respectively - seems to work well.
 DebugMessage() returns the server result
 Bugfix: Delphi ShortInt is C char not C short.
 MyRO is a reference not a pointer (but allows equivalent use).
 My* constant (read-only) - convenient for porting (detects mistaken writes at compile-time) but may generate many warnings!

*/

#ifndef aiclassesh
#define aiclassesh

#include "protocol.h"

//const int lxmax=80, lymax=96;

//formerly functions under CLocation.
//Use functions by passing a Loc as a parameter instead of invoking the function
//as a member of CLocation.
//Example: Valid(^Unit or City^->Loc) instead of ^Unit or City^->Valid()
//Advantages: ANY integer can be used when invoking a former function
//of CLocation.

//int Loc;
bool Valid(int Loc);
int TerrType(int Loc,int me);
int TileFlags(int Loc,int me);
bool CityHere(int Loc,int me);
bool OwnCityHere(int Loc,int me);
bool EnemyCityHere(int Loc,int me);
bool UnitHere(int Loc,int me);
bool OwnUnitHere(int Loc,int me);
bool EnemyUnitHere(int Loc,int me);
int Remote(int Loc,int dx, int dy);
int Distance(int FromLoc,int ToLoc);
void Distance (int FromLoc, int ToLoc, int& dx, int& dy);
int LocCmd(int Loc,int Command, void *Data, int me);

/* These structures are packed to 1 byte aligment */
#ifndef __GNUC__	/*GCC doesn't exactly support pragmas*/
	#define __attribute__(a)
	#ifdef _MSC_VER //Microsoft C/C++
		#pragma pack(1)
	#else	//Borland C/C++
		#pragma option push -a1	
	#endif
#endif

//Extra functions translated from protocol.pas as of version 14
void MakeUnitInfo(int p, const TUn &u, TUnitInfo &ui);
void MakeModelInfo(int p, int mix, const TModel &m, TModelInfo &mi);
bool IsSameModel(const TModelInfo &mi1, const TModelInfo &mi2);
int HypoSpecialTile(int x, int y, int TerrType);

//TUn functions
TModel Common(const TUn &MyUn,int me);
int TestMove(const TUn &MyUn,int dx, int dy, int me);
int Move(const TUn &MyUn,int dx, int dy, int me);
int Remove(const TUn &MyUn,int me);
int StartJob(const TUn &MyUn,int NewJob, int me);
int GetMoveAdvice(const TUn &MyUn,TMoveAdviceData *MoveAdvice, int me);

//TCity functions
int Index(const TCity &MyCity,int me);
int	GetReport(const TCity &MyCity, TCityReport *Report, int me);
int GetAreaInfo(const TCity &MyCity, TCityAreaInfo *AreaInfo, int me);
int StartUnProd(const TCity &MyCity, int mix, int me);
int StartImpProd(const TCity &MyCity, int iix, int me);
int TestStartImpProd(const TCity &MyCity, int iix, int me);
int BuyProject(const TCity &MyCity, int me);
int SellProject(const TCity &MyCity, int me);
int SellImp(const TCity &MyCity, int iix, int me);
int RebuildImp(const TCity &MyCity, int iix, int me);
int SetCityTiles(const TCity &MyCity, int fix, int me);

/*restore previous packing settings*/
#ifndef __GNUC__
	#undef	__attribute__
	#ifdef _MSC_VER //Microsoft C/C++
		#pragma pack()
	#else	//Borland C/C++
		#pragma option pop
	#endif
#endif

//Note: TPlayer Context has replaced TTribe

class TCustomAI
{
public:
	const	int 	me;
	const 	TPlayerContext 	&		MyRO;	//reference more convenient - counts eg nUn are volatile. More precise to define in struct.
	const	unsigned 	long		* const MyMap;
	const	TUn		* const MyUn;
	const	TCity	* const MyCity;
	const	TModel	* const MyModel;	//probably does need to be volatile.

	int	pContact, // player talking with in negotiation
  		ReceivedDipAction,
  		SentDipAction; // received, last sent diplomatic action
  	TOffer	ReceivedOffer, MyOffer; // received, last sent offer
  	bool	AfterNegotiation;

	TCustomAI(	//inline constructor
				const 	int			Player,
				const	TPlayerContext 	&	RO);

	virtual ~TCustomAI() {;}	//virtual destructor (support polymorphism)

//	These functions have been moved to AImain.ccp/AImain.h
//	void Turn(bool Continued);
//	void Negotiation(int Command, pServerData Data);

	int SetGovernment(int Gov);
	int SetRates(int Tax, int Lux);
	int CreateDevModel(int Domain);
	int SetDevModelCap(int f, int Value);
	int SetResearch(int Tech);
	int TestSetResearch(int Tech);
	int SetAttitude(int Player, int Attitude);
	int CancelTreaty(int Player);

	//Client Deactivation
	int Contact(int Player);
	int DipAction(int Command);
	int EndTurn(void);
};

int DebugMessage(int Level, const char *Text, int me);

//export shared data
extern TServerCall	*Server;	//The server
extern TNewGameData	G;		//The Game Data

#endif	//ifndef aiclassesh
