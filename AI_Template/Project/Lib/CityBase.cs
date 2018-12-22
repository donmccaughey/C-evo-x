using System;
using System.Collections.Generic;
using AI;

namespace CevoAILib
{
	enum Building
	{
		None = 28,

		Pyramids = 0, TempleOfZeus = 1, HangingGardens = 2, Colossus = 3, Lighthouse = 4,
		GreatLibrary = 5, Oracle = 6, SunTsusWarAcademy = 7, LeonardosWorkshop = 8, MagellansExpedition = 9,
		MichelangelosChapel = 10, NewtonsCollege = 12, BachsCathedral = 13,
		StatueOfLiberty = 15, EiffelTower = 16, HooverDam = 17, ShinkansenExpress = 18, ManhattanProject = 19,
		MIRSpaceStation = 20,
		WonderRange = 28, // for logic only, < WonderRange means wonder (better use Cevo.Pedia(Building).Kind)

		Barracks = 29, Granary = 30, Temple = 31, Marketplace = 32, Library = 33, Courthouse = 34,
		CityWalls = 35, Aqueduct = 36, Bank = 37, Cathedral = 38, University = 39,
		Harbor = 40, Theater = 41, Factory = 42, MfgPlant = 43, RecyclingCenter = 44,
		PowerStation = 45, HydroelectricDam = 46, NuclearPlant = 47, OffshorePlatform = 48, TownHall = 49,
		SewerSystem = 50, Supermarket = 51, Superhighways = 52, ResearchLab = 53, SAM = 54,
		CoastalFortress = 55, Airport = 56, Dockyard = 57,

		Palace = 58, GreatWall = 59, Colosseum = 60, Observatory = 61, MilitaryAcademy = 62,
		CommandBunker = 63, AlgaePlant = 64, StockExchange = 65, SpacePort = 66,

		ColonyShipComponent = 67, PowerModule = 68, HabitationModule = 69,
	}

	enum CityEvent
	{
		CivilDisorder = 0, ProductionComplete = 1, PopulationGrowth = 2, PopulationDecrease = 3, UnitDisbanded = 4,
		ImprovementSold = 5, ProductionSabotaged = 6, MaximumSizeReached = 7, Pollution = 8, CityUnderSiege = 9,
		WonderAlreadyExists = 10, EmigrationDelayed = 11, CityFounded = 12, TakeoverComplete = 13
	}

	//enum ExploitableLocationStatus { Available = 0, ExploitedByOtherCity = 1, Siege = 2, DisallowedByTreaty = 4 }

	[Flags]
	enum UnitProductionOptions { None = 0x00, AllowDisbandCity = 0x01, AsConscripts = 0x02 }

	/// <summary>
	/// Input parameter for City.OptimizeExploitedLocations__Turn method
	/// </summary>
	class ResourceWeights
	{
		public enum Op {Add = 0, Multiply = 1}

		/// <summary>
		/// predefined value: max growth
		/// </summary>
		public static readonly ResourceWeights MaxGrowth = new ResourceWeights(120, Op.Add, 0.125, Op.Add, 0.0625, Op.Add, 0.0625, Op.Add);

		/// <summary>
		/// predefined value: max production
		/// </summary>
		public static readonly ResourceWeights MaxProduction = new ResourceWeights(0.0625, Op.Add, 120, Op.Add, 30, Op.Add, 1, Op.Add);

		/// <summary>
		/// predefined value: max research
		/// </summary>
		public static readonly ResourceWeights MaxResearch = new ResourceWeights(0.0625, Op.Add, 4, Op.Add, 4, Op.Add, 8, Op.Add);

		/// <summary>
		/// predefined value: hurry production
		/// </summary>
		public static readonly ResourceWeights HurryProduction = new ResourceWeights(0.5, Op.Multiply, 8, Op.Add, 2, Op.Add, 1, Op.Add);

		/// <summary>
		/// predefined value: hurry research
		/// </summary>
		public static readonly ResourceWeights HurryResearch = new ResourceWeights(0.5, Op.Multiply, 1, Op.Add, 1, Op.Add, 1, Op.Add);

		/// <summary>
		/// INTERNAL - only access from CevoAILib classes!
		/// </summary>
		public readonly uint Code;

