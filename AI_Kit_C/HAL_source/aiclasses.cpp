/*The Civ II Evolution Project
AI programming source
Compiler: ANSI C++

This file is PD
Note your changes, include credits

Project home: www.c-evo.org/

Update for Civ Evo 0.14 January 26th 2005 by Charles Nadolski
Addition of some functions initially in protocol.pas to aiclasses.*
Bugfixes to some server calls

Update for Civ Evo 0.13 July 12th 2004 by Charles Nadolski
specifically:
updates to distance algorithm (something didn't seem quite right)

Update for Civ Evo 0.12 Oct 29th 2003 by Charles Nadolski
 Update to match with protocol.h and aiclasses.pas

Update for Civ Evo 0.11 March 9th 2003 by Charles Nadolski
 Update to match with protocol.h and aiclasses.pas

Update for Civ Evo 0.10 November 23rd 2002 by Charles Nadolski
 Removed redundant classes but kept their functions.
 Added and removed functions for compatibility
 with the newest version of aiclasses.pas

Update for Civ Evo 0.8 20th March prototype by Thomas Kay.
 Some functions have become methods.
 Added support for diplomacy.
 Diplomacy model is not suitable for multiplayer modules (you need to save and restore AIme and RNG seed etc).

Actualization to v0.7.0 by Matvej Soloviev ("blackhole89")
Other Changes:
 -CLocation(and all classes implementing it) has an overload-operator int, 
  which returns the location code(so you can use it as an integer)
 -Added AIHELPERS.H : Some server functions which aren't re-implemented in AICLASSES.H
  and some useful tool functions
0.7.0 Changes:
 -Other RO structure

Port to C++ by Thomas Kay from AIClasses.pas 0.6.5
CLocation::Remote() returns a reference to a static CLocation
CUn::Common() returns a reference to the model not a pointer (more convenient to use).

*/

#include "protocol.h"
#include "aiclasses.h"

#ifdef __GNUC__	 /*(Mingw32)*/
	#include <cstdlib>
#else
	#include <stdlib.h>	//abs()
#endif

//Shared data
TServerCall *Server;
TNewGameData G;

void MakeUnitInfo(char p, const TUn &u, TUnitInfo &ui)
{
	ui.Owner = p;
	ui.Loc = u.Loc;
	ui.Health = u.Health;
	ui.Fuel = u.Fuel;
	ui.Job = u.Job;
	ui.Exp = u.Exp;
	ui.Load = u.TroopLoad+u.AirLoad;
	ui.mix = u.mix;
	ui.Flags = (unsigned short)u.Flags;	//in original pascal code, right side has cardinal, left side word
}

void MakeModelInfo(unsigned short  p, unsigned short mix, const TModel &m, TModelInfo &mi)
{
	int i;
	mi.Owner = p;
	mi.mix = mix;
	mi.Domain = m.Domain;
	if(m.Kind==mkEnemyDeveloped)
		mi.Kind = mkSelfDeveloped; // important for IsSameModel()
	else
		mi.Kind = m.Kind;
	mi.Attack = m.Attack;
	mi.Defense = m.Defense;
	mi.Speed = m.Speed;
	mi.Cost = m.Cost;
	if (mi.Domain==dAir)
	{
		mi.TTrans = m.Cap[mcAirTrans]*m.MTrans;
		mi.ATrans_Fuel = m.Cap[mcFuel];
	}
	else
	{
		mi.TTrans = m.Cap[mcSeaTrans]*m.MTrans;
		mi.ATrans_Fuel = m.Cap[mcCarrier]*m.MTrans;
	}
	mi.Bombs = m.Cap[mcBombs]*m.MStrength*2;
	mi.Cap = 0;
	for (i = mcFirstNonCap; i < nFeature; i++)
		if(m.Cap[i]>0)
			mi.Cap = mi.Cap | (1<<(i-mcFirstNonCap));
	mi.MaxUpgrade = 0;
	for (i = 1; i < nUpgrade; i++)
		if (m.Upgrades && (1 << i)!=0)
			mi.MaxUpgrade = i;
	mi.Weight = m.Weight;
	mi.Lost = 0;
}

bool IsSameModel(const TModelInfo &mi1, const TModelInfo &mi2)
{
	return (
		(mi1.Kind == mi2.Kind) &&
		(mi1.Domain == mi2.Domain) &&
		(mi1.Attack == mi2.Attack) &&
		(mi1.Defense == mi2.Defense) &&
		(mi1.Speed == mi2.Speed) &&
		(mi1.Cost == mi2.Cost) &&
		(mi1.TTrans == mi2.TTrans) &&	//ground unit transport capability
		(mi1.ATrans_Fuel == mi2.ATrans_Fuel) &&	//air unit transport capability resp. fuel
		(mi1.Bombs == mi2.Bombs) &&	//additional attack with bombs
		(mi1.Cap == mi2.Cap) &&	//special features, bitset with index Feature-mcFirstNonCap
		(mi1.MaxUpgrade == mi2.MaxUpgrade) &&	//maximum used upgrade
		(mi1.Weight == mi2.Weight) &&
		(mi1.Lost == mi2.Lost)
		);
}

