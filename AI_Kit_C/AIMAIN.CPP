/*
Blank AI template for v14 of c-evo, by Charles Nadolski
cnadolsk@uiuc.edu
NOTE: THIS IS A BLANK TEMPLATE VERSION OF MY SOURCE CODE.
Everything has been deleted exept for diplomacy (which is a translation
of the *older* diplomacy engine in STDAI), client initialization, a couple
 of other useful hints (like how check for enemy attacks on your cities),
and many helper functions contained within aihelpers.h.

Most recent changes for version 13:
Updated tracking of attacks on friendly cities to most recent rules.

Most recent changes for version 12:  you have the choice of either using the CPU clock time
to initialize the random numbers, or use the initial location of the first
settler to seed the random numbers.  Most recommend method 2 to ensure
repeatability.  Thank you Dipl.-Ing. Ulrich Olderdissen [ulrich.olderdissen@gmx.de]
for the random seed suggestion.

0.8 update Thomas Kay.
Diplomacy implemented.
Changed DoTurn() to use MyRO syntax - close to Delphi.
AIMAIN.CPP 0.7.0
C AI Development Template
'01 by Matvej Soloviev ("blackhole89")
*/

#include <stdlib.h>	//abs(), rand()
//#include <time.h>	//time() -- uncomment to enable CPU random number seed instead of fixed seed
#include <assert.h>	//assert()
#include "protocol.h"
#include "aiclasses.h"
#include "aimain.h"
#include "aihelpers.h"

//Include here the items you'd like to have in the save area (Data) of the RO block
//Keep in mind that arrays, lists, and other objects have to be of a fixed size
struct DataBlock	{
	unsigned long RandomSeed;
};

TCustomAI *AI[nPl];
int debug;

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
//	{
//		G.RO[Player]->Data = new DataBlock;
		((DataBlock*)G.RO[Player]->Data)->RandomSeed = AI[Player]->MyUn[0].Loc;
//	}

	//srand (*(static_cast<long*>(G.RO[Player]->Data) + RandomSeed));
	//*(static_cast<long*>(G.RO[Player]->Data) + RandomSeed) = rand();
 	srand(((DataBlock*)G.RO[Player]->Data)->RandomSeed);
	((DataBlock*)G.RO[Player]->Data)->RandomSeed = rand();

	/*

	The bulk of your AI code will go here

	*/

	//Possibly engage in diplomacy (this is what is used in STDAI)
	if ((rand()%10)==0)
	{
		int p1=rand()%nPl;
		if ((AI[Player]->MyRO.Treaty[p1]>trNoContact) && (((1 << p1) & AI[Player]->MyRO.Alive)!=0))
			AI[Player]->Contact(p1);
	}
	AI[Player]->EndTurn();
}

//This basic diplomacy protocol is used in STDAI
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

//This area ensures that your AI is communicating with the core c-evo module.
//Read through this area for a more general understanding of what's going on
//but generally you shouldn't be making many changes to this section.
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
						AI[i]=new TCustomAI(i,*G.RO[i]);
					else
						AI[i]=(TCustomAI*)0;
			}
			break;
		}
	case cBreakGame:
		{
			int i;
			for (i=1; i<nPl; i++)
				if (AI[i]!=(TCustomAI*)0)
					delete AI[i];
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
/*		{
			//The following is example code on how to keep track of enemy attacks on cities
			//uncomment to activate it
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
		}*/
	default: ;	/*ignore other commands*/
	}
}

/*

Your user-made functions that can't be put into AIhelpers.h should be put here

*/