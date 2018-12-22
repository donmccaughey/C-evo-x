using System;
using System.Collections.Generic;
using AI;

namespace CevoAILib
{
	enum ModelDomain { Ground = 0, Sea = 1, Air = 2 }

	enum ModelKind
	{
		OwnDesign = 0x00, ForeignDesign = 0x01, LongBoats = 0x08, TownGuard = 0x10, Glider = 0x11,
		Slaves = 0x21, Settlers = 0x22, SpecialCommando = 0x23, Freight = 0x24, Engineers = 0x122
	}

	enum ModelProperty
	{
		Weapons = 0, Armor = 1, Mobility = 2, SeaTransport = 3, Carrier = 4,
		Turbines = 5, Bombs = 6, Fuel = 7, AirTransport = 8, Navigation = 9,
		RadarSonar = 10, Submarine = 11, Artillery = 12, Alpine = 13, SupplyShip = 14,
		Overweight = 15, AirDefence = 16, SpyPlane = 17, SteamPower = 18, NuclearPower = 19,
		JetEngines = 20, Stealth = 21, Fanatic = 22, FirstStrike = 23, PowerOfWill = 24,
		AcademyTraining = 25, LineProduction = 26
	}

	struct Stage
	{
		public readonly int MaximumWeight;
		public readonly int StrengthMultiplier;
		public readonly int TransportMultiplier;
		public readonly int CostMultiplier;
		readonly int upgradeArray;
		bool ContainsUpgrade(int upgrade) { return (upgradeArray & (1 << upgrade)) != 0; }

		public Stage(int maximumWeight, int strengthMultiplier, int transportMultiplier, int costMultiplier, int upgradeArray)
		{
			this.MaximumWeight = maximumWeight;
			this.StrengthMultiplier = strengthMultiplier;
			this.TransportMultiplier = transportMultiplier;
			this.CostMultiplier = costMultiplier;
			this.upgradeArray = upgradeArray;
		}

		public override string ToString()
		{
			return string.Format("x{0}", StrengthMultiplier);
		}
	}

	/// <summary>
	/// basic model information as available for both own and foreign models
	/// </summary>
	abstract class ModelBase
	{
		#region abstract
		public abstract int ID { get; }
		public abstract ModelKind Kind { get; }
		public abstract Nation Nation { get; }
		public abstract ModelDomain Domain { get; }
		public abstract int Attack { get; }
		public abstract int AttackPlusWithBombs { get; }
		public abstract int Defense { get; }
		public abstract int Speed { get; }
		public abstract int Cost { get; }
		public abstract int TransportCapacity { get; }
		public abstract int CarrierCapacity { get; }
		public abstract int Fuel { get; }
		public abstract int Weight { get; }
		public abstract bool HasFeature(ModelProperty feature);
		#endregion

		/// <summary>
		/// whether model has 2 tiles observation range (distance 5) instead of adjacent locations only
		/// </summary>
		public bool HasExtendedObservationRange
		{
			get
			{
				return (Kind == ModelKind.SpecialCommando ||
					Domain == ModelDomain.Air ||
					HasFeature(ModelProperty.RadarSonar) ||
					HasFeature(ModelProperty.AcademyTraining) ||
					CarrierCapacity > 0);
			}
		}

		public bool HasZoC { get { return Domain == ModelDomain.Ground && Kind != ModelKind.SpecialCommando; } }

		public bool IsCivil { get { return Attack + AttackPlusWithBombs == 0 || Kind == ModelKind.SpecialCommando; } }

		/// <summary>
		/// whether units of this model are capable of doing settler jobs
		/// </summary>
		public bool CanDoJobs { get { return Kind == ModelKind.Settlers || Kind == ModelKind.Engineers || Kind == ModelKind.Slaves; } }

		public bool CanCaptureCity { get { return Domain == ModelDomain.Ground && !IsCivil; } }

		public bool CanBombardCity
		{
			get
			{
				return Attack + AttackPlusWithBombs > 0 &&
					((Domain == ModelDomain.Sea && HasFeature(ModelProperty.Artillery)) ||
					Domain == ModelDomain.Air);
			}
		}

		/// <summary>
		/// whether units of this model pass hostile terrain without damage
		/// </summary>
		public bool IsTerrainResistant { get { return Domain != ModelDomain.Ground || Kind == ModelKind.Engineers; } }

		/// <summary>
		/// By which value the size of a city grows when a unit of this model is added to it. 0 if adding to a city is not possible.
		/// </summary>
		public int AddsToCitySize
		{
			get
			{
				switch (Kind)
				{
					case ModelKind.Settlers: return 2;
					case ModelKind.Slaves: return 1;
					default: return 0;
				}
			}
		}
	}

