using System;
using System.Collections.Generic;
using AI;

namespace CevoAILib
{
	enum Terrain
	{
		Unknown = 0x00, DeadLands = 0x01, Ocean = 0x02, Shore = 0x03, Grassland = 0x04, Desert = 0x05, Prairie = 0x06, 
		Tundra = 0x07, Arctic = 0x08, Swamp = 0x09, Plains = 0x0A, Forest = 0x0B, Hills = 0x0C, Mountains = 0x0D,
		Cobalt = 0x11, Fish = 0x13, Oasis = 0x15, Wheat = 0x16, Gold = 0x17, Ivory = 0x18, Peat = 0x19, Game = 0x1B, Wine = 0x1C, Iron = 0x1D,
		Uranium = 0x21, Manganese = 0x23, Oil = 0x25, Bauxite = 0x26, Gas = 0x27, MineralWater = 0x2B, Coal = 0x2C, Diamonds = 0x2D, Mercury = 0x31
	}

	enum TerrainImprovement { None = 0x0, Irrigation = 0x1, Farm = 0x2, Mine = 0x3, Fortress = 0x4, Base = 0x5 }

	unsafe sealed class Map
	{
		readonly AEmpire theEmpire;
		public readonly int Size;
		public readonly int SizeX;
		public readonly int SizeY;
		public readonly int LandMass;

		public Map(AEmpire empire, int sizeX, int sizeY, int landMass)
		{
			this.theEmpire = empire;
			Size = sizeX * sizeY;
			this.SizeX = sizeX;
			this.SizeY = sizeY >> 1;
			this.LandMass = landMass;
			Ground = (int*)empire.address[1];
			ObservedLast = (short*)empire.address[2];
			Territory = (sbyte*)empire.address[3];
		}

		/// <summary>
		/// during own turn, trigger refresh of display of all values set using Location.SetDebugDisplay
		/// (not necessary in the end of the turn because refresh happens automatically then)
		/// </summary>
		public void RefreshDebugDisplay()
		{
			theEmpire.Play(Protocol.sRefreshDebugMap);
		}

		#region template internal stuff
		/// <summary>
		/// INTERNAL - only access from CevoAILib classes!
		/// </summary>
		public readonly int* Ground;

		/// <summary>
		/// INTERNAL - only access from CevoAILib classes!
		/// </summary>
		public readonly short* ObservedLast;

		/// <summary>
		/// INTERNAL - only access from CevoAILib classes!
		/// </summary>
		public readonly sbyte* Territory;

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// special return values: -0x1000 southpole, -0xFFF..-1 northpole
		/// </summary>
		/// <param name="locationID">id of base location</param>
		/// <param name="neighborIDs">return value array, must have length of 8</param>
		public void GetNeighborIDs(int locationID, int[] neighborIDs)
		{
			int wrap = SizeX;
			int y0 = locationID / wrap;
			int x0 = locationID - y0 * wrap;

			neighborIDs[1] = locationID + wrap * 2;
			neighborIDs[3] = locationID - 1;
			neighborIDs[5] = locationID - wrap * 2;
			neighborIDs[7] = locationID + 1;
			locationID += y0 & 1;
			neighborIDs[0] = locationID + wrap;
			neighborIDs[2] = locationID + wrap - 1;
			neighborIDs[4] = locationID - wrap - 1;
			neighborIDs[6] = locationID - wrap;

			// world is round!
			if (x0 < wrap - 1)
			{
				if (x0 == 0)
				{
					neighborIDs[3] += wrap;
					if ((y0 & 1) == 0)
					{
						neighborIDs[2] += wrap;
						neighborIDs[4] += wrap;
					}
				}
			}
			else
			{
				neighborIDs[7] -= wrap;
				if ((y0 & 1) == 1)
				{
					neighborIDs[0] -= wrap;
					neighborIDs[6] -= wrap;
				}
			}

			// check south pole
			switch ((SizeY << 1) - y0)
			{
				case 1:
					{
						neighborIDs[0] = -0x1000;
						neighborIDs[1] = -0x1000;
						neighborIDs[2] = -0x1000;
						break;
					}
				case 2:
					{
						neighborIDs[1] = -0x1000;
						break;
					}
			}
		}

