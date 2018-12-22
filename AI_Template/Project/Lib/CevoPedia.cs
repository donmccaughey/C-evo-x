using System;
using System.Collections.Generic;

namespace CevoAILib
{
	enum MovementKind { Plain = 1, Difficult = 2, Mountains = 3 }

	enum BuildingKind { CityImprovement, StateImprovement, Wonder, ColonyShipPart, None }

	/// <summary>
	/// game rules and tables to query from code
	/// </summary>
	static class Cevo
	{
		public static GovernmentInfo Pedia(Government government) { return GovernmentInfoList[(int)government]; }
		public static TerrainInfo Pedia(Terrain terrain) { return new TerrainInfo(terrain); }
		public static JobInfo Pedia(Job job, Terrain terrain) { return new JobInfo(job, terrain); }
		public static AdvanceInfo Pedia(Advance advance) { return new AdvanceInfo(advance); }
		public static BuildingInfo Pedia(Building building) { return BuildingInfoList[(int)building]; }

		#region Miscellaneous
		public const int MaxNumberOfNations = 15;
		public const int MaxUnitsPerNation = 4096;
		public const int MaxModelsPerNation = 256;
		public const int MaxCitiesPerNation = 1024;
		public const int MaxDifficulty = 3;
		public const int TerritoryRadiusAroundCities = 9; // one tile counts 2 if straight, 3 if diagonal
		public const Advance AdvanceForNewSpecialResources = Advance.Science;
		public const Advance AdvanceForRareMetalResources = Advance.MassProduction;
		public const int MaxFutureTech = 25; // maximum number of future techs of one kind except computing technology
		public const int MaxFutureTech_Computing = 100; // maximum number of computing technology future techs
		public static readonly ColonyShipParts CompleteColonyShip = new ColonyShipParts(6, 4, 2);

		public const int AnarchyTurns = 3;
		public const int CaptureTurns = 3;
		public const int CancelTreatyBufferTurns = 3;
		public const int PeaceEvacuationTurns = 5;
		public const int ColdWarTurns = 40;

		// unit
		public const int AttackCost = 100;
		public const int MaxHealth = 100;
		public const int ExperienceLevelCost = 50;
		public const int RecoveryOutsideCity = 8;
		public const int RecoveryInCity = 20; // for all types of recovery, note additional limiation: health is never more than doubled
		public const int FastRecovery = 50;
		public const int DamagePerTurnInDesert = 20;
		public const int DamagePerTurnInArctic = 20;

		// city
		public const int MaxCitySizeBasic = 8;
		public const int MaxCitySizeWithAqueduct = 12;
		public const int MaxCitySizeWithSewerSystem = 30;
		public const int BasicCityMorale = 4;
		public const int PollutionCost = 240;
		public static readonly int[] StorageSize = { 40, 30, 40, 50 }; // index is diffuculty level (0 is supervisor)
		public const int UniversityFutureBonus = 5; // percent per tech
		public const int ResearchLabFutureBonus = 10; // percent per tech
		public const int FactoryFutureBonus = 5; // percent per tech
		public const int MfgPlantFutureBonus = 10; // percent per tech

		// diplomacy
		public const int MaxPayment = 65535;
		#endregion

		#region Government
		public struct GovernmentInfo
		{
			public int SettlerFoodSupport;
			public int FreeSupport; // per city, in 1/2*city size
			public Advance Prerequisite;
		}

		static readonly GovernmentInfo[] GovernmentInfoList =
		{
			new GovernmentInfo{SettlerFoodSupport = 1, FreeSupport = 2, Prerequisite = Advance.None},
			new GovernmentInfo{SettlerFoodSupport = 1, FreeSupport = 2, Prerequisite = Advance.None},
			new GovernmentInfo{SettlerFoodSupport = 1, FreeSupport = 1, Prerequisite = Advance.Monarchy},
			new GovernmentInfo{SettlerFoodSupport = 2, FreeSupport = 0, Prerequisite = Advance.TheRepublic},
			new GovernmentInfo{SettlerFoodSupport = 1, FreeSupport = 2, Prerequisite = Advance.Theology},
			new GovernmentInfo{SettlerFoodSupport = 2, FreeSupport = 1, Prerequisite = Advance.Communism},
			new GovernmentInfo{SettlerFoodSupport = 2, FreeSupport = 0, Prerequisite = Advance.Democracy},
			new GovernmentInfo{SettlerFoodSupport = 2, FreeSupport = 0, Prerequisite = Advance.TheInternet}
		};
		#endregion

