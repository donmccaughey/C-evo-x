using System;
using System.Collections.Generic;
using Common;

namespace CevoAILib
{
	struct TravelDistance
	{
		public static TravelDistance Invalid { get { return new TravelDistance(-1, 0, true); } }

		public readonly int Turns;
		public readonly int MovementLeft;
		public readonly bool NewTurn; 
		// NewTurn does not correspond to Turns since Turns might already be increased for mountain delay or hostile
		// terrain recovery although location is reached within same turn

		public TravelDistance(int turns, int movementLeft, bool newTurn)
		{
			if (turns < 0)
			{
				this.Turns = -1;
				this.MovementLeft = 0;
				this.NewTurn = true;
			}
			else
			{
				this.Turns = turns;
				this.MovementLeft = movementLeft;
				this.NewTurn = newTurn;
			}
		}

		public override string ToString()
		{
			return string.Format("{0}.{1}", Turns, MovementLeft);
		}

		public static bool operator <(TravelDistance d1, TravelDistance d2) { return Comparison(d1, d2) < 0; }
		public static bool operator >(TravelDistance d1, TravelDistance d2) { return Comparison(d1, d2) > 0; }
		public static bool operator ==(TravelDistance d1, TravelDistance d2) { return Comparison(d1, d2) == 0; }
		public static bool operator !=(TravelDistance d1, TravelDistance d2) { return Comparison(d1, d2) != 0; }
		public static bool operator <=(TravelDistance d1, TravelDistance d2) { return Comparison(d1, d2) <= 0; }
		public static bool operator >=(TravelDistance d1, TravelDistance d2) { return Comparison(d1, d2) >= 0; }
		public override bool Equals(object obj) { return Comparison(this, (TravelDistance)obj) == 0; }
		public override int GetHashCode() { return (Turns + 2) << 12 - MovementLeft; }

		public static int Comparison(TravelDistance d1, TravelDistance d2)
		{
			return ((d1.Turns + 2) << 12) - d1.MovementLeft - ((d2.Turns + 2) << 12) + d2.MovementLeft;
		}
	}

	class Sprawl : IEnumerable<Location>
	{
		protected readonly AEmpire theEmpire;
		protected readonly int originID;
		protected readonly int startValue;
		protected int approachLocationID = -1;
		protected bool approachLocationWasIterated = false;
		protected readonly AddressPriorityQueue Q;
		protected int currentLocationID = -1;
		protected int currentValue = 0;
		protected int[] neighborIDs = new int[8];
		protected ushort[] backtrace;
		Enumerator enumerator = null;

		public Sprawl(AEmpire empire, Location origin, int startValue)
		{
			this.theEmpire = empire;
			this.originID = origin.ID;
			this.startValue = startValue;
			Q = new AddressPriorityQueue(empire.Map.Size - 1);
			backtrace = new ushort[empire.Map.Size];
		}

		public bool WasIterated(Location location)
		{
			if (location.ID == approachLocationID)
				return approachLocationWasIterated;
			else
			{
				int distance = Q.Distance(location.ID);
				return (distance != AddressPriorityQueue.Unknown && distance != AddressPriorityQueue.Disallowed);
			}
		}

		public Location[] Path(Location location)
		{
			if (WasIterated(location))
			{
				int stepCount = 0;
				ushort locationID = (ushort)location.ID;
				if (locationID == approachLocationID)
					locationID = backtrace[locationID];
				while (locationID != originID)
				{
					stepCount++;
					locationID = backtrace[locationID];
				}
				Location[] result = new Location[stepCount];
				locationID = (ushort)location.ID;
				if (locationID == approachLocationID)
					locationID = backtrace[locationID];
				while (locationID != originID)
				{
					stepCount--;
					result[stepCount] = new Location(theEmpire, locationID);
					locationID = backtrace[locationID];
				}
				return result;
			}
			else
				return null; // not reached yet
		}