		/// <summary>
		/// INTERNAL - only call from CevoAILib classes!
		/// special return values: -0x2000 gap (V21 invalid), -0x1000 southpole, -0xFFF..-1 northpole
		/// </summary>
		/// <param name="locationID">id of base location</param>
		/// <param name="distance5IDs">return value array, must have length of 28</param>
		public void GetDistance5IDs(int locationID, int[] distance5IDs)
		{
			int wrap = SizeX;
			int y0 = locationID / wrap;
			int xComponent0 = locationID - y0 * wrap - 1;
			int xComponentSwitch = xComponent0 - 1 + (y0 & 1);
			if (xComponent0 < 0)
				xComponent0 += wrap;
			if (xComponentSwitch < 0)
				xComponentSwitch += wrap;
			xComponentSwitch = xComponentSwitch ^ xComponent0; // allows easy switching between 2 values
			int yComponent = wrap * (y0 - 3); // may start negative
			int V21 = 0;
			int bit = 1;
			for (int dy = 0; dy < 7; dy++)
			{
				if (yComponent < Size)
				{
					xComponent0 = xComponent0 ^ xComponentSwitch; // switch
					int xComponent = xComponent0;
					for (int dx = 0; dx < 4; dx++)
					{
						if ((bit & 0x67F7F76) != 0)
							distance5IDs[V21] = xComponent + yComponent;
						else
							distance5IDs[V21] = -0x2000;
						xComponent++;
						if (xComponent >= wrap)
							xComponent -= wrap;
						V21++;
						bit <<= 1;
					}
					yComponent += wrap;
				}
				else
				{
					for (int dx = 0; dx < 4; dx++)
					{
						if ((bit & 0x67F7F76) != 0)
							distance5IDs[V21] = -0x1000;
						else
							distance5IDs[V21] = -0x2000;
						V21++;
						bit <<= 1;
					}
				}
			}
		}
		#endregion
	}

	struct RC // relative coordinates
	{
		public readonly int a;
		public readonly int b;

		public RC(int a, int b)
		{
			this.a = a;
			this.b = b;
		}

		public override string ToString()
		{
			return string.Format("({0},{1})",a, b);
		}

		public static bool operator ==(RC RC1, RC RC2) { return RC1.a == RC2.a && RC1.b == RC2.b; }
		public static bool operator !=(RC RC1, RC RC2) { return RC1.a != RC2.a || RC1.b != RC2.b; }
		public override bool Equals(object obj) { return a == ((RC)obj).a && b == ((RC)obj).b; }
		public override int GetHashCode() { return a + (b << 16); }

		public static RC operator +(RC RC1, RC RC2) { return new RC(RC1.a + RC2.a, RC1.b + RC2.b); }
		public static RC operator -(RC RC1, RC RC2) { return new RC(RC1.a - RC2.a, RC1.b - RC2.b); }

		/// <summary>
		/// Absolute distance regardless of direction.
		/// One tile counts 2 if straight, 3 if diagonal.
		/// </summary>
		public int Distance 
		{
			get 
			{
				int adx = Math.Abs(a-b);
				int ady = Math.Abs(a+b);
				return adx + ady + (Math.Abs(adx - ady) >> 1);
			} 
		}
	}

	struct OtherLocation
	{
		public readonly Location Location;
		public readonly RC RC;

		public OtherLocation(Location location, RC RC) // location is the other location, RC the coordinate relative to an origin tile not stored
		{
			this.Location = location;
			this.RC = RC;
		}
	}

	struct JobProgress
	{
		public readonly int Required;
		public readonly int Done;
		public readonly int NextTurnPlus;

		public JobProgress(int Required, int Done, int NextTurnPlus)
		{
			this.Required = Required;
			this.Done = Done;
			this.NextTurnPlus = NextTurnPlus;
		}
	}

	unsafe struct Location
	{
		readonly AEmpire theEmpire;
		public readonly int ID;
		readonly int* address;

		static readonly int[] V8_a = { 1, 1, 0, -1, -1, -1, 0, 1 };
		static readonly int[] V8_b = { 0, 1, 1, 1, 0, -1, -1, -1 };

		// for internal use, if used check < Map.Size, because not checked internally
		public Location(AEmpire empire, int ID)
		{
			this.theEmpire = empire;
			this.ID = ID;
			this.address = theEmpire.Map.Ground + ID;
		}

		public override string ToString()
		{
			return string.Format("{0}", ID);
		}

		public static bool operator ==(Location location1, Location location2) { return location1.ID == location2.ID; }
		public static bool operator !=(Location location1, Location location2) { return location1.ID != location2.ID; }
		public override bool Equals(object obj) { return ID == ((Location)obj).ID; }
		public override int GetHashCode() { return ID; }