int HypoSpecialTile(int x, int y, int TerrType)
{
	int qx, qy;
	if (TerrType==fOcean)
		return 0;

	if (TerrType==fGrass)	//formula for productive grassland
	{
		if((((lymax + x - (y >> 1)) >> 1) + x + ((y+1) >> 1)) & 1)	//That's an arithmetic and, not comparison
			return 1;

		return 0;
	}

	//formula for special resources
	qx = (4*x-y+9980)/10;
	qy = (y+x)/5;
	if (((4*x-y+10000)%10==0) && ((qx & 3)!=0) && ((qy & 3)!=(((qx >> 2) & 1) *2)))
	{
		if(TerrType==fArctic)
			return 1;

		if(TerrType==fShore)
		{
			if (((qx+qy) & 1)==0)
			{
				if ((qx & 3)==2)
					return 2;

				return 1;
			}

			return 0;
		}

		return ((qx+qy) & 1)+1;
	}

	return 0;
}

bool Valid(int Loc)
{
	return((Loc>=0) && (Loc<G.lx*G.ly));
}

int TerrType(int Loc,int me)
{
	return(G.RO[me]->Map[Loc]&TerrainMask);
}

int TileFlags(int Loc,int me)
{
	return(G.RO[me]->Map[Loc] & ~ TerrainMask);
}

int Remote(int Loc,int dx, int dy)
{
	int y0=( (Loc+G.lx*1234) / G.lx ) -1234;
	return (( Loc + ( ( dx + (y0 & 1) + G.lx*1234 ) >> 1 ) ) % G.lx +G.lx * ( y0 + dy ));
}

int Distance (int FromLoc, int ToLoc)
{
	int dx=(((ToLoc%G.lx)*2+(ToLoc/G.lx&1))
		-((FromLoc%G.lx)*2+(FromLoc/G.lx&1))+3*G.lx)%(2*G.lx)-G.lx;
	int dy=ToLoc/G.lx-FromLoc/G.lx;
	return(abs(dx)+abs(dy)+abs(dx-dy) / 2);
}

void Distance (int FromLoc, int ToLoc, int& dx, int& dy)
{
	dx = (((ToLoc%G.lx)*2+(ToLoc/G.lx&1))
		-((FromLoc%G.lx)*2+(FromLoc/G.lx&1))+3*G.lx)%(2*G.lx)-G.lx;
	dy = ToLoc/G.lx-FromLoc/G.lx;
}

bool CityHere(int Loc,int me)
{
	return((G.RO[me]->Map[Loc] & fCity)!=0);
}

bool OwnCityHere(int Loc,int me)
{
	return((G.RO[me]->Map[Loc] & (fCity | fOwned))==(fCity | fOwned));
}

bool EnemyCityHere(int Loc,int me)
{
	return((G.RO[me]->Map[Loc] & (fCity | fOwned))==fCity);
}

bool UnitHere(int Loc,int me)
{
	return((G.RO[me]->Map[Loc] & fUnit)!=0);
}

bool OwnUnitHere(int Loc,int me)
{
	return((G.RO[me]->Map[Loc] & (fUnit | fOwned))==(fUnit | fOwned));
}

bool EnemyUnitHere(int Loc,int me)
{
	return((G.RO[me]->Map[Loc] & (fUnit | fOwned))==fUnit);
}

int LocCmd(int Loc,int Command, pServerData Data, int me)
{
	return(Server(Command, me, Loc, Data));
}

int Index(const TUn &MyUn, int me)
{
	return((int(&MyUn)-int(G.RO[me]->Un)) / sizeof(TUn));
}

TModel Common(const TUn &MyUn, int me)
{
	return(G.RO[me]->Model[MyUn.mix]);
}

int TestMove(const TUn &MyUn, int dx, int dy, int me)
{
	return(Server(sMoveUnit-sExecute+((dx & 7) << 4) +((dy & 7) << 7),me,Index(MyUn,me),NoServerData));
}

int Move(const TUn &MyUn, int dx, int dy, int me)
{
	return(Server(sMoveUnit+((dx & 7) << 4) +((dy & 7) << 7),me,Index(MyUn,me),NoServerData));
}

int Remove(const TUn &MyUn, int me)
{
	return(Server(sRemoveUnit,me,Index(MyUn,me),NoServerData));
}

int StartJob(const TUn &MyUn, int NewJob, int me)
{
	return(Server(sStartJob+(NewJob << 4),me,Index(MyUn,me),NoServerData));
}

int GetMoveAdvice(const TUn &MyUn, TMoveAdviceData *MoveAdvice, int me)
{
	return(Server(sGetMoveAdvice,me,Index(MyUn,me), MoveAdvice));
}

int Index(const TCity &MyCity, int me)
{
	return((int(&MyCity)-int(G.RO[me]->City)) / sizeof(MyCity));
}