	/// <summary>
	/// own model, abstract base class
	/// </summary>
	unsafe abstract class AModel : ModelBase
	{
		protected readonly Empire theEmpire;

		public AModel(Empire empire, int indexInSharedMemory)
		{
			this.theEmpire = empire;
			this.IndexInSharedMemory = indexInSharedMemory;
			address = (int*)theEmpire.address[6] + ROReadPoint.SizeOfModel * indexInSharedMemory;
		}

		protected AModel(Empire empire) // for Blueprint only
		{
			this.theEmpire = empire;
			this.IndexInSharedMemory = -1;
			address = theEmpire.address + ROReadPoint.TestFlags + 19;
		}

		public override string ToString()
		{
			if (Kind == ModelKind.OwnDesign || Kind == ModelKind.ForeignDesign)
				return string.Format("Model{0}.{1}({2}/{3}/{4})", (address[2] >> 12) & 0xF, address[2] & 0xFFF, Attack, Defense, Speed);
			else
				return string.Format("{0}", Kind);
		}

		byte* capacity { get { return (byte*)(address + 10); } }

		#region IModel Members
		/// <summary>
		/// unique model ID
		/// </summary>
		public override int ID { get { return (address[2] & 0xFFFF); } }

		public override ModelKind Kind
		{
			get
			{
				ModelKind kind = (ModelKind)(address[4] & 0xFF);
				if (kind == ModelKind.Settlers && ((address[5] >> 16) & 0xFFFF) > 150) // assume fast settlers are engineers
					return ModelKind.Engineers;
				else
					return kind;
			}
		}

		public override Nation Nation { get { return theEmpire.Us; } }
		public override ModelDomain Domain { get { return (ModelDomain)((address[4] >> 8) & 0xFF); } }
		public override int Attack { get { return (address[4] >> 16) & 0xFFFF; } }
		public override int AttackPlusWithBombs { get { return capacity[(int)ModelProperty.Bombs] * Stage.StrengthMultiplier * 2; } }
		public override int Defense { get { return address[5] & 0xFFFF; } }
		public override int Speed { get { return (address[5] >> 16) & 0xFFFF; } }
		public override int Cost { get { return address[6] & 0xFFFF; } }
		public override int CarrierCapacity { get { return capacity[(int)ModelProperty.Carrier] * Stage.TransportMultiplier; } }
		public override int Fuel { get { return capacity[(int)ModelProperty.Fuel]; } }
		public override int Weight { get { return (address[7] >> 16) & 0xFF; } }

		public override int TransportCapacity
		{
			get
			{
				if (Domain == ModelDomain.Air)
					return capacity[(int)ModelProperty.AirTransport] * Stage.TransportMultiplier;
				else
					return capacity[(int)ModelProperty.SeaTransport] * Stage.TransportMultiplier;
			}
		}

		/// <summary>
		/// Whether model has a certain feature.
		/// Does not work for capacities (Weapons, Armor, Mobility, SeaTransport, Carrier, Turbines, Bombs, Fuel), always returns false for these.
		/// </summary>
		/// <param name="feature">the feature</param>
		/// <returns>true if model has feature, false if not</returns>
		public override bool HasFeature(ModelProperty feature)
		{
			if ((int)feature >= Protocol.mcFirstNonCap)
				return capacity[(int)feature] > 0;
			else
				return false; // to maintain consistency with AForeignModel (capacities have special properties)
		}
		#endregion

		public bool RequiresDoubleSupport { get { return (address[9] & Protocol.mdDoubleSupport) != 0; } }

		public int TurnOfIntroduction { get { return (address[2] >> 16) & 0xFFFF; } }
		public Stage Stage { get { return new Stage((address[7] >> 24) & 0xFF, (address[6] >> 16) & 0xFFFF, address[7] & 0xFF, (address[7] >> 8) & 0xFF, address[8]); } }
		public int NumberBuilt { get { return address[3] & 0xFFFF; } }
		public int NumberLost { get { return (address[3] >> 16) & 0xFFFF; } }

		/// <summary>
		/// persistent custom value
		/// </summary>
		public int Status
		{
			get { return address[0]; }
			set { address[0] = value; }
		}

		#region template internal stuff
		/// <summary>
		/// INTERNAL - only access from CevoAILib classes!
		/// </summary>
		public int IndexInSharedMemory;

		int* address;
		#endregion	
	}

	/// <summary>
	/// foreign model, abstract base class
	/// </summary>
	unsafe abstract class AForeignModel : ModelBase
	{
		protected readonly Empire theEmpire;

