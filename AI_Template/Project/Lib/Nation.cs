using System;
using System.Collections.Generic;
using Common;
using CevoAILib.Diplomacy;
using AI;

namespace CevoAILib
{
	enum Phase { BeginOfTurn, Turn, EndOfTurn, ForeignTurn };

	enum Relation { NoContact = 0, NoTreaty = 1, CeaseFire = 2, Peace = 3, FriendlyContact = 4, Alliance = 5, Identity = 6 }

	enum Attitude { Hostile = 0, Icy = 1, Uncooperative = 2, Neutral = 3, Receptive = 4, Cordial = 5, Enthusiastic = 6 }

	enum Government { Anarchy = 0, Despotism = 1, Monarchy = 2, Republic = 3, Fundamentalism = 4, Communism = 5, Democracy = 6, FutureSociety = 7 }

	enum EmpireEvent { ResearchComplete = 0, AnarchyOver = 3, GliderLost = 8, AircraftLost = 9, PeaceViolation = 10, PeaceEvacuation = 11 }

	enum Advance
	{
		None = -1, MilitaryResearch = 0x800,

		AdvancedFlight = 0, AmphibiousWarfare = 1, Astronomy = 2, AtomicTheory = 3, Automobile = 4,
		Ballistics = 5, Banking = 6, BridgeBuilding = 7, BronzeWorking = 8, CeremonialBurial = 9,
		Chemistry = 10, Chivalry = 11, Composites = 12, CodeOfLaws = 13, CombinedArms = 14,
		CombustionEngine = 15, Communism = 16, Computers = 17, Conscription = 18, Construction = 19,
		TheCorporation = 20, SpaceFlight = 21, Currency = 22, Democracy = 23, Economics = 24,
		Electricity = 25, Electronics = 26, Engineering = 27, Environmentalism = 28, TheWheel = 29,
		Explosives = 30, Flight = 31, Espionage = 32, Gunpowder = 33, HorsebackRiding = 34,
		ImpulseDrive = 35, Industrialization = 36, SmartWeapons = 37, Invention = 38, IronWorking = 39,
		TheLaser = 40, NuclearPower = 41, Literature = 42, TheInternet = 43, Magnetism = 44,
		MapMaking = 45, Masonry = 46, MassProduction = 47, Mathematics = 48, Medicine = 49,
		Metallurgy = 50, Miniaturization = 51, MobileWarfare = 52, Monarchy = 53, Mysticism = 54,
		Navigation = 55, NuclearFission = 56, Philosophy = 57, Physics = 58, Plastics = 59,
		Poetry = 60, Pottery = 61, Radio = 62, Recycling = 63, Refrigeration = 64,
		Monotheism = 65, TheRepublic = 66, Robotics = 67, Rocketry = 68, Railroad = 69,
		Sanitation = 70, Science = 71, Writing = 72, Seafaring = 73, SelfContainedEnvironment = 74,
		Stealth = 75, SteamEngine = 76, Steel = 77, SyntheticFood = 78, Tactics = 79,
		Theology = 80, TheoryOfGravity = 81, Trade = 82, TransstellarColonization = 83, University = 84,
		AdvancedRocketry = 85, WarriorCode = 86, Alphabet = 87, Polytheism = 88, Refining = 89,
		ComputingTechnology = 90, NanoTechnology = 91, MaterialTechnology = 92, ArtificialIntelligence = 93,

		FirstCommon = 0, LastCommon = 89, FirstFuture = 90, LastFuture = 93
	}

	struct Economy
	{
		public readonly int TaxRate;
		public readonly int Research;
		public readonly int Wealth;

		public Economy(int taxRate, int wealth)
		{
			this.TaxRate = taxRate;
			this.Wealth = wealth;
			this.Research = 100 - taxRate - wealth;
		}

		public override string ToString()
		{
			return string.Format("T{0} R{1} W{2}", TaxRate, Research, Wealth);
		}
	}

	struct ColonyShipParts
	{
		public readonly int ComponentCount;
		public readonly int PowerCount;
		public readonly int HabitationCount;
		public int this[Building part]
		{
			get
			{
				switch (part)
				{
					case Building.ColonyShipComponent: return ComponentCount;
					case Building.PowerModule: return PowerCount;
					case Building.HabitationModule: return HabitationCount;
					default: return 0;
				}
			}
		}

		public ColonyShipParts(int componentCount, int powerCount, int habitationCount)
		{
			this.ComponentCount = componentCount;
			this.PowerCount = powerCount;
			this.HabitationCount = habitationCount;
		}

		public override string ToString()
		{
			return string.Format("C{0} P{1} H{2}", ComponentCount, PowerCount, HabitationCount);
		}
	}

	unsafe struct Nation
	{
		public static Nation None { get { return new Nation(null, -1); } }

		readonly AEmpire theEmpire;
		public readonly int ID;

		public Nation(AEmpire empire, int id) // empire refers to the own empire, not the one of the nation
		{
			this.theEmpire = empire;
			this.ID = id;
		}

		public override string ToString()
		{
			return string.Format("{0}", ID);
		}

		public static bool operator ==(Nation nation1, Nation nation2) { return nation1.ID == nation2.ID; }
		public static bool operator !=(Nation nation1, Nation nation2) { return nation1.ID != nation2.ID; }
		public override bool Equals(object obj) { return ID == ((Nation)obj).ID; }
		public override int GetHashCode() { return ID; }

		int* report { get { return (int*)theEmpire.address[10 + ID]; } }

