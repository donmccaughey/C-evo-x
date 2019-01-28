/*
AIHELPERS.H
Some little tool functions for AI Modules
Compiler: Tested with MS Visual C++ 6.0 (But I hope, ANSI C will do it also)
(C) '2001 by Matvej Soloviev ("blackhole89")
TK: removed logfl (didn't compile with it). Not tested.

Minor changes to fit new 10.0 protocol, Charles Nadolski November 23rd, 2002

Functions added and minor changes March 9th 2003 by Charles Nadolski

Greatly expanded by Charles Nadolski, 2003/6/7
Everything after the "NoCityAround" function was created by myself.

Update for Civ Evo 0.12 Oct 29th 2003 by Charles Nadolski
Nov 1st 2003: Minor bugfix for GetSeenTechnologies

Nov 4th 2003: Major bugfixes for functions where an invalid location may cause a crash

July 12th 2004: Code updated for version 13 of c-evo.

November 30th 2005: Added a new helper function

/******************************************************
*All code, unless otherwise stated, by Matvej Soloviev*
******************************************************/

#ifndef _AI_HELPERS
#define _AI_HELPERS

#include <math.h>
#include "protocol.h"
#include "aiclasses.h"

const int
	Dirx[]={1,2,1,0,-1,-2,-1,0,0}, // directions, x-component
	Diry[]={-1,0,1,2,1,0,-1,-2,0}; // directions, y-component

//Get a battle forecast
int getBattleForecast(int defLoc, TUn *u/*, int & defHealth, int  &attHealth*/)
{
	TBattleForecast BF;		// BF instance of structure TBattleForecast
	BF.pAtt = nPl;
	BF.mixAtt = u->mix;
	BF.HealthAtt = u->Health;
	BF.ExpAtt = u->Exp;
	BF.FlagsAtt = u->Flags;
	BF.Movement = u->Movement;

	return Server(sGetBattleForecast,nPl, defLoc, & BF ); // address of BF
}

//Missing Reimplementation in AICLASSES.H : sGetDefender
int GetDefender(int cloc,int nPlr)
{
	int dta;
	Server(sGetDefender,nPlr,cloc,&dta);
	return dta;
}

//Missing Reimplementation in AICLASSES.H : sGetTileInfo
TTileInfo GetTileInfo(long cloc,int nPlr)
{
	TTileInfo tti;
	Server(sGetTileInfo,nPlr,cloc,&tti);
	return tti;
}

//Missing Implementation in AICLASSES.H : sGetCityTileInfo
TTileInfo GetCityTileInfo(long cloc,int nPlr)
{
	TTileInfo tti;
	Server(sGetCityTileInfo,nPlr,cloc,&tti);
	return tti;
}

struct TSeenTechData {
	int *seentechs;
	int nSeenTechs;
};

//Do you have the Tech?
bool HasTech( int nTech , int nPlr )
{
	if(nTech == preNone) return true;
	else return (G.RO[nPlr]->Tech[nTech]==0);
} 

//Returns your best attacking model
int GetOptimalModel(TModel *models,int nModel)
{
	unsigned long BetterOne=0;
	int BetterIX=1;
	for(int mix=1;mix<nModel;mix++)
	{
		if(models[mix].Attack>BetterOne) { BetterOne=models[mix].Attack; BetterIX=mix; }
	}
	return BetterIX;
}

//Returns seen Technologies
//Edited by Charles Nadolski
TSeenTechData GetSeenTechnologies(TPlayerContext *tpc,int nPlr)
{
	DebugMessage(3,"I'm in GetSeenTechnologies",nPlr);
	int *retval;		//Return List
	TSeenTechData ret;	//Return Object
	retval=(int *)malloc((nAdv+3)*sizeof(int)); //Prevent AccessViolation Bugs
	int wpos=0;		//Writing position
	for(int i=0;i<nAdv+3;i++)
	{
		if(tpc->Tech[i]==tsResearched)
		{
	//		Already available
			continue;
		} 
		if(
			(HasTech(AdvPreq[i][0],nPlr) || AdvPreq[i][0]==preNone) &&
			(HasTech(AdvPreq[i][1],nPlr) || AdvPreq[i][1]==preNone) &&
			(HasTech(AdvPreq[i][2],nPlr) || AdvPreq[i][2]==preNone)
			)
		{
			//No Preq
			retval[wpos]=i;
			wpos++;
			continue;
		}
	}
//	logfl<<flush;	//Thomas Kay: ???
	ret.seentechs=retval;
	ret.nSeenTechs=wpos;
	return ret;
}

/********************************************
*All functions below are by Charles Nadolski*
********************************************/

//Returns the direction code for a nearby city tile
//If invalid or false, return -1
int CityAroundDir(int cloc, int me)	{
	int RemoteLoc;
	for(int dir=0;dir<8;dir++)	{
		RemoteLoc=Remote(cloc,Dirx[dir],Diry[dir]);
		if(Valid(RemoteLoc))
			if(CityHere(RemoteLoc,me)) return dir;
	}
	return -1;
}