int GetReport(const TCity &MyCity, TCityReport *Report, int me)
{
	return(Server(sGetCityReport, me, Index(MyCity, me), Report));
}

int GetAreaInfo(const TCity &MyCity, TCityAreaInfo *AreaInfo, int me)
{
	return(Server(sGetCityAreaInfo, me, Index(MyCity, me), AreaInfo));
}

int StartUnProd(const TCity &MyCity, int mix, int me)
{
	return(Server(sSetCityProject,me,Index(MyCity, me),&mix));
}

int StartImpProd(const TCity &MyCity, int iix, int me)
{
	int NewProject=iix+cpImp;
	return(Server(sSetCityProject,me,Index(MyCity, me),&NewProject));
}

int TestStartImpProd(const TCity &MyCity, int iix, int me)
{
	int NewProject=iix+cpImp;
	return(Server(sSetCityProject-sExecute,me,Index(MyCity, me),&NewProject));
}

int BuyProject(const TCity &MyCity, int me)
{
	return(Server(sBuyCityProject,me,Index(MyCity, me),NoServerData));
}

int SellProject(const TCity &MyCity, int me)
{
	return(Server(sSellCityProject,me,Index(MyCity, me),NoServerData));
}

int SellImp(const TCity &MyCity, int iix, int me)
{
	return(Server(sSellCityImprovement,me,Index(MyCity, me),&iix));
}

int RebuildImp(const TCity &MyCity, int iix, int me)
{
	return(Server(sRebuildCityImprovement,me,Index(MyCity, me),&iix));
}

int SetCityTiles(const TCity &MyCity, int NewTiles, int me)
{
	return (Server(sSetCityTiles, me, Index(MyCity, me),&NewTiles));
}
/*
int ToggleTile(const TCity &MyCity, int fix, int me)
{
	return(Server(sToggleCityTile+(fix << 4),me,Index(MyCity, me),NoServerData));
}

int CCity::SetStatus(int NewStatus) const volatile	//volatile in fact
{
	return(Server(sSetCityStatus,AIme,((const CCity*)this)->Index(me),&NewStatus));
}
*/

TCustomAI::TCustomAI(	//inline constructor
				const 	int			Player,
				const	TPlayerContext 	&	RO)
		//initialise constants
	:	me(Player),
	 	MyRO(RO),
	 	MyMap(RO.Map),
	 	MyUn(RO.Un),
	 	MyCity(RO.City),
	 	MyModel(RO.Model)
	{;}
/*
void TCustomAI::Turn(bool Continued)
{
//	AIme=me;
	AfterNegotiation=Continued;
	DoTurn();
//	Server(sTurn, AIme, 0, NoServerData);
}

void TCustomAI::Negotiation(int Command, pServerData Data)
{
//	AIme=me;
	ReceivedDipAction=Command;
	if (Command==scContact)	pContact=*static_cast<int*>(Data);
	if (Command==scDipOffer)	ReceivedOffer=*static_cast<TOffer*>(Data);
	DoNegotiation();
}
*/
int TCustomAI::SetGovernment(int Gov)
{
	return(Server(sSetGovernment,me,Gov,NoServerData));
}

int TCustomAI::SetRates(int Tax, int Lux)
{
	return(Server(sSetRates,me,((Tax / 10) & 0xF)+(((Lux / 10) & 0xF) << 4),NoServerData));
}

int TCustomAI::CreateDevModel(int Domain)
{
	return(Server(sCreateDevModel,me,Domain,NoServerData));
}

int TCustomAI::SetDevModelCap(int f, int Value)
{
	return(Server(sSetDevModelCap+(Value << 4),me,f,NoServerData));
}

int TCustomAI::SetResearch(int Tech)
{
	return(Server(sSetResearch, me, Tech, NoServerData));
}

int TCustomAI::TestSetResearch(int Tech)
{
	return(Server(sSetResearch-sExecute, me, Tech, NoServerData));
}

int TCustomAI::SetAttitude(int Player,int Attitude)
{
	return(Server(sSetAttitude+(Player<<4), me, Attitude, NoServerData));
}

int TCustomAI::CancelTreaty(int Player)
{
	return(Server(sCancelTreaty+(Player<<4), me, 0, NoServerData));
}

int TCustomAI::DipAction(int Command)
{
	int result;
	if (Command==scDipOffer)
		result=Server(Command, me, 0, &MyOffer);
	else
		result=Server(Command, me, 0, NoServerData);
	if (result>-0x100)
		SentDipAction=Command;
	return (result);
}

int TCustomAI::Contact(int Player)
{
	int result=DipAction(scContact+(Player<<4));
	if (result>-0x100)	pContact=Player;
	return (result);
}

int TCustomAI::EndTurn(void)
{
	return(Server(sTurn, me, 0, NoServerData));
}

int DebugMessage(int Level, const char *Text, int me)
{
	return(Server(sMessage, me, Level, (pServerData)Text));
}