		/// <summary>
		/// whether this nation is still in the game
		/// </summary>
		public bool Subsists
		{
			get
			{
				if (ID < 0)
					return false;
				else
					return (theEmpire.address[ROReadPoint.TestFlags + 2] & (1 << ID)) != 0;
			}
		}

		/// <summary>
		/// whether this nation has a specific wonder in one of its cities AND this wonder's effect has not yet expired
		/// </summary>
		/// <param name="wonder">the wonder</param>
		/// <returns>true if nation has wonder and wonder is effective, false if it has not or wonder is expired</returns>
		public bool HasWonder(Building wonder)
		{
			if (ID < 0)
				return false;
			else
				return theEmpire.address[ROReadPoint.Wonder + 2 * (int)wonder + 1] == ID;
		}

		/// <summary>
		/// government form of this nation
		/// </summary>
		public Government Government
		{
			get
			{
				if (this == theEmpire.Us)
					return (Government)theEmpire.address[ROReadPoint.TestFlags + 13];
				else
					return (Government)report[5 + Protocol.nPl];
			}
		}

		/// <summary>
		/// credibility of this nation
		/// </summary>
		public int Credibility
		{
			get
			{
				if (this == theEmpire.Us)
					return theEmpire.address[ROReadPoint.TestFlags + 5];
				else
					return report[4];
			}
		}

		/// <summary>
		/// colony ship of this nation
		/// </summary>
		public ColonyShipParts ColonyShip
		{
			get
			{
				return new ColonyShipParts(theEmpire.address[ROReadPoint.Ship + 3 * ID],
					theEmpire.address[ROReadPoint.Ship + 3 * ID + 1],
					theEmpire.address[ROReadPoint.Ship + 3 * ID + 2]);
			}
		}
	}

	interface IDossier
	{
		int TurnOfReport { get; }
		int Treasury { get; }
		bool Has(Advance advance);
		bool HasAlmost(Advance advance);
		int FutureTechnology(Advance advance);
		Advance Researching { get; }
		int ResearchPile { get; }
		Relation RelationTo(Nation nation);
	}

	/// <summary>
	/// own empire, abstract base class
	/// </summary>
	unsafe abstract class AEmpire : IDossier
	{
		#region abstract
		protected abstract void NewGame();
		protected abstract void Resume();
		protected abstract void OnTurn();
		protected abstract void OnStealAdvance(Advance[] selection);
		protected abstract void OnForeignMove(IUnitInfo unit, Location destination);
		protected abstract void OnBeforeForeignCapture(Nation nation, ICity city);
		protected abstract void OnAfterForeignCapture();
		protected abstract void OnBeforeForeignAttack(IUnitInfo attacker, Location target, BattleOutcome outcome);
		protected abstract void OnAfterForeignAttack();
		protected abstract void OnChanceToNegotiate(Phase situation, Nation Opponent, ref bool wantNegotiation, ref bool cancelTreatyIfRejected);
		protected abstract void OnNegotiate(Negotiation negotiation);
		#endregion

		public readonly Nation Us;
		public readonly Map Map;
		public readonly ToughSet<Unit> Units = new ToughSet<Unit>();
		public readonly ForeignUnitList ForeignUnits;
		public readonly List<Model> Models = new List<Model>();
		public readonly List<ForeignModel> ForeignModels = new List<ForeignModel>();
		public readonly ToughSet<City> Cities = new ToughSet<City>();
		public readonly ToughSet<ForeignCity> ForeignCities = new ToughSet<ForeignCity>();

		/// <summary>
		/// Model blueprint for military research.
		/// </summary>
		public readonly Blueprint Blueprint;

		/// <summary>
		/// persistent memory
		/// </summary>
		public readonly Persistent Persistent;

		public AEmpire(int nationID, IntPtr serverPtr, IntPtr dataPtr, bool isNewGame)
		{
			int* data = (int*)dataPtr;
			serverCall = (ServerCall)System.Runtime.InteropServices.Marshal.GetDelegateForFunctionPointer(serverPtr, typeof(ServerCall));
			address = (int*)data[4 + Protocol.nPl + nationID];
			DifficultyLevel = data[4 + nationID];
			TurnWhenGameEnds = data[3];
			this.isNewGame = isNewGame;
			foreignTurnUpdateAreas = UpdateArea.All;

			Us = new Nation(this, nationID);
			Map = new Map(this, data[0], data[1], data[2]);
			ForeignUnits = new ForeignUnitList(this);
			Blueprint = new Blueprint((Empire)this);
			Persistent = new Persistent((Empire)this, (IntPtr)address[0]);
			debugMapAddress = (int*)address[ROReadPoint.OracleIncome + 1];

			UpdateLists(UpdateArea.All);
		}

		// for convenience, map all members of Us to empire
		public bool Subsists { get { return Us.Subsists; } }
		public Government Government { get { return Us.Government; } }
		public int Credibility { get { return Us.Credibility; } }
		public bool HasWonder(Building wonder) { return Us.HasWonder(wonder); }
		public ColonyShipParts ColonyShip { get { return Us.ColonyShip; } }

		#region IDossier members
		public int TurnOfReport { get { return Turn; } }
		public int Treasury { get { return address[ROReadPoint.TestFlags + 14]; } }

		/// <summary>
		/// whether an advance has been completely researched
		/// </summary>
		/// <param name="advance">the advance</param>
		/// <returns>true if researched, false if not</returns>
		public bool Has(Advance advance) { return ((sbyte*)(address + ROReadPoint.Tech))[(int)advance] >= 0; }

