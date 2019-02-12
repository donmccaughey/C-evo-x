---
title: "protocol.h"
---

# `protocol.h`

This is the definition of the C-evo 1.2.0 protocol for AI development [posted by
Steffen][11] on the C-evo forum.

[11]: http://www.c-evo.org/bb/viewtopic.php?f=5&t=60

{% raw %}
```c
/*
C-evo AI Protocol
Version 1.2.0
Compiler: ANSI C++

Project home: www.c-evo.org/
*/

#ifndef protocolh
#define protocolh


/* general rules*/
enum GeneralRules{
lxmax           = 100,
lymax           = 96,
nAdv		= 94, /*{number of advances}*/
nImp		= 70, /*{number of improvements}*/
nPl		= 15, /*{max number of players, don't change!}*/
nExp		= 5, /* number of experience levels*/
ExpCost		= 50, /*{received damage required for next experience level}*/
MaxFutureTech   = 25, // maximum number of future techs of one kind except computing technology
MaxFutureTech_Computing	= 100, // maximum number of computing technology future techs
CountryRadius   = 9,
MaxCitySize     = 30,
BasicHappy      = 2, // basically happy citizens
MaxPollution	= 240,
ColossusEffect	= 75, /* percent wonder building cost*/
UniversityFutureBonus = 5, // percent per tech
ResLabFutureBonus     = 10, // percent per tech
FactoryFutureBonus    = 5, // percent per tech
MfgPlantFutureBonus   = 10, // percent per tech
AnarchyTurns	= 3,
CaptureTurns    = 3,
CancelTreatyTurns	= 3,
PeaceEvaTurns   = 5,
ColdWarTurns	= 40,
DesertThurst	= 20, /* damage for turn in desert*/
ArcticThurst	= 20, /* damage for turn in arctic*/
FastRecovery	= 50,
CityRecovery	= 20,
NoCityRecovery	= 8,
MaxMoneyPrice	= 0xFFFF,
MaxShipPartPrice	= 100,
InitialCredibility	= 95
};

/*difficulty settings*/
const int
	MaxDiff=3, /*{maximum difficulty level}*/
	StorageSize[]={-1,30,40,50},
	BuildCostMod[]={-1,9,12,15};  /* in 1/12*/

const double
	TechFormula_M[]={0.,2.0,2.3,2.6},
	TechFormula_D[]={0.,102.0,80.0,64.0};

/* server commands*/
enum ServerCommands{
sMessage		= 0x0000,
sSetDebugMap            = 0x0010,
sRefreshDebugMap	= 0x0040m
sGetChart               = 0x0100,
sGetTechCost		= 0x0180,
sGetTileInfo		= 0x0200,
sGetCityTileInfo        = 0x0210,
sGetHypoCityTileInfo    = 0x0220,
sGetJobProgress	= 0x0230,
sGetUnits               = 0x0280,
sGetDefender		= 0x0290,
sGetBattleForecast	= 0x02A0,
sGetMoveAdvice		= 0x02C0,
sGetCity                = 0x0300,
sGetCityReport		= 0x0310,
sGetCityAreaInfo	= 0x0320,
sGetEnemyCityReport     = 0x0330,
sGetCityTileAdvice      = 0x0350,
sGetCityReportNew	= 0x0360,
sGetEnemyCityReportNew	=0x0370,

sExecute		= 0x4000,
cClientEx		= 0x8000,

sTurn			= 0x4800,
sReload                 = 0x4841,

sSetGovernment		= 0x5100,
sSetRates		= 0x5110,
sRevolution		= 0x5120,
sSetResearch		= 0x5200,
sStealTech		= 0x5210,
sSetAttitude            = 0x5300,
sCancelTreaty           = 0x5400,
sCreateDevModel		= 0x5800,
sSetDevModelCap		= 0x5C00,

sRemoveUnit		= 0x6000,
sSetUnitHome		= 0x6010,
sSetSpyMission		= 0x6100,
sLoadUnit		= 0x6200,
sUnloadUnit		= 0x6210,
sSelectTransport        = 0x6220,
sMoveUnit		= 0x6400,
sAddToCity		= 0x6810,
sStartJob		= 0x6C00,

sSetCityProject		= 0x7001,
sBuyCityProject		= 0x7010,
sSellCityProject	= 0x7020,
sSellCityImprovement	= 0x7101,
sRebuildCityImprovement	= 0x7111,
sSetCityTiles           = 0x7201
};

/* client commands*/
enum ClientCommands{
cInitModule		= 0x0000,
cReleaseModule		= 0x0100,
cNewGame		= 0x0800,
cLoadGame		= 0x0810,
cReplay                 = 0x08E0,
cGetReady		= 0x08F0,
cBreakGame		= 0x0900,

cTurn			= 0x2000,
cContinue		= 0x2080,

cShowUnitChanged        = 0x3030,
cShowAfterMove          = 0x3040,
cShowAfterAttack        = 0x3050,
cShowCityChanged        = 0x3090,
cShowMoving             = 0x3140,
cShowCapturing          = 0x3150,
cShowAttacking          = 0x3240,
cShowMissionResult      = 0x3300,
cShowGreatLibTech       = 0x3500,
cShowCancelTreaty       = 0x3800,
cShowEndContact         = 0x3810,
cShowCancelTreatyByAlliance     = 0x3820,
cShowSupportAllianceAgainst     = 0x3830,

cShowSuperView          = 0x3F80
};

/* server and client commands*/
enum SCCommands{
scContact		= 0x4900,
scReject		= 0x4A00,
scDipStart		= 0x4B00,
scDipNotice		= 0x4B10,
scDipAccept		= 0x4B20,
scDipCancelTreaty	= 0x4B30,
scDipOffer		= 0x4B4E,
scDipBreak		= 0x4BF0
};

/* server call return codes*/
enum ServerCallRC{
//server return codes: flags
rExecuted=             0x40000000,
rEffective=            0x20000000,
rUnitRemoved=          0x10000000,
rEnemySpotted=         0x08000000,

//server return codes: command executed
// note: the same return code might have a different meaning for different server functions!
eOK=                   0x60000000, // ok
eEnemySpotted=         0x68000000, // unit move ok, new enemy unit/city spotted
eDied=                 0x70000000, // move executed, unit died due to hostile terrain
eEnemySpotted_Died=    0x78000000, // unit move ok, new enemy unit/city spotted, unit died due to hostile terrain
eLoaded=               0x60000002, // unit move caused loading to transport ship
eLost=                 0x70000004, // attack executed, battle lost, unit is dead
eWon=                  0x60000005, // attack executed, battle won, defender destroyed
eBloody=               0x70000005, // attack executed, defender destroyed, unit is dead
eBombarded=            0x60000006, // empty enemy city bombarded
eExpelled=             0x60000007, // friendly spy expelled
eMissionDone=          0x70000008, // spy moved into city: mission done, spy no longer exists
eJobDone=              0x60000001, // settler job started and already done
eJobDone_Died=         0x70000001, // settler job started and already done, unit died due to hostile terrain
eCity=                 0x70000002, // city founded, settler no more exists
eRemoved=              0x70000000, // sRemoveUnit: unit removed
eUtilized=             0x70000001, // sRemoveUnit: unit utilized for city project

eNotChanged=           0x40000000, // ok, but no effect (e.g. current city project set again)

//server return codes: command not executed
eHiddenUnit=           0x20000013, // unit move: not possible, destination tile occupied by hidden foreign submarine
eStealthUnit=          0x2000001A, // unit move: not possible, destination tile occupied by foreign stealth unit
eZOC_EnemySpotted=     0x28000014, // unit move: not possible, new enemy unit spotted, ZOC violation

eInvalid=              0x0000, // command not allowed now or parameter out of allowed range
eUnknown=              0x0001, // unknown command
eNoTurn=               0x0002, // command only allowed during player's turn
eViolation=            0x0003, // general violation of game rules
eNoPreq=               0x0004, // the prerequisites for this command are not fully met

eNoTime_Move=          0x0008, // normal unit move: too few movement points left
eNoTime_Load=          0x0009, // load unit: too few movement points left
eNoTime_Attack=        0x000A, // attack: no movement points left
eNoTime_Bombard=       0x000B, // bombard city: too few movement points left
eNoTime_Expel=         0x000C, // expel spy: too few movement points left

eDomainMismatch=       0x0011, // move/attack: action not allowed for this unit domain
eNoCapturer=           0x0012, // unit move: this type of unit is not allowed to capture a city
eZOC=                  0x0014, // unit move: not possible, ZOC violation
eTreaty=               0x0015, // move/attack: not possible, peace treaty violation
eDeadLands=            0x0016, // unit move: not possible, eerie terrain
eNoRoad=               0x0017, // unit move: not possible, no road
eNoNav=                0x0019, // unit move: not possible, open sea without navigation
eNoLoadCapacity=       0x001B, // load to transport: no more transport capacity
eNoBombarder=          0x001C, // bombardment impossible because no attack power

eMaxSize=              0x0020, // add to city: bigger size not allowed due to missing aqueduct/sewer
eNoCityTerrain=        0x0022, // found city: not possible in this terrain
eNoBridgeBuilding=     0x0023,
eInvalidOffer=         0x0030,
eOfferNotAcceptable=   0x0031,
eCancelTreatyRush=	0x0032,
eAnarchy=              0x0038, // no negotiation in anarchy
eColdWar=              0x003F,
eNoModel=              0x0040, // sCreateDevModel must be called before!
eTileNotAvailable=     0x0050,
eNoWorkerAvailable=    0x0051,
eOnlyOnce=             0x0058, // sell/rebuild city improvement: only once per city and turn!
eObsolete=             0x0059, // city project: more advanced improvement already exists
eOutOfControl=         0x005A, // buy/sell/rebuild improvement: not in anarchy, not in captured cities

eNoWay=                0x0100 // sGetMoveAdvice: no way found
};

// chart types
enum ChartTypes{
nStat		= 6,
stPop		= 0,
stTerritory     = 1,
stMil		= 2,
stScience	= 3,
stExplore	= 4,
stWork		= 5
};


const int TerrainMask	= 0x1F;
const int TerImpMask    = 0xF000;
const int TerritoryMask	= 0x78000000; // nation territory: player<<27, 15 indicates none
/* tile flags*/
enum TileFlags {
fOcean			= 0x00,
fShore			= 0x01,
fGrass			= 0x02,
fDesert			= 0x03,
fPrairie		= 0x04,
fTundra			= 0x05,
fArctic			= 0x06,
fSwamp			= 0x07,
fForest			= 0x09,
fHills			= 0x0A,
fMountains		= 0x0B,
fUNKNOWN		= 0x1F,

tiNone                  = 0x0000,
tiIrrigation            = 0x1000,
tiFarm                  = 0x2000,
tiMine                  = 0x3000,
tiFort                  = 0x4000,
tiBase                  = 0x5000,

fSpecial		= 0x00000060,
fSpecial1		= 0x00000020,
fSpecial2		= 0x00000040,
fRiver			= 0x00000080,
fRoad			= 0x00000100,
fRR				= 0x00000200,
fCanal			= 0x00000400,
fPoll           = 0x00000800,
fGrWall         = 0x00010000, // tile protected by great wall
fSpiedOut       = 0x00020000,
fStealthUnit	= 0x00040000,
fHiddenUnit		= 0x00080000,
fObserved		= 0x00100000, // set if tile information is from this turn
fOwned			= 0x00200000, // set if unit/city here is own one
fUnit			= 0x00400000,
fCity			= 0x00800000,

fDeadLands              = 0x01000000,
fModern                 = 0x06000000,
fCobalt                 = 0x02000000,
fUranium                = 0x04000000,
fMercury                = 0x06000000,

fRare                   = 0x01000000, // for backward compatibility
fRare1                  = 0x02000000, // for backward compatibility
fRare2                  = 0x04000000,  // for backward compatibility

fOwnZoCUnit             = 0x10000000, // own ZoC unit present at this tile
fInEnemyZoC             = 0x20000000, // tile is adjacent to known foreign ZoC unit (not allied)
fPeace                  = 0x40000000 // tile belongs to territory of nation that we are in peace with but not allied
};


/* city project flags*/
enum CityProjectFlags{
cpIndex         = 0x01FF,
cpConscripts    = 0x0200, // produce unit as conscripts
cpDisbandCity   = 0x0400, // allow to disband city when settlers/conscripts are produced
cpImp           = 0x0800  // 0: index refers to model, 1: index refers to city improvement
};

/* tech status indicators*/
enum TechStatusInd{
tsNA		= -2,
tsSeen		= -1,
tsResearched	= 0,
tsGrLibrary	= 1,
tsCheat		= 15,
tsApplicable	= 0
};


// nation treaties
enum NationTreaties{
trNoContact		= -1,
trNone			= 0,
trCeaseFire		= 1, // obsolete
trPeace			= 2,
trFriendlyContact	= 3,
trAlliance		= 4
};

// attitudes, obsolete
enum Attitudes{
nAttitude		= 7,
atHostile		= 0,
atIcy			= 1,
atUncoop		= 2,
atNeutral		= 3,
atReceptive		= 4,
atCordial		= 5,
atEnth			= 6
};

// offer prices
enum OfferPrices{
opChoose	= 0x00000000, 
opCivilReport	= 0x11000000, // + turn + concerned player shl 16
opMilReport	= 0x12000000, // + turn + concerned player shl 16
opMap		= 0x1F000000,
opTreaty	= 0x20000000, // + suggested nation treaty
opShipParts	= 0x30000000, // + number + part type shl 16
opMoney		= 0x40000000, // + value
opTribute	= 0x48000000, // obsolete
opTech		= 0x50000000, // + advance
opAllTech	= 0x51000000,
opModel		= 0x58000000, // + model index
opAllModel	= 0x59000000,
opCity		= 0x60000000, // not used
opMask		= 0xFF000000
};

// improvement kinds
enum ImprovementKind{
ikTrGoods       = 0,
ikCommon	= 1,
ikNatLocal	= 2,
ikNatGlobal	= 3,
ikWonder	= 4,
ikShipPart	= 5,
ikNA            = 0x7F
};

/* model domains*/
enum ModelDomains{
dGround		= 0,
dSea		= 1,
dAir		= 2
};

/* model kinds*/
enum ModelKinds{
mkSelfDeveloped         = 0x00,
mkEnemyDeveloped        = 0x01,
mkSpecial_Boat          = 0x08,
mkSpecial_SubCabin      = 0x0A,
mkSpecial_TownGuard     = 0x10,
mkSpecial_Glider        = 0x11,
mkScout                 = 0x20,
mkSlaves                = 0x21,
mkSettler               = 0x22,
mkCommando              = 0x23,
mkFreight               = 0x24
};

/*unit flags*/
enum UnitFlags{
unFortified	= 0x01,
unBombsLoaded	= 0x02,
unMountainDelay	= 0x04,
unConscripts    = 0x08,
unWithdrawn     = 0x10,
unMulti		= 0x80
};

// unit report flags
enum UnitReportFlags{
urfAlwaysSupport	= 0x01,
urfDeployed	= 0x02
};

// unit move flags
enum ShowMoveFlags{
umCapturing       = 0x0100,
umSpyMission      = 0x0200,
umBombarding      = 0x0400,
umExpelling       = 0x0800,
umShipLoading     = 0x1000,
umShipUnloading   = 0x2000,
umPlaneLoading    = 0x4000,
umPlaneUnloading  = 0x8000
};

/* model flags*/
enum ModelFlags{
mdZOC		= 0x01,
mdCivil         = 0x02,
mdDoubleSupport = 0x04
};

/* player happened flags*/
enum PlayerHappenedFlags{
phTech		= 0x0001,
phStealTech	= 0x0002,
phBankrupt	= 0x0004, // obsolete
phChangeGov	= 0x0008,
phGliderLost	= 0x0100,
phPlaneLost	= 0x0200,
phPeaceViolation        =0x0400,
phPeaceEvacuation       =0x0800,
phShipComplete	= 0x2000,
phExtinct	= 0x8000,
phGameEnd	= 0xF000
};

/* city happened flags*/
enum CityHappenedFlags{
chDisorder		= 0x0001,
chProduction		= 0x0002,
chPopIncrease		= 0x0004,
chPopDecrease		= 0x0008,
chUnitLost		= 0x0010,
chImprovementLost	= 0x0020,
chProductionSabotaged   = 0x0040,
chNoGrowthWarning	= 0x0080,
chPollution		= 0x0100,
chSiege			= 0x0200,
chOldWonder		= 0x0400,
chNoSettlerProd		= 0x0800,
chFounded		= 0x1000,
chAfterCapture	= 0x2000,
chCaptured		= 0xF0000
};

// city info flags
enum CityInfoFlags{
ciCapital               = 0x01,
ciWalled                = 0x02,
ciCoastalFort           = 0x04,
ciMissileBat            = 0x08,
ciBunker                = 0x10,
ciSpacePort             = 0x20
};

/* city tile available values*/
enum CityFieldValues{
faAvailable		= 0x00,
faNotAvailable		= 0x01,
faSiege			= 0x02,
faPole			= 0x03, // not used
faTreaty                = 0x04,
faInvalid		= 0xFF
};

// battle history flags
enum BattleHistoryFlags{
bhEnemyAttack           = 0x01,
bhMyUnitLost            = 0x02,
bhEnemyUnitLost         = 0x04
};


/* move advice special destinations*/
const int maNextCity	=	-1;


/* government forms*/
enum GovernmentForms{
gAnarchy		= 0,
gDespotism		= 1,
gMonarchy		= 2,
gRepublic		= 3,
gFundamentalism	= 4,
gCommunism		= 5,
gDemocracy		= 6,
gFuture                 = 7,
nGov			= 8
};

// colony ship
enum ShipParts{
spComp		= 0,
spPow		= 1,
spHab		= 2,
nShipPart	= 3
};

const int ShipNeed[]	= {6,4,2};


/* unit jobs*/
enum UnitJobs{
jNone		= 0,
jRoad		= 1,
jRR		= 2,
jClear		= 3,
jIrr		= 4,
jFarm		= 5,
jAfforest	= 6,
jMine		= 7,
jCanal		= 8,
jTrans		= 9,
jFort		= 10,
jPoll		= 11,
jBase		= 12,
jPillage	= 13,
jCity		= 14,
nJob		= 15
};
// job preconditions are:
// technology JobPreq is available, no city, plus the following:
//   jRoad: no river when bridge building unavailable
//   jRR: road
//   jClear: Terrain.ClearTerrain, Hanging Gardens for desert
//   jIrr: Terrain.IrrEff
//   jFarm: irrigation
//   jAfforest: Terrain.AfforestTerrain
//   jMine: Terrain.MineEff
//   jCanal: no Mountains, no Arctic
//   jTrans: Terrain.TransWork
//   jPoll: pollution
//   jPillage: any tile improvement
//   jCity, jFort, jBase: none


// spy mission
enum SpyMission{
smSabotageProd		= 0,
smStealMap		= 1,
smStealForeignReports	= 2,
smStealCivilReport	= 3,
smStealMilReport        = 4,
nSpyMission		= 5
};


// resource weights
enum ResourceWeights{
rwOff		= 0x00000000,
rwMaxGrowth	= 0x3F514141, // 120*F + 1/8*P + 1/16*T + 1/16*S
rwMaxProd	= 0x413F1F01, // 1/16*F + 120*P + 30*T + 1*S
rwMaxScience	= 0x41040408, // 1/16*F + 4*P + 4*T + 8*S
rwForceProd	= 0xF1080201, // F^1/2 * (8*P + 2*T + 1*S)
rwForceScience	= 0xF1010101 // F^1/2 * (1*P + 1*T + 1*S)
};


/* advances*/
enum Advances{
adAdvancedFlight             =0,
adAmphibiousWarfare          =1,
adAstronomy                  =2,
adAtomicTheory               =3,
adAutomobile                 =4,
adBallistics                 =5,
adBanking                    =6,
adBridgeBuilding             =7,
adBronzeWorking              =8,
adCeremonialBurial           =9,
adChemistry                  =10,
adChivalry                   =11,
adComposites                 =12,
adCodeOfLaws                 =13,
adCombinedArms               =14,
adCombustionEngine           =15,
adCommunism                  =16,
adComputers                  =17,
adConscription               =18,
adConstruction               =19,
adTheCorporation             =20,
adSpaceFlight                =21,
adCurrency                   =22,
adDemocracy                  =23,
adEconomics                  =24,
adElectricity                =25,
adElectronics                =26,
adEngineering                =27,
adEnvironmentalism           =28,
adWheel                      =29,
adExplosives                 =30,
adFlight                     =31,
adIntelligence               =32,
adGunpowder                  =33,
adHorsebackRiding            =34,
adImpulseDrive               =35,
adIndustrialization          =36,
adSmartWeapons             =37,
adInvention                  =38,
adIronWorking                =39,
adTheLaser                   =40,
adNuclearPower               =41,
adLiterature                 =42,
adInternet             =43,
adMagnetism                  =44,
adMapMaking                  =45,
adMasonry                    =46,
adMassProduction             =47,
adMathematics                =48,
adMedicine                   =49,
adMetallurgy                 =50,
adMin                        =51,
adMobileWarfare              =52,
adMonarchy                   =53,
adMysticism                  =54,
adNavigation                 =55,
adNuclearFission             =56,
adPhilosophy                 =57,
adPhysics                    =58,
adPlastics                   =59,
adPoetry                     =60,
adPottery                    =61,
adRadio         =62,
adRecycling                  =63,
adRefrigeration              =64,
adMonotheism                 =65,
adTheRepublic                =66,
adRobotics                   =67,
adRocketry                   =68,
adRailroad                   =69,
adSanitation                 =70,
adScience                    =71,
adWriting                    =72,
adSeafaring                  =73,
adSelfContainedEnvironment   =74,
adStealth                    =75,
adSteamEngine                =76,
adSteel                      =77,
adSyntheticFood              =78,
adTactics                    =79,
adTheology                   =80,
adTheoryOfGravity            =81,
adTrade                      =82,
adTransstellarColonization   =83,
adUniversity                 =84,
adAdvancedRocketry           =85,
adWarriorCode                =86,
adAlphabet                   =87,
adPolytheism                 =88,
adRefining                   =89,
futComputingTechnology        =90,
futNanoTechnology      =91,
futMaterialTechnology           =92,
futArtificialIntelligence         =93,
adMilitary	= 0x800		/* = Military Research*/
};


/*wonders*/
enum Wonders{
woPyramids	= 0,
woZeus		= 1,
woGardens	= 2,
woColossus	= 3,
woLighthouse	= 4,
woGrLibrary	= 5,
woOracle	= 6,
woSun		= 7,
woLeo		= 8,
woMagellan	= 9,
woMich		= 10,
/*11*/
woNewton	= 12,
woBach		= 13,
/*14,*/
woLiberty	= 15,
woEiffel	= 16,
woHoover	= 17,
woShinkansen	= 18,
woManhattan	= 19,
woMir		= 20,
nWonder		= 21		 // number of wonders   
};

/*city improvements*/
enum CityImp{
imTrGoods	= 28,
imBarracks	= 29,
imGranary	= 30,
imTemple	= 31,
imMarket	= 32,
imLibrary	= 33,
imCourt		= 34,
imWalls		= 35,
imAqueduct	= 36,
imBank		= 37,
imCathedral	= 38,
imUniversity	= 39,
imHarbor	= 40,
imTheater	= 41,
imFactory	= 42,
imMfgPlant	= 43,
imRecycling	= 44,
imPower		= 45,
imHydro		= 46,
imNuclear	= 47,
imPlatform	= 48,
imTownHall	= 49,
imSewer		= 50,
imSupermarket	= 51,
imHighways	= 52,
imResLab	= 53,
imMissileBat	= 54,
imCoastalFort	= 55,
imAirport	= 56,
imDockyard	= 57,
imPalace       	= 58,
imGrWall       	= 59,
imColosseum    	= 60,
imObservatory       	= 61,
imMilAcademy     	= 62,
imBunker       	= 63,
imAlgae        	= 64,
imStockEx	= 65,
imSpacePort    	= 66,
imShipComp     	= 67,
imShipPow      	= 68,
imShipHab      	= 69
};

const int
	SettlerFood[]	= {1,1,1,2,1,2,2,2},
	CorrLevel[]	= {3,3,1,2,1,0,0,0},
	SupportFree[]	= {2,2,1,0,2,1,0,0};				// in 1/2*city size

/* special prerequisite values*/
enum SpecialPrereqValues{
preNone		= -1,
preLighthouse   = -2,
preSun		= -3,
preLeo		= -4,
preBuilder	= -5,
preNA		= -0xFF
};

/* job prerequisites*/
const int JobPreq[] =
{preNone,preNone,adRailroad,preNone,preNone,adRefrigeration,preNone,preNone,adExplosives,adExplosives,
adConstruction,preNone,adMedicine,preNone,preNone};


/*advance prerequisites*/
const int AdvPreq[][3] =
{{adFlight,adRobotics,preNone}, //adAdvancedFlight
{adNavigation,adTactics,preNone}, //adAmphibiousWarfare
{adMysticism,adAlphabet,preNone}, //adAstronomy
{adTheoryOfGravity,preNone,preNone}, //adAtomicTheory
{adCombustionEngine,adSteel,preNone}, //adAutomobile
{adMathematics,adMetallurgy,preNone}, //adBallistics
{adCurrency,adEngineering,preNone}, //adBanking
{adConstruction,adWheel,preNone}, //adBridgeBuilding
{preNone,preNone,preNone}, //adBronzeWorking
{preNone,preNone,preNone}, //adCeremonialBurial
{adScience,preNone,preNone}, //adChemistry
{adMonarchy,adWarriorCode,preNone}, //adChivalry
{adMetallurgy,adPlastics,preNone}, //adComposites
{adWriting,preNone,preNone}, //adCodeOfLaws
{adAdvancedFlight,adMobileWarfare,preNone}, //adCombinedArms
{adRefining,adExplosives,preNone}, //adCombustionEngine
{adPhilosophy,adIndustrialization,preNone}, //adCommunism
{adMin,preNone,preNone}, //adComputers
{adTheRepublic,adTactics,preNone}, //adConscription
{adMasonry,adAlphabet,preNone}, //adConstruction
{adEconomics,adDemocracy,preNone}, //adTheCorporation
{adAdvancedFlight,adAdvancedRocketry,preNone}, //adSpaceFlight
{adBronzeWorking,preNone,preNone}, //adCurrency
{adConscription,adIndustrialization,preNone}, //adDemocracy
{adBanking,adUniversity,preNone}, //adEconomics
{adMagnetism,preNone,preNone}, //adElectricity
{adRadio,adAtomicTheory,preNone}, //adElectronics
{adConstruction,adBronzeWorking,preNone}, //adEngineering
{adIndustrialization,preNone,preNone}, //adEnvironmentalism
{preNone,preNone,preNone}, //adWheel
{adChemistry,adEngineering,preNone}, //adExplosives
{adCombustionEngine,adPhysics,preNone}, //adFlight
{adTactics,adInvention,preNone}, //adIntelligence
{adMedicine,adIronWorking,preNone}, //adGunpowder
{preNone,preNone,preNone}, //adHorsebackRiding
{adSpaceFlight,adNuclearPower,preNone}, //adImpulseDrive
{adRailroad,adBanking,preNone}, //adIndustrialization
{adAdvancedRocketry,adTheLaser,preNone}, //adSmartWeapons
{adWriting,adWheel,preNone}, //adInvention
{adBronzeWorking,adInvention,preNone}, //adIronWorking
{adMin,adPhysics,preNone}, //adTheLaser
{adNuclearFission,preNone,preNone}, //adNuclearPower
{adPoetry,adTrade,preNone}, //adLiterature
{adDemocracy,adComputers,preNone}, //adInternet
{adPhysics,adIronWorking,preNone}, //adMagnetism
{adAlphabet,preNone,preNone}, //adMapMaking
{preNone,preNone,preNone}, //adMasonry
{adAutomobile,adElectronics,adTheCorporation}, //adMassProduction
{adCurrency,adAlphabet,preNone}, //adMathematics
{adMysticism,adPottery,preNone}, //adMedicine
{adGunpowder,preNone,preNone}, //adMetallurgy
{adRobotics,adPlastics,preNone}, //adMin
{adAutomobile,adTactics,preNone}, //adMobileWarfare
{adPolytheism,preNone,preNone}, //adMonarchy
{adCeremonialBurial,preNone,preNone}, //adMysticism
{adSeafaring,adAstronomy,preNone}, //adNavigation
{adAtomicTheory,adMassProduction,preNone}, //adNuclearFission
{adMathematics,adLiterature,preNone}, //adPhilosophy
{adScience,preNone,preNone}, //adPhysics
{adMassProduction,adRefining,preNone}, //adPlastics
{adMysticism,adWarriorCode,preNone}, //adPoetry
{preNone,preNone,preNone}, //adPottery
{adElectricity,adEngineering,preNone}, //adRadio
{adEnvironmentalism,adPlastics,preNone}, //adRecycling
{adElectricity,preNone,preNone}, //adRefrigeration
{adPolytheism,adAstronomy,preNone}, //adMonotheism
{adLiterature,preNone,preNone}, //adTheRepublic
{adMassProduction,adEconomics,preNone}, //adRobotics
{adBallistics,adExplosives,preNone}, //adRocketry
{adSteamEngine,adBridgeBuilding,preNone}, //adRailroad
{adEnvironmentalism,adMedicine,preNone}, //adSanitation
{adMetallurgy,adTheology,adPhilosophy}, //adScience
{adAlphabet,preNone,preNone}, //adWriting
{adPottery,adMapMaking,preNone}, //adSeafaring
{adRecycling,adSyntheticFood,preNone}, //adSelfContainedEnvironment
{adComposites,adRadio,preNone}, //adStealth
{adScience,adEngineering,preNone}, //adSteamEngine
{adIronWorking,adRailroad,preNone}, //adSteel
{adChemistry,adRefrigeration,preNone}, //adSyntheticFood
{adWarriorCode,adUniversity,preNone}, //adTactics
{adMonotheism,adPoetry,preNone}, //adTheology
{adAstronomy,adPhysics,preNone}, //adTheoryOfGravity
{adCurrency,adCodeOfLaws,preNone}, //adTrade
{adImpulseDrive,adSelfContainedEnvironment,preNone}, //adTransstellarColonization
{adScience,preNone,preNone}, //adUniversity
{adComputers,adRocketry,preNone}, //adAdvancedRocketry
{preNone,preNone,preNone}, //adWarriorCode
{preNone,preNone,preNone}, //adAlphabet
{adCeremonialBurial,adHorsebackRiding,preNone}, //adPolytheism
{adChemistry,preNone,preNone}, //adRefining
{adComputers,preNone,preNone}, //futComputingTechnology
{adRobotics,preNone,preNone}, //futNanoTechnology
{adComposites,preNone,preNone}, //futMaterialTechnology
{adSmartWeapons,preNone,preNone}}; //futArtificialIntelligence


const struct {int Kind,Preq,Cost,Maint,Expiration;} Imp[] = // city improvements
{{ikWonder,adMathematics,400,0,adDemocracy}, //woPyramids
{ikWonder,adPolytheism,200,0,adElectronics}, //woZeus
{ikWonder,adInvention,200,0,adNuclearFission}, //woGardens
{ikWonder,adBronzeWorking,200,0,-1}, //woColossus
{ikWonder,adMapMaking,200,0,adSteel}, //woLighthouse
{ikWonder,adLiterature,400,0,adPlastics}, //woGrLibrary
{ikWonder,adMysticism,200,0,-1}, //woOracle
{ikWonder,adChivalry,300,0,adSpaceFlight}, //woSun
{ikWonder,adPhilosophy,500,0,-1}, //woLeo
{ikWonder,adNavigation,300,0,-1}, //woMagellan
{ikWonder,adMonotheism,400,0,-1}, //woMich
{ikNA,preNA}, //{11}
{ikWonder,adTheoryOfGravity,400,0,-1}, //woNewton
{ikWonder,adTheology,400,0,-1}, //woBach
{ikNA,preNA}, //{14}
{ikWonder,adDemocracy,500,0,-1}, //woLiberty
{ikWonder,adSteel,800,0,-1}, //woEiffel
{ikWonder,adElectronics,800,0,-1}, //woHoover
{ikWonder,adPlastics,500,0,-1}, //woShinkansen
{ikWonder,adNuclearFission,400,0,-1}, //woManhattan
{ikWonder,adSpaceFlight,800,0,-1}, //woMir
{ikNA,preNA}, //{21}
{ikNA,preNA}, //{22}
{ikNA,preNA}, //{23}
{ikNA,preNA}, //{24}
{ikNA,preNA}, //{25}
{ikNA,preNA}, //{26}
{ikNA,preNA}, //{27}
{ikTrGoods,preNone,0,0}, //imTrGoods
{ikCommon,adWarriorCode,40,1}, //imBarracks
{ikCommon,adPottery,60,1}, //imGranary
{ikCommon,adCeremonialBurial,40,1}, //imTemple
{ikCommon,adCurrency,60,1}, //imMarket
{ikCommon,adWriting,80,3}, //imLibrary
{ikCommon,adCodeOfLaws,80,2}, //imCourt
{ikCommon,adMasonry,80,1}, //imWalls
{ikCommon,adConstruction,80,1}, //imAqueduct
{ikCommon,adBanking,120,2}, //imBank
{ikCommon,adMonotheism,100,1}, //imCathedral
{ikCommon,adUniversity,160,5}, //imUniversity
{ikCommon,adSeafaring,60,1}, //imHarbor
{ikCommon,adPoetry,60,2}, //imTheater
{ikCommon,adIndustrialization,200,3}, //imFactory
{ikCommon,adRobotics,320,5}, //imMfgPlant
{ikCommon,adRecycling,320,4}, //imRecycling
{ikCommon,adElectricity,120,2}, //imPower
{ikCommon,adEnvironmentalism,120,1}, //imHydro
{ikCommon,adNuclearPower,240,2}, //imNuclear
{ikCommon,adRefining,160,2}, //imPlatform
{ikCommon,preNone,40,1}, //imTownHall
{ikCommon,adSanitation,120,2}, //imSewer
{ikCommon,adRefrigeration,80,2}, //imSupermarket
{ikCommon,adAutomobile,160,4}, //imHighways
{ikCommon,adComputers,240,7}, //imResLab
{ikCommon,adAdvancedRocketry,100,1}, //imMissileBat
{ikCommon,adMetallurgy,80,1}, //imCoastalFort
{ikCommon,adAdvancedFlight,160,1}, //imAirport
{ikCommon,adAmphibiousWarfare,80,1}, //imDockyard
{ikNatLocal,preNone,100,0}, //imPalace
{ikNatLocal,adEngineering,400,4}, //imGrWall
{ikNatLocal,adConstruction,200,4}, //imColosseum
{ikNatLocal,adAstronomy,300,4}, //imObservatory
{ikNatLocal,adTactics,100,4}, //imMilAcademy
{ikNatLocal,adSteel,200,2}, //imBunker
{ikNatLocal,adSyntheticFood,120,2}, //imAlgae
{ikNatGlobal,adTheCorporation,320,4}, //imStockEx
{ikNatGlobal,adSpaceFlight,400,0}, //imSpacePort
{ikShipPart,adTransstellarColonization,240,0}, //imShipComp
{ikShipPart,adImpulseDrive,600,0}, //imShipPow
{ikShipPart,adSelfContainedEnvironment,800,0}}; //imShipHab


/* government prerequisites*/
const int GovPreq[] =
{preNone,preNone,adMonarchy,adTheRepublic,adTheology,adCommunism,adDemocracy,adInternet};

/*Age prerequisites*/
const int AgePreq[]= {preNone,adScience,adMassProduction,adTransstellarColonization};


/* terrain types*/
const struct {
	int MoveCost,Defense,ClearTerrain,IrrEff,IrrClearWork,AfforestTerrain,
	MineEff,MineAfforestWork,TransTerrain,TransWork,FoodRes[3],ProdRes[3],TradeRes[3];
} Terrain[] =
{{1,4,-1,0,0,-1,0,0,-1,0,{0,0,0},{0,0,0},{0,0,0}}, //Ocn
{1,4,-1,0,0,-1,0,0,-1,0,{1,5,1},{0,0,5},{3,3,3}}, //Sho
{1,4,-1,1,600,fForest,0,1800,fHills,3000,{3,2,2},{0,1,0},{1,1,1}}, //Gra
{1,4,fGrass,0,1800,-1,1,600,fPrairie,3000,{0,3,0},{1,1,4},{1,1,1}}, //Dst
{1,4,-1,1,600,fForest,0,2400,-1,0,{1,3,1},{1,1,3},{1,1,1}}, //Pra
{1,4,-1,1,600,-1,0,0,fGrass,3000,{1,1,1},{0,0,4},{1,6,1}}, //Tun
{2,4,-1,0,0,-1,3,1800,-1,0,{0,3,0},{1,1,0},{0,4,0}}, //Arc
{2,6,fGrass,0,2400,fForest,0,2400,fHills,3000,{1,1,1},{0,4,1},{1,1,5}}, //Swa
{1}, // not used
{2,6,fPrairie,0,600,-1,0,0,-1,0,{1,3,1},{2,2,2},{1,1,4}}, //For
{2,8,-1,1,600,-1,3,1200,fGrass,6000,{1,1,1},{0,0,2},{0,4,0}}, //Hil
{3,12,-1,0,0,-1,2,1200,-1,0,{0,0,0},{1,4,1},{0,0,7}}}; //Mou


/*settler work required MP*/
enum WorkMP{
PillageWork	= 100,
CityWork	= 900,
FarmWork	= 3, // *IrrClearWork
RoadWork	= 300, // *MoveCost
RoadBridgeWork	= 900,
RRWork		= 600, // *MoveCost
RRBridgeWork	= 900,
CanalWork	= 1800,
FortWork	= 600, // *MoveCost
BaseWork	= 600, // *MoveCost
PollWork	= 1800
};


// upgrades for new unit models
// upgrade[domain,0].preq is domain precondition advance
// cost values accumulate if prerequisite is future tech / are maximized if not
const int nUpgrade = 15;

const struct {int Preq,Strength,Trans,Cost;} Upgrade[][nUpgrade] =
{{{adWarriorCode,4,0,3},
{adBronzeWorking,2,0,4},
{adIronWorking,2,0,5},
{adChivalry,2,0,5},
{adMonotheism,3,0,7},
{adGunpowder,3,0,8},
{adExplosives,4,0,9},
{adTactics,5,0,10},
{adRadio,6,0,11},
{adDemocracy,6,0,5},
{adMobileWarfare,7,0,12},
{adRobotics,8,0,15},
{adComposites,8,0,15},
{adTheLaser,8,0,14},
{futMaterialTechnology,10,0,2}},
{{adMapMaking,4,1,8},
{adNavigation,4,0,10},
{adEngineering,0,1,8},
{adGunpowder,8,0,12},
{adMagnetism,12,1,20},
{adExplosives,16,0,24},
{adSteamEngine,24,0,28},
{adAmphibiousWarfare,24,1,18},
{adAdvancedRocketry,32,0,38},
{futMaterialTechnology,14,0,4},
{futArtificialIntelligence,14,0,4},
{preNA},{preNA},{preNA},{preNA}},
{{adFlight,12,1,14},
{adTactics,6,0,17},
{adElectronics,6,0,20},
{adMin,8,0,24},
{adComposites,8,0,26},
{adSmartWeapons,11,0,32},
{futArtificialIntelligence,7,0,4},
{preNA},{preNA},{preNA},{preNA},{preNA},{preNA},{preNA},{preNA}}};


/* model features*/
enum ModelFeatures{
mcWeapons	= 0,
mcArmor	= 1,
mcMob		= 2,
mcSeaTrans	= 3,
mcCarrier	= 4,
mcTurbines      = 5,
mcBombs		= 6,
mcFuel		= 7,
mcAirTrans 	= 8,
mcNav		= 9,
mcRadar		= 10,
mcSub		= 11,
mcArtillery	= 12,
mcAlpine	= 13,
mcSupplyShip	= 14,
mcOver		= 15,
mcAirDef	= 16,
mcSpy		= 17,
mcSE		= 18,
mcNP		= 19,
mcJet		= 20,
mcStealth	= 21,
mcFanatic	= 22,
mcFirst		= 23,
mcWill		= 24,
mcAcademy	= 25,
mcLine		= 26,
nFeature	= 27
};
/*todo: add AutoFeature*/
const int AutoFeature[] = {mcNav,mcSE,mcNP,mcJet,mcAcademy}, mcFirstNonCap=mcNav;

const struct {int Domains,Preq,Weight,Cost;} Feature[] =
{{7,preNone,1,1}, /*mcWeapons*/
{7,preNone,1,1}, /*mcArmor*/
{1,adHorsebackRiding,1,1}, /*mcMob*/
{2,preNone,2,1}, /*mcSeaTrans*/
{2,adAdvancedFlight,2,2}, /*mcCarrier*/
{2,adPhysics,3,1}, /*mcTurbines*/
{4,adAdvancedFlight,1,1}, /*mcBombs*/
{4,preNone,1,1}, /*mcFuel*/
{4,adCombinedArms,2,1}, /*mcAirTrans*/
{2,adNavigation,0,0}, /*mcNav*/
{2,adRadio,0,1}, /*mcRadar*/
{2,adCombustionEngine,2,1}, /*mcSub*/
{3,adBallistics,1,1}, /*mcArtillery*/
{1,adTactics,2,1}, /*mcAlpine*/
{2,adMedicine,1,1}, /*mcSupplyShip*/
{1,adBridgeBuilding,0,2}, /*mcOver*/
{2,adAdvancedRocketry,1,1}, /*mcAirDef*/
{4,adIntelligence,2,1}, /*mcSpy*/
{2,adSteamEngine,0,0}, /*mcSE*/
{2,adNuclearPower,0,0}, /*mcNP*/
{4,adRocketry,0,0}, /*mcJet*/
{4,adStealth,1,2}, /*mcStealth*/
{5,adCommunism,0,1}, /*mcFanatic*/
{1,preSun,0,1}, /*mcFirst*/
{1,preSun,0,1}, /*mcWill*/
{1,preSun,0,0}, /*mcAcademy*/
{7,adMassProduction,0,0}}; /*mcLine*/


// for backward compatibility
enum OldModelKindNames{
mkDiplomat              = 0x23,
mkCaravan               = 0x24
};

enum OldGovernmentFormNames{
gLybertarianism	= 7
};

enum OldAdvanceNames{
adIntelligenArms             =37,
adLybertarianism             =43,
adRadioCommunication         =62,
futResearchTechnology        =90,
futProductionTechnology      =91,
futArmorTechnology           =92,
futMissileTechnology         =93
};

enum OldCityImpNames{
imNatObs       	= 61,
imEliteBar     	= 62
};

enum OldModelFeatureNames{
mcOffense	= 0,
mcDefense	= 1,
mcLongRange	= 12,
mcHospital	= 14
};


typedef void* pServerData;	/*type of data argument - to avoid writing "void*" all over the place!*/
#define NoServerData (pServerData)0
typedef int __stdcall TServerCall(int Command, int Player, int Subject, pServerData Data);

#ifndef __GNUC__	/*GCC doesn't exactly support pragmas*/
	#define __attribute__(a)
	#ifdef _MSC_VER //Microsoft C/C++
		#pragma pack(1)
	#else	//Borland C/C++
		#pragma option push -a1	
	#endif
#endif



struct TUn
{
	long		Loc; /*location */
	#ifdef __cplusplus
	mutable
	#endif
	long		Status;
	long		SavedStatus; // for server internal use only
	unsigned short	ID; // unit number, never changes, unique within this nation
	short		mix; /*index of unit model*/
	short		Home; /*index of home city, -1 if none*/
	short		Master; /*index of transporting unit, -1 if none*/
	short		Movement; /*movement left for this turn*/
	unsigned char	Health; // = 100-Damage
	unsigned char	Fuel;
	unsigned char	Job; /*current terrain improvement job*/
	unsigned char	Exp; /*micro experience, the level is Exp/ExpCost*/
	unsigned char	TroopLoad; /*number of transported ground units*/
	unsigned char	AirLoad; /*number of transported air units*/
	unsigned long	Flags;
} __attribute__((__packed__)) ;


struct TCity
{
	long		Loc; /*location	*/
	#ifdef __cplusplus
		mutable
	#endif
	long	       	Status;
	long	    	SavedStatus; // for server internal use only
	unsigned short	ID; // founding player <<12 + number, never changes, unique within the whole game
	unsigned short	Size;
	short		Project; /*current production project, see city project flags*/
	short		Project0; // for server use only
	short		Food; /*collected food in storage*/
	short		Pollution; /*collected pollution in dump*/
	short		Prod; /*for project collected production points*/
	short		Prod0; /*for project collected production points in the beginning of the turn*/
	unsigned long	Flags; /*flags indicate what happened within the last turnaround*/
	unsigned long	Tiles; /*currently by city exploited tiles, bitset with index (dy+3) shl 2+(dx+3) shr 1, (dx,dy) relative to central tile*/
        unsigned long   N1; // reserved for future use
	unsigned char	Built[((nImp+3)/4) *4]; /*array value =1 indicates built improvement*/
} __attribute__((__packed__)) ;


struct TModel
{
	#ifdef __cplusplus
	mutable
	#endif
	long		Status;
	long		SavedStatus; // for server internal use only
	unsigned short	ID; // developing player <<12 + number, never changes, unique within the whole game
	unsigned short	IntroTurn;
	unsigned short	Built; /*units built with this model*/
	unsigned short	Lost; /*units of this model lost in combat*/
	unsigned char	Kind;
	unsigned char	Domain;
	unsigned short	Attack, Defense, Speed, Cost;
	unsigned short	MStrength; /*construction time multipliers, only valid if kind is mkSelfDeveloped or mkEnemyDeveloped*/
	unsigned char	MTrans, MCost;
	unsigned char	Weight;
	unsigned char	MaxWeight; // weight and maximum weight (construction time)
	unsigned long	Upgrades; /*bitarray indicating all upgrades*/
	unsigned long	Flags;
	unsigned char	Cap[((nFeature+3)/4) *4]; /*special features*/
} __attribute__((__packed__)) ;


struct TUnitInfo
{
	long		Loc;
	unsigned short	mix; /*index of unit model for its owner*/
	unsigned short	emix; // index in enemy model list
	signed char	owner;
	unsigned char	Health; // = 100-Damage
	unsigned char	Fuel;
	unsigned char	Job; //current terrain improvement job
	unsigned char	Exp; //micro experience, the level is Exp div ExpCost
	unsigned char	Load; //number of transported units
	unsigned short	Flags;
} __attribute__((__packed__)) ;


struct TCityInfo
{
	long		Loc;
	long		Status;
        long		SavedStatus; // for server internal use only
	unsigned short	Owner; // last known owner, even if not alive anymore!
	unsigned short	ID; // founding player <<12 + number, never changes, unique within the whole game
	unsigned short	Size;
	unsigned short	Flags;
} __attribute__((__packed__)) ;


struct TModelInfo
{
	unsigned short	Owner; /*Player which owns the model*/
	unsigned short	mix; /*index of unit model for its owner*/
	unsigned short	ID;
	unsigned char	Kind;
	unsigned char	Domain;
	unsigned short	Attack;
	unsigned short	Defense;
	unsigned short	Speed;
	unsigned short	Cost;
	unsigned char	TTrans; /*ground unit transport capability*/
	unsigned char	ATrans_Fuel; /*air unit transport capability resp. fuel*/
	unsigned short	Bombs; //additional attack with bombs
	unsigned long	Cap; //special features, bitset with index Feature-mcFirstNonCap
	unsigned char	MaxUpgrade; /*maximum used upgrade*/
        unsigned char   Weight;
	unsigned short	Lost;
} __attribute__((__packed__)) ;

struct TBattle
{
       unsigned char Enemy;
       unsigned char Flags;
       unsigned short Turn;
       unsigned short mix;
       unsigned short mixEnemy;
       long ToLoc;
       long FromLoc;
} __attribute__((__packed__)) ;

/*restore previous packing settings*/

#ifndef __GNUC__
	#undef	__attribute__
	#ifdef _MSC_VER //Microsoft C/C++
		#pragma pack()
	#else	//Borland C/C++
		#pragma option pop
	#endif
#endif

struct TWonderInfo
{
	long	CityID, // -2 if destroyed, -1 if never completed, >=0 ID of city
		EffectiveOwner; /* owning player if effective, -1 if expired or not built*/
};

struct TShipInfo
{
	long  Parts[nShipPart];
};

struct TEnemyReport
{
  long 	      	TurnOfContact, TurnOfCivilReport, TurnOfMilReport,Attitude,
            	Credibility; // 0..100, last update: ToC
  long 	      	Treaty[nPl]; // diplomatic status with other nations, last update: ToCR
  long 		Government, // gAnarchy..gDemocracy, last update: ToCR
      		Money, // last update: ToCR
            	ResearchTech, ResearchDone; // last update: ToCR
  char      	Tech[((nAdv+3)/4) *4]; // tech status indicator, last update: ToCR
  long       	nModelCounted; // number of models with info in UnCount, last update: ToMR
  unsigned short        UnCount[256]; // number of available units for each model, last update: ToMR
};

struct TMoveAdviceData
{
	long ToLoc, nStep, MoreTurns, MaxHostile_MovementLeft, dx[25], dy[25];
};


struct TTileInfo
{
	long Food, Prod, Trade, ExplCity;
};


struct TCityReport
{
	long HypoTiles, HypoTax, HypoLux, Working, Happy, FoodRep, ProdRep,
                Trade, PollRep, Corruption, Tax, Lux, Science, Support, Eaten,
                ProdCost, Storage, Deployed;
};


struct TCityReportNew
{
	long HypoTiles, // tiles that should be considered as exploited (for the current adjustment, set this to -1 or to TCity.Tiles of the city)
		HypoTaxRate, HypoLuxuryRate, // tax and luxury rate that should be assumed (for current rates, set this to -1 or to RO.TaxRate resp. RO.LuxRate)
		Morale,
		FoodSupport, MaterialSupport, // food and material taken for unit support
		ProjectCost, // material cost of current project
		Storage, // size of food storage
		Deployed, // number of units causing unrest (unrest=2*deployed)
		CollectedControl, CollectedFood, CollectedMaterial, CollectedTrade, // raw control, food, material and trade as collected by the citizens
		Working, // number of exploited tiles including city tile
		FoodSurplus, Production, AddPollution, // food surplus, production gain and pollution after all effects
		Corruption, Tax, Science, Luxury, // corruption, tax, science and wealth after all effects
		HappinessBalance; // = (Morale+Wealth+Control) - (Size+Unrest), value < 0 means disorder
}


struct TCityTileAdviceData
{
	unsigned long ResourceWeights, Tiles;
	#ifndef __cplusplus
	struct
	#endif
	TCityReport CityReport;
};

struct TGetCityData
{
        long Owner;
	#ifndef __cplusplus
	struct
	#endif
        TCity c;
};

struct TCityAreaInfo
{
	long Available[27];
};


struct TJobProgressData
{
	long Required, Done, NextTurnPlus;
}


struct TBattleForecast
{
	long pAtt, mixAtt, HealthAtt, ExpAtt, FlagsAtt, Movement, EndHealthDef,
		EndHealthAtt;
};

struct TShowMove
{
	long Owner, Health, mix, emix, Flags, FromLoc, dx, dy, Fuel, Exp, Load;
};

struct TOffer
{
  long nDeliver, nCost,
  Price[12];
};

struct TPlayerContext
{
	void		*Data;
	unsigned long	*Map; /*the playground, a list of tiles with index = location, see tile flags*/
        short           *MapObservedLast; // turn in which the tile was observed last, index = location
        char            *Territory; // nation to which's territory a tile belongs, -1 indicates none
	#ifdef __cplusplus
		TUn		*Un; /*units of the player*/
		TCity		*City; /*cities of the player*/
		TModel		*Model; /*unit models of the player*/
		TUnitInfo	*EnemyUn; /*known units of enemy players*/
		TCityInfo	*EnemyCity; /*known cities of enemy players*/
		TModelInfo	*EnemyModel; /*known unit models of enemy players*/
		TEnemyReport 	*EnemyReport[nPl];


	#else
		struct TUn		*Un; /*units of the player*/
		struct TCity		*City; /*cities of the player*/
		struct TModel		*Model; /*unit models of the player*/
		struct TUnitInfo	*EnemyUn; /*known units of enemy players*/
		struct TCityInfo	*EnemyCity; /*known cities of enemy players*/
		struct TModelInfo	*EnemyModel; /*known unit models of enemy players*/
		struct TEnemyReport	*EnemyReport [nPl];
	#endif
	long                            TestFlags, //options turned on in the "Manipulation" menu
                                        Turn, //current turn
					Alive, /*bitset of IDs of players still alive*/
					Happened, /*flags indicate what happened within the last turnaround*/
					AnarchyStart, // start turn of anarchy, <0 if not in anarchy
                                        Credibility, // own credibility
                                        MaxCredibility, // maximum credibility still to achieve
					nUn, /*number of units of the player*/
					nCity, /*number of cities of the player*/
					nModel, /*number of unit models of the player*/
					nEnemyUn, /*number of known units of enemy players*/
					nEnemyCity, /*number of known cities of enemy players*/
					nEnemyModel, /*number of known unit models of enemy players*/
					Government,
					Money,
					TaxRate,
					LuxRate,
					Research, /*collected research points for currently researched tech*/
					ResearchTech; //currently researched tech
	#ifndef __cplusplus
	struct
	#endif
	TModel		DevModel; /*currently researched tech*/
	char		Tech[((nAdv+3)/4) *4]; /*unit model currently under development*/
	long            Attitude[nPl]; // attitude to other nations
	long            Treaty[nPl]; // treaty with other nations
	long            EvaStart[nPl]; // peace treaty: start of evacuation period
	long            Tribute[nPl]; // obsolete
	long            TributePaid[nPl]; // obsolete
	#ifndef __cplusplus
	struct
	#endif
	TWonderInfo	Wonder[28]; /*wonders of the world*/
	#ifndef __cplusplus
	struct
	#endif
	TShipInfo	Ship[nPl]; /*colony ships*/
	unsigned char	NatBuilt[((nImp+3)/4) *4 -28]; /* [i] = 1 if national project i+28 built*/
	long            nBattleHistory;
	#ifndef __cplusplus
	struct
	#endif
	TBattle         *BattleHistory; // complete list of all my battles in the whole game
	void	*BorderHelper; // not used
	long	LastCancelTreaty[nPl]; // turn of last treaty cancel
	long	OracleIncome;
};

struct TInitModuleData
{
	TServerCall*	Server;
	long		DataVersion;
        long		DataSize;
        long            Flags;
};

struct TNewGameData
{
	long		lx, ly, LandMass, MaxTurn;
	long		Difficulty[nPl]; /*difficulty levels of the players*/
		/* if it's 0 this player is the supervisor, -1 for unused slots*/
	#ifndef __cplusplus
	struct
	#endif
	TPlayerContext	*RO[nPl];
};

#endif	/* ifndef protocolh */
```
{% endraw %}