		protected enum StepValidity { OK, ForbiddenStep, ForbiddenLocation }

		protected virtual StepValidity Step(int fromLocationId, int toLocationId, int distance, int fromValue, ref int toValue)
		{
			toValue = fromValue + distance;
			return StepValidity.OK;
		}

		protected virtual bool MoveNext()
		{
			bool approached = false;
			if (currentLocationID >= 0 && currentLocationID != approachLocationID)
			{ // first check to reach neighbors from last iterated location
				theEmpire.Map.GetNeighborIDs(currentLocationID, neighborIDs);
				for (int V8 = 0; V8 < 8; V8++)
				{
					int nextLocationID = neighborIDs[V8];
					if (nextLocationID >= 0)
					{
						if (nextLocationID == approachLocationID && !approachLocationWasIterated)
						{
							backtrace[nextLocationID] = (ushort)currentLocationID;
							approached = true;
						}
						else if (Q.Distance(nextLocationID) == AddressPriorityQueue.Unknown)
						{
							int nextValue = 0;
							switch (Step(currentLocationID, nextLocationID, 2 + (V8 & 1), currentValue, ref nextValue))
							{
								case StepValidity.OK:
									{
										if (Q.Offer(nextLocationID, nextValue))
											backtrace[nextLocationID] = (ushort)currentLocationID;
										break;
									}
								case StepValidity.ForbiddenStep: break; // just don't offer
								case StepValidity.ForbiddenLocation: Q.Disallow(nextLocationID); break; // don't try to reach from every direction again
							}
						}
					}
				}
			}

			if (approached)
			{
				currentLocationID = approachLocationID;
				approachLocationWasIterated = true;
				return true;
			}
			else
				return Q.TakeClosest(out currentLocationID, out currentValue);
		}

		void EnumerationEnded()
		{
			if (enumerator == null)
				throw new Exception("Error in Sprawl: Only started foreach loop can end!");
			enumerator.DisposeEvent -= EnumerationEnded;
			enumerator = null;
		}

		#region IEnumerable members
		class Enumerator : IEnumerator<Location>
		{
			Sprawl parent;
			public Enumerator(Sprawl parent) { this.parent = parent; }
			public delegate void DisposeEventHandler();
			public event DisposeEventHandler DisposeEvent;
			public void Reset() { throw new NotSupportedException(); }
			public bool MoveNext() { return parent.MoveNext(); }
			public void Dispose() { DisposeEvent(); }
			public Location Current { get { return new Location(parent.theEmpire, parent.currentLocationID); } }
			object System.Collections.IEnumerator.Current { get { return Current; } }
		}

		public IEnumerator<Location> GetEnumerator()
		{
			if (enumerator != null)
				throw new Exception("Sprawl: Nested iteration is not supported!");
			Q.Clear();
			Q.Offer(originID, startValue);
			currentLocationID = -1;
			approachLocationWasIterated = false;
			enumerator = new Enumerator(this);
			enumerator.DisposeEvent += EnumerationEnded;
			return enumerator;
		}
		System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator() { return GetEnumerator(); }
		#endregion
	}

	/// <summary>
	/// A formation iterator, where the formation might be an island, waters or coherent tiles of the Shore terrain type only.
	/// Tiles not discovered yet always count as end of formation and are never iterated.
	/// </summary>
	class RestrictedSprawl : Sprawl
	{
		public enum TerrainGroup { AllLand, AllWater, Shore }

		TerrainGroup restriction;

		public RestrictedSprawl(AEmpire empire, Location origin, TerrainGroup restriction)
			: base(empire, origin, 0)
		{
			this.restriction = restriction;
		}

		public int Distance(Location location)
		{
			int distance = Q.Distance(location.ID);
			if (distance != AddressPriorityQueue.Unknown && distance != AddressPriorityQueue.Disallowed)
				return distance;
			else
				return -1; // not reached yet
		}

