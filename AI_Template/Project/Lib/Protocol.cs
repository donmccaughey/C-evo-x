using System;
using System.Collections.Generic;

namespace CevoAILib
{
	/// <summary>
	/// INTERNAL - only use from CevoAILib classes!
	/// </summary>
	static class Protocol
	{
		public const int nPl = 15;
		public const int nJob = 15;

		public const int unFortified = 0x01;
		public const int unBombsLoaded = 0x02;
		public const int unMountainDelay = 0x04;
		public const int unConscripts = 0x08;
		public const int unWithdrawn = 0x10;
		public const int unMulti = 0x80;

		public const int mdZOC = 0x01;
		public const int mdCivil = 0x02;
		public const int mdDoubleSupport = 0x04;

		public const int ciCapital = 0x01;
		public const int ciWalled = 0x02;
		public const int ciCoastalFort = 0x04;
		public const int ciMissileBat = 0x08;
		public const int ciBunker = 0x10;
		public const int ciSpacePort = 0x20;

		public const int sExecute = 0x4000; // {call command-sExecute to request return value without execution}

		// Info Request Commands
		public const int sMessage = 0x0000; 
		public const int sSetDebugMap = 0x0010; 
		public const int sRefreshDebugMap = 0x0040;
		public const int sGetChart = 0x0100; // + type shl 4
		public const int sGetTechCost = 0x0180;
		public const int sGetTileInfo = 0x0200;
		public const int sGetCityTileInfo = 0x0210;
		public const int sGetHypoCityTileInfo = 0x0220;
		public const int sGetJobProgress = 0x0230;
		public const int sGetModels = 0x0270;
		public const int sGetUnits = 0x0280;
		public const int sGetDefender = 0x0290;
		public const int sGetBattleForecast = 0x02A0;
		public const int sGetUnitReport = 0x02B0;
		public const int sGetMoveAdvice = 0x02C0;
		public const int sGetPlaneReturn = 0x02D0;
		public const int sGetBattleForecastEx = 0x02E0;
		public const int sGetCity = 0x0300;
		public const int sGetCityReport = 0x0310;
		public const int sGetCityAreaInfo = 0x0320;
		public const int sGetEnemyCityReport = 0x0330;
		public const int sGetEnemyCityAreaInfo = 0x0340;
		public const int sGetCityTileAdvice = 0x0350;
		public const int sGetCityReportNew = 0x0360;
		public const int sGetEnemyCityReportNew = 0x0370;

		// Client Deactivation Commands
		public const int sTurn = 0x4800;

		public const int sSetGovernment = 0x5100;
		public const int sSetRates = 0x5110;
		public const int sRevolution = 0x5120;
		public const int sSetResearch = 0x5200;
		public const int sStealTech = 0x5210;
		public const int sSetAttitude = 0x5300; // + concerned player shl 4
		public const int sCancelTreaty = 0x5400;

		// Model Related Commands
		public const int sCreateDevModel = 0x5800;
		public const int sSetDevModelCap = 0x5C00; // {+value shl 4}

		// Unit Related Commands
		public const int sRemoveUnit = 0x6000;
		public const int sSetUnitHome = 0x6010;
		public const int sSetSpyMission = 0x6100; // + mission shl 4
		public const int sLoadUnit = 0x6200;
		public const int sUnloadUnit = 0x6210;
		public const int sSelectTransport = 0x6220;
		public const int sMoveUnit = 0x6400; // {+dx and 7 shl 4 +dy and 7 shl 7}

		// Settlers Related Commands
		public const int sctSettlers = 0x2800;
		public const int sAddToCity = 0x6810;
		public const int sStartJob = 0x6C00; // {+job shl 4}

		// City Related Commands
		public const int sSetCityProject = 0x7001;
		public const int sBuyCityProject = 0x7010;
		public const int sSellCityProject = 0x7020;
		public const int sSellCityImprovement = 0x7101;
		public const int sRebuildCityImprovement = 0x7111;
		public const int sSetCityTiles = 0x7201;

		public const int cInitModule = 0x0000;
		public const int cReleaseModule = 0x0100;
		public const int cNewGame = 0x0800;
		public const int cLoadGame = 0x0810;
		public const int cGetReady = 0x08F0;
		public const int cBreakGame = 0x0900;
		public const int cTurn = 0x2000;
		public const int cResume = 0x2010;
		public const int cContinue = 0x2080;
		public const int cShowAfterMove = 0x3040;
		public const int cShowAfterAttack = 0x3050;
		public const int cShowCityChanged = 0x3090;
		public const int cShowMoving = 0x3140;
		public const int cShowCapturing = 0x3150;
		public const int cShowAttacking = 0x3240;
		public const int cShowEndContact = 0x3810;

		public const int scContact = 0x4900;
		public const int scReject = 0x4A00;
		public const int scDipStart = 0x4B00;
		public const int scDipNotice = 0x4B10;
		public const int scDipAccept = 0x4B20;
		public const int scDipCancelTreaty = 0x4B30;
		public const int scDipOffer = 0x4B4E;
		public const int scDipBreak = 0x4BF0;

		public const int opChoose = 0x00000000;
		public const int opCivilReport = 0x11000000; // + turn + concerned nation shl 16
		public const int opMilReport = 0x12000000; // + turn + concerned nation shl 16
		public const int opMap = 0x1F000000;
		public const int opTreaty = 0x20000000; // + suggested nation treaty
		public const int opShipParts = 0x30000000; // + number + part type shl 16
		public const int opMoney = 0x40000000; // + value
		public const int opTech = 0x50000000; // + advance
		public const int opAllTech = 0x51000000;
		public const int opModel = 0x58000000; // + model index
		public const int opAllModel = 0x59000000;
		public const int opMask = 0x7F000000;

		public const int rExecuted = 0x40000000;
		public const int rEffective = 0x20000000;
		public const int rUnitRemoved = 0x10000000;
		public const int rEnemySpotted = 0x08000000;

		public const int eEnemyDestroyed = 0x05;

		public const int mcFirstNonCap = 9;

		public const int cpIndex = 0x1FF;
		public const int cpConscripts = 0x200;
		public const int cpDisbandCity = 0x400;
		public const int cpImp = 0x800;

		public const int phStealTech = 0x02;
	}

	/// <summary>
	/// INTERNAL - only use from CevoAILib classes!
	/// </summary>
	static class ROReadPoint
	{
		public const int TestFlags = 25;
		public const int DevModel = 44;
		public const int Tech = 61;
		public const int Attitude = 85;
		public const int Wonder = 160;
		public const int Ship = 216;
		public const int NatBuilt = 261;
		public const int nBattleHistory = 272;
		public const int OracleIncome = 290;

		public const int SizeOfUn = 8;
		public const int SizeOfUnitInfo = 4;
		public const int SizeOfCity = 28;
		public const int SizeOfCityInfo = 5;
		public const int SizeOfModel = 17;
		public const int SizeOfModelInfo = 7;
	}
}