		public static RC operator -(Location location1, Location location2)
		{
			int wrap = location2.theEmpire.Map.SizeX;
			int y1 = location2.ID / wrap;
			int x1 = location2.ID - y1 * wrap;
			int dy = location1.ID / wrap;
			int dx = location1.ID - dy * wrap;
			dx = ((dx * 2 + (dy & 1)) - (x1 * 2 + (y1 & 1)) + 3 * wrap) % (2 * wrap) - wrap;
			dy -= y1;
			return new RC((dx + dy) >> 1, (dy - dx) >> 1);
		}

		public static Location operator +(Location location, RC RC)
		{
			int wrap = location.theEmpire.Map.SizeX;
			int y0 = location.ID / wrap;
			int otherLocationID = (location.ID + ((RC.a - RC.b + (y0 & 1) + wrap * 2) >> 1)) % wrap + wrap * (y0 + RC.a + RC.b);
			if (otherLocationID >= location.theEmpire.Map.Size)
				otherLocationID = -0x1000;
			return new Location(location.theEmpire, otherLocationID);
		}

		public static Location operator -(Location location, RC RC) { return location + new RC(-RC.a, -RC.b); }

		/// <summary>
		/// true if location is on the map, false if beyond upper or lower edge of the map
		/// </summary>
		public bool IsValid { get { return ID >= 0; } }

		/// <summary>
		/// set number shown on debug map
		/// </summary>
		/// <param name="value">number, 0 for nothing</param>
		public void SetDebugDisplay(int value)
		{
			if (ID >= 0)
				theEmpire.debugMapAddress[ID] = value;
		}

		/// <summary>
		/// Set of all adjacent locations.
		/// All locations returned are on the map.
		/// Usually the array has 8 elements, but it's less if the location is close to the upper or lower edge of the map.
		/// Take the result as a set with no specific order. Don't rely on the array indices to always have the same meaning.
		/// </summary>
		public OtherLocation[] Neighbors
		{
			get
			{
				int[] neighborIDs = new int[8];
				theEmpire.Map.GetNeighborIDs(ID, neighborIDs);
				int count = 0;
				for (int V8 = 0; V8 < 8; V8++)
				{
					if (neighborIDs[V8] >= 0)
						count++;
				}
				OtherLocation[] neighbors = new OtherLocation[count];
				count = 0;
				for (int V8 = 0; V8 < 8; V8++)
				{
					if (neighborIDs[V8] >= 0)
					{
						neighbors[count] = new OtherLocation(new Location(theEmpire, neighborIDs[V8]), new RC(V8_a[V8], V8_b[V8]));
						count++;
					}
				}
				return neighbors;
			}
		}

		/// <summary>
		/// Set of all locations with a distance of 5 or less, including the location itself.
		/// This is the city radius, and also it's the extended visibility radius of units.
		/// All locations returned are on the map.
		/// Usually the array has 21 elements, but it's less if the location is close to the upper or lower edge of the map.
		/// Take the result as a set with no specific order. Don't rely on the array indices to always have the same meaning.
		/// </summary>
		public OtherLocation[] Distance5Area
		{
			get
			{
				int[] distance5IDs = new int[28];
				theEmpire.Map.GetDistance5IDs(ID, distance5IDs);
				int count = 0;
				for (int V21 = 1; V21 < 27; V21++)
				{
					if (distance5IDs[V21] >= 0)
						count++;
				}
				OtherLocation[] distance5Area = new OtherLocation[count];
				count = 0;
				for (int V21 = 1; V21 < 27; V21++)
				{
					if (distance5IDs[V21] >= 0)
					{
						int dy = (V21 >> 2) - 3;
						int dx = ((V21 & 3) << 1) - 3 + ((dy + 3) & 1);
						distance5Area[count] = new OtherLocation(new Location(theEmpire, distance5IDs[V21]), new RC((dx + dy) >> 1, (dy - dx) >> 1));
						count++;
					}
				}
				return distance5Area;
			}
		}

		/// <summary>
		/// whether this location is adjacent to another one
		/// </summary>
		/// <param name="otherLocation">the other location</param>
		/// <returns>true if adjacent, false if not adjacent, also false if identical</returns>
		public bool IsNeighborOf(Location otherLocation)
		{
			int[] neighborIDs = new int[8];
			theEmpire.Map.GetNeighborIDs(ID, neighborIDs);
			return Array.IndexOf<int>(neighborIDs, otherLocation.ID) >= 0;
		}

		#region basic info
		/// <summary>
		/// Simulation of latitude, returns value between -90 and 90.
		/// (May be used for strategic consideration and climate estimation.)
		/// </summary>
		public int Latitude { get { return 90 - (ID / theEmpire.Map.SizeX) * 180 / ((theEmpire.Map.SizeY << 1) - 1); } }