		/// <summary>
		/// whether an advance was gained from a trade with another nation or from the temple of zeus wonder
		/// </summary>
		/// <param name="advance">the advance</param>
		/// <returns>true if gained, false if not</returns>
		public bool HasAlmost(Advance advance) { return ((sbyte*)(address + ROReadPoint.Tech))[(int)advance] == -1; }

		/// <summary>
		/// science points collected for current research
		/// </summary>
		public int ResearchPile { get { return address[ROReadPoint.TestFlags + 17]; } }

		/// <summary>
		/// advance currently researched
		/// </summary>
		public Advance Researching
		{
			get
			{
				int ad = address[ROReadPoint.TestFlags + 18];
				if (ad < 0)
					return Advance.None;
				else
					return (Advance)ad;
			}
		}

		/// <summary>
		/// relation to specific other nation
		/// </summary>
		/// <param name="thirdNation">the other nation</param>
		/// <returns>the relation</returns>
		public Relation RelationTo(Nation nation)
		{
			if (nation == Us)
				return Relation.Identity;
			else
				return (Relation)(address[ROReadPoint.Attitude + Protocol.nPl + nation.ID] + 1);
		}

		/// <summary>
		/// number of future technologies developed
		/// </summary>
		/// <param name="advance">the future technology</param>
		/// <returns>number</returns>
		public int FutureTechnology(Advance advance)
		{
			sbyte raw = ((sbyte*)(address + ROReadPoint.Tech))[(int)advance];
			if (raw <= 0)
				return 0;
			else
				return raw;
		}
		#endregion

		public bool IsMyTurn { get { return phase != Phase.ForeignTurn; } }
		public int Turn { get { return address[ROReadPoint.TestFlags + 1]; } }

		/// <summary>
		/// whether a specific nation level event occurred in this turn 
		/// </summary>
		/// <param name="empireEvent">the event</param>
		/// <returns>true if the event occurred, false if not</returns>
		public bool HadEvent__Turn(EmpireEvent empireEvent) { return (address[ROReadPoint.TestFlags + 3] & (1 << (int)empireEvent)) != 0; }

		public readonly int DifficultyLevel;
		//bool IsManipulationActivated(Manipulation manipulation); todo !!!
		public readonly int TurnWhenGameEnds;
		public int TurnOfAnarchyBegin { get { return address[ROReadPoint.TestFlags + 4]; } }
		public int MaximumCredibilityLeft { get { return address[ROReadPoint.TestFlags + 6]; } }

		/// <summary>
		/// current economy settings, call ChangeEconomy__Turn to change
		/// </summary>
		public Economy Economy { get { return new Economy(address[ROReadPoint.TestFlags + 15], address[ROReadPoint.TestFlags + 16]); } }

		public int IncomeFromOracle { get { return address[ROReadPoint.OracleIncome]; } }
		public bool CanSetResearch__Turn(Advance advance) { return TestPlay(Protocol.sSetResearch, (int)advance).OK; }
		public RelationDetails RelationDetailsTo(Nation nation) { return new RelationDetails(this, nation); }
		public BattleHistory BattleHistory { get { return new BattleHistory(this); } }

		/// <summary>
		/// number of nations that are still in the game
		/// </summary>
		public int NumberOfSubsistingNations
		{
			get
			{
				int aliveArray = address[ROReadPoint.TestFlags + 2];
				int count = 0;
				for (int nationID = 0; nationID < Protocol.nPl; nationID++)
				{
					if ((aliveArray & (1 << nationID)) != 0)
						count++;
				}
				return count;
			}
		}

		/// <summary>
		/// set of nations that are still in the game
		/// </summary>
		public Nation[] SubsistingNations
		{
			get
			{
				Nation[] subsistingNations = new Nation[NumberOfSubsistingNations];
				int aliveArray = address[ROReadPoint.TestFlags + 2];
				int count = 0;
				for (int nationID = 0; nationID < Protocol.nPl; nationID++)
				{
					if ((aliveArray & (1 << nationID)) != 0)
					{
						subsistingNations[count] = new Nation(this, nationID);
						count++;
					}
				}
				return subsistingNations;
			}
		}

		/// <summary>
		/// science points to collect before the current research is complete
		/// </summary>
		public int CurrentResearchCost
		{
			get
			{
				fixed (int* researchCost = new int[1])
				{
					Play(Protocol.sGetTechCost, 0, researchCost);
					return researchCost[0];
				}
			}
		}

		/// <summary>
		/// Whether a specific building is built in one of the own cities.
		/// Applicable to wonders and state improvements.
		/// In case of wonders true is only returned if this wonder's effect has not yet expired.
		/// </summary>
		/// <param name="wonder">the wonder</param>
		/// <returns>true if built and effective, false if not</returns>
		public bool Has(Building building)
		{
			if (building < Building.WonderRange)
				return Us.HasWonder(building);
			else
				return ((sbyte*)(address + ROReadPoint.NatBuilt))[(int)building - (int)Building.WonderRange] > 0;
		}

		public bool Wonder_WasBuilt(Building wonder) { return address[ROReadPoint.Wonder + 2 * (int)wonder] != -1; }
		public bool Wonder_WasDestroyed(Building wonder) { return address[ROReadPoint.Wonder + 2 * (int)wonder] == -2; }
		public bool Wonder_IsInCity(Building wonder, ICity city) { return address[ROReadPoint.Wonder + 2 * (int)wonder] == city.ID; }

		public Dossier LastDossier(Nation nation) { return new Dossier(this, nation); }
		public MilitaryReport LastMilitaryReport(Nation nation) { return new MilitaryReport(this, nation); }

