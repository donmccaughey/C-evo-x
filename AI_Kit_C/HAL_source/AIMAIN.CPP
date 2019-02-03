/*
HAL artificial intelligence module for cEvo, Charles Nadolski.
The credits for the source code are at the bottom of this comment section.
Thanks for this C++ booster code!
I haven't changed the Diplomacy yet as I just want to start with
an AI that can build cities and explore.

Dreamy-eyed vision:
True AI will probably never be implemented in this game,
given the size of the state space, and the limited computing
and memory power alloted. However, I aim to implement
an AI that uses very simple rules that are nevertheless
very adaptable to different circumstances, and certain
AI concepts and algorithms will still be used.

Credits to for the random number seeder Ulrich Olderdissen [ulrich.olderdissen@gmx.de]

0.8 update Thomas Kay.
Diplomacy implemented.
Changed DoTurn() to use MyRO syntax - close to Delphi.
AIMAIN.CPP 0.7.0
C AI Development Template
'01 by Matvej Soloviev ("blackhole89")
*/

#include <stdlib.h>	//abs(), rand()
//#include <time.h>	//time() -- uncomment to enable CPU random number seed instead of fixed seed
#include <math.h>	//sqrt()
#include <assert.h>	//assert()
#include "protocol.h"
#include "aiclasses.h"
#include "aimain.h"
#include "aihelpers.h"
#include "HALlist.h"

TCustomAI *AI[nPl];
HALdata *HAL[nPl];
int debug;

//Include here the items you'd like to have in the save area (Data) of the RO block
//Keep in mind that arrays, lists, and other objects have to be of a fixed size
struct DataBlock	{
	unsigned long RandomSeed;
};