		#region Terrain and Jobs
		enum JobCost
		{
			RoadCost = 300, // *MovementKind
			RailroadCost = 600, // *MovementKind
			FarmlandCostMultiplier = 3, // *IrrigationCost
			CanalCost = 1800,
			FortressCost = 600, // *MovementKind
			CleanUpCost = 1800,
			BaseCost = 600, // *MovementKind
			PillageCost = 100,
			CityCost = 900
		}

		public struct BaseTerrainInfo
		{
			public MovementKind MovementKind;
			public int DefenseBonus;
			public Terrain ClearResult;
			public int ClearCost;
			public int IrrigationFoodGain;
			public int IrrigationCost;
			public Terrain AfforestResult;
			public int AfforestCost;
			public int MineMaterialGain;
			public int MineCost;
			public Terrain TransformationResult;
			public int TransformationCost;
		}

		static readonly BaseTerrainInfo[] BaseTerrainInfoList =
		{
			new BaseTerrainInfo {MovementKind = MovementKind.Plain, DefenseBonus = 4, ClearResult = Terrain.Unknown, ClearCost = 0, 
				IrrigationFoodGain = 0, IrrigationCost = 0, AfforestResult = Terrain.Unknown, AfforestCost = 0, 
				MineMaterialGain = 0, MineCost = 0, TransformationResult = Terrain.Unknown, TransformationCost = 0}, // {-}
			new BaseTerrainInfo {MovementKind = MovementKind.Plain, DefenseBonus = 4, ClearResult = Terrain.Unknown, ClearCost = 0, 
				IrrigationFoodGain = 0, IrrigationCost = 0, AfforestResult = Terrain.Unknown, AfforestCost = 0, 
				MineMaterialGain = 0, MineCost = 0, TransformationResult = Terrain.Unknown, TransformationCost = 0}, // {Ddl}
			new BaseTerrainInfo {MovementKind = MovementKind.Plain, DefenseBonus = 4, ClearResult = Terrain.Unknown, ClearCost = 0, 
				IrrigationFoodGain = 0, IrrigationCost = 0, AfforestResult = Terrain.Unknown, AfforestCost = 0, 
				MineMaterialGain = 0, MineCost = 0, TransformationResult = Terrain.Unknown, TransformationCost = 0}, // {Ocn}
			new BaseTerrainInfo {MovementKind = MovementKind.Plain, DefenseBonus = 4, ClearResult = Terrain.Unknown, ClearCost = 0, 
				IrrigationFoodGain = 0, IrrigationCost = 0, AfforestResult = Terrain.Unknown, AfforestCost = 0, 
				MineMaterialGain = 0, MineCost = 0, TransformationResult = Terrain.Unknown, TransformationCost = 0}, // {Sho}
			new BaseTerrainInfo {MovementKind = MovementKind.Plain, DefenseBonus = 4, ClearResult = Terrain.Unknown, ClearCost = 0, 
				IrrigationFoodGain = 1, IrrigationCost = 600, AfforestResult = Terrain.Forest, AfforestCost = 1800, 
				MineMaterialGain = 0, MineCost = 0, TransformationResult = Terrain.Hills, TransformationCost = 3000}, // {Gra}
			new BaseTerrainInfo {MovementKind = MovementKind.Plain, DefenseBonus = 4, ClearResult = Terrain.Grassland, ClearCost = 1800, 
				IrrigationFoodGain = 0, IrrigationCost = 0, AfforestResult = Terrain.Unknown, AfforestCost = 0, 
				MineMaterialGain = 1, MineCost = 600, TransformationResult = Terrain.Prairie, TransformationCost = 3000}, // {Dst}
			new BaseTerrainInfo {MovementKind = MovementKind.Plain, DefenseBonus = 4, ClearResult = Terrain.Unknown, ClearCost = 0, 
				IrrigationFoodGain = 1, IrrigationCost = 600, AfforestResult = Terrain.Forest, AfforestCost = 2400, 
				MineMaterialGain = 0, MineCost = 0, TransformationResult = Terrain.Unknown, TransformationCost = 0}, // {Pra}
			new BaseTerrainInfo {MovementKind = MovementKind.Plain, DefenseBonus = 4, ClearResult = Terrain.Unknown, ClearCost = 0, 
				IrrigationFoodGain = 1, IrrigationCost = 600, AfforestResult = Terrain.Unknown, AfforestCost = 0, 
				MineMaterialGain = 0, MineCost = 0, TransformationResult = Terrain.Grassland, TransformationCost = 3000}, // {Tun}
			new BaseTerrainInfo {MovementKind = MovementKind.Difficult, DefenseBonus = 4, ClearResult = Terrain.Unknown, ClearCost = 0, 
				IrrigationFoodGain = 0, IrrigationCost = 0, AfforestResult = Terrain.Unknown, AfforestCost = 0, 
				MineMaterialGain = 3, MineCost = 1800, TransformationResult = Terrain.Unknown, TransformationCost = 0}, // {Arc}
			new BaseTerrainInfo {MovementKind = MovementKind.Difficult, DefenseBonus = 6, ClearResult = Terrain.Grassland, ClearCost = 2400, 
				IrrigationFoodGain = 0, IrrigationCost = 0, AfforestResult = Terrain.Forest, AfforestCost = 2400, 
				MineMaterialGain = 0, MineCost = 0, TransformationResult = Terrain.Hills, TransformationCost = 3000}, // {Swa}
			new BaseTerrainInfo {MovementKind = MovementKind.Plain, DefenseBonus = 4, ClearResult = Terrain.Unknown, ClearCost = 0, 
				IrrigationFoodGain = 1, IrrigationCost = 600, AfforestResult = Terrain.Forest, AfforestCost = 1800, 
				MineMaterialGain = 0, MineCost = 0, TransformationResult = Terrain.Hills, TransformationCost = 3000}, // {Gra}
			new BaseTerrainInfo {MovementKind = MovementKind.Difficult, DefenseBonus = 6, ClearResult = Terrain.Prairie, ClearCost = 600, 
				IrrigationFoodGain = 0, IrrigationCost = 0, AfforestResult = Terrain.Unknown, AfforestCost = 0, 
				MineMaterialGain = 0, MineCost = 0, TransformationResult = Terrain.Unknown, TransformationCost = 0}, // {For}
			new BaseTerrainInfo {MovementKind = MovementKind.Difficult, DefenseBonus = 8, ClearResult = Terrain.Unknown, ClearCost = 0, 
				IrrigationFoodGain = 1, IrrigationCost = 600, AfforestResult = Terrain.Unknown, AfforestCost = 0, 
				MineMaterialGain = 3, MineCost = 1200, TransformationResult = Terrain.Grassland, TransformationCost = 6000}, // {Hil}
			new BaseTerrainInfo {MovementKind = MovementKind.Mountains, DefenseBonus = 12, ClearResult = Terrain.Unknown, ClearCost = 0, 
				IrrigationFoodGain = 0, IrrigationCost = 0, AfforestResult = Terrain.Unknown, AfforestCost = 0, 
				MineMaterialGain = 2, MineCost = 1200, TransformationResult = Terrain.Unknown, TransformationCost = 0} // {Mou}
		};