		/// <summary>
		/// Weights resources using a formula of the shape Pow(A1,wA1) * Pow(A2,wA2) * ... * (B1*wB1 + B2*wB2 + ...).
		/// </summary>
		/// <param name="foodWeight">weight of food</param>
		/// <param name="foodOp">operation for food weight, Multiply = A part, Add = B part of formula</param>
		/// <param name="productionWeight">weight of production</param>
		/// <param name="productionOp">operation for production weight, Multiply = A part, Add = B part of formula</param>
		/// <param name="taxWeight">weight of tax</param>
		/// <param name="taxOp">operation for tax weight, Multiply = A part, Add = B part of formula</param>
		/// <param name="scienceWeight">weight of science</param>
		/// <param name="scienceOp">operation for science weight, Multiply = A part, Add = B part of formula</param>
		public ResourceWeights(double foodWeight, Op foodOp, double productionWeight, Op productionOp, double taxWeight, Op taxOp, double scienceWeight, Op scienceOp)
		{
			Code = (ItemCode(foodWeight, foodOp) << 24)
				+ (ItemCode(productionWeight, productionOp) << 16)
				+ (ItemCode(taxWeight, taxOp) << 8)
				+ ItemCode(scienceWeight, scienceOp);
		}

		uint ItemCode(double weight, Op op)
		{
			int exp = (int)(Math.Log(weight, 2.0) + Math.Log(32.0 / 31.0, 2.0) + 990) - 993;
			if (exp >= 4)
				return 0x3F | ((uint)op << 7); // above maximum

			if (exp < -4)
				exp = -4;
			uint mant = (uint)(weight * (1 << (4 - exp)) / 16.0 + 0.5);
			if (mant > 15)
				mant = 15;
			if (exp < 0)
				return mant | ((uint)(exp + 4) << 4) | ((uint)op << 7) | 0x40;
			else
				return mant | ((uint)exp << 4) | ((uint)op << 7);
		}
	}

	/// <summary>
	/// set of the 3 basic resources (food, material, trade)
	/// </summary>
	struct BaseResourceSet
	{
		public int Food;
		public int Material;
		public int Trade;

		public BaseResourceSet(int food, int material, int trade)
		{
			this.Food = food;
			this.Material = material;
			this.Trade = trade;
		}

		public override string ToString()
		{
			return string.Format("F{0} M{1} T{2}", Food, Material, Trade);
		}
	}

	//struct ExploitableLocation
	//{
	//    public readonly Location Location;
	//    public readonly RC RC;
	//    public readonly ExploitableLocationStatus Status;
	//    public readonly BaseResourceSet PotentialResources;

	//    public ExploitableLocation(Location location, RC RC, ExploitableLocationStatus status, BaseResourceSet potentialResources)
	//    {
	//        this.Location = location;
	//        this.RC = RC;
	//        this.Status = status;
	//        this.PotentialResources = potentialResources;
	//    }
	//}

	/// <summary>
	/// basic city information as available for both own and foreign cities
	/// </summary>
	interface ICity
	{
		bool Exists { get; }
		int ID { get; }
		Location Location { get; }
		Nation Nation { get; }
		Nation Founder { get; }
		int SerialNo { get; }
		int Size { get; }
		bool Has(Building building);
	}

	/// <summary>
	/// own city, abstract base class
	/// </summary>
	unsafe abstract class ACity : ICity
	{
		protected readonly Empire theEmpire;
		protected readonly int id;

		public ACity(Empire empire, int indexInSharedMemory)
		{
			this.theEmpire = empire;
			IndexInSharedMemory = indexInSharedMemory;
			id = address[3] & 0xFFFF; // save to be able to find city back
		}

		public override string ToString()
		{
			return string.Format("{0}.{1}@{2}", (id >> 12) & 0xF, id & 0xFFF, address[0]);
		}

		#region ICity Members
		/// <summary>
		/// true - city still exists, false - city has been destroyed
		/// </summary>
		public bool Exists { get { return indexInSharedMemory >= 0; } }

		/// <summary>
		/// unique city ID
		/// </summary>
		public int ID { get { return id; } }

		public Location Location { get { return new Location(theEmpire, address[0]); } }
		public Nation Nation { get { return theEmpire.Us; } }
		public Nation Founder { get { return new Nation(theEmpire, (id >> 12) & 0xF); } }