		/// <summary>
		/// whether the tile at this location was visible to an own unit or city at any point in the game
		/// </summary>
		public bool IsDiscovered { get { return (*address & 0x1F) != 0x1F; } }

		/// <summary>
		/// whether the tile is visible to an own unit or city in this turn
		/// </summary>
		public bool IsObserved { get { return (*address & 0x100000) != 0; } }

		/// <summary>
		/// whether the tile is visible to an own special commando or spy plane in this turn
		/// </summary>
		public bool IsSpiedOut { get { return (*address & 0x20000) != 0; } }

		/// <summary>
		/// turn in which the tile was visible to an own unit or city last
		/// </summary>
		public int TurnObservedLast { get { return theEmpire.Map.ObservedLast[ID]; } }

		/// <summary>
		/// whether an own city at this location would be protected by the great wall
		/// </summary>
		public bool IsGreatWallProtected { get { return (*address & 0x10000) != 0; } }

		/// <summary>
		/// Whether tile can not be moved to because it's in the territory of a nation that we are in peace with but not allied.
		/// </summary>
		public bool IsDisallowedTerritory { get { return (*address & 0x40000000) != 0; } }

		/// <summary>
		/// whether units located here have 2 tiles observation range (distance 5) instead of adjacent locations only
		/// </summary>
		public bool ProvidesExtendedObservationRange
		{
			get
			{
				return BaseTerrain == Terrain.Mountains || 
					Improvement == TerrainImprovement.Fortress || 
					Improvement == TerrainImprovement.Base;
			}
		}
		#endregion

		#region terrain
		/// <summary>
		/// Exact terrain type including special resources.
		/// </summary>
		public Terrain Terrain
		{
			get
			{
				int raw = *address;
				if ((raw & 0x1F) == 0x1F)
					return Terrain.Unknown;
				else if ((raw & 0x1000000) != 0)
					return Terrain.DeadLands + ((raw >> 21) & 0x30);
				else if ((raw & 0x7F) == 0x22)
					return Terrain.Plains;
				else
					return (Terrain)((raw & 0xF) + ((raw >> 1) & 0x30) + 2);
			}
		}

		/// <summary>
		/// Base terrain type not including special resources.
		/// </summary>
		public Terrain BaseTerrain { get { return (Terrain)((int)Terrain & 0xF); } }

		/// <summary>
		/// Whether it's a water tile (terrain Ocean or Shore).
		/// </summary>
		public bool IsWater { get { return (*address & 0x1E) == 0x00; } }

		/// <summary>
		/// damage dealt to a unit which is not resistant to hostile terrain if that unit stays at this location for a full turn
		/// </summary>
		public int OneTurnHostileDamage
		{
			get
			{
				if ((*address & 0x800480) != 0 || // city, river or canal
					(*address & 0xF000) == 0x5000) // base
					return 0;
				else if ((*address & 0x1F) == 0x03 && (*address & 0x60) != 0x20) // desert but not an oasis
					return Cevo.DamagePerTurnInDesert;
				else if ((*address & 0x1F) == 0x06) // arctic
					return Cevo.DamagePerTurnInArctic;
				else
					return 0;
			}
		}

		public bool HasRiver { get { return (*address & 0x80) != 0; } }
		public bool HasRoad { get { return (*address & 0x100) != 0; } }
		public bool HasRailRoad { get { return (*address & 0x200) != 0; } }
		public bool HasCanal { get { return (*address & 0x400) != 0; } }
		public bool IsPolluted { get { return (*address & 0x800) != 0; } }

		/// <summary>
		/// Terrain improvement built on this tile.
		/// </summary>
		public TerrainImprovement Improvement { get { return (TerrainImprovement)((*address >> 12) & 0xF); } }
		#endregion

		/// <summary>
		/// Query progress of a specific settler job at this location
		/// </summary>
		/// <param name="job">the job</param>
		/// <param name="progress">the progress</param>
		/// <returns>result of operation</returns>
		public PlayResult GetJobProgress__Turn(Job job, out JobProgress progress)
		{
			fixed (int* jobProgressData = new int[Protocol.nJob * 3])
			{
				PlayResult result = theEmpire.Play(Protocol.sGetJobProgress, ID, jobProgressData);
				progress = new JobProgress(jobProgressData[(int)job * 3], jobProgressData[(int)job * 3 + 1], jobProgressData[(int)job * 3 + 2]);
				return result;
			}
		}

