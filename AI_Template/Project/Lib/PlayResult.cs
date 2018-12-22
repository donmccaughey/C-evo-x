using System;
using System.Collections.Generic;

namespace CevoAILib
{
	enum PlayError
	{
		None = -1,

		// internal, should not occur
		InternalError_UnknownCommand = 1,
		InternalError_InvalidData = 0,

		// general
		NoTurn = 2, // command only allowed during player's turn
		RulesViolation = 3, // general violation of game rules
		PrerequisitesMissed = 4, // the prerequisites for this command are not fully met
		InvalidLocation = 512, // location is not valid

		// unit movement
		NoTime_Move = 8, // normal unit move: too few movement points left
		NoTime_Load = 9, // load unit: too few movement points left
		DomainMismatch = 17, // move/attack: action not allowed for this unit domain
		NoNavigation = 25, // unit move: not possible, open sea without navigation
		NoRoad = 23, // unit move: not possible, no road
		NoCapturer = 18, // unit move: this type of unit is not allowed to capture a city
		ZoCViolation = 20, // unit move: not possible, ZoC violation
		TreatyViolation = 21, // move/attack: not possible, peace treaty violation
		SubmarineBlock = 19, // unit move: not possible, destination tile occupied by hidden foreign submarine
		StealthUnitBlock = 26, // unit move: not possible, destination tile occupied by foreign stealth unit
		NoLoadCapacity = 27, // load to transport: no more transport capacity
		NoWay = 513,
		RecoverFirst = 514,
		Incomplete = 515,

		// fighting
		NoTime_Attack = 10, // attack: no movement points left
		NoTime_Bombard = 11, // bombard city: too few movement points left
		NoTime_Expel = 12, // expel spy: too few movement points left
		NoBombarder = 28, // bombardment impossible because no attack power

		// settlers
		NoCityTerrain = 34, // found city: not possible in this terrain
		NoBridgeBuilding = 35,
		DeadLands = 22, // sStartJob: not possible, dead lands
		MaxSize = 32, // add to city: bigger size not allowed due to missing aqueduct/sewer

		// city
		RebuildSellOnlyOnce = 88, // sell/rebuild city improvement: only once per city and turn!
		UselessBuilding = 89, // city project: more advanced improvement already exists
		OutOfControl = 90, // buy/sell/rebuild improvement: not in anarchy, not in captured cities
		LocationNotAvailable = 80, // set exploited locations
		TooManyLocations = 81, // set exploited locations

		// model
		ResearchInProgress = 516, // blueprint can't be changed during military research

		// negotiation
		InvalidOffer = 48,
		OfferNotAcceptable = 49,
		CancelTreatyRush = 50,
	}

	struct PlayResult
	{
		readonly int code;

		public PlayResult(int code) { this.code = code; }
		public PlayResult(PlayError error) { this.code = (int)error & 0xFFFF; }

		public override string ToString()
		{
			if ((code & Protocol.rExecuted) != 0)
				return "OK";
			else
				return string.Format("{0}", Error);
		}

		public PlayError Error
		{
			get
			{
				if (OK)
					return PlayError.None;
				else
					return (PlayError)(code & 0xFFFF);
			}
		}

		public bool OK { get { return (code & Protocol.rExecuted) != 0; } }
		public bool Effective { get { return (code & Protocol.rEffective) != 0; } }
		public bool UnitRemoved { get { return (code & Protocol.rUnitRemoved) != 0; } }
		public bool EnemyDestroyed { get { return OK && (code & 0xFFFF) == Protocol.eEnemyDestroyed; } }
		public bool NewUnitOrCitySpotted { get { return (code & Protocol.rEnemySpotted) != 0; } }

		public static PlayResult Success { get { return new PlayResult(Protocol.rExecuted | Protocol.rEffective); } }
		public static PlayResult NoChange { get { return new PlayResult(Protocol.rExecuted); } }
	}
}