		/// <summary>
		/// number of cities the founding nation founded before this one
		/// </summary>
		public int SerialNo { get { return id & 0xFFF; } }

		public int Size { get { return (address[3] >> 16) & 0xFFFF; } }

		/// <summary>
		/// Whether the city has a specific building or wonder.
		/// </summary>
		/// <param name="building">the building</param>
		/// <returns>whether building exists in this city</returns>
		public bool Has(Building building) { return ((byte*)(address + 10))[(int)building] > 0; }
		#endregion

		/// <summary>
		/// City area, i.e. the locations of all tiles that might potentially be exploited by the city, including the city location.
		/// Usually the array has 21 elements, but it's less if the city is close to the upper or lower end of the map.
		/// </summary>
		OtherLocation[] Area { get { return Location.Distance5Area; } }

		/// <summary>
		/// Whether a location is in the area of the city, i.e. might potentially be exploited by it.
		/// </summary>
		/// <param name="otherLocation">the location</param>
		/// <returns>true if in area, false if not</returns>
		public bool AreaSpans(Location otherLocation) { return otherLocation.IsValid && (otherLocation - Location).Distance <= 5; }

		/// <summary>
		/// whether the city had a specific event in this turn
		/// </summary>
		/// <param name="cityEvent">the event</param>
		/// <returns>true if event occurred, false if not</returns>
		public bool HadEvent__Turn(CityEvent cityEvent) { return (address[7] & (1 << (int)cityEvent)) != 0; }

		/// <summary>
		/// If city was captured, turns until the takeover is complete and the city can be managed. Always 0 for cities that were not captured.
		/// </summary>
		public int TurnsTillTakeoverComplete { get { return (address[7] >> 16) & 0xF; } }

		/// <summary>
		/// food collected by the city
		/// </summary>
		public int FoodPile { get { return address[5] & 0xFFFF; } }

		/// <summary>
		/// material collected by the city
		/// </summary>
		public int MaterialPile { get { return address[6] & 0xFFFF; } }

		/// <summary>
		/// pollution accumulated in the city
		/// </summary>
		public int PollutionPile { get { return (address[5] >> 16) & 0xFFFF; } }

		/// <summary>
		/// size of food storage
		/// </summary>
		public int StorageSize { get { return Cevo.StorageSize[theEmpire.DifficultyLevel]; } }

		/// <summary>
		/// number of units that might have their home in this city without requiring material support
		/// </summary>
		public int FreeSupport { get { return Size * Cevo.Pedia(theEmpire.Government).FreeSupport / 2; } }

		#region report
		public int Morale { get { UpdateReport(); return report[3]; } }
		public int Control { get { UpdateReport(); return report[9]; } }
		public int Wealth { get { UpdateReport(); return report[20]; } }
		public int Unrest { get { UpdateReport(); return 2 * report[8]; } }
		public int HappinessBalance { get { UpdateReport(); return report[21]; } }
		public int FoodSupport { get { UpdateReport(); return report[4]; } }
		public int MaterialSupport { get { UpdateReport(); return report[5]; } }
		public int ProductionCost { get { UpdateReport(); return report[6]; } }
		public BaseResourceSet TotalResourcesFromArea { get { UpdateReport(); return new BaseResourceSet(report[10], report[11], report[12]); } }
		public int FoodSurplus { get { UpdateReport(); return report[14]; } }
		public int MaterialSurplus { get { UpdateReport(); return report[15]; } }
		public int PollutionPlus { get { UpdateReport(); return report[16]; } }
		public int Corruption { get { UpdateReport(); return report[17]; } }
		public int TaxOutput { get { UpdateReport(); return report[18]; } }
		public int ScienceOutput { get { UpdateReport(); return report[19]; } }
		#endregion

		public int NumberOfExploitedLocations
		{
			get
			{
				int array = address[8];
				int count = 0;
				for (int V21 = 1; V21 < 27; V21++)
				{
					if ((array & (1 << V21)) != 0)
						count++;
				}
				return count;
			}
		}