		protected override StepValidity Step(int fromLocationId, int toLocationId, int distance, int fromValue, ref int toValue)
		{
			Location toLocation = new Location(theEmpire, toLocationId);
			toValue = fromValue + distance;
			switch (restriction)
			{
				default: // TerrainGroup.AllLand:
					if (toLocation.IsDiscovered && !toLocation.IsWater)
						return StepValidity.OK;
					else
						return StepValidity.ForbiddenLocation;

				case TerrainGroup.AllWater:
					if (toLocation.IsDiscovered && toLocation.IsWater)
						return StepValidity.OK;
					else
						return StepValidity.ForbiddenLocation;

				case TerrainGroup.Shore:
					if (toLocation.BaseTerrain == Terrain.Shore)
						return StepValidity.OK;
					else
						return StepValidity.ForbiddenLocation;
			}
		}
	}

	/// <summary>
	/// A unit movement iterator.
	/// </summary>
	class TravelSprawl : Sprawl
	{
		static readonly MovementKind[] rawTerrainMovementKind = 
		{
			MovementKind.Plain, //Ocn
			MovementKind.Plain, //Sho
			MovementKind.Plain, //Gra
			MovementKind.Plain, //Dst
			MovementKind.Plain, //Pra
			MovementKind.Plain, //Tun
			MovementKind.Difficult, //Arc
			MovementKind.Difficult, //Swa
			MovementKind.Difficult, //-
			MovementKind.Difficult, //For
			MovementKind.Difficult, //Hil
			MovementKind.Mountains //Mou
		};

		[Flags]
		public enum Options
		{
			None = 0x00, IgnoreBlocking = 0x001, IgnoreZoC = 0x002, IgnoreTreaty = 0x004, EmptyPlanet = 0x007,
			ZeroCostRailroad = 0x010, TerrainResistant = 0x020, Overweight = 0x040, Alpine = 0x080, Navigation = 0x100
		}

		const int NewTurn = 0x1;

		protected ModelDomain domain;
		protected int speed;
		protected Options options;
		protected int baseDifficultMoveCost;
		protected int baseRailroadMoveCost;

		/// <summary>
		/// Create general unit movement iterator for an existing or hypothetical unit.
		/// </summary>
		/// <param name="empire">empire</param>
		/// <param name="nation">nation of the unit</param>
		/// <param name="origin">initial unit location</param>
		/// <param name="domain">unit domain</param>
		/// <param name="unitSpeed">speed of the unit</param>
		/// <param name="initialMovementLeft">initial movement points left</param>
		/// <param name="options">options</param>
		public TravelSprawl(AEmpire empire, Nation nation, Location origin, ModelDomain domain, int unitSpeed, int initialMovementLeft, Options options)
			: base(empire, origin, unitSpeed - initialMovementLeft)
		{
			this.domain = domain;
			this.speed = unitSpeed;
			this.options = options;
			if (nation != empire.Us)
				options |= Options.EmptyPlanet; // default location info relates to own nation, so it can't be considered then
			if (nation.HasWonder(Building.ShinkansenExpress))
				options |= Options.ZeroCostRailroad;
			if (nation.HasWonder(Building.HangingGardens))
				options |= Options.TerrainResistant;
			baseDifficultMoveCost = 100 + (unitSpeed - 150) / 5;
			if ((options & Options.ZeroCostRailroad) != 0)
				baseRailroadMoveCost = 0;
			else
				baseRailroadMoveCost = (unitSpeed / 50) * 4;
		}

		/// <summary>
		/// Unit movement iterator for an own unit.
		/// </summary>
		/// <param name="empire">empire</param>
		/// <param name="unit">the unit</param>
		public TravelSprawl(AEmpire empire, AUnit unit)
			: this(empire, unit.Nation, unit.Location, unit.Model.Domain, unit.Speed, unit.MovementLeft, Options.None)
		{
			SetOptionsFromUnit(unit);
		}

