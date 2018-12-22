using System;
using System.Collections.Generic;
using AI;

namespace CevoAILib
{
	enum Job
	{
		None = 0, BuildRoad = 1, BuildRailRoad = 2, ClearOrDrain = 3, Irrigate = 4, BuildFarmland = 5, Afforest = 6, BuildMine = 7,
		BuildCanal = 8, Transform = 9, BuildFortress = 10, CleanUp = 11, BuildBase = 12, Pillage = 13, BuildCity = 14
	}

	enum SpyMission { SabotageProduction = 1, StealMaps = 2, CollectThirdNationKnowledge = 3, PrepareDossier = 4, PrepareMilitaryReport = 5 }

	struct BattleOutcome
	{
		public readonly int EndHealthOfAttacker;
		public readonly int EndHealthOfDefender;

		public BattleOutcome(int endHealthOfAttacker, int endHealthOfDefender)
		{
			this.EndHealthOfAttacker = endHealthOfAttacker;
			this.EndHealthOfDefender = endHealthOfDefender;
		}

		public override string ToString()
		{
			return string.Format("A{0} D{1}", EndHealthOfAttacker, EndHealthOfDefender);
		}
	}

	/// <summary>
	/// basic unit information as available for both own and foreign units
	/// </summary>
	interface IUnitInfo
	{
		Nation Nation { get; }
		ModelBase Model { get; }
		Location Location { get; }
		bool AreOtherUnitsPresent { get; }
		bool IsLoaded { get; }
		int Speed { get; } // usually same as Model.Speed
		bool IsTerrainResistant { get; }
		int Experience { get; }
		int ExperienceLevel { get; }
		int Health { get; }
		bool IsFortified { get; }
		int Load { get; }
		int Fuel { get; }
		Job Job { get; }
	}

	/// <summary>
	/// own unit, abstract base class
	/// </summary>
	unsafe abstract class AUnit : IUnitInfo
	{
		/// <summary>
		/// movement points an own or foreign unit has per turn, considering damage and wonders
		/// </summary>
		/// <param name="unit">the unit</param>
		/// <returns>movement points</returns>
		public static int UnitSpeed(IUnitInfo unit)
		{
			if (unit.Model.Domain == ModelDomain.Sea)
			{
				int speed = unit.Model.Speed;
				if (unit.Nation.HasWonder(Building.MagellansExpedition))
					speed += 200;
				if (unit.Health < 100)
					speed = ((speed - 250) * unit.Health / 5000) * 50 + 250;
				return speed;
			}
			else
				return unit.Model.Speed;
		}

		protected readonly Empire theEmpire;
		public readonly int ID;
		protected readonly Model model;

		public AUnit(Empire empire, int indexInSharedMemory)
		{
			this.theEmpire = empire;
			IndexInSharedMemory = indexInSharedMemory;
			ID = address[3] & 0xFFFF; // save to be able to find unit back
			model = theEmpire.Models[(address[3] >> 16) & 0xFFFF];
		}

		public override string ToString()
		{
			return string.Format("{0}@{1}", model, address[0]);
		}

		#region IUnitInfo members
		public Nation Nation { get { return theEmpire.Us; } }
		public ModelBase Model { get { return model; } }
		public Location Location { get { return new Location(theEmpire, address[0]); } }

		/// <summary>
		/// whether other units are present at the same location
		/// </summary>
		public bool AreOtherUnitsPresent { get { return (address[7] & Protocol.unMulti) != 0; } }

		/// <summary>
		/// whether unit is loaded to a ship or plane
		/// </summary>
		public bool IsLoaded { get { return ((uint)address[4] & 0x80000000) == 0; } } // sign bit

		/// <summary>
		/// movement points this unit has per turn, considering damage and wonders
		/// </summary>
		public int Speed { get { return UnitSpeed(this); } }