		#region effective methods
		/// <summary>
		/// Start revolution.
		/// </summary>
		/// <returns>result of operation</returns>
		public PlayResult Revolution__Turn() 
		{ 
			PlayResult result = Play(Protocol.sRevolution);
			if (result.OK)
				InvalidateAllCityReports();
			return result;
		}

		/// <summary>
		/// Set government form. Requires AnarchyOver event to have occurred this turn.
		/// </summary>
		/// <param name="newGovernment">new government form</param>
		/// <returns>result of operation</returns>
		public PlayResult SetGovernment__Turn(Government newGovernment) 
		{
			PlayResult result = Play(Protocol.sSetGovernment, (int)newGovernment);
			if (result.Effective)
				InvalidateAllCityReports();
			return result;
		}

		/// <summary>
		/// Change economy settings.
		/// </summary>
		/// <param name="economy">new economy settings</param>
		/// <returns>result of operation</returns>
		public PlayResult ChangeEconomy__Turn(Economy economy) 
		{
			PlayResult result = Play(Protocol.sSetRates, (economy.TaxRate / 10 & 0xf) + ((economy.Wealth / 10 & 0xf) << 4));
			if (result.Effective)
				InvalidateAllCityReports();
			return result;
		}

		/// <summary>
		/// Set new advance to research. Requires ResearchComplete event to have occurred this turn.
		/// If advance is MilitaryResearch Blueprint must have been designed as desired already.
		/// </summary>
		/// <param name="advance">advance to research</param>
		/// <returns>result of operation</returns>
		public PlayResult SetResearch__Turn(Advance advance) { return Play(Protocol.sSetResearch, (int)advance); }

		/// <summary>
		/// Steal advance as offered by the temple of zeus wonder.
		/// Call from OnStealAdvance handler only.
		/// </summary>
		/// <param name="advance">the advance to steal</param>
		/// <returns>result of operation</returns>
		public PlayResult StealAdvance__Turn(Advance advance) { return Play(Protocol.sStealTech, (int)advance); }

		/// <summary>
		/// change attitude to other nation
		/// </summary>
		/// <param name="nation">the nation</param>
		/// <param name="attitude">the attitude</param>
		/// <returns>result of operation</returns>
		public PlayResult ChangeAttitudeTo(Nation nation, Attitude attitude) { return Play(Protocol.sSetAttitude + (nation.ID << 4), (int)attitude); }
		#endregion

		#region template internal stuff
		[System.Runtime.InteropServices.UnmanagedFunctionPointer(System.Runtime.InteropServices.CallingConvention.StdCall)]
		delegate int ServerCall(int command, int nation, int subject, void* data);

		readonly ServerCall serverCall;
		readonly bool isNewGame;

		/// <summary>
		/// INTERNAL - only access from CevoAILib classes!
		/// </summary>
		public readonly int* address;

		/// <summary>
		/// INTERNAL - only access from CevoAILib classes!
		/// </summary>
		public readonly int* debugMapAddress;

		/// <summary>
		/// INTERNAL - only access from CevoAILib classes!
		/// </summary>
		public readonly Unit[] UnitLookup = new Unit[Cevo.MaxUnitsPerNation];

		/// <summary>
		/// INTERNAL - only access from CevoAILib classes!
		/// </summary>
		public readonly City[] CityLookup = new City[Cevo.MaxCitiesPerNation];

		readonly byte[] foreignCityLookup = new byte[Cevo.MaxCitiesPerNation * Cevo.MaxNumberOfNations];
		bool called = false;
		Phase phase = Phase.ForeignTurn;
		bool foreignMoveSkipped;
		bool foreignMoveIsCapture;
		UpdateArea foreignTurnUpdateAreas;