		/// <summary>
		/// Special unit movement iterator when the goal is to move an own unit adjacent to a certain location.
		/// </summary>
		/// <param name="empire">empire</param>
		/// <param name="unit">the unit</param>
		/// <param name="approachLocation">loaction to approach to</param>
		public TravelSprawl(AEmpire empire, AUnit unit, Location approachLocation)
			: this(empire, unit)
		{
			approachLocationID = approachLocation.ID;
			if (unit.Location != approachLocation)
				Q.Disallow(approachLocationID);
		}

		/// <summary>
		/// Unit movement iterator for a foreign unit.
		/// </summary>
		/// <param name="empire">empire</param>
		/// <param name="unit">the unit</param>
		public TravelSprawl(AEmpire empire, ForeignUnit unit)
			: this(empire, unit.Nation, unit.Location, unit.Model.Domain, unit.Speed, unit.Speed, Options.None)
		{
			SetOptionsFromUnit(unit);
		}

		public TravelDistance Distance(Location location)
		{
			int distance = 0;
			if (location.ID == approachLocationID)
			{
				if (!approachLocationWasIterated)
					return TravelDistance.Invalid; // not reached yet

				distance = Q.Distance(backtrace[approachLocationID]);
			}
			else
				distance = Q.Distance(location.ID);
			if (distance != AddressPriorityQueue.Unknown && distance != AddressPriorityQueue.Disallowed)
				return new TravelDistance(distance >> 12, speed - ((distance >> 1) & 0x7FF), (distance & NewTurn) != 0);
			else
				return TravelDistance.Invalid; // not reached yet
		}

		/// <summary>
		/// damage the unit would receive from hostile terrain travelling to a location before it reaches an intermediate non-hostile terrain location
		/// </summary>
		/// <param name="location">the location to travel to</param>
		/// <returns>the damage</returns>
		public int DamageToNextNonHostileLocation(Location fromLocation, Location toLocation)
		{
			if ((options & Options.TerrainResistant) == 0 && WasIterated(toLocation))
			{
				int damage = 0;
				ushort locationID = (ushort)toLocation.ID;
				if (locationID == approachLocationID)
					locationID = backtrace[locationID];
				int sourceTerrainDamage = 0;
				int sourceDistance = 0;
				int destinationTerrainDamage = new Location(theEmpire, locationID).OneTurnHostileDamage;
				int destinationDistance = Q.Distance(locationID);
				while (locationID != fromLocation.ID)
				{
					locationID = backtrace[locationID];
					sourceTerrainDamage = new Location(theEmpire, locationID).OneTurnHostileDamage;
					sourceDistance = Q.Distance(locationID);
					if (locationID != fromLocation.ID && sourceTerrainDamage == 0)
						damage = 0;
					else if ((destinationDistance & NewTurn) != 0)
					{ // move has to wait for next turn
						if (sourceTerrainDamage > 0 &&
							((sourceDistance >> 1) & 0x7FF) < speed) // movement left
							damage += (sourceTerrainDamage * (speed - ((sourceDistance >> 1) & 0x7FF)) - 1) / speed + 1; // unit spends rest of turn here
						if (destinationTerrainDamage > 0)
							damage += (destinationTerrainDamage * ((destinationDistance >> 1) & 0x7FF) - 1) / speed + 1; // move
					}
					else
					{
						if (destinationTerrainDamage > 0)
							damage += (destinationTerrainDamage * (((destinationDistance >> 1) & 0x7FF) - ((sourceDistance >> 1) & 0x7FF)) - 1) / speed + 1; // move
					}
					destinationTerrainDamage = sourceTerrainDamage;
					destinationDistance = sourceDistance;
				}
				return damage;
			}
			else
				return 0;
		}