		/// <summary>
		/// whether this unit passes hostile terrain without damage
		/// </summary>
		public bool IsTerrainResistant { get { return model.IsTerrainResistant || theEmpire.Us.HasWonder(Building.HangingGardens); } }

		/// <summary>
		/// Experience points collected.
		/// </summary>
		public int Experience { get { return (address[6] >> 8) & 0xFF; } }

		/// <summary>
		/// Experience level as applied in combat. 0 = Green ... 4 = Elite.
		/// </summary>
		public int ExperienceLevel { get { return Experience / Cevo.ExperienceLevelCost; } }

		public int Health { get { return (sbyte)((address[5] >> 16) & 0xFF); } }
		public bool IsFortified { get { return (address[7] & Protocol.unFortified) != 0; } }

		/// <summary>
		/// total number of units loaded to this unit
		/// </summary>
		public int Load { get { return TroopLoad + AirLoad; } }

		/// <summary>
		/// Fuel remaining, not necessarily the same as Model.Fuel.
		/// </summary>
		public int Fuel { get { return (sbyte)((address[5] >> 24) & 0xFF); } }

		/// <summary>
		/// settler job this unit is currently doing
		/// </summary>
		public Job Job { get { return (Job)(address[6] & 0xFF); } }
		#endregion

		public bool Exists { get { return indexInSharedMemory >= 0; } }
		public bool IsConscripts { get { return (address[7] & Protocol.unConscripts) != 0; } }
		public int MovementLeft { get { return (short)(address[5] & 0xFFFF); } }
		public bool MustPauseForMountains { get { return (address[7] & Protocol.unMountainDelay) != 0; } }
		public bool WasWithdrawn { get { return (address[7] & Protocol.unWithdrawn) != 0; } }
		public bool CausesUnrest { get { return Location.MayCauseUnrest && !model.IsCivil; } }
		public int TroopLoad { get { return (address[6] >> 16) & 0xFF; } }
		public int AirLoad { get { return (address[6] >> 24) & 0xFF; } }
		public bool AreBombsLoaded { get { return (address[7] & Protocol.unBombsLoaded) != 0; } }

		/// <summary>
		/// home city, null if none
		/// </summary>
		public City Home
		{ 
			get 
			{
				int homeCityIndexInSharedMemory = (short)(address[4] & 0xFFFF);
				if (homeCityIndexInSharedMemory >= 0)
					return theEmpire.CityLookup[homeCityIndexInSharedMemory];
				else
					return null; 
			} 
		}

		/// <summary>
		/// ship or aircraft by which this unit is currently transported, null if not transported
		/// </summary>
		public Unit Transport
		{ 
			get 
			{
				int transportIndexInSharedMemory = (short)((address[4] >> 16) & 0xFFFF);
				if (transportIndexInSharedMemory >= 0)
					return theEmpire.UnitLookup[transportIndexInSharedMemory];
				else
					return null; 
			} 
		}

		/// <summary>
		/// persistent custom value
		/// </summary>
		public int Status
		{
			get { return address[1]; }
			set { address[1] = value; }
		}

		#region effective methods
		/// <summary>
		/// Move unit to a certain location.
		/// Moves along shortest possible path considering all known information.
		/// Only does the part of the move that is possible within this turn.
		/// If move has to be continued next turn the return value has the Error property Incomplete.
		/// Operation breaks even if it could be continued within the turn if a new foreign unit or city is spotted,
		/// in this case the result has the NewUnitOrCitySpotted property set.
		/// Hostile terrain is considered to find a compromise between damage and reaching the target fast.
		/// </summary>
		/// <param name="target">target location</param>
		/// <returns>result of operation</returns>
		public PlayResult MoveTo__Turn(Location target)
		{
			if (target == Location)
				return PlayResult.NoChange;
			else
				return MoveTo(target, false);
		}

