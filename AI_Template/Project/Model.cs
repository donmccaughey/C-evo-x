using System;
using System.Collections.Generic;
using CevoAILib;

namespace AI
{
	sealed class Model : AModel
	{
		public Model(Empire empire, int indexInSharedMemory)
			: base(empire, indexInSharedMemory)
		{
		}
	}

	sealed class ForeignModel : AForeignModel
	{
		public ForeignModel(Empire empire, int indexInSharedMemory)
			: base(empire, indexInSharedMemory)
		{
		}
	}
}