void DoTurn(int Player)
{

	if (AI[Player]->AfterNegotiation)
	{
		AI[Player]->EndTurn();
		return;
	}

	//Random Number Initialization:
	//Comment this section out if you want to use a CPU-clock generated seed
	//(see cInitModule for using the CPU as a seeder)
	//This seeder however will ensure that you get the same list of random numbers
	//for a specific book.
	if (G.RO[Player]->Turn == 0)
		//If in the first turn, get the random seed from the location of the first settler
		//and store it to the memory block
		((DataBlock*)G.RO[Player]->Data)->RandomSeed = AI[Player]->MyUn[0].Loc;

	//srand (*(static_cast<long*>(G.RO[Player]->Data) + RandomSeed));
	//*(static_cast<long*>(G.RO[Player]->Data) + RandomSeed) = rand();
 	srand(((DataBlock*)G.RO[Player]->Data)->RandomSeed);
	((DataBlock*)G.RO[Player]->Data)->RandomSeed = rand();

	/*****************
	*Model Management*
	*****************/

	int flag,i,j,uix, mix, SettlerModel;
	HALlist<int> AttackerModels,DefenderModels,GadgetryModels,CruiserModels;
	HALnode<int>* mcurr;

	//Find best models for Settler
	//Tally models for Defender, Attacker, and Gadgetry
	for(mix=0,SettlerModel=0;mix<AI[Player]->MyRO.nModel;mix++)
	{
		if(mix==1) //will always be militia
			AddModel(AttackerModels, mix, Player);
		else if(mix==2) //will always be town guard
			AddModel(DefenderModels, mix, Player);
		else if((AI[Player]->MyModel[mix].Kind==mkSettler) || (AI[Player]->MyModel[mix].Kind==mkSlaves))
			SettlerModel=mix;
		else if(
			(AI[Player]->MyModel[mix].Attack>=AI[Player]->MyModel[mix].Defense) &&
			(AI[Player]->MyModel[mix].Domain==dSea)
			)
			AddModel(CruiserModels, mix, Player);
		else if(
			(AI[Player]->MyModel[mix].Domain==dGround) &&
			(AI[Player]->MyModel[mix].Cap[mcDefense] == 2) &&
			(AI[Player]->MyModel[mix].Cap[mcMob] == 0)
			)
			AddModel(DefenderModels, mix, Player);
		else if(
			(AI[Player]->MyModel[mix].Domain==dGround) &&
			(AI[Player]->MyModel[mix].Cap[mcOffense]/2 == AI[Player]->MyModel[mix].Cap[mcMob]/2)
			)
			AddModel(AttackerModels, mix, Player);
		else if(
			(AI[Player]->MyModel[mix].Domain==dGround) &&
			(AI[Player]->MyModel[mix].Cap[mcOffense]/2 >= AI[Player]->MyModel[mix].Cap[mcMob])
			)
			AddModel(GadgetryModels, mix, Player);
	}

	//Create revolution if new tech has been discovered
	//Not quite ready for libertarianism yet...
	if((AI[Player]->MyRO.Happened & phTech) != 0)
	{
		int TempGov=gAnarchy;
		if(HasTech(adDemocracy,Player))
			TempGov=gDemocracy;
		else if(HasTech(adTheRepublic,Player))
			TempGov=gRepublic;
		else if(HasTech(adMonarchy,Player))
			TempGov=gMonarchy;
/*		if(HasTech(adLybertarianism,Player))
			TempGov=gLybertarianism;*/
		//If current government is inferior to the one just researched, revolution begins
		if (AI[Player]->MyRO.Government<TempGov)
			Server(sRevolution, Player, 0, NoServerData);
	}


	//Attempt to change government forms if anarchy has ended
	//Not quite ready for libertarianism yet...
	if((AI[Player]->MyRO.Happened & phChangeGov) != 0)
	{
/*		if(HasTech(adLybertarianism,Player))
			AI[Player]->SetGovernment(gLybertarianism);
		else*/ if(HasTech(adDemocracy,Player))
			AI[Player]->SetGovernment(gDemocracy);
		else if(HasTech(adTheRepublic,Player))
			AI[Player]->SetGovernment(gRepublic);
		else if(HasTech(adMonarchy,Player))
			AI[Player]->SetGovernment(gMonarchy);
	}

	int BestAttacker=AttackerModels.head()->data;
	int BestDefender=DefenderModels.head()->data;
	int BestGadgetry,BestCruiser;
	if(GadgetryModels.length()>0)
		BestGadgetry=GadgetryModels.head()->data;
	else
		BestGadgetry=1;//Militia model
	if(CruiserModels.length()>0)
		BestCruiser=CruiserModels.head()->data;
	else
		BestCruiser=1;//Militia model

	/*********
	*Research*
	*********/

	if((AI[Player]->MyRO.Happened & phTech) != 0)
	{
		TSeenTechData AvailableTech = GetSeenTechnologies(G.RO[Player],Player);
		//rush to get scouts
		if(!HasTech(adHorsebackRiding,Player))
			AI[Player]->SetResearch(adHorsebackRiding);
		else if(!HasTech(adBronzeWorking,Player))
			AI[Player]->SetResearch(adBronzeWorking);
		else if(!HasTech(adWarriorCode,Player))
			AI[Player]->SetResearch(adWarriorCode);
		else if(BuildBetterAttacker(BestAttacker, Player))
			AI[Player]->SetResearch(adMilitary);
		//Research tree towards Monarchy...
		else if(!HasTech(adMonarchy,Player))
			for(i=0;i<AvailableTech.nSeenTechs;i++)
			{
				if(AvailableTech.seentechs[i]==adCeremonialBurial)
				{
					AI[Player]->SetResearch(adCeremonialBurial);
					break;
				}
				else if(AvailableTech.seentechs[i]==adPolytheism)
				{
					AI[Player]->SetResearch(adPolytheism);
					break;
				}
				else if(AvailableTech.seentechs[i]==adMonarchy)
				{
					AI[Player]->SetResearch(adMonarchy);
					break;
				}
			}
		//research defenders and rest next
		else if(BuildBetterDefender(BestDefender, Player))
			AI[Player]->SetResearch(adMilitary);
		else if(BuildBetterGadgetry(BestGadgetry, Player))
			AI[Player]->SetResearch(adMilitary);
		else if(BuildBetterCruiser(BestCruiser, Player))
			AI[Player]->SetResearch(adMilitary);
		else
		{
			for(i=0;i<AvailableTech.nSeenTechs;i++)
				if(	//Checks if a tech has been stolen/acquired
					(G.RO[Player]->Tech[AvailableTech.seentechs[i]]==tsGrLibrary) ||
					(G.RO[Player]->Tech[AvailableTech.seentechs[i]]==tsSeen)
					)
						AI[Player]->SetResearch(i);

			if(i==AvailableTech.nSeenTechs)	//pick a random tech if no stolen tech is found
				AI[Player]->SetResearch(AvailableTech.seentechs[rand()%AvailableTech.nSeenTechs]);
		}
	}

	/******************
	*Reset Unit Arrays*
	******************/

	PruneUnit(HAL[Player]->SettlerList,Player);
	PruneUnit(HAL[Player]->AttackerList,Player);
	PruneUnit(HAL[Player]->DefenderList,Player);
	PruneUnit(HAL[Player]->GadgetryList,Player);
	PruneUnit(HAL[Player]->CruiserList,Player);

	//Now add missing or newly-built units and update the indexes of ALL units
	for(uix=0; uix<AI[Player]->MyRO.nUn; uix++)
	{
		if(
			(Common(AI[Player]->MyUn[uix],Player).Kind==mkSettler) ||
			(Common(AI[Player]->MyUn[uix],Player).Kind==mkSlaves)
			)
			AddUnit(HAL[Player]->SettlerList,uix,Player);
		else
		{
			bool done=false;
			for(mcurr=AttackerModels.head();(mcurr!=NULL) && !done;mcurr=mcurr->next)
				if(AI[Player]->MyUn[uix].mix==mcurr->data)
					done=AddUnit(HAL[Player]->AttackerList,uix,Player);
			for(mcurr=DefenderModels.head();(mcurr!=NULL) && !done;mcurr=mcurr->next)
				if(AI[Player]->MyUn[uix].mix==mcurr->data)
					done=AddUnit(HAL[Player]->DefenderList,uix,Player);
			for(mcurr=GadgetryModels.head();(mcurr!=NULL) && !done;mcurr=mcurr->next)
				if(AI[Player]->MyUn[uix].mix==mcurr->data)
					done=AddUnit(HAL[Player]->GadgetryList,uix,Player);
			for(mcurr=CruiserModels.head();(mcurr!=NULL) && !done;mcurr=mcurr->next)
				if(AI[Player]->MyUn[uix].mix==mcurr->data)
					done=AddUnit(HAL[Player]->CruiserList,uix,Player);
		}
	}

	//Get the total number of land tiles, and untouched land tiles (used in calculation of number of needed settlers)
	//Also obtain extimate of number of tiles
	long tix;
	int TerrainType,TerrainFlags,LandTiles=0,VirginTiles=0,
		mask=TerImpMask | fRoad | fRR | fPoll | fCity;
	int *EnemyTiles= new int[nPl];
	for (i=0;i<nPl;i++) EnemyTiles[i]=0;
	HALlist<SettlerTile>	SettlerTiles;
	HALlist<SettlerCity>	SettlerCities;
	TTileInfo TempTile;
	for(tix=0;tix<G.lx*G.ly;tix++)
	{
		TerrainType=TerrType(tix,Player);
		TerrainFlags=TileFlags(tix,Player);
		if(	(TerrainType>=fGrass) &&
			(TerrainType<=fMountains)
		)	{
			LandTiles++;
			SettlerCity TempCity;
			TempCity.SiteRank = CitySiteRank(tix,Player);
			//City to be founded must be able to support at least a size 4 city
			if(TempCity.SiteRank >= 8)	{
				TempCity.SettlersHere = SettlersOnTile(tix,Player);
				TempCity.Loc = tix;
				SettlerCities.Append(TempCity);
			}
			if((TerrainFlags & mask) == 0)
				VirginTiles++;
		}
		//get tiles within your territory
		if(((TerrainFlags & TerritoryMask)>>27)!=15)	{
			EnemyTiles[(TerrainFlags & TerritoryMask)>>27]++;
			if (((TerrainFlags & TerritoryMask)>>27)==Player)	{
					//record tiles that *need* to be terraformed and hills
					flag=Server(sGetCityTileInfo,Player,tix,&TempTile);
					if(	((TempTile.ExplCity!=-1) && (flag != 0))	||
						(TerrainType==fHills) || (TerrainType==fMountains)
					)	{
						SettlerTile TempSettlerTile;
						TempSettlerTile.TerraformSettler = TerraformJobs(tix,mkSettler,Player);
						TempSettlerTile.TerraformSlave = TerraformJobs(tix,mkSlaves,Player);
						if((TempSettlerTile.TerraformSettler > 0) && (TempSettlerTile.TerraformSlave > 0))	{
							TempSettlerTile.SettlersHere = SettlersOnTile(tix,Player);
							TempSettlerTile.Loc = tix;
							SettlerTiles.Append(TempSettlerTile);
						}
					}
			}
		}
	}

	//City Actions
	bool UselessProject;
	TCityReport ThisCity;
	TCityAreaInfo CityTiles;
	int cix,dx,dy,TerrainFlag,ImpNum,OldWonder=-1,
		Max,Min,MaxTrade=0,MaxIndex,MinIndex,MaxTradeIndex=-1,
		TotalTax=0, TotalCost=0,MaxPopIndex=-1,MaxProd=0,MaxProdIndex=-1;
	unsigned long MaxPop=0;
	HALnode<UnitData>* ucurr;
	//Check if certain projects/wonders exist.  Fince maximum research city, net income
	bool Palace=(AI[Player]->MyRO.NatBuilt[imPalace-imTrGoods]==1),
		GreatWall=(AI[Player]->MyRO.NatBuilt[imGrWall-imTrGoods]==1),
		Hoover=(AI[Player]->MyRO.Wonder[woHoover].EffectiveOwner==Player);

	for(cix=0;cix<AI[Player]->MyRO.nCity;cix++)	{
		//Refresh the Status field in cities so they don't all become ones
		AI[Player]->MyCity[cix].Status = AI[Player]->MyCity[cix].Status << 1;
		ThisCity.HypoTiles=AI[Player]->MyCity[cix].Tiles;
		Server(sGetCityReport, Player, cix, &ThisCity);
		if(ThisCity.Trade>MaxTrade)	{
			MaxTrade=ThisCity.Trade;
			MaxTradeIndex=cix;
		}
		if(AI[Player]->MyCity[cix].Prod>MaxProd)	{
			MaxProd=AI[Player]->MyCity[cix].Prod;
			MaxProdIndex=cix;
		}
		if(AI[Player]->MyCity[cix].Size>MaxPop)		{
			MaxPop=AI[Player]->MyCity[cix].Size;
			MaxPopIndex=cix;
		}
		TotalTax+=ThisCity.Tax;
		for(i=0;i<nImp;i++)
			if(AI[Player]->MyCity[cix].Built[i]==1)
				TotalCost+=Imp[i].Maint;
	}

	//Increase taxes if getting low on funds
	if(
		(AI[Player]->MyRO.Money<(AI[Player]->MyRO.nCity*8)) &&
		((TotalTax-TotalCost)<0)
	)
		//you don't want to have tech stagnation, so keep a minimum of 10% science production
		if(AI[Player]->MyRO.TaxRate<80)
			AI[Player]->SetRates(AI[Player]->MyRO.TaxRate+10,AI[Player]->MyRO.LuxRate);

	//Lower taxes if reaching a surplus
	if(	(	(AI[Player]->MyRO.Money>(AI[Player]->MyRO.nCity*16)) &&
			((TotalTax-TotalCost)>0)	) ||
		(AI[Player]->MyRO.Money>(AI[Player]->MyRO.nCity*32))
	)
		if(AI[Player]->MyRO.TaxRate>0)
			flag=AI[Player]->SetRates(AI[Player]->MyRO.TaxRate-10,AI[Player]->MyRO.LuxRate);

	for(cix=0; cix<AI[Player]->MyRO.nCity;cix++)
	{
		ThisCity.HypoTiles=-1;
		Server(sGetCityReport, Player, cix, &ThisCity);
		Server(sGetCityAreaInfo, Player, cix, &CityTiles);
		/**************************
		CityActions:
		Specialist/Tile Maintenance
		**************************/
		//Check if there is at least one specialist in this city (defined as being non-working citizens)
		//Check if there is "too much" happiness (defined as having less unhappy citizens than half the city size)
		if(
			((AI[Player]->MyCity[cix].Size-ThisCity.Working)>0) &&
			((ThisCity.Working-ThisCity.Happy)<(AI[Player]->MyCity[cix].Size/2))
			)
		{	//Locate best available tile
			Max=0;
			MaxIndex=-1;
			for(i=-2;i<=2;i++)
				for(j=-2;j<=2;j++)
				{
					dx=i-j;
					dy=i+j;
					if(
						//Center Tile (city proper)
						!((dx==0) && (dy==0)) &&
						//Corner Tile (out of city range)
						((dx*dx+dy*dy) <= 10) &&
						//available
						(CityTiles.Available[((dy+3)<<2) + ((dx+3)>>1)]==faAvailable) &&
						//unexploited
						(((AI[Player]->MyCity[cix].Tiles >> (((dy+3)<<2) + ((dx+3)>>1))) & 1) == 0)
						)
					{
						TempTile=GetTileInfo(Remote(AI[Player]->MyCity[cix].Loc,dx,dy),Player);
						if((TempTile.Food+TempTile.Prod+TempTile.Trade)>Max)
							{
								Max=(TempTile.Food+TempTile.Prod+TempTile.Trade);
								MaxIndex=((dy+3)<<2) + ((dx+3)>>1);
							}
					}
				}
			if(MaxIndex!=-1)
			{	//make specialist work on best tile
				//do OR operation on bit located at MaxIndex in Tiles exploited by city
				unsigned long NewTiles = 1;
				NewTiles = AI[Player]->MyCity[cix].Tiles | (NewTiles << MaxIndex);
				Server(sSetCityTiles, Player, cix, &NewTiles);
				ThisCity.HypoTiles=-1;
				Server(sGetCityReport, Player, cix, &ThisCity);
				Server(sGetCityAreaInfo, Player, cix, &CityTiles);
			}
		}

		//check if the city has low food production
		if(
			((AI[Player]->MyCity[cix].Flags & chDisorder) == 0) &&
			((ThisCity.FoodRep-ThisCity.Eaten)<=0)
			)
		{
			Max=0;
			MaxIndex=-1;
			Min=16;	//doubt if any tile will produce more than 16 total resources
			MinIndex=-1;
			for(i=-2;i<=2;i++)
				for(j=-2;j<=2;j++)
				{
					dx=i-j;
					dy=i+j;
					if(	//Center Tile (city proper)
						!((dx==0) && (dy==0)) &&
						//Corner Tile (out of city range)
						((dx*dx+dy*dy) <= 10)
						)
					{
						if(	//Get best untaken food tile
							(CityTiles.Available[((dy+3)<<2) + ((dx+3)>>1)]==faAvailable) &&
							(((AI[Player]->MyCity[cix].Tiles >> (((dy+3)<<2) + ((dx+3)>>1))) & 1) == 0)
							)
						{
							TempTile=GetTileInfo(Remote(AI[Player]->MyCity[cix].Loc,dx,dy),Player);
							if(TempTile.Food>Max)
							{
								Max=TempTile.Food;
								MaxIndex=((dy+3)<<2) + ((dx+3)>>1);
							}
						}
						 //Get worst taken tile 
						else if(((AI[Player]->MyCity[cix].Tiles >> (((dy+3)<<2) + ((dx+3)>>1))) & 1) != 0)
						{
							TempTile=GetCityTileInfo(Remote(AI[Player]->MyCity[cix].Loc,dx,dy),Player);
							if((TempTile.Food+TempTile.Prod+TempTile.Trade)<Min)
							{
								Min=(TempTile.Food+TempTile.Prod+TempTile.Trade);
								MinIndex=((dy+3)<<2) + ((dx+3)>>1);
							}
						}
					}
				}
			if((MaxIndex!=-1) && (MinIndex!=-1))
			{	//Exchange poorest tile for best food tile
				//do OR operation on bit located at MaxIndex in Tiles exploited by city
				//do AND operation on bit located at MinIndex in Tiles exploited by city
				unsigned long NewTiles = 1;
				NewTiles = AI[Player]->MyCity[cix].Tiles & ~(NewTiles << MinIndex) | (NewTiles << MaxIndex);
				Server(sSetCityTiles, Player, cix, &NewTiles);
				//reset city information
				ThisCity.HypoTiles=-1;
				Server(sGetCityReport, Player, cix, &ThisCity);
				Server(sGetCityAreaInfo, Player, cix, &CityTiles);
			}
		}

		//check if the city has no production, or very little production, depending on city size
		//(this doesn't work for cities building ship parts)
		if(
			(	((AI[Player]->MyCity[cix].Project & cpImp) == 0) ||
				(Imp[(AI[Player]->MyCity[cix].Project & cpIndex)].Kind!=ikWonder)	) &&
			((AI[Player]->MyCity[cix].Flags & chDisorder) == 0) &&
			((ThisCity.ProdRep-ThisCity.Support)<(AI[Player]->MyCity[cix].Size-3))
			)
		{
			Max=0;
			MaxIndex=-1;
			Min=8;	//doubt if any tile will produce more than 8 food
			MinIndex=-1;
			for(i=-2;i<=2;i++)
				for(j=-2;j<=2;j++)
				{
					dx=i-j;
					dy=i+j;
					if(
						//Center Tile (city proper)
						!((dx==0) && (dy==0)) &&
						//Corner Tile (out of city range)
						((dx*dx+dy*dy) <= 10)
						)
					{
						if(	//Get best untaken production tile
							(CityTiles.Available[((dy+3)<<2) + ((dx+3)>>1)]==faAvailable) &&
							(((AI[Player]->MyCity[cix].Tiles >> (((dy+3)<<2) + ((dx+3)>>1))) & 1) == 0)
							)
						{
							TempTile=GetTileInfo(Remote(AI[Player]->MyCity[cix].Loc,dx,dy),Player);
							if(TempTile.Prod>Max)
							{
								Max=TempTile.Prod;
								MaxIndex=((dy+3)<<2) + ((dx+3)>>1);
							}
						}
						else if(((AI[Player]->MyCity[cix].Tiles >> (((dy+3)<<2) + ((dx+3)>>1))) & 1) != 0)
						{
							TempTile=GetCityTileInfo(Remote(AI[Player]->MyCity[cix].Loc,dx,dy),Player);
							if( //Get worst taken food tile (that doesn't produce much resources)
							(TempTile.ExplCity==cix) &&
							(TempTile.Food<Min) &&
							(TempTile.Prod<=1)
							)
							{
								Min=TempTile.Food;
								MinIndex=((dy+3)<<2) + ((dx+3)>>1);
							}
						}
					}
				}
			if((MaxIndex!=-1) && (MinIndex!=-1))
			{	//Exchange worst food tile for best production tile
				//do OR operation on bit located at MaxIndex in Tiles exploited by city
				//do AND operation on bit located at MinIndex in Tiles exploited by city
				unsigned long NewTiles = 1;
				NewTiles = AI[Player]->MyCity[cix].Tiles & ~(NewTiles << MinIndex) | (NewTiles << MaxIndex);
				Server(sSetCityTiles, Player, cix, &NewTiles);
				//reset city information
				ThisCity.HypoTiles=-1;
				Server(sGetCityReport, Player, cix, &ThisCity);
				Server(sGetCityAreaInfo, Player, cix, &CityTiles);
			}
		}

		//Check if there is Civil Disorder
		if((AI[Player]->MyCity[cix].Flags & chDisorder) != 0)
		{
			//Locate worst available tile
			Min=16;	//doubt if any tile will contain more than 16 resources
			MinIndex=-1;
			for(i=-2;i<=2;i++)
				for(j=-2;j<=2;j++)
				{
					dx=i-j;
					dy=i+j;
					if(
						//Center Tile (city proper)
						!((dx==0) && (dy==0)) &&
						//Tile Exploited
						(((AI[Player]->MyCity[cix].Tiles >> (((dy+3)<<2) + ((dx+3)>>1))) & 1) != 0)
						)
					{
						TempTile=GetCityTileInfo(Remote(AI[Player]->MyCity[cix].Loc,dx,dy),Player);
						//Get worst taken tile
						if((TempTile.Food+TempTile.Prod+TempTile.Trade)<Min)
						{
							Min=(TempTile.Food+TempTile.Prod+TempTile.Trade);
							MinIndex=((dy+3)<<2) + ((dx+3)>>1);
						}
					}
				}
			if(MinIndex!=-1)
			{	//Change worst tile into specialist
				//do AND operation on bit located at MinIndex in Tiles exploited by city
				unsigned long NewTiles = 1;
				NewTiles = AI[Player]->MyCity[cix].Tiles & ~(NewTiles << MinIndex);
				Server(sSetCityTiles, Player, cix, &NewTiles);
				//reset city information
				ThisCity.HypoTiles=-1;
				Server(sGetCityReport, Player, cix, &ThisCity);
				Server(sGetCityAreaInfo, Player, cix, &CityTiles);
			}
		}

		/**********************
		City Actions:
		Improvement Maintenance
		**********************/
		//Sell hydro plants if Hoover Dam is built
		//Note: will replace with more complicated formula once <%50 landmass is taken into account
		if (Hoover)
		{
			ImpNum=imHydro;
			Server(sSellCityImprovement,Player,cix,&ImpNum);
		}
		//Sell city walls if protected by GreatWall
		if((TileFlags(AI[Player]->MyCity[cix].Loc,Player) & fGrWall)!=0)
		{
			ImpNum=imWalls;
			Server(sSellCityImprovement,Player,cix,&ImpNum);
		}

		//sell town hall if palace or courthouse built
		if(
			(AI[Player]->MyCity[cix].Built[imTownHall]==1) &&
			(	(AI[Player]->MyCity[cix].Built[imPalace]==1) ||
				(AI[Player]->MyCity[cix].Built[imCourt]==1)	)
		)
		{
			ImpNum=imTownHall;
			Server(sSellCityImprovement,Player,cix,&ImpNum);
		}

		//sell courthouse if palace built
		if(
			(AI[Player]->MyCity[cix].Built[imPalace]==1) &&
			(AI[Player]->MyCity[cix].Built[imCourt]==1)
		)
		{
			ImpNum=imCourt;
			Server(sSellCityImprovement,Player,cix,&ImpNum);
		}

		/********************************
		City Actions:
		Unit and Improvement construction
		********************************/

		//Check if current project is not needed...
		UselessProject=false;
		//Check buildings
		if((AI[Player]->MyCity[cix].Project & cpImp) !=0)
		{
			//trading goods is "useless"
			if(Imp[(AI[Player]->MyCity[cix].Project & cpIndex)].Kind==ikTrGoods)
				UselessProject=true;
			//Useless if building already-built or expired wonder...
			else if(
				(Imp[(AI[Player]->MyCity[cix].Project & cpIndex)].Kind==ikWonder) &&
				(	(AI[Player]->MyRO.Wonder[(AI[Player]->MyCity[cix].Project & cpIndex)].EffectiveOwner>-1) ||
					((AI[Player]->MyCity[cix].Flags & chOldWonder)!=0)	)
				)
			{
				UselessProject=true;
				OldWonder=(AI[Player]->MyCity[cix].Project & cpIndex);
			}
			//Check for repeat National Projects
			else if (
				(	(Imp[(AI[Player]->MyCity[cix].Project & cpIndex)].Kind == ikNatLocal) ||
					(Imp[(AI[Player]->MyCity[cix].Project & cpIndex)].Kind == ikNatGlobal)	) &&
				(AI[Player]->MyRO.NatBuilt[(AI[Player]->MyCity[cix].Project & cpIndex)-28]==1)
				)
				UselessProject=true;
			//Check for repeat City Walls
			else if (
				((AI[Player]->MyCity[cix].Project & cpIndex) == imWalls) &&
				((TileFlags(AI[Player]->MyCity[cix].Loc,Player) & fGrWall)!=0)
				)
				UselessProject=true;
			//Check for repeat Hydro
			else if (
				((AI[Player]->MyCity[cix].Project & cpIndex) == imHydro)
				)
				UselessProject=Hoover;
			//Check for spaceship parts missing res
			else if(
				(Imp[(AI[Player]->MyCity[cix].Project & cpIndex)].Kind == ikShipPart) &&
				(ThisCity.ProdRep==0)
				)
				UselessProject=true;
		}
		//Check Units
		else if((AI[Player]->MyCity[cix].Project & cpImp) ==0)
		{
			//Check for too many settlers, or old settler model
			if(	(G.RO[Player]->Model[AI[Player]->MyCity[cix].Project].Kind == mkSettler) ||
				(G.RO[Player]->Model[AI[Player]->MyCity[cix].Project].Kind == mkSlaves)	)
			{
				if(
					(AI[Player]->MyRO.Government==gLybertarianism) ||
					(HAL[Player]->SettlerList.length()>AI[Player]->MyRO.nCity*VirginTiles/LandTiles) ||
						(
						//Build settlers when have excess food
						(	((ThisCity.FoodRep-ThisCity.Eaten)<=2)	||
							(AI[Player]->MyCity[cix].Size<4)	) &&
						//Build settlers when approaching max population
						(((AI[Player]->MyCity[cix].Size!=7) && (AI[Player]->MyCity[cix].Size!=8)) ||
							(AI[Player]->MyCity[cix].Built[imAqueduct]==1)) &&
						(((AI[Player]->MyCity[cix].Size!=10) && (AI[Player]->MyCity[cix].Size!=11) && (AI[Player]->MyCity[cix].Size!=12))
							|| (AI[Player]->MyCity[cix].Built[imSewer]==1))
						) ||
					(AI[Player]->MyCity[cix].Project != SettlerModel)
					)
					UselessProject=true;
			}
			else//(	(G.RO[Player]->Model[AI[Player]->MyCity[cix].Project].Kind != mkSettler) &&
				//	(G.RO[Player]->Model[AI[Player]->MyCity[cix].Project].Kind != mkSlaves)	)
			{
				//Check for too many Defense units, obsolete units
				for(mcurr=DefenderModels.head(); mcurr!=NULL; mcurr=mcurr->next)
				{
					if(mcurr->data==(AI[Player]->MyCity[cix].Project & cpIndex))
					{
						UselessProject=(
							(AI[Player]->MyCity[cix].Project!=DefenderModels.head()->data) ||
							(DefendersInCity(cix,Player)>=DefendersNeeded(cix,ThisCity,Player))
							);
						//no need to search any further
						break;
					}
				}
				//Check for too many Cruiser units, obsolete units
				if(!UselessProject)
					for(mcurr=CruiserModels.head();mcurr!=NULL;mcurr=mcurr->next)
					{
						if(mcurr->data==(AI[Player]->MyCity[cix].Project & cpIndex))
						{
							UselessProject=(
								(AI[Player]->MyCity[cix].Project!=CruiserModels.head()->data) ||
								(CruisersOwnedByCity(cix,Player)>0)
								);
							//no need to search any further
							break;
						}
					}
				//Check for too many Gadgetry units, obsolete units
				if(!UselessProject)
					for(mcurr=GadgetryModels.head();mcurr!=NULL;mcurr=mcurr->next)
					{
						if(mcurr->data==AI[Player]->MyCity[cix].Project)
						{
							UselessProject=(
								(AI[Player]->MyCity[cix].Project!=GadgetryModels.head()->data) ||
								(HAL[Player]->GadgetryList.length()>=GadgetryNeeded(Player))
								);
							//no need to search any further
							break;
						}
					}
				//Check for too many Attack units, obsolete units, or there are no defensive units, or too much support
				if(!UselessProject)
					for(mcurr=AttackerModels.head();mcurr!=NULL;mcurr=mcurr->next)
					{
						if(mcurr->data==AI[Player]->MyCity[cix].Project)
						{
							UselessProject=(
								(AI[Player]->MyCity[cix].Project!=AttackerModels.head()->data) ||
								(HAL[Player]->AttackerList.length()>AttackersNeeded(EnemyTiles,Player)) ||
								(ThisCity.Support>(ThisCity.ProdRep/2))
								);
							//no need to search any further
							break;
						}
					}
			}
		}

		//Build Units
		if(UselessProject)
		{
			//Build Defenders if not enough defense in city
			if(DefendersInCity(cix,Player)<DefendersNeeded(cix,ThisCity,Player))
			{
				flag=StartUnProd(AI[Player]->MyCity[cix], DefenderModels.head()->data, Player);
				UselessProject=((flag!=eOK) && (flag!=eNotChanged));
			}
			else if(//Can't build settlers if in lybertarianism or have too many
				(AI[Player]->MyRO.Government!=gLybertarianism) &&
				(HAL[Player]->SettlerList.length()<=AI[Player]->MyRO.nCity*VirginTiles/LandTiles) &&
					(
					//Build settlers when have excess food
					(	((ThisCity.FoodRep-ThisCity.Eaten)>2)	&&
						(AI[Player]->MyCity[cix].Size>=4)	) ||
					//Build settlers when approaching max population
					(((AI[Player]->MyCity[cix].Size==7) || (AI[Player]->MyCity[cix].Size==8))
						&& (AI[Player]->MyCity[cix].Built[imAqueduct]==0)) ||
					(((AI[Player]->MyCity[cix].Size==10) || (AI[Player]->MyCity[cix].Size==11) || (AI[Player]->MyCity[cix].Size==12))
						&& (AI[Player]->MyCity[cix].Built[imSewer]==0)) ||
					//More than a third of the population are entertainers
					(AI[Player]->MyCity[cix].Size>(3*ThisCity.Working/2))
					)
				)
			{
				flag=StartUnProd(AI[Player]->MyCity[cix], SettlerModel, Player);
				UselessProject=((flag!=eOK) && (flag!=eNotChanged));
			}
			//Build siege (gadgetry) units.
			else if(
				(HAL[Player]->GadgetryList.length()<GadgetryNeeded(Player)) &&
				(GadgetryModels.length()>0) &&
				((ThisCity.ProdRep-ThisCity.Support)>(AI[Player]->MyModel[BestGadgetry].Cost/12))
				)
			{
				flag=StartUnProd(AI[Player]->MyCity[cix], BestGadgetry, Player);
				UselessProject=((flag!=eOK) && (flag!=eNotChanged));
			}
			//Build Cruiser units.
			else if(
				(CruisersOwnedByCity(cix,Player)==0) &&
				(Coastal(AI[Player]->MyCity[cix].Loc,Player)) &&
				(CruiserModels.length()>0) &&
				((ThisCity.ProdRep-ThisCity.Support)>(AI[Player]->MyModel[BestCruiser].Cost/12))
				)
			{
				flag=StartUnProd(AI[Player]->MyCity[cix], BestCruiser, Player);
				UselessProject=((flag!=eOK) && (flag!=eNotChanged));
			}
			//Build marauding attack units.
			//Maximum is equal to the total number of cities modified by the number of hostile nations
			else if(
				(HAL[Player]->AttackerList.length()<AttackersNeeded(EnemyTiles,Player)) &&
				((ThisCity.ProdRep-ThisCity.Support)>(AI[Player]->MyModel[BestAttacker].Cost/12)) &&
				(ThisCity.Support<(ThisCity.ProdRep/2))
				)
			{
				flag=StartUnProd(AI[Player]->MyCity[cix], BestAttacker, Player);
				UselessProject=((flag!=eOK) && (flag!=eNotChanged));
			}
		}

		//Build palace only in most populated city... build regardless if uselessproject
		if(!Palace && (cix==MaxPopIndex))
		{
			flag=StartImpProd(AI[Player]->MyCity[cix], imPalace, Player);
			UselessProject=((flag!=eOK) && (flag!=eNotChanged));
		}

		if(	//need to take townhalls outside the loop
			UselessProject &&
			(AI[Player]->MyCity[cix].Built[imTownHall]==0) &&
			(AI[Player]->MyCity[cix].Built[imPalace]==0) &&
			(AI[Player]->MyCity[cix].Built[imCourt]==0)
		)
		{
			flag=StartImpProd(AI[Player]->MyCity[cix], imTownHall, Player);
			UselessProject=((flag!=eOK) && (flag!=eNotChanged));
		}

		//Build Improvements if no units building
		for (i=(imTrGoods+1); (i<nImp) && UselessProject; i++)
			if(
				(AI[Player]->MyCity[cix].Built[i]==0) &&//array value =1 indicates built improvement
				(HasTech(Imp[i].Preq,Player))
			)
			{
				switch(i)
				{
				//Don't know how to use these projects yet...
				case imBunker:
				case imAlgae:
				case imColosseum:
				//These projects are handled outside the loop
				case imTownHall:
				case imPalace:
					break;
				//Require Unique Circumstances
				case imRecycling:
					//Only build if polluting
					if(AI[Player]->MyCity[cix].Pollution>0)
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				case imTemple:
				case imTheater:
				case imCathedral:
					//Only build these if you have a significant number of unhappy people
					if((ThisCity.Working-ThisCity.Happy)>(AI[Player]->MyCity[cix].Size/3))
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				case imCourt:
					//Only build if you don't have a palace
					if(AI[Player]->MyCity[cix].Built[imPalace]==0)
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				case imAqueduct://should build an aqueduct only if approaching population limit
					if(AI[Player]->MyCity[cix].Size>5)
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				case imSewer://should build sanitation system only if approaching population limit
					if(AI[Player]->MyCity[cix].Size>9)
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				case imEliteBar://city with largest production gets to build elite barracks
					if(cix==MaxProdIndex)
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				case imNatObs://National Observatory
					if(cix==MaxTradeIndex)//Is the best research city
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				//Don't build great walls if great walls are built (doesn't quite work best for expanding on islands yet)
				case imGrWall:
					if (!GreatWall && ((ThisCity.ProdRep-ThisCity.Support)>(Imp[imGrWall].Cost/40)))
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				//Don't build walls if protected by great walls
				case imWalls:
					if((TileFlags(AI[Player]->MyCity[cix].Loc,Player) & fGrWall)==0)
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				//Build near shore
				case imHarbor:
				case imPlatform:
				case imCoastalFort:
				case imDockyard:
					if(Coastal(AI[Player]->MyCity[cix].Loc,Player))
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				//Build near river/mountain
				case imHydro:
					if(HydroAvailable(AI[Player]->MyCity[cix].Loc,Player) && !Hoover)
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				//No unique circumstances for other buildings
				default:
					if((Imp[i].Kind==ikNatLocal) || (Imp[i].Kind==ikNatGlobal))
					{	//Build National Project only if can build in 40 turns
						//Check for repeat National Projects
						for(j=0;j<AI[Player]->MyRO.nCity;j++)
							if(AI[Player]->MyCity[j].Built[i]==1) break;
						if(j<AI[Player]->MyRO.nCity) break;
						if((ThisCity.ProdRep-ThisCity.Support)>(Imp[i].Cost/40))
						{
							flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
							UselessProject=((flag!=eOK) && (flag!=eNotChanged));
							break;
						}
						else
							break;
					}
					else
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
				}
			}
		//Build Wonders if no Improvements building
		for (i=0; (i<nWonder) && UselessProject; i++)
			if(
				(AI[Player]->MyCity[cix].Built[i]==0) &&//array value =1 indicates built improvement
				(HasTech(Imp[i].Preq,Player))
			)	{
				switch(i)
				{
				//Don't know how to use these wonders yet...
				case woPyramids:
				case woManhattan:
					break;
				//Require Unique Circumstances
				case woNewton://Only build if in a monarchy... should be rare for now
					if((AI[Player]->MyRO.Government==gMonarchy) && ((ThisCity.ProdRep-ThisCity.Support)>(Imp[i].Cost/40)))
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				//Build near shore
				case woLighthouse:
				case woMagellan:
					if(Coastal(AI[Player]->MyCity[cix].Loc,Player) &&
						((ThisCity.ProdRep-ThisCity.Support)>(Imp[i].Cost/40)))
					{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				//Build near river/mountain
				case woHoover:
					if(
						HydroAvailable(AI[Player]->MyCity[cix].Loc,Player) && !Hoover &&
						((ThisCity.ProdRep-ThisCity.Support)>(Imp[i].Cost/40))
					)	{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				//No unique circumstances for other buildings
				default:
					if(
						((ThisCity.ProdRep-ThisCity.Support)>(Imp[i].Cost/40)) &&
						(Imp[i].Expiration==-1) &&
						(i!=OldWonder)
					)	{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					//If not enough production, the wonder is expired AND you don't have
					//the Eiffel Tower, you can't build this wonder.
					else if(
						((ThisCity.ProdRep-ThisCity.Support)>(Imp[i].Cost/40)) &&
						(!SomeoneHasTech(Imp[i].Expiration) || (AI[Player]->MyRO.Wonder[0x00000010].EffectiveOwner==Player)) &&
						(OldWonder!=i)
					)	{
						flag=StartImpProd(AI[Player]->MyCity[cix], i, Player);
						UselessProject=((flag!=eOK) && (flag!=eNotChanged));
						break;
					}
					else
						break;
				}
			}
		//If you still can't build anything, just trade goods.
		if(UselessProject)
			StartImpProd(AI[Player]->MyCity[cix], imTrGoods, Player);
		//Try to buy the improvement/unit
		//Cost must be one third of the treasury, or no deal
		else if((AI[Player]->MyCity[cix].Project & cpImp) != 0)
		{
			if(AI[Player]->MyRO.Money>10*(Imp[AI[Player]->MyCity[cix].Project & cpIndex].Cost-ThisCity.ProdRep))
				BuyProject(AI[Player]->MyCity[cix], Player);
		}
		else if((AI[Player]->MyCity[cix].Project & cpImp) == 0)
		{
			if(AI[Player]->MyRO.Money>10*(AI[Player]->MyModel[AI[Player]->MyCity[cix].Project & cpIndex].Cost-ThisCity.ProdRep))
				BuyProject(AI[Player]->MyCity[cix], Player);
		}

	}

	//Settler Actions
	TUn TempUnit;
	int TempLoc, MaxXdir, MaxYdir, k/*, TerraformNum, SiteRank*/, Dist;
	HALnode<SettlerTile> *tcurr;
	HALnode<SettlerTile> *MaxTile;
	HALnode<SettlerCity> *scurr;
	HALnode<SettlerCity> *MaxSite;
	float MaxCost,TempCost;

	for(ucurr=HAL[Player]->SettlerList.head(); ucurr!=NULL; ucurr=ucurr->next)	{
		TempUnit=AI[Player]->MyUn[ucurr->data.Index];
		TempLoc=TempUnit.Loc;
		TerrainType = TerrType(TempLoc, Player);
		TerrainFlag = TileFlags(TempLoc, Player);
		TempTile = GetCityTileInfo(TempLoc, Player);
		if (ucurr->data.Moves.MoreTurns>0)
			ExecuteMovement(ucurr->data, Player);
		else
		{
		//Build Cities
		if(	//Don't build if within another city's radius, or near a settler building a city.
			!CityInThree(TempLoc,Player)	&&
			(	(TerrainType==fGrass) ||
				(TerrainType==fPrairie) ||
				(TerrainType==fTundra)	)
			)
			Server(sStartJob+(jCity << 4),Player,ucurr->data.Index,NoServerData);
		//Terraforming
		else if(
			(TempUnit.Movement>100) &&	//Only terraform if not having a job
			//Terraform only if within another city's radius, or near a settler building a city.
			(TerraformJobs(TempLoc,Common(TempUnit,Player).Kind, Player)>0)
			)
		{
			flag = eUnknown;
			//First thing to do is to unpollute
			if((TerrainFlag & fPoll) != 0)
				Server(sStartJob+(jPoll << 4),Player,ucurr->data.Index,NoServerData);
			//Draining Swamps:
			else if	(
				(TerrainType == fSwamp) &&
				((TerrainFlag & (fSpecial | fRare | fRare1 | fRare2)) == 0)	//But does NOT contain special or rare resources
			)
				Server(sStartJob+(jClear << 4),Player,ucurr->data.Index,NoServerData);
			//Road Building:
			else if	((
				((TerrainType != fDesert) && (TerrainType != fArctic) && (TerrainType != fSwamp)) || //Not arctic, desert or swamp
				((TerrainFlag & (fSpecial | fRare | fRare1 | fRare2)) != 0)	//But contains special
				) &&
					(((TerrainFlag & fRoad) == 0) && ((TerrainFlag & fRR) == 0) &&
					(HasTech(adBridgeBuilding,Player) || ((TerrainFlag & fRiver) == 0) )) &&
					//complicated formula to prevent building roads on terrain that don't need them before RailRoad
					(((TerrainType != fForest) && (TerrainType != fHills) && (TerrainType != fMountains)) || HasTech(adRailroad,Player))
					)
				Server(sStartJob+(jRoad << 4),Player,ucurr->data.Index,NoServerData);
			//RailRoad Building:
			else if	((
				((TerrainType != fDesert) && (TerrainType != fArctic) && (TerrainType != fSwamp)) || //Not arctic, desert or swamp
				((TerrainFlag & (fSpecial | fRare | fRare1 | fRare2)) != 0)	//But contains special
				) &&
					(((TerrainFlag & fRR) == 0) && HasTech(JobPreq[jRR], Player)))
				Server(sStartJob+(jRR << 4),Player,ucurr->data.Index,NoServerData);
			//Irrigating:
			else if	(
				((TerrainType != fDesert) && (TerrainType < fArctic)) && //Not desert, arctic, or un-irrigable terrain
				(
					((TerrainFlag & TerImpMask) != tiIrrigation) &&
					HasWaterAccess(TempLoc,Player) &&
					((TerrainFlag & TerImpMask) != tiFarm)  &&
					(TempTile.ExplCity >= 0)
				)
			)
				Server(sStartJob+(jIrr << 4),Player,ucurr->data.Index,NoServerData);
			//Farming:
			else if	(
				((TerrainType != fDesert) && (TerrainType < fArctic)) && //Not desert, arctic, or un-irrigable terrain
				(
					((TerrainFlag & TerImpMask) != tiFarm) &&
					HasTech(JobPreq[jFarm], Player) &&
					HasWaterAccess(TempLoc,Player) &&
					(TempTile.ExplCity >= 0)
				)
			)
				Server(sStartJob+(jFarm << 4),Player,ucurr->data.Index,NoServerData);
			//Mining:
			else if	((TerrainType >= fHills) &&//minable terrain
				((TerrainFlag & TerImpMask) != tiMine))
				Server(sStartJob+(jMine << 4),Player,ucurr->data.Index,NoServerData);
			else if	(//Transformation
				((TerrainType == fDesert) || (TerrainType == fTundra)) &&
				((TerrainFlag & (fSpecial | fRare | fRare1 | fRare2)) == 0)	&& //But does NOT contain special
				HasTech(JobPreq[jTrans],Player) &&
				(TempTile.ExplCity >= 0)
			)
				Server(sStartJob+(jTrans << 4),Player,ucurr->data.Index,NoServerData);

		}
		//Settlers move to site if not moved already
		//Assign a movement destination by terraforming jobs
		else if (TempUnit.Movement>=150)	{
			bool Moving=false;
			MaxCost=0;
			Max=0;
			for(tcurr=MaxTile=SettlerTiles.head(); tcurr!=NULL; tcurr=tcurr->next)
				if((tcurr->data.Loc != TempLoc) && (tcurr->data.SettlersHere<2))	{
					//Weighted terraform cost is modified by the distance from the job
					Dist = Distance(TempLoc,tcurr->data.Loc);
					if(Common(TempUnit,Player).Kind == mkSlaves)
						TempCost = float(tcurr->data.TerraformSlave)/Dist;
					else //Common(TempUnit,Player).Kind == mkSettler
						TempCost = float(tcurr->data.TerraformSettler)/Dist;
					if(TempCost>MaxCost)	{
						MaxCost=TempCost;
						Max=Dist;
						MaxTile=tcurr;
					}
				}
			if (MaxCost > 0)	{
				ucurr->data.Moves.ToLoc=MaxTile->data.Loc;
				ucurr->data.Moves.MoreTurns=Max;
				ucurr->data.Moves.MaxHostile_MovementLeft=100;
				flag=Server(sGetMoveAdvice, Player, ucurr->data.Index, &ucurr->data.Moves);
				//NoWay to get to destination.  Try increasing the turns allotted
				for(i=1;(i<4) && (flag==eNoWay);i++)	{
					ucurr->data.Moves.MoreTurns = Max << i;
					flag=Server(sGetMoveAdvice, Player, ucurr->data.Index, &ucurr->data.Moves);
				}
				if(flag!=eNoWay)	{
					ExecuteMovement(ucurr->data,Player);
					Moving=true;
					MaxTile->data.SettlersHere++;
				}
			}
			//If the settler STILL doesn't have anything to do, it must try to found another city
			if (
				!Moving &&
				(Common(TempUnit,Player).Kind!=mkSlaves)
			)	{
				MaxCost=0;
				for(scurr=MaxSite=SettlerCities.head(); scurr!=NULL; scurr=scurr->next)
					if((scurr->data.Loc != TempLoc) && (scurr->data.SettlersHere<2))	{
						//Weighted city site rank is modified by the distance from the job
						Dist = Distance(TempLoc,scurr->data.Loc);
						TempCost = float(scurr->data.SiteRank)/Dist;
						if(TempCost>MaxCost)	{
							MaxCost=TempCost;
							Max=Dist;
							MaxSite=scurr;
						}
					}
				//City to be founded must be able to support at least a size 4 city
				if (MaxCost > 0)	{
					ucurr->data.Moves.ToLoc=MaxSite->data.Loc;
					ucurr->data.Moves.MoreTurns=Max;
					ucurr->data.Moves.MaxHostile_MovementLeft=100;
					flag=Server(sGetMoveAdvice, Player, ucurr->data.Index, &ucurr->data.Moves);
					//NoWay to get to destination.  Try increasing the turns allotted
					for(i=1;(i<4) && (flag==eNoWay);i++)	{
						ucurr->data.Moves.MoreTurns = Max << i;
						flag=Server(sGetMoveAdvice, Player, ucurr->data.Index, &ucurr->data.Moves);
					}
					if(flag!=eNoWay)	{
						ExecuteMovement(ucurr->data,Player);
						MaxSite->data.SettlersHere++;
					}
				}
			}
		}
		}
	}

	int UnknownNum;
	//Attacker Movement	
	int BattleResult;
	for(ucurr=HAL[Player]->AttackerList.head(); ucurr!=NULL; ucurr=ucurr->next)
	{
		TempUnit=AI[Player]->MyUn[ucurr->data.Index];
		TempLoc=TempUnit.Loc;
		//Fortify (don't do anything) if damage suffered
		if(
			!NearDefenselessCity(TempLoc,Player) &&
			(TempUnit.Health<90) &&
			(TerrType(TempLoc,Player) != fDesert) &&
			(TerrType(TempLoc,Player) != fArctic)
			)
			DebugMessage(1,"Low health: digging in.",Player);
		//Attacker move to site if not moved already
		else if(
			(ucurr->data.Moves.MoreTurns>0) &&
			(HAL[Player]->AttackerList.length()>AttackersNeeded(EnemyTiles,Player)/2)
			)
		{
			ExecuteMovement(ucurr->data, Player);
			StealTech(Player);
		}
		//Assign a movement destination by best possible odds of survival in an attack
		else if	(TempUnit.Movement>=100)
		{
			bool Moving=false;
			if(HostileNations(Player)>0)
			{
				for (k=1; k<20; k++)
				{
					Max=-200; //Value for an invalid battle result
					MaxXdir=0;
					MaxYdir=0;
					for (i=-2*k; i<=2*k; i++)
						for (j=-2*k; j<=2*k; j++)
						{
							dx = i-j;
							dy = i+j;
							if(
								(sqrt(double(dx*dx+dy*dy)) <= 3*k) &&
								(sqrt(double(dx*dx+dy*dy)) > (2*k-1))
								)
							{
								BattleResult = PotentialBattle(TempUnit,Remote(TempLoc, dx,dy), Player);
								if (BattleResult>Max)
								{
									Max=BattleResult;
									MaxXdir=dx;
									MaxYdir=dy;
								}
							}
						}
					if (Max > -200)
					{
						ucurr->data.Moves.ToLoc=Remote(TempLoc, MaxXdir,MaxYdir);
						ucurr->data.Moves.MoreTurns=2*k;
						ucurr->data.Moves.MaxHostile_MovementLeft=100;
						flag=Server(sGetMoveAdvice, Player, ucurr->data.Index, &ucurr->data.Moves);
						//NoWay to get to destination.  Try a different destination.
						if(flag!=eNoWay)
						{
							ExecuteMovement(ucurr->data,Player);
							StealTech(Player);
							Moving=true;
						}
					}
					if (Moving) break;
				}
			}

			//If there's absolutely nothing better to do, you might as well scout!
			if(!Moving)
			{
				Moving=false;
				for (k=1; k<20; k++)
					{
					Max=0;
					MaxXdir=0;
					MaxYdir=0;
					for (i=-2*k; i<=2*k; i++)
						for (j=-2*k; j<=2*k; j++)
						{
							dx = i-j;
							dy = i+j;
							if(
								(sqrt(double(dx*dx+dy*dy)) <= 3*k) &&
								(sqrt(double(dx*dx+dy*dy)) > (2*k-1))
								)
							{
								UnknownNum = UnknownTiles(Remote(TempLoc,dx,dy), Player);
								if (UnknownNum>Max)
								{
									Max=UnknownNum;
									MaxXdir=dx;
									MaxYdir=dy;
								}
							}
						}
					if (Max > 0)
					{
						ucurr->data.Moves.ToLoc=Remote(TempLoc, MaxXdir,MaxYdir);
						ucurr->data.Moves.MoreTurns=2*k;
						ucurr->data.Moves.MaxHostile_MovementLeft=100;
						flag=Server(sGetMoveAdvice, Player, ucurr->data.Index, &ucurr->data.Moves);
						//NoWay to get to destination.  Try a different destination.
						if(flag!=eNoWay)
						{
							ExecuteMovement(ucurr->data,Player);
							StealTech(Player);
							Moving=true;
						}
					}
					if (Moving) break;
				}
			}
		}
	}

	//Gadgetry Movement	
	for(ucurr=HAL[Player]->GadgetryList.head(); ucurr!=NULL; ucurr=ucurr->next)
	{
		TempUnit=AI[Player]->MyUn[ucurr->data.Index];
		TempLoc=TempUnit.Loc;
		//Fortify (don't do anything) if damage suffered
		if(
			!NearDefenselessCity(TempLoc,Player) &&
			(TempUnit.Health<90) &&
			(TerrType(TempLoc,Player) != fDesert) &&
			(TerrType(TempLoc,Player) != fArctic)
			)
			DebugMessage(1,"Low health: digging in.",Player);
		//Gadgetry move to site if not moved already
		else if(ucurr->data.Moves.MoreTurns>0)
		{
			ExecuteMovement(ucurr->data, Player);
			StealTech(Player);
		}
		//Assign a movement destination by best possible odds of survival in an attack
		else if	(TempUnit.Movement>=100)
		{
			bool Moving=false;
			for (k=1; k<20; k++)
			{
				Max=-200; //Value for an invalid battle result
				MaxXdir=0;
				MaxYdir=0;
				for (i=-2*k; i<=2*k; i++)
					for (j=-2*k; j<=2*k; j++)
					{
						dx = i-j;
						dy = i+j;
						if(
							(sqrt(double(dx*dx+dy*dy)) <= 3*k) &&
							(sqrt(double(dx*dx+dy*dy)) > (2*k-1))
							)
						{
							BattleResult = PotentialGadgetryBattle(TempUnit,Remote(TempLoc,dx,dy),Player);
							if (BattleResult>Max)
							{
								Max=BattleResult;
								MaxXdir=dx;
								MaxYdir=dy;
							}
						}
					}
				if (Max > -200)
				{
					ucurr->data.Moves.ToLoc=Remote(TempLoc, MaxXdir,MaxYdir);
					ucurr->data.Moves.MoreTurns=2*k;
					ucurr->data.Moves.MaxHostile_MovementLeft=100;
					flag=Server(sGetMoveAdvice, Player, ucurr->data.Index, &ucurr->data.Moves);
					//NoWay to get to destination.  Try a different destination.
					if(flag!=eNoWay)
					{
						ExecuteMovement(ucurr->data,Player);
						Moving=true;
					}
				}
				if (Moving) break;
			}
		}
	}

	//Cruiser Movement
	for(ucurr=HAL[Player]->CruiserList.head(); ucurr!=NULL; ucurr=ucurr->next)
	{
		TempUnit=AI[Player]->MyUn[ucurr->data.Index];
		TempLoc=TempUnit.Loc;
		//Fortify (don't do anything) if damage suffered
		if(TempUnit.Health<80)
			DebugMessage(1,"Low health: digging in.",Player);
		//Cruiser move to site if not moved already
		else if(ucurr->data.Moves.MoreTurns>0)
			ExecuteMovement(ucurr->data, Player);
		//Assign a movement destination by best possible odds of survival in an attack
		else if	(TempUnit.Movement>=100)
		{
			bool Moving=false;
			for (k=1; k<20; k++)
			{
				Max=-200; //Value for an invalid battle result
				MaxXdir=0;
				MaxYdir=0;
				for (i=-2*k; i<=2*k; i++)
					for (j=-2*k; j<=2*k; j++)
					{
						dx = i-j;
						dy = i+j;
						if(
							(sqrt(double(dx*dx+dy*dy)) <= 3*k) &&
							(sqrt(double(dx*dx+dy*dy)) > (2*k-1))
							)
						{
							BattleResult = PotentialSeaBattle(TempUnit,Remote(TempLoc,dx,dy),Player);
							if (BattleResult>Max)
							{
								Max=BattleResult;
								MaxXdir=dx;
								MaxYdir=dy;
							}
						}
					}
				if (Max > -200)
				{
					ucurr->data.Moves.ToLoc=Remote(TempLoc, MaxXdir,MaxYdir);
					ucurr->data.Moves.MoreTurns=2*k;
					ucurr->data.Moves.MaxHostile_MovementLeft=100;
					flag=Server(sGetMoveAdvice, Player, ucurr->data.Index, &ucurr->data.Moves);
					if((flag==eDomainMismatch) && (k==1))
					{
						flag=Server(sMoveUnit+((MaxXdir & 7) << 4) +((MaxYdir & 7) << 7),Player,ucurr->data.Index,NoServerData);
						Moving=((flag==eWon) || (flag==eLost) || (flag==eBloody) || (flag==eOK));
					}
					//NoWay to get to destination.  Try a different destination.
					else if(flag!=eNoWay)
					{
						ExecuteMovement(ucurr->data,Player);
						Moving=true;
					}
				}
				if (Moving) break;
			}
			//If there's absolutely nothing better to do, you might as well scout!
			if(!Moving)
			{
				Moving=false;
				for (k=1; k<20; k++)
				{
					Max=0;
					MaxXdir=0;
					MaxYdir=0;
					for (i=-2*k; i<=2*k; i++)
						for (j=-2*k; j<=2*k; j++)
						{
							dx = i-j;
							dy = i+j;
							if(	(sqrt(double(dx*dx+dy*dy)) <= 3*k) &&
								(sqrt(double(dx*dx+dy*dy)) > (2*k-1))
							)	{
								UnknownNum = UnknownSeaTiles(Remote(TempLoc,dx,dy), Player);
								if (UnknownNum>Max)
								{
									Max=UnknownNum;
									MaxXdir=dx;
									MaxYdir=dy;
								}
							}
						}
					if (Max > 0)
					{
						ucurr->data.Moves.ToLoc=Remote(TempLoc, MaxXdir,MaxYdir);
						ucurr->data.Moves.MoreTurns=2*k;
						ucurr->data.Moves.MaxHostile_MovementLeft=100;
						flag=Server(sGetMoveAdvice, Player, ucurr->data.Index, &ucurr->data.Moves);
						//NoWay to get to destination.  Try a different destination.
							if(flag!=eNoWay)
						{
							ExecuteMovement(ucurr->data,Player);
							Moving=true;
						}
					}
					if (Moving) break;
				}
			}
		}
	}

	//Attackers attack targets (while idle) if victory is probable
	for(ucurr=HAL[Player]->AttackerList.head(); ucurr!=NULL; ucurr=ucurr->next)
		SnipeEnemy(ucurr, Player);

	//Defenders attack targets next to city if victory is probable
	for(ucurr=HAL[Player]->DefenderList.head(); ucurr!=NULL; ucurr=ucurr->next)
		SnipeEnemy(ucurr, Player);

	//If an inferior defense unit exists a city, disband it, as long as the city remains defended
	if((DefenderModels.length()>1))
	{
		ucurr=HAL[Player]->DefenderList.head();
		while(ucurr!=NULL)
		{
			for(cix=0; cix<AI[Player]->MyRO.nCity;cix++)
			{
			 
				if(AI[Player]->MyUn[ucurr->data.Index].Loc==AI[Player]->MyCity[cix].Loc)
				{
					if(
						(	(AI[Player]->MyModel[AI[Player]->MyUn[ucurr->data.Index].mix].Defense*3/2)
							< AI[Player]->MyModel[DefenderModels.head()->data].Defense	) &&
						(DefendersInCity(cix,Player)>=DefendersNeeded(cix,ThisCity,Player))
						)
					{
						Remove(AI[Player]->MyUn[ucurr->data.Index],Player);
						HALnode<UnitData>* temp=ucurr->next;
						HAL[Player]->DefenderList.Remove(ucurr);
						ucurr=temp;
					}
					else
						ucurr=ucurr->next;
					break;
				}
			}
			if(cix==AI[Player]->MyRO.nCity) ucurr=ucurr->next;
		}
	}

	//If too many aggressive units, prune the obsolete ones until a more reasonable number.
	if(AttackerModels.length()>1)
	{
		ucurr=HAL[Player]->AttackerList.head();
		while(
			(ucurr!=NULL) &&
			(HAL[Player]->AttackerList.length()>AttackersNeeded(EnemyTiles,Player))
			)
		{
			if(AI[Player]->MyUn[ucurr->data.Index].mix!=AttackerModels.head()->data)
			{
				Remove(AI[Player]->MyUn[ucurr->data.Index],Player);
				HALnode<UnitData>* temp=ucurr->next;
				HAL[Player]->AttackerList.Remove(ucurr);
				ucurr=temp;
			}
			else ucurr=ucurr->next;
		}
	}

	//If too many siege units, prune the obsolete ones until a more reasonable number.
	if(GadgetryModels.length()>0)
	{
		ucurr=HAL[Player]->GadgetryList.head();
		while(
			(ucurr!=NULL) &&
			(HAL[Player]->GadgetryList.length()>GadgetryNeeded(Player))
			)
		{
			//Prune if siege weapon is weaker than tank/cavalry models
			if(AI[Player]->MyModel[AI[Player]->MyUn[ucurr->data.Index].mix].Attack
				<= AI[Player]->MyModel[AttackerModels.head()->data].Attack)
			{
				Remove(AI[Player]->MyUn[ucurr->data.Index],Player);
				HALnode<UnitData>* temp=ucurr->next;
				HAL[Player]->GadgetryList.Remove(ucurr);
				ucurr=temp;
			}
			else ucurr=ucurr->next;
		}
	}

	//Possibly engage in diplomacy
	if ((rand()%10)==0)
	{
		int p1=rand()%nPl;
		if ((AI[Player]->MyRO.Treaty[p1]>trNoContact) && (((1 << p1) & AI[Player]->MyRO.Alive)!=0))
			AI[Player]->Contact(p1);
	}
	AI[Player]->EndTurn();
}

void DoNegotiation(int Player)
{
	bool Done;
	switch (AI[Player]->ReceivedDipAction)
	{
  		case scContact:
    		if (rand()%2)
	   			AI[Player]->DipAction(scDipStart);
    		else
    			AI[Player]->DipAction(scReject);
    		break;
    	case scDipBreak:
    	case scDipCancelTreaty:
    		AI[Player]->DipAction(scDipNotice);
    		break;
    	default:
    	{
    		Done=false;
    		if ((AI[Player]->ReceivedDipAction==scDipOffer) && (rand()%2))
    			Done= AI[Player]->DipAction(scDipAccept)>-0x100;
    		if (!Done && (AI[Player]->MyRO.Treaty[AI[Player]->pContact]>=trPeace) && ((rand()%10)==0))
    			Done= AI[Player]->DipAction(scDipCancelTreaty)>-0x100;
    		if (!Done && ((AI[Player]->SentDipAction & 0xFF0F)!=scContact)
				&& !((AI[Player]->ReceivedDipAction==scDipOffer)
				&& ((AI[Player]->ReceivedOffer.nDeliver+AI[Player]->ReceivedOffer.nCost)==0))
    			&& ((rand()%5)==0))
    				Done= AI[Player]->DipAction(scDipBreak)>-0x100;
    		if (!Done)
    		{ // suggest quit
    			AI[Player]->MyOffer.nDeliver=0;
    			AI[Player]->MyOffer.nCost=0;
    			AI[Player]->DipAction(scDipOffer);
    		}
    	}
	}
}

extern "C" void __stdcall client(int Command, int Player, pServerData Data)
{
	switch (Command)
	{
	case cInitModule:
		{
			Server = (TServerCall*) *(int*)Data;

			//We need a place to save the seed for the random number, so init the save file
			TInitModuleData* DataBlockInit= static_cast<TInitModuleData*>(Data);
			DataBlockInit->DataVersion=1;
			DataBlockInit->DataSize=sizeof(DataBlock);
			//Note: when using the Data block, it is initialized to void*
			//You will have to use (DataBlock*)Data every single time to access it
			assert(DataBlockInit->DataSize<=4096);	//make sure that the data block doesn't exceed 4096 bytes

			//If you would rather use the CPU clock to initialize the number generator, use the following
			//srand((unsigned)time(NULL));

			break;
		}
	case cNewGame:
	case cLoadGame:
		{
			G=*(TNewGameData*)Data;
			{
				int i;
				for (i=1; i<nPl; i++)
					if (G.RO[i]!=(TPlayerContext*)0)
					{
						AI[i]=new TCustomAI(i,*G.RO[i]);
						HAL[i]=new HALdata;
					}
					else
					{
						AI[i]=(TCustomAI*)0;
						HAL[i]=(HALdata*)0;
					}
			}
			break;
		}
	case cBreakGame:
		{
			int i;
			for (i=1; i<nPl; i++)
				if (AI[i]!=(TCustomAI*)0)
				{
					delete AI[i];
					delete HAL[i];
				}
			break;
		}
	case cTurn:
		{
			DebugMessage(1,"cTurn(false)",Player);
			AI[Player]->AfterNegotiation=false;
			DoTurn(Player);
			break;
		}
	case cContinue:
		{
			DebugMessage(1,"cTurn(true)",Player);
			AI[Player]->AfterNegotiation=true;
			DoTurn(Player);
			break;
		}
	case scContact:
/*		{//	If you would like to disable diplomacy, uncomment this section
			Server(scReject,Player,0,NoServerData); //FORGET IT!
			break;
		}*/
	case scDipStart:
	case scDipBreak:
	case scReject:
	case scDipNotice:
	case scDipAccept:
	case scDipCancelTreaty:
	case scDipOffer:
		{
			AI[Player]->ReceivedDipAction=Command;
			if (Command==scContact)
				AI[Player]->pContact=*static_cast<int*>(Data);
			if (Command==scDipOffer)
				AI[Player]->ReceivedOffer=*static_cast<TOffer*>(Data);
			DoNegotiation(Player);
			break;
		}
	case cShowAttacking://Check if enemy units have attacked a city
		{
			TShowMove Attack = *static_cast<TShowMove*>(Data);
			int TempLoc = Remote(Attack.FromLoc,Attack.dx,Attack.dy),
				cix;
			for(cix=0;cix<AI[Player]->MyRO.nCity;cix++)
				if(AI[Player]->MyCity[cix].Loc==TempLoc)
				{
					//Status field will keep track of how many attacks a city has endured
					AI[Player]->MyCity[cix].Status = AI[Player]->MyCity[cix].Status << 1;
					AI[Player]->MyCity[cix].Status = AI[Player]->MyCity[cix].Status | 1;
					break;
				}
			break;
		}
	default: ;	/*ignore other commands*/
	}
}

//Says if another friendly city is being built within a theoretical city's limits
bool BuildingCityInLimits(int cloc, int me)
{
	HALnode<UnitData>* ucurr;
	for(ucurr=HAL[me]->SettlerList.head(); ucurr!=NULL; ucurr=ucurr->next)
		if(AI[me]->MyUn[ucurr->data.Index].Job==jCity)
			for(int i=-2;i<=2;i++)
				for(int j=-2;j<=2;j++)
					if(((i-j)*(i-j)+(i+j)*(i+j)) <= 10)
						if(Remote(cloc,i-j,i+j)==AI[me]->MyUn[ucurr->data.Index].Loc) return true;

	return false;
}

//Returns the number of possible terraformings jobs in a tile
//Return -1 if it's an invalid tile.
short TerraformJobs(long TempLoc,int UnitKind, int Player)
{
	//Invalid Location
	if(!Valid(TempLoc))
		return -1;
	
	int TerrainType = TerrType(TempLoc, Player);
	int TerrainFlag = TileFlags(TempLoc, Player);
	TTileInfo TempTile = GetCityTileInfo(TempLoc, Player);
	//Limit to non-water tiles and tiles that are/will be used by a city, and not enemy-occupied tiles
	if (
		(TerrainType < fGrass) ||
		CityHere(TempLoc,Player) ||
		(((TerrainFlag & (fRare | fRare1 | fRare2)) != 0) && (UnitKind!=mkSlaves)) ||
		(!CityInLimits(TempLoc, Player) && !BuildingCityInLimits(TempLoc, Player)) ||
		(TerrainType == fUNKNOWN) ||
		(EnemyUnitHere(TempLoc,Player)==true)
		)
		return -1;

	short TerraformNum=0;
	//Clean up pollution:
	//First thing to do is to unpollute
	if((TerrainFlag & fPoll) != 0)
		TerraformNum+=3;//Has a VERY HIGH priority
	//Draining Swamps:
	if	(
		(TerrainType == fSwamp) &&
		((TerrainFlag & (fSpecial | fRare | fRare1 | fRare2)) == 0)	//But does NOT contain special or rare resources
	)
		TerraformNum++;
	//Road Building:
	if	(
		((TerrainType != fDesert) && (TerrainType != fArctic) && (TerrainType != fSwamp)) || //Not arctic, desert or swamp
		((TerrainFlag & (fSpecial | fRare | fRare1 | fRare2)) != 0)	//But contains special
		)
		if(
			((TerrainFlag & fRoad) == 0) && ((TerrainFlag & fRR) == 0) &&
			(HasTech(adBridgeBuilding,Player) || ((TerrainFlag & fRiver) == 0) ) &&
			//complicated formula to prevent building roads on terrain that don't need them before RailRoad
			(((TerrainType != fForest) && (TerrainType != fHills) && (TerrainType != fMountains)) || HasTech(JobPreq[jRR],Player))
			)
			TerraformNum++;
	//RailRoad Building:
	if	(
		((TerrainType != fDesert) && (TerrainType != fArctic) && (TerrainType != fSwamp)) || //Not arctic, desert or swamp
		((TerrainFlag & (fSpecial | fRare | fRare1 | fRare2)) != 0)	//But contains special
		)
		if(((TerrainFlag & fRR) == 0) && HasTech(JobPreq[jRR], Player))
			TerraformNum++;
	//Irrigating:
	if	((TerrainType != fDesert) && (TerrainType < fArctic)) //|| //Not desert, arctic, or un-irrigable terrain
		if(
			((TerrainFlag & TerImpMask) != tiIrrigation) &&
			HasWaterAccess(TempLoc,Player) &&
			((TerrainFlag & TerImpMask) != tiFarm) &&
			(TempTile.ExplCity >= 0)
		)
			TerraformNum+=2;//Has a HIGH priority
	//Farming:
	if	((TerrainType != fDesert) && (TerrainType < fArctic)) //|| //Not desert, arctic, or un-irrigable terrain
		if(
			((TerrainFlag & TerImpMask) != tiFarm) &&
			HasTech(JobPreq[jFarm], Player) &&
			HasWaterAccess(TempLoc,Player) &&
			(TempTile.ExplCity >= 0)
		)
			TerraformNum++;
	//Mining:
	if	(TerrainType >= fHills) //minable terrain
		if((TerrainFlag & TerImpMask) != tiMine)
			TerraformNum++;

	if	(//Transformation
		((TerrainType == fDesert) || (TerrainType == fTundra)) &&
		((TerrainFlag & (fSpecial | fRare | fRare1 | fRare2)) == 0)	)	//But does NOT contain special
		if(
			HasTech(JobPreq[jTrans],Player) &&
			(TempTile.ExplCity >= 0)
		)
			TerraformNum++;

	return TerraformNum;
}


//Returns the total number of explotable food resources in the top four
//food production tiles in a theoretical city site.
//Return -1 if it's an invalid tile.
short CitySiteRank(long TempLoc, int Player)
{
	//Invalid Location or non-citybuilding unit
	if(!Valid(TempLoc))
		return -1;
	
	int TerrainType = TerrType(TempLoc, Player);
	//Limit site to flat-lands and without a limit of three tiles to a city
	if (
		!((TerrainType == fGrass) || (TerrainType == fTundra) || (TerrainType == fPrairie)) ||
		(CityInThree(TempLoc, Player))
		)
		return -1;

	TTileInfo TempTile;
	int RemoteLoc,i,j;
	//array containing the top four food production tile values
	short Top4Tiles[]= {0, 0, 0, 0};

	for(i=-2;i<=2;i++)
		for(j=-2;j<=2;j++)
			if(((i-j)*(i-j)+(i+j)*(i+j)) <= 10)
			{
				RemoteLoc=Remote(TempLoc,i-j,i+j);
				if(Valid(RemoteLoc))
				{
					TempTile=GetTileInfo(RemoteLoc,Player);
					if(TempTile.Food>Top4Tiles[0])
					{
						Top4Tiles[3]=Top4Tiles[2];
						Top4Tiles[2]=Top4Tiles[1];
						Top4Tiles[1]=Top4Tiles[0];
						Top4Tiles[0]=(short)TempTile.Food;
					}
					else if(TempTile.Food>Top4Tiles[1])
					{
						Top4Tiles[3]=Top4Tiles[2];
						Top4Tiles[2]=Top4Tiles[1];
						Top4Tiles[1]=(short)TempTile.Food;
					}
					else if(TempTile.Food>Top4Tiles[2])
					{
						Top4Tiles[3]=Top4Tiles[2];
						Top4Tiles[2]=(short)TempTile.Food;
					}
					else if(TempTile.Food>Top4Tiles[3])
						Top4Tiles[3]=(short)TempTile.Food;
				}
			}

	return (Top4Tiles[0]+Top4Tiles[1]+Top4Tiles[2]+Top4Tiles[3]);
}

//Detects a city within a radius of three tiles
bool CityInThree(int cloc, int me)
{
	int tempLoc,i,j;
	HALnode<UnitData>* ucurr;
	for (i=-3; i<=3; i++)
		for (j=-3; j<=3; j++)
		{
			int	dx = i-j,
				dy = i+j;
			if((dx*dx+dy*dy)<=26)
			{
				tempLoc=Remote(cloc,dx,dy);
				if(Valid(tempLoc))
					if(CityHere(tempLoc,me))
						return true;
				for(ucurr=HAL[me]->SettlerList.head(); ucurr!=NULL; ucurr=ucurr->next)
					if(AI[me]->MyUn[ucurr->data.Index].Job==jCity)
						if(AI[me]->MyUn[ucurr->data.Index].Loc==tempLoc)
							return true;
			}
		}
	return false;
}

//Checks if any units in a UnitList need to be removed using ID field
//Updates indexes of units if an ID match is found
void PruneUnit(HALlist<UnitData> &UnitList, int me)
{
	HALnode<UnitData>* ucurr=UnitList.head();
	while(ucurr!=NULL)
	{
		int uix;
		for(uix=0;
			((uix<AI[me]->MyRO.nUn) && (ucurr->data.ID!=AI[me]->MyUn[uix].ID));
			uix++);
		//If ID not found, remove the unit
		if(uix==AI[me]->MyRO.nUn)	{
			HALnode<UnitData>* temp=ucurr->next;
			UnitList.Remove(ucurr);
			ucurr=temp;
		}
		//ID found. Update the unit index in UnitList
		else	{
			ucurr->data.Index=uix;
			ucurr=ucurr->next;
		}
	}
}

//Receives a unit index and determines if it needs to be added to a unit array
//If it need to add it, it does, and returns true. else, returns false.
bool AddUnit(HALlist<UnitData> &UnitList, int uix, int Player)
{
	HALnode<UnitData>* ucurr;
	for(ucurr=UnitList.head();
		(ucurr!=NULL) && (AI[Player]->MyUn[uix].ID!=ucurr->data.ID);
		ucurr=ucurr->next);
	//unit is not present in custom array. add it.
	if (ucurr==NULL)	{
		UnitData NewUnit;
		NewUnit.Moves.MoreTurns=0;
		NewUnit.ID=AI[Player]->MyUn[uix].ID;
		NewUnit.Index=uix;
		UnitList.Append(NewUnit);
		return true;
	}
	else return false;
}

//Uses UnitData to plan and execute a move until no more future moves are needed
void ExecuteMovement(UnitData &Unit, int Player)
{
	int	flag=Server(sGetMoveAdvice, Player, Unit.Index, &Unit.Moves),MoveIndex;
	for(MoveIndex=0;(flag==eOK) && (MoveIndex<Unit.Moves.nStep);MoveIndex++)
		flag=Move(AI[Player]->MyUn[Unit.Index], Unit.Moves.dx[MoveIndex], Unit.Moves.dy[MoveIndex], Player);
	//Check if your unit was attacking a city...
	if((flag==eWon) || (flag==eLost) || (flag==eBloody))
	{
		int cix;
		for(cix=0;cix<AI[Player]->MyRO.nEnemyCity;cix++)
			if(Unit.Moves.ToLoc==AI[Player]->MyRO.EnemyCity[cix].Loc)
			{
				AI[Player]->MyRO.EnemyCity[cix].Status++;	//Increment the number of attacks that city has witnessed
				break;
			}
	}
	//If no more movement possible or movement blocked, nullify information from GetMoveAdvice.
	else if(flag==eNoWay)
		Unit.Moves.MoreTurns=0;
}

//Create a DevModel for a defender.  Return true if it's better than current best model
bool BuildBetterDefender(int DefenseModel,int me)
{
	//no need to create dev model if no hostile nations have been found, or have a far superior model
	if(
		((AI[me]->MyModel[DefenseModel].Defense) > 10) &&
		(	(HostileNations(me)==0) ||
			(	(AI[me]->MyModel[DefenseModel].Defense > BestHostileAttack(me)) &&
				(AI[me]->MyModel[DefenseModel].Defense > (BestHostileSeaAttack(me)/2))
			)
		)
	)
		return false;

	int flag=eOK,value;
	AI[me]->CreateDevModel(dGround);
	//if SunTzu is active, get First Strike
	if(AI[me]->MyRO.Wonder[woSun].EffectiveOwner==me)
	{
		AI[me]->SetDevModelCap(mcFirst, 1);
		AI[me]->SetDevModelCap(mcAcademy, 1);
		AI[me]->SetDevModelCap(mcWill, 0);
	}
	else if(HasTech(Feature[mcFanatic].Preq,me))
	{
		//Get fanaticism if researched
		AI[me]->SetDevModelCap(mcFanatic, 1);
		AI[me]->SetDevModelCap(mcFirst, 0);
		AI[me]->SetDevModelCap(mcWill, 0);
		AI[me]->SetDevModelCap(mcAcademy, 0);
	}

	if(HasTech(Feature[mcLine].Preq,me))
		AI[me]->SetDevModelCap(mcLine, 1);


	//always set defense to maximum (two)
	AI[me]->SetDevModelCap(mcDefense, 2);
	//set mobility to zero (no faster)
	AI[me]->SetDevModelCap(mcMob, 0);


	//increment offense up to a value of two
	for(value=0;(flag==eOK) && (value<=2);value++)
		flag=AI[me]->SetDevModelCap(mcOffense, value);

	int DevDefense=AI[me]->MyRO.DevModel.Defense;
	int BestDefense=AI[me]->MyModel[DefenseModel].Defense;
	//round if greater than 100
	if ((DevDefense>100) || (BestDefense>100))
	{
		DevDefense/=10;
		BestDefense/=10;
	}
	return (DevDefense > BestDefense);
}

//Create a DevModel for an attacker.  Return true if it's better than current best model
bool BuildBetterAttacker(int AttackModel,int me)
{
	//no need to create dev model if no hostile nations have been found, or have a far superior model
	if(
		((AI[me]->MyModel[AttackModel].Attack) > 10) &&
		(	(HostileNations(me)==0) ||
			(AI[me]->MyModel[AttackModel].Attack > (2*BestHostileDefense(me)))
		)
	)
		return false;

	int flag=eOK,value=(AI[me]->MyModel[AttackModel].Weight/3);
	AI[me]->CreateDevModel(dGround);
	//If SunTzu is active, get these powerups
	if(AI[me]->MyRO.Wonder[woSun].EffectiveOwner==me)
	{
		AI[me]->SetDevModelCap(mcFirst, 1);
		AI[me]->SetDevModelCap(mcWill, 1);
		AI[me]->SetDevModelCap(mcAcademy, 1);
	}
	else if(HasTech(Feature[mcFanatic].Preq,me))
	{
		//Get fanaticism if researched
		AI[me]->SetDevModelCap(mcFanatic, 1);
		AI[me]->SetDevModelCap(mcFirst, 0);
		AI[me]->SetDevModelCap(mcWill, 0);
		AI[me]->SetDevModelCap(mcAcademy, 0);
	}

	if(HasTech(Feature[mcLine].Preq,me))
		AI[me]->SetDevModelCap(mcLine, 1);

	for(;;)
	{	//increment offense/mobility if possible
		flag=AI[me]->SetDevModelCap(mcOffense, value);
		if(flag!=eOK) break;
		flag=AI[me]->SetDevModelCap(mcMob, value);
		if(flag!=eOK) break;
		//defense should be half as good as offense
		AI[me]->SetDevModelCap(mcDefense, value/2);
		value++;
	}

	//round if greater than 100
	int DevAttack=AI[me]->MyRO.DevModel.Attack;
	int BestAttack=AI[me]->MyModel[AttackModel].Attack;
	if ((DevAttack>100) || (BestAttack>100))
	{
		DevAttack/=10;
		BestAttack/=10;
	}

	return (DevAttack > BestAttack);
}

//Return true if two or more defenders are in this city
int DefendersInCity(int cix, int me)
{
	int defenders=0;
	HALnode<UnitData>* ucurr;
	for(ucurr=HAL[me]->DefenderList.head(); ucurr!=NULL; ucurr=ucurr->next)
		if(AI[me]->MyUn[ucurr->data.Index].Loc==AI[me]->MyCity[cix].Loc)
			defenders++;
	return defenders;
}

//checks if an enemy unit is on a tile.  Then returns the result of a potential attack
//range: -100 total defeat, +100 supreme victory.  -200 if invalid attack or no enemy.
int PotentialBattle(TUn MyUnit, int TargetLoc, int me)
{
	if(!Valid(TargetLoc))
		return -200;
	if(TerrType(TargetLoc,me)<fGrass)
		return -200;
	else if(EnemyUnitHere(TargetLoc,me))
	{
		int uix;
		for(uix=0;uix<AI[me]->MyRO.nEnemyUn;uix++)
			if(
				(AI[me]->MyRO.EnemyUn[uix].Loc==TargetLoc) &&
				//Check if the owner of the unit is at war with you
				(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyUn[uix].Owner]==trNone)
				)
			{	//Call GetBattlerForecast
				TBattleForecast BF;
				BF.pAtt = me;
				BF.mixAtt = MyUnit.mix;
				BF.HealthAtt = MyUnit.Health;
				BF.ExpAtt = MyUnit.Exp;
				BF.FlagsAtt = MyUnit.Flags;
				BF.Movement = MyUnit.Movement;
				int flag=Server(sGetBattleForecast, me, TargetLoc, &BF);
				//can't attack that kind of unit
				if (flag==eDomainMismatch) return -200;
				//Return difference in health
				else return (BF.EndHealthAtt-BF.EndHealthDef);
			}
	}
	//If only a city is found, it's better than nothing
	else if(
		EnemyCityHere(TargetLoc,me) &&
		((G.RO[me]->Map[TargetLoc] & fObserved) == 0)
		)
	{
		int cix;
		for(cix=0;cix<AI[me]->MyRO.nEnemyCity;cix++)
			if(
				(AI[me]->MyRO.EnemyCity[cix].Loc==TargetLoc) &&
				//Check if the owner of the city is at war with you
				(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyCity[cix].Owner]==trNone)
				)
				if((AI[me]->MyRO.EnemyCity[cix].Flags & ciWalled) != 0)
					return -100; //Walled city.  Assume the worst.
				else
					return 0; //Unwalled city, not so bad.
	}
	else if(
		//Only ground units can occupy enemy cities
		(AI[me]->MyModel[MyUnit.mix].Domain == dGround) &&
		((G.RO[me]->Map[TargetLoc] & fObserved) != 0) &&
		EnemyCityHere(TargetLoc,me)
		)
	{
		int cix;
		for(cix=0;cix<AI[me]->MyRO.nEnemyCity;cix++)
			if(
				(AI[me]->MyRO.EnemyCity[cix].Loc==TargetLoc) &&
				//Check if the owner of the city is at war with you
				(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyCity[cix].Owner]==trNone)
				)
					return 100; //Undefended city.  Easy pickings.
	}

	//No enemy unit or city found
	return -200;
}