		/// <summary>
		/// Move unit adjacent to a certain location.
		/// Moves along shortest possible path considering all known information.
		/// Only does the part of the move that is possible within this turn.
		/// If move has to be continued next turn the return value has the Error property Incomplete.
		/// Operation breaks even if it could be continued within the turn if a new foreign unit or city is spotted,
		/// in this case the result has the NewUnitOrCitySpotted property set.
		/// Hostile terrain is considered to find a compromise between damage and reaching the target fast.
		/// </summary>
		/// <param name="target">location to move adjacent to</param>
		/// <returns>result of operation</returns>
		public PlayResult MoveToNeighborOf__Turn(Location target)
		{
			if (target.IsNeighborOf(Location))
				return PlayResult.NoChange;
			else
				return MoveTo(target, true);
		}

		// internal
		PlayResult MoveTo(Location target, bool approach)
		{
			if (!target.IsValid)
				return new PlayResult(PlayError.InvalidLocation);
			if (MustPauseForMountains)
				return new PlayResult(PlayError.Incomplete);

			// pathfinding necessary
			TravelSprawl sprawl = null;
			if (approach)
				sprawl = new TravelSprawl(theEmpire, this, target);
			else
				sprawl = new TravelSprawl(theEmpire, this);
			foreach (Location reachedLocation in sprawl)
			{
				if (reachedLocation == target)
					break;
			}
			if (!sprawl.WasIterated(target))
				return new PlayResult(PlayError.NoWay);

			Location[] path = sprawl.Path(target);
			foreach (Location step in path)
			{
				if (sprawl.Distance(step).NewTurn)
					return new PlayResult(PlayError.Incomplete); // has to be continued next turn
				if (!IsTerrainResistant && Location.OneTurnHostileDamage == 0 && step.OneTurnHostileDamage > 0)
				{ // recover before passing hostile terrain?
					int damageToNextNonHostileLocation = sprawl.DamageToNextNonHostileLocation(Location, target);
					if (damageToNextNonHostileLocation >= 100)
						return new PlayResult(PlayError.NoWay);
					else if (Location.OneTurnHostileDamage == 0 && Health <= damageToNextNonHostileLocation)
						return new PlayResult(PlayError.RecoverFirst);
				}

				PlayResult result = Step__Turn(step);
				if (!result.OK || result.UnitRemoved || result.NewUnitOrCitySpotted)
					return result;
			}
			return PlayResult.Success;
		}

