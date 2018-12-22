using System;
using System.Collections.Generic;
using CevoAILib;

namespace AI
{
	sealed class Unit : AUnit
	{
		public Unit(Empire empire, int indexInSharedMemory)
			: base(empire, indexInSharedMemory)
		{
		}
	}
}