		static readonly BaseResourceSet[] TerrainResourcesList = 
		{
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 1, Trade = 1}, // {Dst}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {Ocn}
			new BaseResourceSet{Food = 1, Material = 0, Trade = 3}, // {Sho}
			new BaseResourceSet{Food = 3, Material = 0, Trade = 1}, // {Gra}
			new BaseResourceSet{Food = 0, Material = 1, Trade = 1}, // {Dst}
			new BaseResourceSet{Food = 1, Material = 1, Trade = 1}, // {Pra}
			new BaseResourceSet{Food = 1, Material = 0, Trade = 1}, // {Tun}
			new BaseResourceSet{Food = 0, Material = 1, Trade = 0}, // {Arc}
			new BaseResourceSet{Food = 1, Material = 0, Trade = 1}, // {Swa}
			new BaseResourceSet{Food = 2, Material = 1, Trade = 1}, // {Gra1}
			new BaseResourceSet{Food = 1, Material = 2, Trade = 1}, // {For}
			new BaseResourceSet{Food = 1, Material = 0, Trade = 0}, // {Hil}
			new BaseResourceSet{Food = 0, Material = 1, Trade = 0}, // {Mou}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 1, Trade = 1}, // {Dst}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 5, Material = 0, Trade = 3}, // {Sho1}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 3, Material = 1, Trade = 1}, // {Dst1}
			new BaseResourceSet{Food = 3, Material = 1, Trade = 1}, // {Pra1}
			new BaseResourceSet{Food = 1, Material = 0, Trade = 6}, // {Tun1}
			new BaseResourceSet{Food = 3, Material = 1, Trade = 4}, // {Arc1}
			new BaseResourceSet{Food = 1, Material = 4, Trade = 1}, // {Swa1}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 3, Material = 2, Trade = 1}, // {For1}
			new BaseResourceSet{Food = 1, Material = 0, Trade = 4}, // {Hil1}
			new BaseResourceSet{Food = 0, Material = 4, Trade = 0}, // {Mou1}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 1, Trade = 1}, // {Dst}		
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 1, Material = 5, Trade = 3}, // {Sho2}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 4, Trade = 1}, // {Dst2}
			new BaseResourceSet{Food = 1, Material = 3, Trade = 1}, // {Pra2} 
			new BaseResourceSet{Food = 1, Material = 4, Trade = 1}, // {Tun2}            
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 1, Material = 2, Trade = 4}, // {For2}
			new BaseResourceSet{Food = 1, Material = 2, Trade = 0}, // {Hil2}
			new BaseResourceSet{Food = 0, Material = 1, Trade = 7}, // {Mou2}      
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 0, Trade = 0}, // {-}
			new BaseResourceSet{Food = 0, Material = 1, Trade = 1} // {Dst}
		};

		static readonly Advance[] JobPrerequisites =
		{
			Advance.None, Advance.None, Advance.Railroad,Advance.None,Advance.None,
			Advance.Refrigeration,Advance.None,Advance.None,Advance.Explosives,Advance.Explosives,
			Advance.Construction,Advance.None,Advance.Medicine,Advance.None,Advance.None
		};

		public struct TerrainInfo
		{
			Terrain terrain;
			public TerrainInfo(Terrain terrain) { this.terrain = terrain; }
			public BaseResourceSet Resources { get { return TerrainResourcesList[(int)terrain]; } }
			public MovementKind MovementKind { get { return BaseTerrainInfoList[(int)terrain & 0xF].MovementKind; } }
			public int DefenseBonus { get { return BaseTerrainInfoList[(int)terrain & 0xF].DefenseBonus; } }
		}

		public struct JobInfo
		{
			public bool IsPossible;
			public int Cost;
			public Terrain NewTerrain;
			public BaseResourceSet Gain;
			public Advance Prerequisite;

			public JobInfo(Job job, Terrain terrain)
			{
				IsPossible = false;
				Cost = 0;
				NewTerrain = terrain;
				Gain = new BaseResourceSet(0, 0, 0);
				Prerequisite = JobPrerequisites[(int)job];
				Terrain baseTerrain = (Terrain)((int)terrain & 0xF);

				switch (job)
				{
					case CevoAILib.Job.None:
						{
							break;
						}

					case CevoAILib.Job.BuildRoad:
						{
							IsPossible = true;
							Cost = (int)JobCost.RoadCost * (int)BaseTerrainInfoList[(int)baseTerrain].MovementKind;
							if (BaseTerrainInfoList[(int)baseTerrain].MovementKind == MovementKind.Plain)
								Gain.Trade = 1;
							break;
						}

					case CevoAILib.Job.BuildRailRoad:
						{
							IsPossible = true;
							Cost = (int)JobCost.RailroadCost * (int)BaseTerrainInfoList[(int)baseTerrain].MovementKind;
							Gain.Material = (TerrainResourcesList[(int)terrain].Material + BaseTerrainInfoList[(int)baseTerrain].MineMaterialGain) / 2;
							// assume mine as already built, if possible
							break;
						}

					case CevoAILib.Job.ClearOrDrain:
						{
							if (BaseTerrainInfoList[(int)baseTerrain].ClearResult != Terrain.Unknown)
							{
								IsPossible = true;
								Cost = BaseTerrainInfoList[(int)baseTerrain].ClearCost;
								NewTerrain = BaseTerrainInfoList[(int)baseTerrain].ClearResult;
								if (NewTerrain != Terrain.Grassland)
									NewTerrain = (Terrain)((int)NewTerrain + ((int)terrain & 0xF0)); // keep special resource
							}
							break;
						}

					case CevoAILib.Job.Irrigate:
						{
							if (BaseTerrainInfoList[(int)baseTerrain].IrrigationFoodGain > 0)
							{
								IsPossible = true;
								Cost = BaseTerrainInfoList[(int)baseTerrain].IrrigationCost;
								Gain.Food = BaseTerrainInfoList[(int)baseTerrain].IrrigationFoodGain;
							}
							break;
						}

					case CevoAILib.Job.BuildFarmland:
						{
							if (BaseTerrainInfoList[(int)baseTerrain].IrrigationFoodGain > 0)
							{
								IsPossible = true;
								Cost = (int)JobCost.FarmlandCostMultiplier * BaseTerrainInfoList[(int)baseTerrain].IrrigationCost;
								Gain.Food = (TerrainResourcesList[(int)terrain].Food + BaseTerrainInfoList[(int)baseTerrain].IrrigationFoodGain) / 2;
							}
							break;
						}

					case CevoAILib.Job.Afforest:
						{
							if (BaseTerrainInfoList[(int)baseTerrain].AfforestResult != Terrain.Unknown)
							{
								IsPossible = true;
								Cost = BaseTerrainInfoList[(int)baseTerrain].AfforestCost;
								NewTerrain = BaseTerrainInfoList[(int)baseTerrain].AfforestResult;
								if (NewTerrain != Terrain.Grassland)
									NewTerrain = (Terrain)((int)NewTerrain + ((int)terrain & 0xF0)); // keep special resource
							}
							break;
						}

					case CevoAILib.Job.BuildMine:
						{
							if (BaseTerrainInfoList[(int)baseTerrain].MineMaterialGain > 0)
							{
								IsPossible = true;
								Cost = BaseTerrainInfoList[(int)baseTerrain].MineCost;
								Gain.Material = BaseTerrainInfoList[(int)baseTerrain].MineMaterialGain;
							}
							break;
						}

					case CevoAILib.Job.BuildCanal:
						{
							IsPossible = (baseTerrain != Terrain.Mountains && baseTerrain != Terrain.Arctic);
							Cost = (int)JobCost.CanalCost;
							break;
						}

					case CevoAILib.Job.Transform:
						{
							if (BaseTerrainInfoList[(int)baseTerrain].TransformationResult != Terrain.Unknown)
							{
								IsPossible = true;
								Cost = BaseTerrainInfoList[(int)baseTerrain].TransformationCost;
								NewTerrain = BaseTerrainInfoList[(int)baseTerrain].TransformationResult;
								if (NewTerrain != Terrain.Grassland)
									NewTerrain = (Terrain)((int)NewTerrain + ((int)terrain & 0xF0)); // keep special resource
							}
							break;
						}

					case CevoAILib.Job.BuildFortress:
						{
							IsPossible = true;
							Cost = (int)JobCost.FortressCost * (int)BaseTerrainInfoList[(int)baseTerrain].MovementKind;
							break;
						}

					case CevoAILib.Job.CleanUp:
						{
							IsPossible = true;
							Cost = (int)JobCost.CleanUpCost;
							break;
						}

					case CevoAILib.Job.BuildBase:
						{
							IsPossible = true;
							Cost = (int)JobCost.BaseCost * (int)BaseTerrainInfoList[(int)baseTerrain].MovementKind;
							break;
						}

					case CevoAILib.Job.Pillage:
						{
							IsPossible = true;
							Cost = (int)JobCost.PillageCost;
							break;
						}

					case CevoAILib.Job.BuildCity:
						{
							IsPossible = (BaseTerrainInfoList[(int)baseTerrain].IrrigationFoodGain > 0);
							Cost = (int)JobCost.CityCost;
							break;
						}
				}
				IsPossible = IsPossible && baseTerrain >= Terrain.Grassland;
			}
		}
		#endregion

		#region Advances
		public struct AdvanceInfo
		{
			public List<Advance> Prerequisites;

			public AdvanceInfo(Advance advance)
			{
				Prerequisites = new List<Advance>(AdvancePrerequisites[(int)advance]);
			}
		}

		static readonly Advance[][] AdvancePrerequisites =
		{
			new Advance[] {Advance.Flight, Advance.Robotics}, // AdvancedFlight
			new Advance[] {Advance.Navigation, Advance.Tactics}, // AmphibiousWarfare
			new Advance[] {Advance.Mysticism, Advance.Alphabet}, // Astronomy
			new Advance[] {Advance.TheoryOfGravity}, // AtomicTheory
			new Advance[] {Advance.CombustionEngine, Advance.Steel}, // Automobile
			new Advance[] {Advance.Mathematics, Advance.Metallurgy}, // Ballistics
			new Advance[] {Advance.Currency, Advance.Engineering}, // Banking
			new Advance[] {Advance.Construction, Advance.TheWheel}, // BridgeBuilding
			new Advance[] {}, // BronzeWorking
			new Advance[] {}, // CeremonialBurial
			new Advance[] {Advance.Science}, // Chemistry
			new Advance[] {Advance.Monarchy, Advance.WarriorCode}, // Chivalry
			new Advance[] {Advance.Metallurgy, Advance.Plastics}, // Composites
			new Advance[] {Advance.Writing}, // CodeOfLaws
			new Advance[] {Advance.AdvancedFlight, Advance.MobileWarfare}, // CombinedArms
			new Advance[] {Advance.Refining, Advance.Explosives}, // CombustionEngine
			new Advance[] {Advance.Philosophy, Advance.Industrialization}, // Communism
			new Advance[] {Advance.Miniaturization}, // Computers
			new Advance[] {Advance.TheRepublic, Advance.Tactics}, // Conscription
			new Advance[] {Advance.Masonry, Advance.Alphabet}, // Construction
			new Advance[] {Advance.Economics, Advance.Democracy}, // TheCorporation
			new Advance[] {Advance.AdvancedFlight, Advance.AdvancedRocketry}, // SpaceFlight
			new Advance[] {Advance.BronzeWorking}, // Currency
			new Advance[] {Advance.Conscription, Advance.Industrialization}, // Democracy
			new Advance[] {Advance.Banking, Advance.University}, // Economics
			new Advance[] {Advance.Magnetism}, // Electricity
			new Advance[] {Advance.Radio, Advance.AtomicTheory}, // Electronics
			new Advance[] {Advance.Construction, Advance.BronzeWorking}, // Engineering
			new Advance[] {Advance.Industrialization}, // Environmentalism
			new Advance[] {}, // TheWheel
			new Advance[] {Advance.Chemistry, Advance.Engineering}, // Explosives
			new Advance[] {Advance.CombustionEngine, Advance.Physics}, // Flight
			new Advance[] {Advance.Tactics, Advance.Invention}, // Intelligence
			new Advance[] {Advance.Medicine, Advance.IronWorking}, // Gunpowder
			new Advance[] {}, // HorsebackRiding
			new Advance[] {Advance.SpaceFlight, Advance.NuclearPower}, // ImpulseDrive
			new Advance[] {Advance.Railroad, Advance.Banking}, // Industrialization
			new Advance[] {Advance.AdvancedRocketry, Advance.TheLaser}, // IntelligenArms
			new Advance[] {Advance.Writing, Advance.TheWheel}, // Invention
			new Advance[] {Advance.BronzeWorking, Advance.Invention}, // IronWorking
			new Advance[] {Advance.Miniaturization, Advance.Physics}, // TheLaser
			new Advance[] {Advance.NuclearFission}, // NuclearPower
			new Advance[] {Advance.Poetry, Advance.Trade}, // Literature
			new Advance[] {Advance.Democracy, Advance.Computers}, // Lybertarianism
			new Advance[] {Advance.Physics, Advance.IronWorking}, // Magnetism
			new Advance[] {Advance.Alphabet}, // MapMaking
			new Advance[] {}, // Masonry
			new Advance[] {Advance.Automobile, Advance.Electronics, Advance.TheCorporation}, // MassProduction
			new Advance[] {Advance.Currency, Advance.Alphabet}, // Mathematics
			new Advance[] {Advance.Mysticism, Advance.Pottery}, // Medicine
			new Advance[] {Advance.Gunpowder}, // Metallurgy
			new Advance[] {Advance.Robotics, Advance.Plastics}, // Miniaturization
			new Advance[] {Advance.Automobile, Advance.Tactics}, // MobileWarfare
			new Advance[] {Advance.Polytheism}, // Monarchy
			new Advance[] {Advance.CeremonialBurial}, // Mysticism
			new Advance[] {Advance.Seafaring, Advance.Astronomy}, // Navigation
			new Advance[] {Advance.AtomicTheory, Advance.MassProduction}, // NuclearFission
			new Advance[] {Advance.Mathematics, Advance.Literature}, // Philosophy
			new Advance[] {Advance.Science}, // Physics
			new Advance[] {Advance.MassProduction, Advance.Refining}, // Plastics
			new Advance[] {Advance.Mysticism, Advance.WarriorCode}, // Poetry
			new Advance[] {}, // Pottery
			new Advance[] {Advance.Electricity, Advance.Engineering}, // Radio
			new Advance[] {Advance.Environmentalism, Advance.Plastics}, // Recycling
			new Advance[] {Advance.Electricity}, // Refrigeration
			new Advance[] {Advance.Polytheism, Advance.Astronomy}, // Monotheism
			new Advance[] {Advance.Literature}, // TheRepublic
			new Advance[] {Advance.MassProduction, Advance.Economics}, // Robotics
			new Advance[] {Advance.Ballistics, Advance.Explosives}, // Rocketry
			new Advance[] {Advance.SteamEngine, Advance.BridgeBuilding}, // Railroad
			new Advance[] {Advance.Environmentalism, Advance.Medicine}, // Sanitation
			new Advance[] {Advance.Metallurgy, Advance.Theology, Advance.Philosophy}, // Science
			new Advance[] {Advance.Alphabet}, // Writing
			new Advance[] {Advance.Pottery, Advance.MapMaking}, // Seafaring
			new Advance[] {Advance.Recycling, Advance.SyntheticFood}, // SelfContainedEnvironment
			new Advance[] {Advance.Composites, Advance.Radio}, // Stealth
			new Advance[] {Advance.Science, Advance.Engineering}, // SteamEngine
			new Advance[] {Advance.IronWorking, Advance.Railroad}, // Steel
			new Advance[] {Advance.Chemistry, Advance.Refrigeration}, // SyntheticFood
			new Advance[] {Advance.WarriorCode, Advance.University}, // Tactics
			new Advance[] {Advance.Monotheism, Advance.Poetry}, // Theology
			new Advance[] {Advance.Astronomy, Advance.Physics}, // TheoryOfGravity
			new Advance[] {Advance.Currency, Advance.CodeOfLaws}, // Trade
			new Advance[] {Advance.ImpulseDrive, Advance.SelfContainedEnvironment}, // TransstellarColonization
			new Advance[] {Advance.Science}, // University
			new Advance[] {Advance.Computers, Advance.Rocketry}, // AdvancedRocketry
			new Advance[] {}, // WarriorCode
			new Advance[] {}, // Alphabet
			new Advance[] {Advance.CeremonialBurial, Advance.HorsebackRiding}, // Polytheism
			new Advance[] {Advance.Chemistry}, // Refining
			new Advance[] {Advance.Computers}, // ResearchTechnology
			new Advance[] {Advance.Robotics}, // ProductionTechnology
			new Advance[] {Advance.Composites}, // ArmorTechnology
			new Advance[] {Advance.SmartWeapons} // MissileTechnology
		};
		#endregion

		#region Buildings
		public struct BuildingInfo
		{
			public BuildingKind Kind;
			public Advance Prerequisite;
			public int Cost;
			public int Maintenance;
			public Advance Expiration;
		}

		static readonly BuildingInfo[] BuildingInfoList =
		{
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Mathematics, Cost = 400, Maintenance = 0, Expiration = Advance.Democracy}, // Pyramids
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Polytheism, Cost = 200, Maintenance = 0, Expiration = Advance.Electronics}, // Zeus
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Invention, Cost = 200, Maintenance = 0, Expiration = Advance.NuclearFission}, // Gardens
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.BronzeWorking, Cost = 200, Maintenance = 0, Expiration = Advance.None}, // Colossus
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.MapMaking, Cost = 200, Maintenance = 0, Expiration = Advance.Steel}, // Lighthouse
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Literature, Cost = 400, Maintenance = 0, Expiration = Advance.Plastics}, // GrLibrary
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Mysticism, Cost = 200, Maintenance = 0, Expiration = Advance.None}, // Oracle
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Chivalry, Cost = 300, Maintenance = 0, Expiration = Advance.SpaceFlight}, // Sun
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Philosophy, Cost = 500, Maintenance = 0, Expiration = Advance.None}, // Leo
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Navigation, Cost = 300, Maintenance = 0, Expiration = Advance.None}, // Magellan
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Monotheism, Cost = 400, Maintenance = 0, Expiration = Advance.None}, // Mich
			new BuildingInfo {Kind = BuildingKind.None, Prerequisite = Advance.None}, // {11}
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.TheoryOfGravity, Cost = 400, Maintenance = 0, Expiration = Advance.None}, // Newton
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Theology, Cost = 400, Maintenance = 0, Expiration = Advance.None}, // Bach
			new BuildingInfo {Kind = BuildingKind.None, Prerequisite = Advance.None}, // {14}
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Democracy, Cost = 500, Maintenance = 0, Expiration = Advance.None}, // Liberty
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Steel, Cost = 800, Maintenance = 0, Expiration = Advance.None}, // Eiffel
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Electronics, Cost = 800, Maintenance = 0, Expiration = Advance.None}, // Hoover
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.Plastics, Cost = 500, Maintenance = 0, Expiration = Advance.None}, // Shinkansen
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.NuclearFission, Cost = 400, Maintenance = 0, Expiration = Advance.None}, // Manhattan
			new BuildingInfo {Kind = BuildingKind.Wonder, Prerequisite = Advance.SpaceFlight, Cost = 800, Maintenance = 0, Expiration = Advance.None}, // Mir
			new BuildingInfo {Kind = BuildingKind.None, Prerequisite = Advance.None}, // {21}
			new BuildingInfo {Kind = BuildingKind.None, Prerequisite = Advance.None}, // {22}
			new BuildingInfo {Kind = BuildingKind.None, Prerequisite = Advance.None}, // {23}
			new BuildingInfo {Kind = BuildingKind.None, Prerequisite = Advance.None}, // {24}
			new BuildingInfo {Kind = BuildingKind.None, Prerequisite = Advance.None}, // {25}
			new BuildingInfo {Kind = BuildingKind.None, Prerequisite = Advance.None}, // {26}
			new BuildingInfo {Kind = BuildingKind.None, Prerequisite = Advance.None}, // {27}
			new BuildingInfo {Kind = BuildingKind.None, Prerequisite = Advance.None, Cost = 0, Maintenance = 0}, // TrGoods
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.WarriorCode, Cost = 40, Maintenance = 1}, // Barracks
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Pottery, Cost = 60, Maintenance = 1}, // Granary
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.CeremonialBurial, Cost = 40, Maintenance = 1}, // Temple
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Currency, Cost = 60, Maintenance = 1}, // Market
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Writing, Cost = 80, Maintenance = 3}, // Library
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.CodeOfLaws, Cost = 80, Maintenance = 2}, // Court
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Masonry, Cost = 80, Maintenance = 1}, // Walls
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Construction, Cost = 80, Maintenance = 1}, // Aqueduct
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Banking, Cost = 120, Maintenance = 2}, // Bank
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Monotheism, Cost = 100, Maintenance = 1}, // Cathedral
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.University, Cost = 160, Maintenance = 5}, // University
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Seafaring, Cost = 60, Maintenance = 1}, // Harbor
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Poetry, Cost = 60, Maintenance = 2}, // Theater
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Industrialization, Cost = 200, Maintenance = 3}, // Factory
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Robotics, Cost = 320, Maintenance = 5}, // MfgPlant
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Recycling, Cost = 320, Maintenance = 4}, // Recycling
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Electricity, Cost = 120, Maintenance = 2}, // Power
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Environmentalism, Cost = 120, Maintenance = 1}, // Hydro
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.NuclearPower, Cost = 240, Maintenance = 2}, // Nuclear
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Refining, Cost = 160, Maintenance = 2}, // Platform
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.None, Cost = 40, Maintenance = 1}, // TownHall
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Sanitation, Cost = 120, Maintenance = 2}, // Sewer
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Refrigeration, Cost = 80, Maintenance = 2}, // Supermarket
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Automobile, Cost = 160, Maintenance = 4}, // Highways
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Computers, Cost = 240, Maintenance = 7}, // ResLab
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.AdvancedRocketry, Cost = 100, Maintenance = 1}, // MissileBat
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.Metallurgy, Cost = 80, Maintenance = 1}, // CoastalFort
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.AdvancedFlight, Cost = 160, Maintenance = 1}, // Airport
			new BuildingInfo {Kind = BuildingKind.CityImprovement, Prerequisite = Advance.AmphibiousWarfare, Cost = 80, Maintenance = 1}, // Dockyard
			new BuildingInfo {Kind = BuildingKind.StateImprovement, Prerequisite = Advance.None, Cost = 100, Maintenance = 0}, // Palace
			new BuildingInfo {Kind = BuildingKind.StateImprovement, Prerequisite = Advance.Engineering, Cost = 400, Maintenance = 4}, // GrWall
			new BuildingInfo {Kind = BuildingKind.StateImprovement, Prerequisite = Advance.Construction, Cost = 200, Maintenance = 4}, // Colosseum
			new BuildingInfo {Kind = BuildingKind.StateImprovement, Prerequisite = Advance.Astronomy, Cost = 300, Maintenance = 4}, // Observatory
			new BuildingInfo {Kind = BuildingKind.StateImprovement, Prerequisite = Advance.Tactics, Cost = 100, Maintenance = 4}, // MilAcademy
			new BuildingInfo {Kind = BuildingKind.StateImprovement, Prerequisite = Advance.Steel, Cost = 200, Maintenance = 2}, // Bunker
			new BuildingInfo {Kind = BuildingKind.StateImprovement, Prerequisite = Advance.SyntheticFood, Cost = 120, Maintenance = 2}, // Algae
			new BuildingInfo {Kind = BuildingKind.StateImprovement, Prerequisite = Advance.TheCorporation, Cost = 320, Maintenance = 4}, // StockEx
			new BuildingInfo {Kind = BuildingKind.StateImprovement, Prerequisite = Advance.SpaceFlight, Cost = 400, Maintenance = 0}, // SpacePort
			new BuildingInfo {Kind = BuildingKind.ColonyShipPart, Prerequisite = Advance.TransstellarColonization, Cost = 240, Maintenance = 0}, // ShipComp
			new BuildingInfo {Kind = BuildingKind.ColonyShipPart, Prerequisite = Advance.ImpulseDrive, Cost = 600, Maintenance = 0}, // ShipPow
			new BuildingInfo {Kind = BuildingKind.ColonyShipPart, Prerequisite = Advance.SelfContainedEnvironment, Cost = 800, Maintenance = 0} // ShipHab
		};
		#endregion
	}
}
