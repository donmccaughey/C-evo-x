using System;
using System.Collections.Generic;
using CevoAILib;

namespace AI
{
	sealed class City : ACity
	{
		public City(Empire empire, int indexInSharedMemory)
			: base(empire, indexInSharedMemory)
		{
		}
	}

	sealed class ForeignCity : AForeignCity
	{
		public ForeignCity(Empire empire, int indexInSharedMemory)
			: base (empire, indexInSharedMemory)
		{
		}
	}
}