		void SetOptionsFromUnit(IUnitInfo unit)
		{
			if (unit.Model.Domain != ModelDomain.Ground || unit.Model.Kind == ModelKind.SpecialCommando)
				options |= Options.IgnoreZoC;
			if (unit.Model.Kind == ModelKind.SpecialCommando)
				options |= Options.IgnoreTreaty;
			if (domain != ModelDomain.Ground || unit.IsTerrainResistant)
				options |= Options.TerrainResistant;
			if (unit.Model.HasFeature(ModelProperty.Overweight))
				options |= Options.Overweight;
			if (unit.Model.HasFeature(ModelProperty.Alpine))
				options |= Options.Alpine;
			if (unit.Model.HasFeature(ModelProperty.Navigation))
				options |= Options.Navigation;
		}

		unsafe protected override StepValidity Step(int fromLocationID, int toLocationID, int distance, int fromValue, ref int toValue)
		{
			switch (domain)
			{
				default: // case ModelDomain.Ground
					{
						int fromTile = theEmpire.Map.Ground[fromLocationID];
						int toTile = theEmpire.Map.Ground[toLocationID];
						int moveCost = 100;

						if ((toTile & 0x1F) == 0x1F)
							return StepValidity.ForbiddenLocation; // not discovered

						if ((toTile & 0x600000) == 0x400000 && (options & Options.IgnoreBlocking) == 0)
							return StepValidity.ForbiddenLocation; // foreign unit

						if ((toTile & 0x1E) == 0x00)
							return StepValidity.ForbiddenLocation; // water

						if ((toTile & 0x40000000) != 0 && (options & Options.IgnoreTreaty) == 0)
						{
							if ((fromTile & 0x40000000) == 0 ||
								new Location(theEmpire, fromLocationID).TerritoryNation != new Location(theEmpire, toLocationID).TerritoryNation)
								return StepValidity.ForbiddenStep; // treaty
						}

						if ((options & Options.IgnoreZoC) == 0 &&
							(fromTile & 0x800000) == 0 && // not coming out of city
							(toTile & 0xA00000) != 0xA00000 && // not moving into own city
							(fromTile & 0x20000000) != 0 && // fromLocation in ZoC
							(toTile & 0x30000000) == 0x20000000) // toLocation in ZoC
							return StepValidity.ForbiddenStep; // ZoC violation

						if ((fromTile & 0x800200) != 0 && (toTile & 0x800200) != 0) // both locations have railroad or city
							moveCost = baseRailroadMoveCost;
						else if ((options & Options.Alpine) != 0 ||
							((fromTile & 0x800300) != 0 && (toTile & 0x800300) != 0) || // both locations have road, railroad or city
							(fromTile & toTile & 0x480) != 0) // both locations have river or both locations have canal
						{
							if ((options & Options.Overweight) != 0)
								moveCost = 80;
							else
								moveCost = 40;
						}
						else
						{
							if ((options & Options.Overweight) != 0)
								return StepValidity.ForbiddenStep;

							switch (rawTerrainMovementKind[toTile & 0xF])
							{
								case MovementKind.Plain: { moveCost = 100; break; }
								case MovementKind.Difficult: { moveCost = baseDifficultMoveCost; break; }

								case MovementKind.Mountains:
									{
										if (((fromValue >> 1) & 0x7FF) == 0) // only possible in first step
											toValue = (fromValue & 0x7FFFF000) + 0x1000 + (speed << 1);
										else
										{
											toValue = ((fromValue & 0x7FFFF000) + 0x2000 + (speed << 1)) | NewTurn; // must wait for next turn
											if ((options & Options.TerrainResistant) == 0
												&& ((fromValue >> 1) & 0x7FF) < speed // movement left
												&& (fromTile & 0x800480) == 0 // no city, river or canal
												&& (fromTile & 0xF000) != 0x5000 // no base
												&& ((fromTile & 0x1F) == 0x06 || (fromTile & 0x3F) == 0x03)) // arctic or desert but not an oasis
											{ // add recovery turns for waiting on hostile terrain
												int waitDamage = (Cevo.DamagePerTurnInDesert * (speed - ((fromValue >> 1) & 0x7FF)) - 1) / speed + 1;
												toValue += ((waitDamage + 4) >> 3) << 12; // actually: toValue += Math.Round(waitDamage / Cevo.RecoveryOutsideCity) << 12
											}
										}
										return StepValidity.OK;
									}
							}
						}
						if (distance == 3)
							moveCost += moveCost >> 1;
						int damageMovement = 0;
						if ((options & Options.TerrainResistant) == 0
							&& (toTile & 0x800480) == 0 // no city, river or canal
							&& (toTile & 0xF000) != 0x5000 // no base											
							&& ((toTile & 0x1F) == 0x06 || (toTile & 0x3F) == 0x03)) // arctic or desert but not an oasis
							damageMovement = moveCost;

						if (((fromValue >> 1) & 0x7FF) + moveCost <= speed && ((fromValue >> 1) & 0x7FF) < speed)
							toValue = (fromValue & ~NewTurn) + (moveCost << 1);
						else
						{
							toValue = ((fromValue & 0x7FFFF000) + 0x1000 + (moveCost << 1)) | NewTurn; // must wait for next turn

							if ((options & Options.TerrainResistant) == 0
								&& (fromTile & 0x800480) == 0 // no city, river or canal
								&& (fromTile & 0xF000) != 0x5000 // no base											
								&& ((fromTile & 0x1F) == 0x06 || (fromTile & 0x3F) == 0x03)) // arctic or desert but not an oasis
								damageMovement += speed - ((fromValue >> 1) & 0x7FF);
						}
						if (damageMovement > 0) // add recovery turns for waiting on hostile terrain and moving in it
						{
							int damage = (Cevo.DamagePerTurnInDesert * damageMovement - 1) / speed + 1;
							toValue += ((damage + 4) >> 3) << 12; // actually: toValue += Math.Round(damage / Cevo.RecoveryOutsideCity) << 12
						}

						return StepValidity.OK;
					}

				case ModelDomain.Sea:
					{
						int toTile = theEmpire.Map.Ground[toLocationID];
						if (((toTile & 0x800400) == 0 && (toTile & 0x1E) != 0x00))
							return StepValidity.ForbiddenLocation; // no city, no canal, no water
						if ((toTile & 0x1F) == 0x00 && (options & Options.Navigation) == 0)
							return StepValidity.ForbiddenLocation; // open sea, no navigation

						int moveCost = 100;
						if (distance == 3)
							moveCost = 150;
						if (((fromValue >> 1) & 0x7FF) + moveCost <= speed && ((fromValue >> 1) & 0x7FF) < speed)
							toValue = (fromValue & ~NewTurn) + (moveCost << 1);
						else
							toValue = ((fromValue & 0x7FFFF000) + 0x1000 + (moveCost << 1)) | NewTurn; // must wait for next turn
						return StepValidity.OK;
					}

				case ModelDomain.Air:
					{
						int moveCost = 100;
						if (distance == 3)
							moveCost = 150;
						if (((fromValue >> 1) & 0x7FF) + moveCost <= speed && ((fromValue >> 1) & 0x7FF) < speed)
							toValue = (fromValue & ~NewTurn) + (moveCost << 1);
						else
							toValue = ((fromValue & 0x7FFFF000) + 0x1000 + (moveCost << 1)) | NewTurn; // must wait for next turn
						return StepValidity.OK;
					}
			}
		}
	}

	/// <summary>
	/// An island iterator. Same set of locations as a RestrictedSprawl with AllLand option but with different order of
	/// iteration. Simulates the movement of a standard slow ground unit so tiles that are easier to reach are
	/// iterated earlier.
	/// Tiles not discovered yet count as end of the island and are never iterated.
	/// </summary>
	class ExploreSprawl : TravelSprawl
	{
		public ExploreSprawl(AEmpire empire, Location origin)
			: base(empire, empire.Us, origin, ModelDomain.Ground, 150, 150, Options.EmptyPlanet)
		{
		}
	}
}