		/// <summary>
		/// Move unit to neighbor location.
		/// Causes loading to transport if:
		/// (1) unit is ground unit and target location is water and has transport present
		/// (2) unit is aircraft and target location has carrier present
		/// </summary>
		/// <param name="target">location to move to, must be neighbor of current location</param>
		/// <returns>result of operation</returns>
		public PlayResult Step__Turn(Location target)
		{
			if (!target.IsValid)
				return new PlayResult(PlayError.InvalidLocation);
			RC targetRC = target - Location;
			if (targetRC.Distance > 3)
				return new PlayResult(PlayError.RulesViolation);

			OtherLocation[] newObservations = null;
			if (model.HasExtendedObservationRange || target.ProvidesExtendedObservationRange)
				newObservations = target.Distance5Area;
			else
				newObservations = target.Neighbors;
			for (int i = 0; i < newObservations.Length; i++)
			{
				if (newObservations[i].Location.IsObserved)
					newObservations[i] = new OtherLocation(new Location(theEmpire, -1), new RC(0, 0)); // not a new observation, make invalid
			}
			bool foreignCityChangePossible = false;
			foreach (OtherLocation observation in newObservations)
			{
				if (observation.Location.IsValid)
					foreignCityChangePossible |= observation.Location.HasForeignCity;
			}

			int moveCommand = Protocol.sMoveUnit + (((targetRC.a - targetRC.b) & 7) << 4) + (((targetRC.a + targetRC.b) & 7) << 7);
			List<City> citiesChanged = null;
			if (Load > 0)
			{
				if ((!target.HasForeignUnit && target.MayCauseUnrest != Location.MayCauseUnrest) || // crossing border changing unrest
					theEmpire.TestPlay(moveCommand, indexInSharedMemory).UnitRemoved) // transport will die
				{ // reports of all home cities of transported units will become invalid
					citiesChanged = new List<City>();
					foreach (Unit unit in theEmpire.Units)
					{
						if (unit.Transport == this && unit.Home != null && !citiesChanged.Contains(unit.Home))
							citiesChanged.Add(unit.Home);
					}
				}
			}
			bool targetHadForeignCityBefore = target.HasForeignCity;
			bool causedUnrestBefore = CausesUnrest;
			PlayResult result = theEmpire.Play(moveCommand, indexInSharedMemory);
			if (result.Effective)
			{
				AEmpire.UpdateArea updateArea = AEmpire.UpdateArea.Basic;

				foreach (OtherLocation observation in newObservations)
				{
					if (observation.Location.IsValid)
						foreignCityChangePossible |= observation.Location.HasForeignCity;
				}
				if (foreignCityChangePossible)
					updateArea |= AEmpire.UpdateArea.ForeignCities;

				if (result.UnitRemoved)
					updateArea |= AEmpire.UpdateArea.Units;
				if (targetHadForeignCityBefore && !target.HasForeignCity)
				{
					updateArea |= AEmpire.UpdateArea.ForeignCities; // foreign city destroyed or captured
					if (target.HasOwnCity)
						updateArea |= AEmpire.UpdateArea.Cities; // captured, new own city
				}
				if (updateArea != AEmpire.UpdateArea.Basic)
					theEmpire.UpdateLists(updateArea);
				if (Home != null && (!Exists || CausesUnrest != causedUnrestBefore))
					Home.InvalidateReport();
				if (citiesChanged != null)
				{
					foreach (City city in citiesChanged)
						city.InvalidateReport();
				}

				if (theEmpire.HadEvent__Turn((EmpireEvent)Protocol.phStealTech)) // capture with temple of zeus
					theEmpire.StealAdvance();
			}
			return result;
		}

		/// <summary>
		/// Attack a unit. Moves along shortest possible path considering all known information.
		/// Only does the part of the move that is possible within this turn.
		/// If move has to be continued next turn the return value has the Error property Incomplete.
		/// Hostile terrain is considered to find a compromise between damage and reaching the target fast.
		/// </summary>
		/// <param name="target">unit to attack</param>
		/// <returns>result of operation</returns>
		public PlayResult Attack__Turn(Location target)
		{
			if (!target.IsValid)
				return new PlayResult(PlayError.InvalidLocation);
			PlayResult moved = MoveToNeighborOf__Turn(target);
			if (!moved.OK || moved.UnitRemoved || moved.NewUnitOrCitySpotted)
				return moved;
			else
				return Step__Turn(target);
		}

		/// <summary>
		/// Attack a unit. Moves along shortest possible path considering all known information.
		/// Only does the part of the move that is possible within this turn.
		/// If move has to be continued next turn the return value has the Error property Incomplete.
		/// Operation breaks even if it could be continued within the turn if a new foreign unit or city is spotted,
		/// in this case the result has the NewUnitOrCitySpotted property set.
		/// Hostile terrain is considered to find a compromise between damage and reaching the target fast.
		/// </summary>
		/// <param name="target">unit to attack</param>
		/// <returns>result of operation</returns>
		public PlayResult Attack__Turn(IUnitInfo unit)
		{
			return Attack__Turn(unit.Location);
		}