		public Location[] ExploitedLocations
		{
			get
			{
				int[] distance5IDs = new int[28];
				theEmpire.Map.GetDistance5IDs(Location.ID, distance5IDs);
				Location[] exploitedLocations = new Location[NumberOfExploitedLocations];
				int array = address[8];
				int count = 0;
				for (int V21 = 1; V21 < 27; V21++)
				{
					if ((array & (1 << V21)) != 0)
					{
						exploitedLocations[count] = new Location(theEmpire, distance5IDs[V21]);
						count++;
					}
				}
				return exploitedLocations;
			}
		}

		//public XC GetExploitableLocations__Turn(ref ExploitableLocation[] exploitableLocations)
		//{
		//    XC result;
		//    int[] distance5IDs = new int[28];
		//    theEmpire.Map.GetDistance5IDs(Location.ID, distance5IDs);

		//    fixed (int* cityAreaInfo = new int[28], tileInfo = new int[4])
		//    {
		//        result = theEmpire.Play(Protocol.sGetCityAreaInfo, Location.ID, cityAreaInfo);
		//        if (result.OK)
		//        {
		//            int count = 0;
		//            for (int V21 = 1; V21 < 27; V21++)
		//            {
		//                if (distance5IDs[V21] >= 0)
		//                    count++;
		//            }
		//            exploitableLocations = new ExploitableLocation[count];
		//            count = 0;
		//            for (int V21 = 1; V21 < 27; V21++)
		//            {
		//                if (distance5IDs[V21] >= 0)
		//                {
		//                    int dy = (V21 >> 2) - 3;
		//                    int dx = ((V21 & 3) << 1) - 3 + ((dy + 3) & 1);
		//                    tileInfo[3] = indexInSharedMemory;
		//                    theEmpire.Play(Protocol.sGetHypoCityTileInfo, distance5IDs[V21], tileInfo);
		//                    exploitableLocations[count] = new ExploitableLocation(
		//                        new Location(theEmpire, distance5IDs[V21]),
		//                        new RC((dx + dy) >> 1, (dy - dx) >> 1),
		//                        (ExploitableLocationStatus)cityAreaInfo[V21],
		//                        new BaseResourceSet(tileInfo[0], tileInfo[1], tileInfo[2]));
		//                    count++;
		//                }
		//            }
		//        }
		//    }
		//    return result;
		//}

		/// <summary>
		/// model of unit currently in production, null if production project is not a unit
		/// </summary>
		public Model UnitInProduction
		{
			get
			{
				int project = address[4] & 0xFFFF;
				if ((project & Protocol.cpImp) != 0)
					return null;
				else
					return theEmpire.Models[project & Protocol.cpIndex];
			}
		}

		/// <summary>
		/// building currently in production, Building.None if production project is not a building
		/// </summary>
		public Building BuildingInProduction
		{
			get
			{
				int project = address[4] & 0xFFFF;
				if ((project & Protocol.cpImp) == 0)
					return Building.None;
				else
					return (Building)(project & Protocol.cpIndex);
			}
		}

