#ifndef aimainh
#define aimainh

#include "protocol.h"
#include "aiclasses.h"
#include "HALlist.h"


#define UNREFERENCED_PARAMETER(x) x


struct UnitData
{
	int Index;
	TMoveAdviceData Moves;
	unsigned short ID;
};

struct HALdata	{
	HALlist<UnitData>	SettlerList;	//Keeps track of settler unit data.
	HALlist<UnitData>	AttackerList;	//Keeps track of attack unit data.
	HALlist<UnitData>	DefenderList;	//Keeps track of defense unit data.
	HALlist<UnitData>	GadgetryList;	//Keeps track of gadgetry unit data.
	HALlist<UnitData>	CruiserList;	//Keeps track of agressive naval unit data.
};

struct SettlerTile	{
	short	SettlersHere,
			TerraformSlave,
			TerraformSettler;
	int		Loc;
};

struct SettlerCity	{
	short	SettlersHere,
			SiteRank;
	int		Loc;
};

void DoTurn(int Player);
void DoNegotiation(int Player);
bool BuildingCityInLimits(int cloc, int me);
//Returns the number of possible terraformings jobs in a tile
//Return -1 if it's an invalid tile.
short TerraformJobs(long TempLoc,int UnitKind, int Player);
//Returns the total number of explotable food resources in the top four
//food production tiles in a theoretical city site.
//Return -1 if it's an invalid tile.
short CitySiteRank(long TempLoc, int Player);
//Detects a city within a radius of three tiles
bool CityInThree(int cloc, int me);
//Checks if any units in a UnitList need to be removed using ID field
//Updates indexes of units if an ID match is found
void PruneUnit(HALlist<UnitData> &UnitList, int me);
//Receives a unit index and determines if it needs to be added to a unit array
//Add units in ascending ID order
bool AddUnit(HALlist<UnitData> &UnitList, int uix, int Player);
//Uses UnitData to plan and execute a move until no more future moves are needed
void ExecuteMovement(UnitData &Unit, int Player);
//Create a DevModel for a defender.  Return true if it's better than current best model
bool BuildBetterDefender(int DefenseModel,int me);
//Create a DevModel for an attacker.  Return true if it's better than current best model
bool BuildBetterAttacker(int AttackModel,int me);
//Return the defenders in this city
int DefendersInCity(int cix, int me);
//checks if an enemy unit is on a tile.  Then returns the result of a potential attack
//range: -100 total defeat, +100 supreme victory.  -200 if invalid attack or no enemy.
int PotentialBattle(TUn MyUnit, int TargetLoc, int me);
int PotentialSeaBattle(TUn MyUnit, int TargetLoc, int me);
int PotentialGadgetryBattle(TUn MyUnit, int TargetLoc, int me);
//Return the number of nations that either don't have contact or no treaty
int HostileNations(int me);
//find the number of active players in the game
int ActivePlayers(int me);
//number of settlers on a tile
short SettlersOnTile(long Loc, int me);
//returns value of best attack value of a hostile unit model
int BestHostileAttack(int me);
int BestHostileSeaAttack(int me);
//returns value of best defense value of a hostile unit model
int BestHostileDefense(int me);
int BestHostileSeaDefense(int me);
//Returns number of gadgetry units needed based on number of total attacks on certain cities
//returns value of best defense value of a hostile sea unit model
int GadgetryNeeded(int me);
//Create a DevModel for a gadgetry unit.  Return true if it's better than current best model
bool BuildBetterGadgetry(int GadgetryModel,int me);
void StealTech(int me);
//Create a DevModel for a Cruiser unit.  Return true if it's better than current best model
bool BuildBetterCruiser(int CruiserModel,int me);
//Return number of cruisers owned by city.
int CruisersOwnedByCity(int cix, int me);
//Add a model index to the custom list of models
void AddModel(HALlist<int> &Models, int mix, int me);
//Make a unit model obsolete if none of its kind have been built
//void MakeObsolete(HALlist<int> &Models, int me);
//Returns estimate of number of attackers needed to take over enemy civs.
float AttackersNeeded(const int EnemyTiles[], int me);
//Attack an adjacent enemy if resulting health will be greater than 30%
void SnipeEnemy(HALnode<UnitData>* ucurr, int me);
//How many defenders needed within a city
int DefendersNeeded(int cix, const TCityReport &ThisCity, int me);

//The Client function
//extern = export
extern "C" void __stdcall client(int Command, int Player, void* Data);

#endif //ifndef aimainh