		/// <summary>
		/// Attack a city. If city is defended, attack defender. If city is undefended, capture (Ground) or bombard (Sea, Air) it.
		/// Moves along shortest possible path considering all known information.
		/// Only does the part of the move that is possible within this turn.
		/// If move has to be continued next turn the return value has the Error property Incomplete.
		/// Operation breaks even if it could be continued within the turn if a new foreign unit or city is spotted,
		/// in this case the result has the NewUnitOrCitySpotted property set.
		/// Hostile terrain is considered to find a compromise between damage and reaching the target fast.
		/// </summary>
		/// <param name="target">city to attack</param>
		/// <returns>result of operation</returns>
		public PlayResult Attack__Turn(ICity city)
		{
			return Attack__Turn(city.Location);
		}

		public PlayResult DoSpyMission__Turn(SpyMission mission, Location target)
		{
			if (!target.IsValid)
				return new PlayResult(PlayError.InvalidLocation);
			PlayResult result = theEmpire.Play(Protocol.sSetSpyMission + ((int)mission << 4));
			if (!result.OK)
				return result;
			else
			{
				result = MoveToNeighborOf__Turn(target);
				if (!result.OK || result.UnitRemoved || result.NewUnitOrCitySpotted)
					return result;
				else
					return Step__Turn(target);
			}
		}

		public PlayResult DoSpyMission__Turn(SpyMission mission, ICity city)
		{
			return DoSpyMission__Turn(mission, city.Location);
		}

		//bool MoveForecast__Turn(ToLoc; var RemainingMovement: integer)
		//{
		//    return true; // todo !!!
		//}

		//bool AttackForecast__Turn(ToLoc,AttackMovement; var RemainingHealth: integer)
		//{
		//    return true; // todo !!!
		//}

		//bool DefenseForecast__Turn(euix,ToLoc: integer; var RemainingHealth: integer)
		//{
		//    return true; // todo !!!
		//}

		/// <summary>
		/// Disband unit. If located in city producing a unit, utilize material.
		/// </summary>
		/// <returns>result of operation</returns>
		public PlayResult Disband__Turn()
		{
			City city = Location.OwnCity;

			List<City> citiesChanged = null;
			if (Load > 0)
			{
				citiesChanged = new List<City>();
				foreach (Unit unit in theEmpire.Units)
				{
					if (unit.Transport == this && unit.Home != null && !citiesChanged.Contains(unit.Home))
						citiesChanged.Add(unit.Home);
				}
			}

			PlayResult result = theEmpire.Play(Protocol.sRemoveUnit, indexInSharedMemory);
			if (result.OK)
			{
				theEmpire.UpdateLists(AEmpire.UpdateArea.Units);
				if (Home != null)
					Home.InvalidateReport();
				if (city != null)
					city.InvalidateReport(); // in case unit was utilized
				if (citiesChanged != null)
				{
					foreach (City city1 in citiesChanged)
						city1.InvalidateReport();
				}
			}
			return result;
		}

		/// <summary>
		/// start settler job
		/// </summary>
		/// <param name="job">the job to start</param>
		/// <returns>result of operation</returns>
		public PlayResult StartJob__Turn(Job job)
		{
			return theEmpire.Play(Protocol.sStartJob + ((int)job << 4), indexInSharedMemory);
		}

		/// <summary>
		/// set home of unit in city it's located in
		/// </summary>
		/// <returns>result of operation</returns>
		public PlayResult SetHomeHere__Turn()
		{
			City oldHome = Home;
			PlayResult result = theEmpire.Play(Protocol.sSetUnitHome, indexInSharedMemory);
			if (result.OK)
			{
				if (oldHome != null)
					oldHome.InvalidateReport();
				if (Home != null)
					Home.InvalidateReport();
			}
			return result;
		}

		/// <summary>
		/// load unit to transport at same location
		/// </summary>
		/// <returns>result of operation</returns>
		public PlayResult LoadToTransport__Turn()
		{
			return theEmpire.Play(Protocol.sLoadUnit, indexInSharedMemory);
		}

		/// <summary>
		/// unload unit from transport
		/// </summary>
		/// <returns>result of operation</returns>
		public PlayResult UnloadFromTransport__Turn()
		{
			return theEmpire.Play(Protocol.sUnloadUnit, indexInSharedMemory);
		}

