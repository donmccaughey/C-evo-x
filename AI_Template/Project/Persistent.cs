using System;
using System.Collections.Generic;
using CevoAILib;

namespace AI
{
	unsafe class Persistent
	{
		struct MyData
		{
			public int Version;
			public fixed short EstimatedStrength[Cevo.MaxNumberOfNations];
			public Advance LastResearch;
			public fixed sbyte BiggestFriend[Cevo.MaxNumberOfNations];
		}

		Empire theEmpire;
		MyData* data;

		public Persistent(Empire empire, IntPtr dataPtr)
		{
			if (sizeof(MyData) > 4096)
				throw new Exception("Persistent data size exceeds limit!");

			this.theEmpire = empire;
			this.data = (MyData*)dataPtr;

			// initialization
			data->LastResearch = Advance.None;
			for (int nationID = 0; nationID < Cevo.MaxNumberOfNations; nationID++)
			{
				data->EstimatedStrength[nationID] = 100;
				data->BiggestFriend[nationID] = (sbyte)Nation.None.ID;
			}
		}

		public int Version
		{
			get
			{
				return data->Version;
			}
			set
			{
				data->Version = value;
			}
		}

		public int EstimatedStrength(Nation nation)
		{
			return data->EstimatedStrength[nation.ID];
		}

		public void SetEstimatedStrength(Nation nation, int strength)
		{
			data->EstimatedStrength[nation.ID] = (short)strength;
		}

		public Advance LastResearch
		{
			get
			{
				return data->LastResearch;
			}
			set
			{
				data->LastResearch = value;
			}
		}

		public Nation BiggestFriendOf(Nation nation)
		{
			return new Nation(theEmpire, data->BiggestFriend[nation.ID]);
		}

		public void SetBiggestFriendOf(Nation nation, Nation friend)
		{
			data->BiggestFriend[nation.ID] = (sbyte)friend.ID;
		}
	}
}