		/// <summary>
		/// Nation to who's territory this location belongs. Nation.None if none.
		/// </summary>
		public Nation TerritoryNation
		{
			get
			{
				sbyte raw = theEmpire.Map.Territory[ID];
				if (raw < 0)
					return Nation.None;
				else
					return new Nation(theEmpire, raw);
			}
		}

		/// <summary>
		/// Whether a non-civil unit will cause unrest in it's home city if placed at this location.
		/// </summary>
		public bool MayCauseUnrest
		{
			get
			{
				switch (theEmpire.Government)
				{
					case Government.Republic:
					case Government.FutureSociety:
						{
							sbyte raw = theEmpire.Map.Territory[ID];
							return raw >= 0 && theEmpire.RelationTo(new Nation(theEmpire, raw)) < Relation.Alliance;
						}
					case Government.Democracy:
						{
							sbyte raw = theEmpire.Map.Territory[ID];
							return raw < 0 || theEmpire.RelationTo(new Nation(theEmpire, raw)) < Relation.Alliance;
						}
					default:
						return false;
				}
			}
		}

		#region unit info
		public bool HasOwnUnit { get { return (*address & 0x600000) == 0x600000; } }
		public bool HasOwnZoCUnit { get { return (*address & 0x10000000) != 0; } }
		public bool HasForeignUnit { get { return (*address & 0x600000) == 0x400000; } }
		public bool HasAnyUnit { get { return (*address & 0x400000) != 0; } }
		public bool HasForeignSubmarine { get { return (*address & 0x80000) != 0; } }
		public bool HasForeignStealthUnit { get { return (*address & 0x40000) != 0; } }
		public bool IsInForeignZoC { get { return (*address & 0x20000000) != 0; } }

		/// <summary>
		/// Own unit that would defend an enemy attack to this location. null if no own unit present.
		/// </summary>
		public Unit OwnDefender
		{
			get
			{
				if (!HasOwnUnit)
					return null;
				else
				{
					fixed (int* data = new int[1])
					{
						if (!theEmpire.Play(Protocol.sGetDefender, ID, data).OK)
							return null;
						else
							return theEmpire.UnitLookup[data[0]];
					}
				}
			}
		}

		/// <summary>
		/// Foreign unit that would defend an attack to this location. null if no foreign unit present.
		/// </summary>
		public IUnitInfo ForeignDefender
		{
			get
			{
				if (!HasForeignUnit)
					return null;
				else
					return theEmpire.ForeignUnits.UnitByLocation(this);
			}
		}

		/// <summary>
		/// Unit that would defend an attack to this location. null if no unit present.
		/// </summary>
		public IUnitInfo Defender
		{
			get
			{
				if (HasOwnUnit)
					return OwnDefender;
				else if (HasForeignUnit)
					return ForeignDefender;
				else
					return null;
			}
		}
		#endregion

		#region city info
		public bool HasOwnCity { get { return (*address & 0xA00000) == 0xA00000; } }
		public bool HasForeignCity { get { return (*address & 0xA00000) == 0x800000; } }
		public bool HasAnyCity { get { return (*address & 0x800000) != 0; } }

		/// <summary>
		/// Own city at this location. null if no own city present.
		/// </summary>
		public City OwnCity
		{
			get
			{
				if (!HasOwnCity)
					return null;
				else
				{
					foreach (City city in theEmpire.Cities)
					{
						if (city.Location == this)
							return city;
					}
					return null;
				}
			}
		}

		/// <summary>
		/// Foreign city at this location. null if no foreign city present.
		/// </summary>
		public ForeignCity ForeignCity
		{
			get
			{
				if (!HasForeignCity)
					return null;
				{
					foreach (ForeignCity city in theEmpire.ForeignCities)
					{
						if (city.Location == this)
							return city;
					}
					return null;
				}
			}
		}

		/// <summary>
		/// City at this location. null if no city present.
		/// </summary>
		public ICity City
		{
			get
			{
				if (HasOwnCity)
					return OwnCity;
				else if (HasForeignCity)
					return ForeignCity;
				else
					return null;
			}
		}

		/// <summary>
		/// Own city that is exploiting this tile. null if not exploited or exploited by foreign city.
		/// </summary>
		/// <returns></returns>
		public City GetExploitingCity__Turn()
		{
			if (!IsValid)
				return null;
			City city = null;
			fixed (int* tileInfo = new int[4])
			{
				theEmpire.Play(Protocol.sGetCityTileInfo, ID, tileInfo);
				if (tileInfo[3] >= 0)
					city = theEmpire.CityLookup[tileInfo[3]];
				if (city != null && city.Location != this)
					city = null;
			}
			return city;
		}
		#endregion
	}
}