		/// <summary>
		/// if this unit is a transport, select it as target for subsequent loading of units
		/// </summary>
		/// <returns></returns>
		public PlayResult SelectAsTransport__Turn()
		{
			return theEmpire.Play(Protocol.sSelectTransport, indexInSharedMemory);
		}

		/// <summary>
		/// add unit to the city it's located in
		/// </summary>
		/// <returns>result of operation</returns>
		public PlayResult AddToCity__Turn()
		{
			City city = Location.OwnCity;
			PlayResult result = theEmpire.Play(Protocol.sAddToCity, indexInSharedMemory);
			if (result.OK)
			{
				if (Home != null)
					Home.InvalidateReport();
				if (city != null)
					city.InvalidateReport();
			}
			return result;
		}
		#endregion

		#region template internal stuff
		int indexInSharedMemory = -1;
		int* address;

		/// <summary>
		/// INTERNAL - only access from CevoAILib classes!
		/// </summary>
		public int IndexInSharedMemory
		{
			get { return indexInSharedMemory; }
			set
			{
				if (value != indexInSharedMemory)
				{
					indexInSharedMemory = value;
					if (indexInSharedMemory >= 0)
						address = (int*)theEmpire.address[4] + ROReadPoint.SizeOfUn * indexInSharedMemory;
				}
			}
		}
		#endregion
	}

	unsafe struct MovingUnit : IUnitInfo
	{
		readonly AEmpire theEmpire;
		int[] showMoveData;

		public MovingUnit(AEmpire empire, int* data)
		{
			this.theEmpire = empire;
			showMoveData = new int[13];
			for (int i = 0; i < 13; i++)
				showMoveData[i] = data[i];
		}

		public override string ToString()
		{
			return Model.ToString();
		}

		#region IUnitInfo members
		public Nation Nation { get { return new Nation(theEmpire, showMoveData[0]); } }
		public ModelBase Model { get { return theEmpire.ForeignModels[showMoveData[3]]; } }
		public Location Location { get { return new Location(theEmpire, showMoveData[5]); } }
		public bool AreOtherUnitsPresent { get { return (showMoveData[4] & Protocol.unMulti) != 0; } }
		public bool IsLoaded { get { return false; } }
		public int Speed { get { return AUnit.UnitSpeed(this); } }
		public bool IsTerrainResistant { get { return Model.IsTerrainResistant || Nation.HasWonder(Building.HangingGardens); } }
		public int Experience { get { return showMoveData[11]; } }
		public int ExperienceLevel { get { return Experience / Cevo.ExperienceLevelCost; } }
		public int Health { get { return showMoveData[1]; } }
		public bool IsFortified { get { return (showMoveData[4] & Protocol.unFortified) != 0; } }
		public int Load { get { return showMoveData[12]; } }
		public int Fuel { get { return showMoveData[10]; } }
		public Job Job { get { return Job.None; } }
		#endregion
	}

	/// <summary>
	/// foreign unit, abstract base class
	/// </summary>
	struct ForeignUnit : IUnitInfo
	{
		readonly AEmpire theEmpire;
		readonly Location location;
		readonly ModelBase model;
		readonly int data2;
		readonly int data3;

		public ForeignUnit(AEmpire empire, Location location, ModelBase model, int data2, int data3)
		{
			this.theEmpire = empire;
			this.location = location;
			this.model = model;
			this.data2 = data2;
			this.data3 = data3;
		}

		public override string ToString()
		{
			return string.Format("{0}@{1}", model, location.ID);
		}

		#region IUnitInfo members
		public Nation Nation { get { return new Nation(theEmpire, data2 & 0xFF); } }
		public ModelBase Model { get { return model; } }
		public Location Location { get { return location; } }