		public bool CanSetBuildingInProduction__Turn(Building building)
		{
			return theEmpire.TestPlay(Protocol.sSetCityProject, indexInSharedMemory, ((int)building & Protocol.cpIndex) | Protocol.cpImp).OK;
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
		//public XC SetExploitedLocations__Turn(Location[] locations)
		//{
		//    int[] distance5IDs = new int[28];
		//    theEmpire.Map.GetDistance5IDs(Location.ID, distance5IDs);
		//    int array = 0;
		//    foreach (Location location in locations)
		//    {
		//        int V21 = Array.IndexOf<int>(distance5IDs, location.ID);
		//        if (V21 < 0)
		//            return new XC(ServerReturnCode.TileNotAvailable);
		//        array += 1 << V21;
		//    }
		//    XC result = theEmpire.Play(Protocol.sSetCityTiles, indexInSharedMemory, array);
		//    if (result.Effective)
		//        InvalidateReport();
		//    return result;
		//}

		/// <summary>
		/// Change selection of tiles to exploit by the city.
		/// Does not touch the tile selection of other cities.
		/// </summary>
		/// <param name="resourceWeights">selection strategy: how to weight the different resource types</param>
		/// <returns>result of operation</returns>
		public PlayResult OptimizeExploitedLocations__Turn(ResourceWeights resourceWeights)
		{
			PlayResult result;
			fixed (uint* cityTileAdvice = new uint[20])
			{
				cityTileAdvice[0] = resourceWeights.Code;
				result = theEmpire.Play(Protocol.sGetCityTileAdvice, indexInSharedMemory, cityTileAdvice);
				if (result.OK)
					result = theEmpire.Play(Protocol.sSetCityTiles, indexInSharedMemory, (int)cityTileAdvice[1]);
			}
			if (result.Effective)
				InvalidateReport();
			return result;
		}

		/// <summary>
		/// Do no longer exploit any tile except the tile of the city itself. Combined with OptimizeExploitedLocations, this can
		/// be used to set priorities for tile exploitation between cities with overlapping area. Typical sequence:
		/// (1) LowPriorityCity.StopExploitation
		/// (2) HighPriorityCity.OptimizeExploitedLocations
		/// (3) LowPriorityCity.OptimizeExploitedLocations
		/// Usually calling this should be followed by an OptimizeExploitedLocations for the same city within the same turn. Otherwise 
		/// the city will remain in the non-exploiting state and start to decline.
		/// </summary>
		/// <returns>result of operation</returns>
		public PlayResult StopExploitation__Turn()
		{
			PlayResult result = theEmpire.Play(Protocol.sSetCityTiles, indexInSharedMemory, 1<<13);
			if (result.Effective)
				InvalidateReport();
			return result;
		}

		/// <summary>
		/// Change production project to a unit.
		/// </summary>
		/// <param name="model">model of the unit to produce</param>
		/// <param name="options">options</param>
		/// <returns>result of operation</returns>
		public PlayResult SetUnitInProduction__Turn(Model model, UnitProductionOptions options)
		{
			int optionArray = 0;
			if ((options & UnitProductionOptions.AsConscripts) != 0)
				optionArray += Protocol.cpConscripts;
			if ((options & UnitProductionOptions.AllowDisbandCity) != 0)
				optionArray += Protocol.cpDisbandCity;
			PlayResult result = theEmpire.Play(Protocol.sSetCityProject, indexInSharedMemory, model.IndexInSharedMemory | optionArray);
			if (result.Effective)
				InvalidateReport();
			return result;
		}

		/// <summary>
		/// Change production project to a unit.
		/// </summary>
		/// <param name="model">model of the unit to produce</param>
		/// <returns>result of operation</returns>
		public PlayResult SetUnitInProduction__Turn(Model model)
		{
			return SetUnitInProduction__Turn(model, UnitProductionOptions.None);
		}

		/// <summary>
		/// Change production project to a buiding or wonder.
		/// </summary>
		/// <param name="building">the building to produce</param>
		/// <returns>result of operation</returns>
		public PlayResult SetBuildingInProduction__Turn(Building building)
		{
			PlayResult result = theEmpire.Play(Protocol.sSetCityProject, indexInSharedMemory, ((int)building & Protocol.cpIndex) | Protocol.cpImp);
			if (result.Effective)
				InvalidateReport();
			return result;
		}

		/// <summary>
		/// stop production and set production to trade goods
		/// </summary>
		/// <returns>result of operation</returns>
		public PlayResult StopProduction__Turn()
		{
			return SetBuildingInProduction__Turn(Building.None);
		}

		/// <summary>
		/// buy material to complete the production in the next turn
		/// </summary>
		/// <returns>result of operation</returns>
		public PlayResult BuyMaterial__Turn()
		{
			return theEmpire.Play(Protocol.sBuyCityProject, indexInSharedMemory);
		}

		/// <summary>
		/// sell an existing building
		/// </summary>
		/// <param name="building">the building to sell</param>
		/// <returns>result of operation</returns>
		public PlayResult SellBuilding__Turn(Building building)
		{
			PlayResult result = theEmpire.Play(Protocol.sSellCityImprovement, indexInSharedMemory, (int)building);
			if (result.Effective)
			{
				if (building == Building.Palace || building == Building.StockExchange || building == Building.SpacePort)
					theEmpire.InvalidateAllCityReports();
				else
					InvalidateReport();
			}
			return result;
		}

		/// <summary>
		/// rebuild an existing building
		/// </summary>
		/// <param name="building">the building to rebuild</param>
		/// <returns>result of operation</returns>
		public PlayResult RebuildBuilding__Turn(Building building)
		{
			PlayResult result = theEmpire.Play(Protocol.sRebuildCityImprovement, indexInSharedMemory, (int)building);
			if (result.Effective)
			{
				if (building == Building.Palace || building == Building.StockExchange || building == Building.SpacePort)
					theEmpire.InvalidateAllCityReports();
				else
					InvalidateReport();
			}
			return result;
		}
		#endregion

		#region template internal stuff
		int indexInSharedMemory = -1;
		int* address;
		int[] report = new int[22];
		bool isReportValid = false;

		void UpdateReport()
		{
			if (!isReportValid)
			{
				report[0] = -1;
				report[1] = -1;
				report[2] = -1;
				fixed (int* data = report)
				{
					theEmpire.Play(Protocol.sGetCityReportNew, indexInSharedMemory, data);
				}
				isReportValid = true;
			}
		}

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
						address = (int*)theEmpire.address[5] + ROReadPoint.SizeOfCity * indexInSharedMemory;
				}
			}
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// </summary>
		public void InvalidateReport() { isReportValid = false; }
		#endregion
	}

	/// <summary>
	/// foreign city, abstract base class
	/// </summary>
	unsafe abstract class AForeignCity : ICity
	{
		protected readonly Empire theEmpire;
		protected readonly int id;

		public AForeignCity(Empire empire, int indexInSharedMemory)
		{
			this.theEmpire = empire;
			IndexInSharedMemory = indexInSharedMemory;
			id = (address[3] >> 16) & 0xFFFF; // save to be able to find city back
		}

		public override string ToString()
		{
			return string.Format("{0}.{1}@{2}", (id >> 12) & 0xF, id & 0xFFF, address[0]);
		}

		#region ICity Members
		/// <summary>
		/// true - city still exists, false - city has been destroyed
		/// </summary>
		public bool Exists { get { return indexInSharedMemory >= 0; } }

		/// <summary>
		/// unique city ID
		/// </summary>
		public int ID { get { return id; } }

		public Location Location { get { return new Location(theEmpire, address[0]); } }
		public Nation Nation { get { return new Nation(theEmpire, address[3] & 0xFFFF); } }
		public Nation Founder { get { return new Nation(theEmpire, (id >> 12) & 0xF); } }

		/// <summary>
		/// number of cities the founding nation founded before this one
		/// </summary>
		public int SerialNo { get { return id & 0xFFF; } }

		public int Size { get { return address[4] & 0xFFFF; } }

		/// <summary>
		/// Whether the city has a specific building or wonder.
		/// Only works for buildings which are known if built in a foreign city.
		/// These are: wonders, palace, space port and all defense facilities.
		/// For all others, the return value is always false.
		/// </summary>
		/// <param name="building">the building</param>
		/// <returns>whether building exists in this city</returns>
		public bool Has(Building building)
		{
			switch (building)
			{
				case Building.Palace:
					return (address[4] & (Protocol.ciCapital << 16)) != 0;
				case Building.SpacePort:
					return (address[4] & (Protocol.ciSpacePort << 16)) != 0;
				case Building.CommandBunker:
					return (address[4] & (Protocol.ciBunker << 16)) != 0;
				case Building.CityWalls:
					return (address[4] & (Protocol.ciWalled << 16)) != 0;
				case Building.CoastalFortress:
					return (address[4] & (Protocol.ciCoastalFort << 16)) != 0;
				case Building.SAM:
					return (address[4] & (Protocol.ciMissileBat << 16)) != 0;
				default:
					if (building < Building.WonderRange)
						return theEmpire.Wonder_IsInCity(building, this);
					else
						return false; // unknown
			}
		}
		#endregion

		/// <summary>
		/// city size and building information dates back to this turn
		/// </summary>
		public int TurnOfInformation { get { return Location.TurnObservedLast; } }

		/// <summary>
		/// persistent custom value
		/// </summary>
		public int Status
		{
			get { return address[1]; }
			set { address[1] = value; }
		}

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
						address = (int*)theEmpire.address[8] + ROReadPoint.SizeOfCityInfo * indexInSharedMemory;
				}
			}
		}
		#endregion
	}
}