//Return the number of nations that have no treaty with me
int HostileNations(int me)
{
	int pix,hostile=0;
	for (pix=0;pix<nPl;pix++)
		if(
			(pix!=me) &&
			(((1 << pix) & AI[me]->MyRO.Alive)!=0) &&
			(AI[me]->MyRO.Treaty[pix]==trNone)
			)
			hostile++;
	return hostile;
}

//find the number of active players in the game
int ActivePlayers(int me)
{
	int pix,active=0;
	for(pix=(G.Difficulty[0]<1);pix<nPl;pix++)
		if(((1 << pix) & AI[me]->MyRO.Alive)!=0)
			active++;
	return active;
}

//number of settlers on a tile
short SettlersOnTile(long Loc, int me)
{
	short settlers=0;
	HALnode<UnitData>* ucurr;
	for(ucurr=HAL[me]->SettlerList.head(); ucurr!=NULL; ucurr=ucurr->next)
		if (AI[me]->MyUn[ucurr->data.Index].Loc==Loc)
			settlers++;
	return settlers;
}

//returns value of best attack value of a hostile ground unit model
int BestHostileAttack(int me)
{
	int mix,BestAttack=0;
	for(mix=0;mix<AI[me]->MyRO.nEnemyModel;mix++)
		if(
			(AI[me]->MyRO.EnemyModel[mix].Owner!=me) &&
			(AI[me]->MyRO.EnemyModel[mix].Domain==dGround) &&
			(((1 << AI[me]->MyRO.EnemyModel[mix].Owner) & AI[me]->MyRO.Alive)!=0) &&
			(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyModel[mix].Owner]<=trNone) &&
			(AI[me]->MyRO.EnemyModel[mix].Attack>BestAttack)
			)
			BestAttack=AI[me]->MyRO.EnemyModel[mix].Attack;
	return BestAttack;
}