		/// <summary>
		/// whether other units are present at the same location
		/// </summary>
		public bool AreOtherUnitsPresent { get { return (data3 & (Protocol.unMulti << 16)) != 0; } }

		/// <summary>
		/// alwas false, loaded foreign units are not in list
		/// </summary>
		public bool IsLoaded { get { return false; } }

		/// <summary>
		/// movement points this unit has per turn, considering damage and wonders
		/// </summary>
		public int Speed { get { return AUnit.UnitSpeed(this); } }

		/// <summary>
		/// whether this unit passes hostile terrain without damage
		/// </summary>
		public bool IsTerrainResistant { get { return model.IsTerrainResistant || Nation.HasWonder(Building.HangingGardens); } }

		/// <summary>
		/// Experience points collected.
		/// </summary>
		public int Experience { get { return data3 & 0xFF; } }

		/// <summary>
		/// Experience level as applied in combat. 0 = Green ... 4 = Elite.
		/// </summary>
		public int ExperienceLevel { get { return Experience / Cevo.ExperienceLevelCost; } }

		public int Health { get { return (sbyte)((data2 >> 8) & 0xFF); } }
		public bool IsFortified { get { return (data3 & (Protocol.unFortified << 16)) != 0; } }

		/// <summary>
		/// total number of units loaded to this unit
		/// </summary>
		public int Load { get { return (sbyte)((data3 >> 8) & 0xFF); } }

		/// <summary>
		/// Fuel remaining, not necessarily the same as Model.Fuel.
		/// </summary>
		public int Fuel { get { return (sbyte)((data2 >> 16) & 0xFF); } }

		/// <summary>
		/// settler job this unit is currently doing
		/// </summary>
		public Job Job { get { return (Job)((data2 >> 24) & 0xFF); } }
		#endregion
	}

	unsafe sealed class ForeignUnitList : IEnumerable<IUnitInfo>
	{
		readonly AEmpire theEmpire;
		readonly int* address;

		public ForeignUnitList(AEmpire empire)
		{
			theEmpire = empire;
			address = (int*)empire.address[7];
		}

		IUnitInfo this[int index]
		{
			get
			{
				return new ForeignUnit(
					theEmpire,
					new Location(theEmpire, address[ROReadPoint.SizeOfUnitInfo * index]),
					theEmpire.ForeignModels[(address[ROReadPoint.SizeOfUnitInfo * index + 1] >> 16) & 0xFFFF],
					address[ROReadPoint.SizeOfUnitInfo * index + 2],
					address[ROReadPoint.SizeOfUnitInfo * index + 3]);
			}
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public IUnitInfo UnitByLocation(Location location)
		{
			int index = -1;
			bool inRange = true;
			do
			{
				index++;
				inRange = (index < theEmpire.address[ROReadPoint.TestFlags + 10]);
			}
			while (inRange && address[ROReadPoint.SizeOfUnitInfo * index] != location.ID);
			if (inRange)
				return this[index];
			else
				return null;
		}

		#region IEnumerable members
		class Enumerator : IEnumerator<IUnitInfo>
		{
			ForeignUnitList list;
			int index;

			public Enumerator(ForeignUnitList list) { this.list = list; index = -1; }
			public void Reset() { index = -1; }
			public IUnitInfo Current { get { return list[index]; } }
			object System.Collections.IEnumerator.Current { get { return list[index]; } }
			public void Dispose() { }

			public bool MoveNext()
			{
				bool inRange = true;
				do
				{
					index++;
					inRange = (index < list.theEmpire.address[ROReadPoint.TestFlags + 10]);
				}
				while (inRange && list.address[ROReadPoint.SizeOfUnitInfo * index] < 0); // LID < 0 indicates gap in list
				return inRange;
			}
		}

		public IEnumerator<IUnitInfo> GetEnumerator() { return new Enumerator(this); }
		System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator() { return new Enumerator(this); }
		#endregion
	}
}