		public AForeignModel(Empire empire, int indexInSharedMemory)
		{
			this.theEmpire = empire;
			this.indexInSharedMemory = indexInSharedMemory;
			address = (int*)theEmpire.address[9] + ROReadPoint.SizeOfModelInfo * indexInSharedMemory;
		}

		public override string ToString()
		{
			if (Kind == ModelKind.OwnDesign || Kind == ModelKind.ForeignDesign)
				return string.Format("Model{0}.{1}({2}/{3}/{4})", (address[1] >> 12) & 0xF, address[1] & 0xFFF, Attack, Defense, Speed);
			else
				return string.Format("{0}", Kind);
		}

		#region IModel Members
		/// <summary>
		/// unique model ID
		/// </summary>
		public override int ID { get { return address[1] & 0xFFFF; } }

		public override ModelKind Kind
		{
			get
			{
				ModelKind kind = (ModelKind)((address[1] >> 16) & 0xFF);
				if (kind == ModelKind.Settlers && (address[3] & 0xFFFF) > 150) // assume fast settlers are engineers
					return ModelKind.Engineers;
				else
					return kind;
			}
		}

		public override Nation Nation { get { return new Nation(theEmpire, address[0] & 0xFFFF); } }
		public override ModelDomain Domain { get { return (ModelDomain)((address[1] >> 24) & 0xFF); } }
		public override int Attack { get { return address[2] & 0xFFFF; } }
		public override int AttackPlusWithBombs { get { return (address[4] >> 16) & 0xFFFF; } }
		public override int Defense { get { return (address[2] >> 16) & 0xFFFF; } }
		public override int Speed { get { return address[3] & 0xFFFF; } }
		public override int Cost { get { return (address[3] >> 16) & 0xFFFF; } }
		public override int TransportCapacity { get { return address[4] & 0xFF; } }
		public override int Weight { get { return (address[6] >> 8) & 0xFF; } }

		public override int CarrierCapacity
		{
			get
			{
				if (Domain == ModelDomain.Sea)
					return (address[4] >> 8) & 0xFF;
				else
					return 0;
			}
		}

		public override int Fuel
		{
			get
			{
				if (Domain == ModelDomain.Air)
					return (address[4] >> 8) & 0xFF;
				else
					return 0;
			}
		}

		/// <summary>
		/// Whether model has a certain feature.
		/// Does not work for capacities (Weapons, Armor, Mobility, SeaTransport, Carrier, Turbines, Bombs, Fuel), always returns false for these.
		/// </summary>
		/// <param name="feature">the feature</param>
		/// <returns>true if model has feature, false if not</returns>
		public override bool HasFeature(ModelProperty feature)
		{
			if ((int)feature >= Protocol.mcFirstNonCap)
				return (address[5] & (1 << ((int)feature - Protocol.mcFirstNonCap))) != 0;
			else
				return false;
		}
		#endregion

		public int NumberDefeatet { get { return (address[6] >> 16) & 0xFFFF; } }

		#region template internal stuff
		int indexInSharedMemory = -1;
		int* address;

		/// <summary>
		/// INTERNAL - only access from CevoAILib classes!
		/// </summary>
		public int IndexInNationsSharedMemory { get { return (address[0] >> 16) & 0xFFFF; } }
		#endregion	
	}

	/// <summary>
	/// Model blueprint for military research. Class of AEmpire.Blueprint.
	/// </summary>
	class Blueprint : AModel
	{
		public Blueprint(Empire empire)
			: base(empire)
		{
		}

		/// <summary>
		/// Set domain of model. Do this before setting properties.
		/// </summary>
		/// <param name="domain">the domain</param>
		/// <returns>result of operation</returns>
		public PlayResult SetDomain__Turn(ModelDomain domain)
		{
			if (theEmpire.Researching == Advance.MilitaryResearch)
				return new PlayResult(PlayError.ResearchInProgress);
			else
				return theEmpire.Play(Protocol.sCreateDevModel, (int)domain);
		}

		/// <summary>
		/// Set property of model. Do this after setting the domain. Earlier calls for the same property are voided.
		/// </summary>
		/// <param name="property">the property</param>
		/// <param name="value">for capacities: count of usage, for features: 1 = use, 0 = don't use</param>
		/// <returns>result of operation</returns>
		public PlayResult SetProperty__Turn(ModelProperty property, int value)
		{
			if (theEmpire.Researching == Advance.MilitaryResearch)
				return new PlayResult(PlayError.ResearchInProgress);
			else
				return theEmpire.Play(Protocol.sSetDevModelCap + (value << 4), (int)property);
		}
	}
}