//returns value of best attack value of a hostile sea unit model
int BestHostileSeaAttack(int me)
{
	int mix,BestAttack=0;
	for(mix=0;mix<AI[me]->MyRO.nEnemyModel;mix++)
		if(
			(AI[me]->MyRO.EnemyModel[mix].Owner!=me) &&
			(AI[me]->MyRO.EnemyModel[mix].Domain==dSea) &&
			(((1 << AI[me]->MyRO.EnemyModel[mix].Owner) & AI[me]->MyRO.Alive)!=0) &&
			(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyModel[mix].Owner]<=trNone) &&
			(AI[me]->MyRO.EnemyModel[mix].Attack>BestAttack)
			)
			BestAttack=AI[me]->MyRO.EnemyModel[mix].Attack;
	return BestAttack;
}

//returns value of best defense value of a hostile ground unit model
int BestHostileDefense(int me)
{
	int mix,BestDefense=0;
	for(mix=0;mix<AI[me]->MyRO.nEnemyModel;mix++)
		if(
			(AI[me]->MyRO.EnemyModel[mix].Owner!=me) &&
			(AI[me]->MyRO.EnemyModel[mix].Domain==dGround) &&
			(((1 << AI[me]->MyRO.EnemyModel[mix].Owner) & AI[me]->MyRO.Alive)!=0) &&
			(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyModel[mix].Owner]<=trNone) &&
			(AI[me]->MyRO.EnemyModel[mix].Defense>BestDefense)
			)
			BestDefense=AI[me]->MyRO.EnemyModel[mix].Defense;
	return BestDefense;
}