		// diplomacy
		Nation possibleNegotiationWith = Nation.None;
		bool cancelTreatyIfRejected = false;
		List<Nation> nationsContacted = new List<Nation>();
		List<Nation> nationsNotToContact = new List<Nation>();
		Negotiation currentNegotiation = null;

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public void StealAdvance()
		{
			List<Advance> stealable = new List<Advance>();
			for (Advance testAdvance = Advance.FirstCommon; testAdvance <= Advance.LastCommon; testAdvance++)
			{
				if (TestPlay(Protocol.sStealTech, (int)testAdvance).OK)
					stealable.Add(testAdvance);
			}
			if (stealable.Count > 0)
				OnStealAdvance(stealable.ToArray());
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public PlayResult Play(int command, int subject, void* data)
		{
			return new PlayResult(serverCall(command, Us.ID, subject, data));
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public PlayResult Play(int command, int subject, int data)
		{
			fixed (int* dataPtr = new int[1])
			{
				dataPtr[0] = data;
				return new PlayResult(serverCall(command, Us.ID, subject, dataPtr));
			}
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public PlayResult Play(int command, int subject)
		{
			return new PlayResult(serverCall(command, Us.ID, subject, null));
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public PlayResult Play(int command)
		{
			return new PlayResult(serverCall(command, Us.ID, 0, null));
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public PlayResult TestPlay(int command, int subject, void* data)
		{
			return new PlayResult(serverCall(command - Protocol.sExecute, Us.ID, subject, data));
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public PlayResult TestPlay(int command, int subject, int data)
		{
			fixed (int* dataPtr = new int[1])
			{
				dataPtr[0] = data;
				return new PlayResult(serverCall(command - Protocol.sExecute, Us.ID, subject, dataPtr));
			}
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public PlayResult TestPlay(int command, int subject)
		{
			return new PlayResult(serverCall(command - Protocol.sExecute, Us.ID, subject, null));
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public PlayResult TestPlay(int command)
		{
			return new PlayResult(serverCall(command - Protocol.sExecute, Us.ID, 0, null));
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public void InvalidateAllCityReports() { foreach (City city in Cities) city.InvalidateReport(); }

		[Flags]
		public enum UpdateArea { Basic = 0x00, Units = 0x01, Cities = 0x02, ForeignCities = 0x08, All = 0xFF }

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// update the lists Models and ForeignModels
		/// and to correct the lists Units, Cities and ForeignCities
		/// this includes address correction of objects, adding objects for new items, 
		/// removing objects of destroyed items and marking these objects
		/// </summary>
		public void UpdateLists(UpdateArea areas)
		{
			// models
			int* sharedMemoryList = (int*)address[6];
			int sharedMemoryCount = address[ROReadPoint.TestFlags + 9];
			for (int indexInSharedMemory = Models.Count; indexInSharedMemory < sharedMemoryCount; indexInSharedMemory++)
				Models.Add(new Model((Empire)this, indexInSharedMemory));

			// foreign models
			sharedMemoryList = (int*)address[9];
			sharedMemoryCount = address[ROReadPoint.TestFlags + 12];
			for (int indexInSharedMemory = ForeignModels.Count; indexInSharedMemory < sharedMemoryCount; indexInSharedMemory++)
				ForeignModels.Add(new ForeignModel((Empire)this, indexInSharedMemory));

			// cities
#if DEBUG
			bool doCities = true;
#else
			bool doCities = (areas & UpdateArea.Cities) != 0;
#endif
			if (doCities)
			{
				sharedMemoryList = (int*)address[5];
				sharedMemoryCount = address[ROReadPoint.TestFlags + 8];
				Array.Clear(CityLookup, 0, sharedMemoryCount);
				foreach (City city in Cities)
				{
					int indexInSharedMemory = city.IndexInSharedMemory; // items do only move backward in shared memory
					int originalIndex = indexInSharedMemory;
					while (indexInSharedMemory >= 0 &&
						(indexInSharedMemory >= sharedMemoryCount || // index beyond bounds
						(sharedMemoryList[ROReadPoint.SizeOfCity * indexInSharedMemory + 3] & 0xFFFF) != city.ID || // not the right city
						sharedMemoryList[ROReadPoint.SizeOfCity * indexInSharedMemory] < 0)) // LID < 0 indicates gap in list
						indexInSharedMemory--;
					if (indexInSharedMemory < 0)
					{ // city was captured or destroyd, remove
						if ((areas & UpdateArea.Cities) == 0) // debug check fails
							throw new Exception("UpdateLists: City removal is not updated!");
						city.IndexInSharedMemory = -1;
						Cities.RemoveCurrent();
					}
					else
					{ // city still exists, correct shared memory index
						if (indexInSharedMemory != originalIndex)
						{
							if ((areas & UpdateArea.Cities) == 0) // debug check fails
								throw new Exception("UpdateLists: City index change is not updated!");
							city.IndexInSharedMemory = indexInSharedMemory;
						}
						CityLookup[indexInSharedMemory] = city;
					}
				}
				for (int indexInSharedMemory = 0; indexInSharedMemory < sharedMemoryCount; indexInSharedMemory++)
				{
					if (CityLookup[indexInSharedMemory] == null &&
						sharedMemoryList[ROReadPoint.SizeOfCity * indexInSharedMemory] >= 0) // LID < 0 indicates gap in list
					{ // shared memory object not in list
						if ((areas & UpdateArea.Cities) == 0) // debug check fails
							throw new Exception("UpdateLists: City creation is not updated!");
						City city = new City((Empire)this, indexInSharedMemory);
						Cities.Add(city);
						CityLookup[indexInSharedMemory] = city;
					}
				}
			}

			// foreign cities
#if DEBUG
			bool doForeignCities = true;
#else
			bool doForeignCities = (areas & UpdateArea.ForeignCities) != 0;
#endif
			if (doForeignCities)
			{
				sharedMemoryList = (int*)address[8];
				sharedMemoryCount = address[ROReadPoint.TestFlags + 11];
				Array.Clear(foreignCityLookup, 0, sharedMemoryCount);
				foreach (ForeignCity city in ForeignCities)
				{
					int indexInSharedMemory = city.IndexInSharedMemory; // items do only move backward in shared memory
					int originalIndex = indexInSharedMemory;
					while (indexInSharedMemory >= 0 &&
						(indexInSharedMemory >= sharedMemoryCount || // index beyond bounds
						((sharedMemoryList[ROReadPoint.SizeOfCityInfo * indexInSharedMemory + 3] >> 16) & 0xFFFF) != city.ID || // not the right city
						sharedMemoryList[ROReadPoint.SizeOfCityInfo * indexInSharedMemory] < 0)) // LID < 0 indicates gap in list
						indexInSharedMemory--;
					if (indexInSharedMemory < 0)
					{ // city was captured or destroyd, remove
						if ((areas & UpdateArea.ForeignCities) == 0) // debug check fails
							throw new Exception("UpdateLists: Foreign city removal is not updated!");
						city.IndexInSharedMemory = -1;
						ForeignCities.RemoveCurrent();
					}
					else
					{ // city still exists, correct shared memory index
						if (indexInSharedMemory != originalIndex)
						{
							if ((areas & UpdateArea.ForeignCities) == 0) // debug check fails
								throw new Exception("UpdateLists: Foreign city index change is not updated!");
							city.IndexInSharedMemory = indexInSharedMemory;
						}
						foreignCityLookup[indexInSharedMemory] = 1;
					}
				}
				for (int indexInSharedMemory = 0; indexInSharedMemory < sharedMemoryCount; indexInSharedMemory++)
				{
					if (foreignCityLookup[indexInSharedMemory] == 0 &&
						sharedMemoryList[ROReadPoint.SizeOfCityInfo * indexInSharedMemory] >= 0) // LID < 0 indicates gap in list
					{
						if ((areas & UpdateArea.ForeignCities) == 0) // debug check fails
							throw new Exception("UpdateLists: Foreign city creation is not updated!");
						ForeignCities.Add(new ForeignCity((Empire)this, indexInSharedMemory));
					}
				}
			}

			// units
#if DEBUG
			bool doUnits = true;
#else
			bool doUnits = (areas & UpdateArea.Units) != 0;
#endif
			if (doUnits)
			{
				sharedMemoryList = (int*)address[4];
				sharedMemoryCount = address[ROReadPoint.TestFlags + 7];
				Array.Clear(UnitLookup, 0, sharedMemoryCount);
				foreach (Unit unit in Units)
				{
					int indexInSharedMemory = unit.IndexInSharedMemory; // items do only move backward in shared memory
					int originalIndex = indexInSharedMemory;
					while (indexInSharedMemory >= 0 &&
						(indexInSharedMemory >= sharedMemoryCount || // index beyond bounds
						(sharedMemoryList[ROReadPoint.SizeOfUn * indexInSharedMemory + 3] & 0xFFFF) != unit.ID || // not the right unit
						sharedMemoryList[ROReadPoint.SizeOfUn * indexInSharedMemory] < 0)) // LID < 0 indicates gap in list
						indexInSharedMemory--;
					if (indexInSharedMemory < 0)
					{ // unit was destroyd, remove
						if ((areas & UpdateArea.Units) == 0) // debug check fails
							throw new Exception("UpdateLists: Unit removal is not updated!");
						unit.IndexInSharedMemory = -1;
						Units.RemoveCurrent();
					}
					else
					{ // unit still exists, correct shared memory index
						if (indexInSharedMemory != originalIndex)
						{
							if ((areas & UpdateArea.Units) == 0) // debug check fails
								throw new Exception("UpdateLists: Unit index change is not updated!");
							unit.IndexInSharedMemory = indexInSharedMemory;
						}
						UnitLookup[indexInSharedMemory] = unit;
					}
				}
				for (int indexInSharedMemory = 0; indexInSharedMemory < sharedMemoryCount; indexInSharedMemory++)
				{
					if (UnitLookup[indexInSharedMemory] == null &&
						sharedMemoryList[ROReadPoint.SizeOfUn * indexInSharedMemory] >= 0) // LID < 0 indicates gap in list
					{ // shared memory object not in list
						if ((areas & UpdateArea.Units) == 0) // debug check fails
							throw new Exception("UpdateLists: Unit creation is not updated!");
						Unit unit = new Unit((Empire)this, indexInSharedMemory);
						Units.Add(unit);
						UnitLookup[indexInSharedMemory] = unit;
					}
				}
			}
		}

		// internal
		void ForeignTurnUpdate()
		{
			UpdateLists(foreignTurnUpdateAreas);
			foreignTurnUpdateAreas = UpdateArea.Basic;
		}

		/// <summary>
		/// INTERNAL - only call from Plugin class!
		/// </summary>
		public void Process(int command, IntPtr dataPtr)
		{
			if (!called)
			{
				UpdateLists(UpdateArea.All);
				if (isNewGame)
					NewGame();
				else
					Resume();
			}
			called = true;

			int* data = (int*)dataPtr;
			switch (command)
			{
				case Protocol.cTurn:
				case Protocol.cContinue:
					{
						if (!Subsists)
						{
							Play(Protocol.sTurn);
							return;
						}

						if (command == Protocol.cTurn)
						{
							phase = Phase.BeginOfTurn;
							nationsContacted.Clear();
							if (Researching != Advance.MilitaryResearch)
								Play(Protocol.sCreateDevModel, (int)ModelDomain.Ground); // keep blueprint current
							UpdateLists(UpdateArea.All);
						}
						if (command == Protocol.cContinue && possibleNegotiationWith != Nation.None)
						{ // that means a negotiation attempt was made but rejected
							if (cancelTreatyIfRejected && RelationTo(possibleNegotiationWith) >= Relation.Peace)
								Play(Protocol.sCancelTreaty);
						}
						else
							nationsNotToContact.Clear();
						currentNegotiation = null;
						possibleNegotiationWith = Nation.None;
						cancelTreatyIfRejected = false;

						InvalidateAllCityReports(); // turn begin and after negotiation

						while (true)
						{
							if (Government != Government.Anarchy)
							{
								foreach (Nation nation in SubsistingNations)
								{
									if (nation != Us &&
										RelationTo(nation) != Relation.NoContact &&
										nation.Government != Government.Anarchy &&
										!(nationsContacted.Contains(nation)) &&
										!(nationsNotToContact.Contains(nation)) &&
										TestPlay(Protocol.scContact + (nation.ID << 4)).OK)
									{
										bool wantNegotiation = false;
										cancelTreatyIfRejected = false;
										OnChanceToNegotiate(phase, nation, ref wantNegotiation, ref cancelTreatyIfRejected);
										if (wantNegotiation)
										{
											nationsContacted.Add(nation);
											possibleNegotiationWith = nation;
											Play(Protocol.scContact + (nation.ID << 4));
											return;
										}
										else
											nationsNotToContact.Add(nation);
									}
								}
							}
							if (phase == Phase.BeginOfTurn)
							{
								phase = Phase.Turn;
								OnTurn();
								phase = Phase.EndOfTurn;
								nationsContacted.Clear();
								nationsNotToContact.Clear();
							}
							else
								break;
						}

#if DEBUG
						UpdateLists(UpdateArea.Basic); // check for list update problems
#endif

						foreignTurnUpdateAreas = UpdateArea.Units; // units might be disbanded in after-turn processing
						phase = Phase.ForeignTurn;
						Play(Protocol.sTurn);
						break;
					}

				case Protocol.scContact:
					{
						if (phase != Phase.ForeignTurn)
							throw new Exception("Error in logic: scDipStart should not be called in own turn!");
						ForeignTurnUpdate();
						possibleNegotiationWith = new Nation(this, data[0]);
						bool wantNegotiation = false;
						bool dummy = false;
						OnChanceToNegotiate(phase, possibleNegotiationWith, ref wantNegotiation, ref dummy);
						if (wantNegotiation)
							Play(Protocol.scDipStart);
						else
							Play(Protocol.scReject);
						break;
					}

				case Protocol.scDipStart:
				case Protocol.scDipNotice:
				case Protocol.scDipAccept:
				case Protocol.scDipCancelTreaty:
				case Protocol.scDipOffer:
				case Protocol.scDipBreak:
					{
						if (currentNegotiation == null)
							currentNegotiation = new Negotiation(this, phase, possibleNegotiationWith);
						possibleNegotiationWith = Nation.None;
						cancelTreatyIfRejected = false;

						if (command == Protocol.scDipStart) // no statements yet in this negotiation
						{
							if (phase == Phase.ForeignTurn)
								throw new Exception("Error in logic: scDipStart should only be called in own turn!");
							currentNegotiation.SetOurNextStatement(new SuggestEnd());
						}
						else
						{
							bool afterTrade = (command == Protocol.scDipAccept || // opponent accepted our suggested trade
								(currentNegotiation.History.Count > 0 && currentNegotiation.OurNextStatement is AcceptTrade)); // we accepted opponent suggested trade
							if (phase == Phase.ForeignTurn)
							{
								if (afterTrade)
									foreignTurnUpdateAreas |= UpdateArea.ForeignCities; // in case map was traded
								ForeignTurnUpdate();
							}
							else
							{
								if (afterTrade)
									UpdateLists(UpdateArea.ForeignCities); // in case map was traded
							}

							IStatement oppenentStatement = StatementFactory.OpponentStatementFromCommand(this, currentNegotiation.Opponent, command, data);
							if (currentNegotiation.History.Count == 0 && phase == Phase.ForeignTurn)
								currentNegotiation.History.Insert(0, new ExchangeOfStatements(new SuggestEnd() /*imaginary, has not happened*/, oppenentStatement));
							else
								currentNegotiation.History.Insert(0, new ExchangeOfStatements(currentNegotiation.OurNextStatement, oppenentStatement));
							if (oppenentStatement is CancelTreaty || oppenentStatement is Break)
								currentNegotiation.SetOurNextStatement(new Notice()); // initialize with standard response
							else
								currentNegotiation.SetOurNextStatement(new SuggestEnd()); // initialize with standard response
						}

						OnNegotiate(currentNegotiation);

						if (currentNegotiation.OurNextStatement is SuggestTrade)
						{
							fixed (int* tradeData = new int[14])
							{
								((SuggestTrade)currentNegotiation.OurNextStatement).FillRawStream(tradeData);
								Play(currentNegotiation.OurNextStatement.Command, 0, tradeData);
							}
						}
						else
							Play(currentNegotiation.OurNextStatement.Command);
						break;
					}

				case Protocol.cShowEndContact: { currentNegotiation = null; break; }

				case Protocol.cShowMoving:
				case Protocol.cShowCapturing:
					{
						if (phase != Phase.ForeignTurn)
							throw new Exception("Error in logic: cShowMoving should not be called in own turn!");
						foreignMoveIsCapture = (command == Protocol.cShowCapturing);
						Relation relationToMovingNation = (Relation)(address[ROReadPoint.Attitude + Protocol.nPl + data[0]] + 1);
						foreignMoveSkipped = !foreignMoveIsCapture && relationToMovingNation == Relation.Alliance; 
							// allied movement: low relevance, high frequency, so skip
						if (foreignMoveSkipped)
							foreignTurnUpdateAreas |= UpdateArea.ForeignCities; // allies movement might gain new city information
						else
						{
							ForeignTurnUpdate();
							MovingUnit unit = new MovingUnit(this, data);
							RC test = new RC((data[6] + data[7]) >> 1, (data[7] - data[6]) >> 1);
							Location target = unit.Location + new RC((data[6] + data[7]) >> 1, (data[7] - data[6]) >> 1);
							OnForeignMove(unit, target);
							if (foreignMoveIsCapture)
								OnBeforeForeignCapture(unit.Nation, target.City);
						}
						break;
					}

				case Protocol.cShowAttacking:
					{
						if (phase != Phase.ForeignTurn)
							throw new Exception("Error in logic: cShowAttacking should not be called in own turn!");
						ForeignTurnUpdate();
						MovingUnit unit = new MovingUnit(this, data);
						Location target = unit.Location + new RC((data[6] + data[7]) >> 1, (data[7] - data[6]) >> 1);
						OnBeforeForeignAttack(unit, target, new BattleOutcome(data[8], data[9]));
						break;
					}

				case Protocol.cShowAfterMove:
					{
						if (phase != Phase.ForeignTurn)
							throw new Exception("Error in logic: cShowAfterMove should not be called in own turn!");
						if (foreignMoveIsCapture && !foreignMoveSkipped)
						{
							ForeignTurnUpdate();
							OnAfterForeignCapture(); // cShowCityChanged was already called here
						}
						break;
					}

				case Protocol.cShowAfterAttack:
					{
						if (phase != Phase.ForeignTurn)
							throw new Exception("Error in logic: cShowAfterAttack should not be called in own turn!");
						foreignTurnUpdateAreas |= UpdateArea.Units; // if city was destroyed by attack, cShowCityChanged was already called here
						ForeignTurnUpdate(); 
						OnAfterForeignAttack();
						break;
					}

				case Protocol.cShowCityChanged:
					{
						if (phase != Phase.ForeignTurn)
							throw new Exception("Error in logic: cShowCityChanged should not be called in own turn!");
						foreignTurnUpdateAreas |= UpdateArea.All; // not called very often, so full update doesn't hurt
						break;
					}
			}
		}
		#endregion
	}

	unsafe struct RelationDetails
	{
		readonly AEmpire theEmpire;
		readonly Nation nation;

		public RelationDetails(AEmpire empire, Nation nation)
		{
			this.theEmpire = empire;
			this.nation = nation;
		}

		int* report { get { return (int*)theEmpire.address[10 + nation.ID]; } }

		public Attitude OurAttitudeToThem { get { return (Attitude)theEmpire.address[ROReadPoint.Attitude + nation.ID]; } }
		public Attitude TheirAttitudeToUs { get { return (Attitude)report[4]; } }
		public int TurnOfLastNegotiation { get { return report[0]; } }
		public int TurnOfLastCancellingTreaty { get { return theEmpire.address[ROReadPoint.nBattleHistory + 3 + nation.ID]; } }
		public int TurnOfPeaceEvacuationBegin { get { return theEmpire.address[ROReadPoint.Attitude + 2 * Protocol.nPl + nation.ID]; } }
	}

	unsafe struct Dossier : IDossier
	{
		readonly AEmpire theEmpire;
		readonly Nation nation;

		public Dossier(AEmpire empire, Nation nation)
		{
			this.theEmpire = empire;
			this.nation = nation;
		}

		public override string ToString()
		{
			if (TurnOfReport >= 0)
				return string.Format("{0}", TurnOfReport);
			else
				return "NA";
		}

		public bool IsAvailable { get { return TurnOfReport >= 0; } }

		int* report { get { return (int*)theEmpire.address[10 + nation.ID]; } }

		public int TurnOfReport { get { return report[1]; } }
		public int Treasury { get { return report[6 + Protocol.nPl]; } }

		/// <summary>
		/// whether an advance has been completely researched
		/// </summary>
		/// <param name="advance">the advance</param>
		/// <returns>true if researched, false if not</returns>
		public bool Has(Advance advance) { return ((sbyte*)(report + 9 + Protocol.nPl))[(int)advance] >= 0; }

		/// <summary>
		/// whether an advance was gained from a trade with another nation or from the temple of zeus wonder
		/// </summary>
		/// <param name="advance">the advance</param>
		/// <returns>true if gained, false if not</returns>
		public bool HasAlmost(Advance advance) { return ((sbyte*)(report + 9 + Protocol.nPl))[(int)advance] == -1; }

		/// <summary>
		/// science points collected for current research
		/// </summary>
		public int ResearchPile { get { return report[8 + Protocol.nPl]; } }

		/// <summary>
		/// advance currently researched
		/// </summary>
		public Advance Researching
		{
			get
			{
				int ad = report[7 + Protocol.nPl];
				if (ad < 0)
					return Advance.None;
				else
					return (Advance)ad;
			}
		}

		/// <summary>
		/// relation to specific other nation
		/// </summary>
		/// <param name="thirdNation">the other nation</param>
		/// <returns>the relation</returns>
		public Relation RelationTo(Nation thirdNation)
		{
			if (thirdNation == nation)
				return Relation.Identity;
			else
				return (Relation)(report[5 + thirdNation.ID] + 1);
		}

		/// <summary>
		/// number of future technologies developed
		/// </summary>
		/// <param name="advance">the future technology</param>
		/// <returns>number</returns>
		public int FutureTechnology(Advance advance)
		{
			sbyte raw = ((sbyte*)(report + 9 + Protocol.nPl))[(int)advance];
			if (raw <= 0)
				return 0;
			else
				return raw;
		}
	}

	unsafe struct MilitaryReport
	{
		readonly AEmpire theEmpire;
		readonly Nation nation;

		public MilitaryReport(AEmpire empire, Nation nation)
		{
			this.theEmpire = empire;
			this.nation = nation;
		}

		public override string ToString()
		{
			if (TurnOfReport >= 0)
				return string.Format("{0}", TurnOfReport);
			else
				return "NA";
		}

		public bool IsAvailable { get { return TurnOfReport >= 0; } }

		int* report { get { return (int*)theEmpire.address[10 + nation.ID]; } }

		public int TurnOfReport { get { return report[2]; } }

		// todo !!!
	}

	unsafe struct BattleHistory
	{
		readonly AEmpire theEmpire;

		public BattleHistory(AEmpire empire)
		{
			theEmpire = empire;
		}

		// todo !!!
	}
}