//Returns Location of a nearby city tile
//If invalid or false, return -1
int CityAroundLoc(int cloc, int me)	{
	int RemoteLoc;
	for(int dir=0;dir<8;dir++)	{
		RemoteLoc=Remote(cloc,Dirx[dir],Diry[dir]);
		if(Valid(RemoteLoc))
			if(CityHere(RemoteLoc,me)) return RemoteLoc;
	}
	return -1;
}

//Returns the direction code for a nearby unit tile
//If invalid or false, return -1
int UnitAroundDir(int cloc, int me)	{
	int RemoteLoc;
	for(int dir=0;dir<8;dir++)	{
		RemoteLoc=Remote(cloc,Dirx[dir],Diry[dir]);
		if(Valid(RemoteLoc))
			if(UnitHere(RemoteLoc,me)) return dir;
	}
	return -1;
}

//Returns Location of a nearby unit tile
//If invalid or false, return -1
int UnitAroundLoc(int cloc, int me)	{
	int RemoteLoc;
	for(int dir=0;dir<8;dir++)	{
		RemoteLoc=Remote(cloc,Dirx[dir],Diry[dir]);
		if(Valid(RemoteLoc))
			if(UnitHere(RemoteLoc,me)) return RemoteLoc;
	}
	return -1;
}

//Returns the direction code for a nearby grass tile
//If invalid or false, return -1
int GrassAroundDir(int cloc, int me)	{
	int RemoteLoc;
	for(int dir=0;dir<8;dir++)	{
	    RemoteLoc=Remote(cloc,Dirx[dir],Diry[dir]);
		if(Valid(RemoteLoc))
			if(TerrType(RemoteLoc,me)==fGrass) return dir;
	}
	return -1;
}

//Returns the Location of a nearby grass tile
//If invalid or false, return -1
int GrassAroundLoc(int cloc, int me)	{
	int RemoteLoc;
	for(int dir=0;dir<8;dir++)	{
		RemoteLoc=Remote(cloc,Dirx[dir],Diry[dir]);
		if(Valid(RemoteLoc))
			if(TerrType(RemoteLoc,me)==fGrass) return RemoteLoc;
	}
	return -1;
}

//Returns the number of unknown tiles surrounding a tile
//Return -1 if it's an invalid tile.
int UnknownTiles(int TempLoc,int Player)	{
	//Invalid Location
	if(!Valid(TempLoc))
		return -1;
	
	int TerrainType = TerrType(TempLoc, Player);
	int TerrainFlag = TileFlags(TempLoc, Player);
	//Limit to known non-water, non-eerie, and not enemy occupied tiles
	if (
		(TerrainType < fGrass) || (TerrainType == fUNKNOWN) ||
		((TerrainFlag & (fRare | fRare1 | fRare2)) != 0) ||
		EnemyUnitHere(TempLoc,Player) || EnemyCityHere(TempLoc,Player)
		)
		return -1;

	int UnknownNum=0;
	int RemoteLoc;
	for (int i=0;i<8;i++)
	{
		RemoteLoc=Remote(TempLoc,Dirx[i],Diry[i]);
		if (Valid(RemoteLoc))
			if(TerrType(RemoteLoc, Player) == fUNKNOWN)
				UnknownNum++;
	}
	return UnknownNum;
}

//Returns the number of unknown tiles surrounding a sea tile
//Return -1 if it's an invalid tile.
int UnknownSeaTiles(int TempLoc,int Player)
{
	//Invalid Location
	if(!Valid(TempLoc))
		return -1;
	
	int TerrainType = TerrType(TempLoc, Player);
	//Limit to known water, and not enemy occupied tiles
	if (
		(TerrainType >= fGrass) ||
		EnemyUnitHere(TempLoc,Player) || EnemyCityHere(TempLoc,Player)
		)
		return -1;

	int UnknownNum=0;
	int RemoteLoc;
	for (int i=0;i<8;i++)
	{
		RemoteLoc=Remote(TempLoc,Dirx[i],Diry[i]);
		if (Valid(RemoteLoc))
			if(TerrType(RemoteLoc, Player) == fUNKNOWN)
				UnknownNum++;
	}
	return UnknownNum;
}

//returns true if only target is a defenseless city
bool NearDefenselessCity(int Loc,int me)
{
	int dir;
	for (dir=0;dir<8;dir++)
		if(Valid(Remote(Loc,Dirx[dir],Diry[dir])))
			if(	//Foreign City that does not contain a unit
				EnemyCityHere(Remote(Loc,Dirx[dir],Diry[dir]),me) &&
				!EnemyUnitHere(Remote(Loc,Dirx[dir],Diry[dir]),me)
				)
				return true;
	return false;
}