//returns value of best defense value of a hostile sea unit model
int BestHostileSeaDefense(int me)
{
	int mix,BestDefense=0;
	for(mix=0;mix<AI[me]->MyRO.nEnemyModel;mix++)
		if(
			(AI[me]->MyRO.EnemyModel[mix].Owner!=me) &&
			(AI[me]->MyRO.EnemyModel[mix].Domain==dSea) &&
			(((1 << AI[me]->MyRO.EnemyModel[mix].Owner) & AI[me]->MyRO.Alive)!=0) &&
			(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyModel[mix].Owner]<=trNone) &&
			(AI[me]->MyRO.EnemyModel[mix].Defense>BestDefense)
			)
			BestDefense=AI[me]->MyRO.EnemyModel[mix].Defense;
	return BestDefense;
}


//Returns number of gadgetry units needed based on number of total attacks on certain cities
int GadgetryNeeded(int me)
{
	int cix,gadgets=0;
	for(cix=0;cix<AI[me]->MyRO.nEnemyCity;cix++)
		//Need gadgets to take down cities that aren't taken after many attacks
		gadgets+=AI[me]->MyRO.EnemyCity[cix].Status/5;
	return gadgets;
}

//Create a DevModel for a gadgetry unit.  Return true if it's better than current best model
bool BuildBetterGadgetry(int GadgetryModel,int me)
{
	//no need to create dev model if no hostile nations have been found, or no gadgetry needed
	if(
		(	(HostileNations(me)==0) &&
			((AI[me]->MyModel[GadgetryModel].Attack) > 10)	) ||
			(GadgetryNeeded(me)==0) ||
			(AI[me]->MyModel[GadgetryModel].Attack > (3*BestHostileDefense(me)))
		)
		return false;

	int flag=eOK,value=(AI[me]->MyModel[GadgetryModel].Weight/3);
	AI[me]->CreateDevModel(dGround);
	//If SunTzu is active, get these powerups
	if(AI[me]->MyRO.Wonder[woSun].EffectiveOwner==me)
	{
		AI[me]->SetDevModelCap(mcFirst, 1);
		AI[me]->SetDevModelCap(mcWill, 1);
		AI[me]->SetDevModelCap(mcAcademy, 1);
	}
	else if(HasTech(Feature[mcFanatic].Preq,me))
	{
		//Get fanaticism if researched
		AI[me]->SetDevModelCap(mcFanatic, 1);
		AI[me]->SetDevModelCap(mcFirst, 0);
		AI[me]->SetDevModelCap(mcWill, 0);
		AI[me]->SetDevModelCap(mcAcademy, 0);
	}

	if(HasTech(Feature[mcLine].Preq,me))
		AI[me]->SetDevModelCap(mcLine, 1);

	if(HasTech(Feature[mcLongRange].Preq,me))
		AI[me]->SetDevModelCap(mcLongRange, 1);

	for(;;)
	{	//increment offense if possible
		flag=AI[me]->SetDevModelCap(mcOffense, value);
		if(flag!=eOK) break;
		//Should have speed half as important as offense
		flag=AI[me]->SetDevModelCap(mcMob, value/2);
		if(flag!=eOK) break;
		//defense should be 1/3 as important as offense
		AI[me]->SetDevModelCap(mcDefense, value/3);
		value++;
	}

	int DevAttack=AI[me]->MyRO.DevModel.Attack;
	int BestAttack=AI[me]->MyModel[GadgetryModel].Attack;
	//round if greater than 100
	if ((DevAttack>100) || (BestAttack>100))
	{
		DevAttack/=10;
		BestAttack/=10;
	}
	return (DevAttack > BestAttack);
}

//Create a DevModel for a Cruiser unit.  Return true if it's better than current best model
bool BuildBetterCruiser(int CruiserModel,int me)
{
	//no need to create dev model if no hostile nations have been found, or no gadgetry needed
	if(
		(	(HostileNations(me)==0) &&
			((AI[me]->MyModel[CruiserModel].Attack) > 10)	) ||
		(	(AI[me]->MyModel[CruiserModel].Attack > (3*BestHostileDefense(me))) &&
			(AI[me]->MyModel[CruiserModel].Attack > 1.5*BestHostileSeaDefense(me)) &&
			(HostileNations(me)>0)	) ||
		!HasTech(adMapMaking,me)
		)
		return false;

	//Don't research if you don't have coastal cities
	bool HaveCoast=false;
	int cix;
	for(cix=0;(cix<AI[me]->MyRO.nCity) && !HaveCoast;cix++)
		HaveCoast=HaveCoast || Coastal(AI[me]->MyCity[cix].Loc,me);
	if(!HaveCoast) return false;

	AI[me]->CreateDevModel(dSea);
	//Make sure it can't transport units
	AI[me]->SetDevModelCap(mcSeaTrans, 0);
	//Get navigation if possible
	if(HasTech(Feature[mcNav].Preq, me))
		AI[me]->SetDevModelCap(mcNav, 1);
	//Get steam power if possible
	if(HasTech(Feature[mcSE].Preq, me))
		AI[me]->SetDevModelCap(mcSE, 1);
	//Get Long Range Guns
	if(HasTech(Feature[mcLongRange].Preq,me))
		AI[me]->SetDevModelCap(mcLongRange, 1);
	//Get radar if possible
	if(HasTech(Feature[mcRadar].Preq, me))
		AI[me]->SetDevModelCap(mcRadar, 1);
	//Get nuclear power if possible
	if(HasTech(Feature[mcNP].Preq, me))
		AI[me]->SetDevModelCap(mcNP, 1);
	//Get STA missiles if possible
	if(HasTech(Feature[mcAirDef].Preq, me))
		AI[me]->SetDevModelCap(mcAirDef, 1);
	//Get turbines if possible
	if(HasTech(Feature[mcTurbines].Preq, me))
		AI[me]->SetDevModelCap(mcTurbines, 1);
	//Get Line production if possible
	if(HasTech(Feature[mcLine].Preq,me))
		AI[me]->SetDevModelCap(mcLine, 1);

	int flag=eOK;
	for(int value=(AI[me]->MyModel[CruiserModel].Weight/3); flag==eOK; value++)
	{
		flag=AI[me]->SetDevModelCap(mcOffense, value);
		AI[me]->SetDevModelCap(mcDefense, value/2);
	}

	int DevAttack=AI[me]->MyRO.DevModel.Attack;
	int BestAttack=AI[me]->MyModel[CruiserModel].Attack;
	//round if greater than 100
	if ((DevAttack>100) || (BestAttack>100))
	{
		DevAttack/=10;
		BestAttack/=10;
	}
	return (DevAttack > BestAttack);
}