//At least one person has researched this tech
bool SomeoneHasTech(int Tech)
{
	int pix;
	for(pix=(G.Difficulty[0]<1);pix<nPl;pix++)
	{
		//If a nation is destroyed, it's RO goes to NULL, can't tell if have tech
		if(G.RO[pix]!=0)
			if(G.RO[pix]->Tech[Tech]==0) return true;
	}
	return false;
}

//Determines if a shore tile is around location, and therefore coastal improvements built
bool Coastal(long cloc, int me)
{
	long tempLoc;
	int dir;
	for (dir=0; dir<=8; dir++)
	{
		tempLoc=Remote(cloc,Dirx[dir],Diry[dir]);
		if(Valid(tempLoc))
			if(TerrType(tempLoc, me)==fShore)
				return true;
	}
	return false;
}

//Determines if a hydroelectric style plant could be built at a location
bool HydroAvailable(int cloc, int me)
{
	int tempLoc,dir;
	if(Valid(cloc))
		if(	(TerrType(cloc, me)==fMountains) ||
			((TileFlags(cloc, me) & fRiver) != 0)	)
			return true;
	for (dir=0; dir<=8; dir++)
	{
		tempLoc=Remote(cloc,Dirx[dir],Diry[dir]);
		if(Valid(tempLoc))
			if(	(TerrType(tempLoc, me)==fMountains) ||
				((TileFlags(tempLoc, me) & fRiver) != 0)	)
				return true;
	}
	return false;
}

//Returns true if irrigation is possible in a tile
bool HasWaterAccess(int cloc, int me)
{
	int TerrainFlag=TileFlags(cloc,me);
	if(
		((TerrainFlag & TerImpMask) == tiIrrigation) ||
		((TerrainFlag & TerImpMask) == tiFarm) ||
		((TerrainFlag & (fRiver | fCanal))!=0)
		)
		return true;

	int TerrainType;
	int RemoteLoc=Remote(cloc,1,1);
	if(Valid(RemoteLoc))
	{
		TerrainFlag=TileFlags(RemoteLoc,me);
		TerrainType=TerrType(RemoteLoc,me);
		if(
			((TerrainFlag & TerImpMask) == tiIrrigation) ||
			((TerrainFlag & TerImpMask) == tiFarm) ||
			((TerrainFlag & (fRiver | fCanal))!=0) ||
			(TerrainType == fShore)
			)
			return true;
	}

	RemoteLoc=Remote(cloc,1,-1);
	if(Valid(RemoteLoc))
	{
		TerrainFlag=TileFlags(RemoteLoc,me);
		TerrainType=TerrType(RemoteLoc,me);
		if(
			((TerrainFlag & TerImpMask) == tiIrrigation) ||
			((TerrainFlag & TerImpMask) == tiFarm) ||
			((TerrainFlag & (fRiver | fCanal))!=0) ||
			(TerrainType == fShore)
			)
			return true;
	}

	RemoteLoc=Remote(cloc,-1,1);
	if(Valid(RemoteLoc))
	{
		TerrainFlag=TileFlags(RemoteLoc,me);
		TerrainType=TerrType(RemoteLoc,me);
		if(
			((TerrainFlag & TerImpMask) == tiIrrigation) ||
			((TerrainFlag & TerImpMask) == tiFarm) ||
			((TerrainFlag & (fRiver | fCanal))!=0) ||
			(TerrainType == fShore)
			)
			return true;
	}

	RemoteLoc=Remote(cloc,-1,-1);
	if(Valid(RemoteLoc))
	{
		TerrainFlag=TileFlags(RemoteLoc,me);
		TerrainType=TerrType(RemoteLoc,me);
		if(
			((TerrainFlag & TerImpMask) == tiIrrigation) ||
			((TerrainFlag & TerImpMask) == tiFarm) ||
			((TerrainFlag & (fRiver | fCanal))!=0) ||
			(TerrainType == fShore)
			)
			return true;
	}

	return false;
}

//Says if another friendly city exists within a theoretical city's limits
bool CityInLimits(int cloc, int me)
{
	int tempLoc,i,j;
	for(i=-2;i<=2;i++)
		for(j=-2;j<=2;j++)
			if(((i-j)*(i-j)+(i+j)*(i+j)) <= 10)	//Corner Tile (out of city range)
			{
				tempLoc=Remote(cloc,i-j,i+j);
				if(Valid(tempLoc))
					if(OwnCityHere(tempLoc,me))
						return true;
			}
	return false;
}

// sometimes, you might wish to calc the distance as floating point value
// the int-Version is of course the faster one!
// the functions below are using the int-version
// --Frank Mierse
float FloatDistance (int FromLoc, int ToLoc)
{
	float xx, yy;
	int dx=(((ToLoc%G.lx)*2+(ToLoc/G.lx&1))
		-((FromLoc%G.lx)*2+(FromLoc/G.lx&1))+3*G.lx)%(2*G.lx)-G.lx;
	int dy=ToLoc/G.lx - FromLoc/G.lx;

	xx = float(dx * dx);
	yy = float(dy * dy);
	return (sqrt (xx + yy));
}

#endif