void StealTech(int me)
{
	int tix,flag;
	//phStealTech flag set in RO.Happened, choose a tech to steal
	if((AI[me]->MyRO.Happened & phStealTech) != 0)
	{
		int MaxTechCost=0,MaxTech=-1,TechCost=0;
		//Find the most expensive stealable technology
		for (tix=0;tix<=94;tix++)
		{
			flag=Server(sStealTech-sExecute, me, tix, NoServerData);
			if (flag==eOK)
			{
				flag=Server(sGetTechCost, me, tix, &TechCost);
				if((TechCost>MaxTechCost) && (flag==eOK))
				{
					MaxTechCost=TechCost;
					MaxTech=tix;
				}
			}
		}
		//Set Research Goals if not done already
		if (MaxTech>=0)
			Server(sStealTech, me, MaxTech, NoServerData);
	}
}

//Return number of cruisers owned by city.
int CruisersOwnedByCity(int cix, int me)
{
	HALnode<UnitData>* ucurr;
	int cruisers=0;
	for(ucurr=HAL[me]->CruiserList.head(); ucurr!=NULL; ucurr=ucurr->next)
		if(AI[me]->MyUn[ucurr->data.Index].Home==cix)
			cruisers++;
	return cruisers;
}

//checks if an enemy unit is on a tile.  Then returns the result of a potential attack
//range: -100 total defeat, +100 supreme victory.  -200 if invalid attack or no enemy.
int PotentialSeaBattle(TUn MyUnit, int TargetLoc, int me)
{
	if(!Valid(TargetLoc))
		return -200;
	if(	(TerrType(TargetLoc,me)>=fGrass) &&
		(AI[me]->MyModel[MyUnit.mix].Cap[mcLongRange] == 0)
	)
		return -200;
	else if(EnemyUnitHere(TargetLoc,me))
	{
		int uix;
		for(uix=0;uix<AI[me]->MyRO.nEnemyUn;uix++)
			if(
				(AI[me]->MyRO.EnemyUn[uix].Loc==TargetLoc) &&
				//Check if the owner of the unit is at war with you, or no contact
				(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyUn[uix].Owner]<=trNone) &&
				(	//Check if enemy unit is a sea unit, or if capable of bombarding a ground unit
					(AI[me]->MyRO.EnemyModel[AI[me]->MyRO.EnemyUn[uix].emix].Domain == dSea) ||
					(
						(AI[me]->MyRO.EnemyModel[AI[me]->MyRO.EnemyUn[uix].emix].Domain == dGround) &&
						(AI[me]->MyModel[MyUnit.mix].Cap[mcLongRange] == 1)
					)
				)
			)
			{	//Call GetBattlerForecast
				TBattleForecast BF;
				BF.pAtt = me;
				BF.mixAtt = MyUnit.mix;
				BF.HealthAtt = MyUnit.Health;
				BF.ExpAtt = MyUnit.Exp;
				BF.FlagsAtt = MyUnit.Flags;
				BF.Movement = MyUnit.Movement;
				int flag=Server(sGetBattleForecast, me, TargetLoc, &BF);
				//can't attack that kind of unit
				if (flag==eDomainMismatch) return -200;
				//Return difference in health
				else return (BF.EndHealthAtt-BF.EndHealthDef);
			}
	}
	//If only a city is found, it's better than nothing
	else if(
		EnemyCityHere(TargetLoc,me) &&
		((G.RO[me]->Map[TargetLoc] & fObserved) == 0) &&
		(AI[me]->MyModel[MyUnit.mix].Cap[mcLongRange] == 1)
		)
	{
		int cix;
		for(cix=0;cix<AI[me]->MyRO.nEnemyCity;cix++)
			if(
				(AI[me]->MyRO.EnemyCity[cix].Loc==TargetLoc) &&
				//Check if the owner of the city is at war with you
				(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyCity[cix].Owner]==trNone)
				)
					return 0; //Unwalled city, not so bad.
	}

	//No enemy unit or city found
	return -200;
}

//Add a model index to the custom list of models
void AddModel(HALlist<int> &Models, int mix, int me)
{
	HALnode<int>* mcurr;
	for(mcurr=Models.head(); mcurr!=NULL; mcurr=mcurr->next)
		if(AI[me]->MyModel[mix].Attack>AI[me]->MyModel[mcurr->data].Attack)
		{
			Models.InsertBefore(mcurr, mix);
			break;
		}
	if (mcurr==NULL) Models.Append(mix);
}

//Returns estimate of number of attackers needed to take over enemy civs.
float AttackersNeeded(const int EnemyTiles[], int me)
{
	int pix,total=0;
	for(pix=0; pix<nPl; pix++)
		if(
			(AI[me]->MyRO.Treaty[pix]==trNone) &&
			(pix!=me) &&
			(((1 << pix) & AI[me]->MyRO.Alive)!=0)
			)
			total+=EnemyTiles[pix];

	//use of 9 as divider, because a unit can hold 9 tiles with ZOC
	//plus two for scouting
	return float(total)/9+2;
}

//Attack an adjacent enemy if resulting health will be greater than 30%
void SnipeEnemy(HALnode<UnitData>* ucurr, int me)
{
	//attack if best possible odds of survival in an attack are more than 1/3 health
	if(AI[me]->MyUn[ucurr->data.Index].Movement>=100)
	{
		int BattleResult,Maxdir;
		int Max=-200; //Value for an invalid battle result
		for (int dir=Maxdir=0; dir<8; dir++)
		{
			BattleResult = PotentialBattle(AI[me]->MyUn[ucurr->data.Index],
				Remote(AI[me]->MyUn[ucurr->data.Index].Loc,Dirx[dir],Diry[dir]), me);
			if (BattleResult>Max)
			{
				Max=BattleResult;
				Maxdir=dir;
			}
		}
		if(Max>30) Move(AI[me]->MyUn[ucurr->data.Index], Dirx[Maxdir], Diry[Maxdir], me);
	}
}

//How many defenders needed within a city
int DefendersNeeded(int cix, const TCityReport &ThisCity, int me)
{
	UNREFERENCED_PARAMETER(ThisCity);

	long Status = AI[me]->MyCity[cix].Status;
	int ExtraDef=0;
	for(int i=0; i<32; i++)
		if (((Status >> i) & 1) == 1)
			ExtraDef++;

	ExtraDef/=4;

	return (2 + ExtraDef);
}

//checks if an enemy unit is on a tile.  Then returns the result of a potential attack
//range: -100 total defeat, +100 supreme victory.  -200 if invalid attack or no enemy.
int PotentialGadgetryBattle(TUn MyUnit, int TargetLoc, int me)
{
	if(!Valid(TargetLoc))
		return -200;
	if(	(TerrType(TargetLoc,me)<fGrass) &&
		(AI[me]->MyModel[MyUnit.mix].Cap[mcLongRange] == 0)
	)
		return -200;
	else if(EnemyUnitHere(TargetLoc,me))
	{
		int uix;
		for(uix=0;uix<AI[me]->MyRO.nEnemyUn;uix++)
			if(
				(AI[me]->MyRO.EnemyUn[uix].Loc==TargetLoc) &&
				//Check if the owner of the unit is at war with you
				(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyUn[uix].Owner]==trNone) &&
				(	//Check if enemy unit is a ground unit, or if capable of bombarding a sea unit
					(AI[me]->MyRO.EnemyModel[AI[me]->MyRO.EnemyUn[uix].emix].Domain == dGround) ||
					(
						(AI[me]->MyRO.EnemyModel[AI[me]->MyRO.EnemyUn[uix].emix].Domain == dSea) &&
						(AI[me]->MyModel[MyUnit.mix].Cap[mcLongRange] == 1)
					)
				)
			)
			{	//Call GetBattlerForecast
				TBattleForecast BF;
				BF.pAtt = me;
				BF.mixAtt = MyUnit.mix;
				BF.HealthAtt = MyUnit.Health;
				BF.ExpAtt = MyUnit.Exp;
				BF.FlagsAtt = MyUnit.Flags;
				BF.Movement = MyUnit.Movement;
				int flag=Server(sGetBattleForecast, me, TargetLoc, &BF);
				//can't attack that kind of unit
				if (flag==eDomainMismatch) return -200;
				//Return difference in health
				else return (BF.EndHealthAtt-BF.EndHealthDef);
			}
	}
	//If only a city is found, it's better than nothing
	else if(
		EnemyCityHere(TargetLoc,me) &&
		((G.RO[me]->Map[TargetLoc] & fObserved) == 0)
		)
	{
		int cix;
		for(cix=0;cix<AI[me]->MyRO.nEnemyCity;cix++)
			if(
				(AI[me]->MyRO.EnemyCity[cix].Loc==TargetLoc) &&
				//Check if the owner of the city is at war with you
				(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyCity[cix].Owner]==trNone)
				)
					return 0;	//Gadgetry units are good against cities regardless of walls
								//but you should still be careful...
	}
	else if(
		//Only ground units can occupy enemy cities
		((G.RO[me]->Map[TargetLoc] & fObserved) != 0) &&
		EnemyCityHere(TargetLoc,me)
		)
	{
		int cix;
		for(cix=0;cix<AI[me]->MyRO.nEnemyCity;cix++)
			if(
				(AI[me]->MyRO.EnemyCity[cix].Loc==TargetLoc) &&
				//Check if the owner of the city is at war with you
				(AI[me]->MyRO.Treaty[AI[me]->MyRO.EnemyCity[cix].Owner]==trNone)
				)
					return 100; //Undefended city.  Easy pickings.
	}

	//No enemy unit or city found
	return -200;
}

