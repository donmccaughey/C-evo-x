using System;
using System.Collections.Generic;

// collection class with the following operations:
// * add object
// * iterate collection using foreach statement
// * remove current object from within iteration

// when removing objects while iterating, the following conditions are assured:
// * no elements that are still in the collection are left out
// * no elements that are no longer in the collection are iterated
// * no element is iterated twice
// * in case of nested iterations of the collection, all this is true for each of them

// calling GetEnumerator explicitely is not recommended
// never iterate from multiple threads at the same time

namespace Common
{
	/// <summary>
	/// Simple collection class which can be changed from within iteration.
	/// </summary>
	/// <typeparam name="T">type of collected objects</typeparam>
	class ToughSet<T> : IEnumerable<T>
	{
		List<T> list = new List<T>();
		List<Enumerator<T>> enumerators = new List<Enumerator<T>>(4); // list will rarely have more than 1 element

		/// <summary>
		/// Creates an empty collection.
		/// </summary>
		public ToughSet() { }

		/// <summary>
		/// Number of elements contained in the collection.
		/// </summary>
		public int Count { get { return list.Count; } }

		/// <summary>
		/// Adds an object to the collection.
		/// </summary>
		/// <param name="item">The object to be added.</param>
		public void Add(T item) { list.Add(item); }

		/// <summary>
		/// Removes the current object of an iteration from the collection. Can only be called from within foreach loop.
		/// </summary>
		public void RemoveCurrent()
		{
			if (enumerators.Count == 0)
				throw new Exception("ToughSet.Remove() can only be called from within foreach loop!");
			Enumerator<T> innerEnumerator = enumerators[enumerators.Count - 1];
			if (!innerEnumerator.currentWasRemoved)
			{
				int removeIndex = innerEnumerator.index;
				if (removeIndex >= 0 && removeIndex < list.Count)
				{
					list.RemoveAt(removeIndex);
					foreach (Enumerator<T> enumerator in enumerators)
						enumerator.RemoveAt(removeIndex);
				}
			}
		}

		void EnumerationEnded(Enumerator<T> enumerator) // parameter is only for proof of correctness
		{
			if (enumerators.Count == 0)
				throw new Exception("Error in ToughSet: Only started foreach loop can end!");
			Enumerator<T> innerEnumerator = enumerators[enumerators.Count - 1];
			if (enumerator != innerEnumerator)
				throw new Exception("Error in ToughSet: Only most inner foreach loop can end!");
			enumerator.DisposeEvent -= EnumerationEnded;
			enumerators.RemoveAt(enumerators.Count - 1);
		}

		#region IEnumerable members
		class Enumerator<TEn> : IEnumerator<TEn>
		{
			ToughSet<TEn> parent;
			public int index;
			public bool currentWasRemoved = false;
			TEn current;

			public Enumerator(ToughSet<TEn> parent)
			{
				this.parent = parent;
				index = -1;
			}

			public void RemoveAt(int removeIndex)
			{
				if (removeIndex == index)
					currentWasRemoved = true;
				if (removeIndex <= index)
					index--;
			}

			public delegate void DisposeEventHandler(Enumerator<TEn> enumerator);
			public event DisposeEventHandler DisposeEvent;

			#region IEnumerator Members
			public void Reset() { index = -1; }
			public TEn Current { get { return current; } }
			object System.Collections.IEnumerator.Current { get { return current; } }
			public void Dispose() { DisposeEvent(this); }

			public bool MoveNext()
			{
				index++;
				if (index < parent.list.Count)
				{
					current = parent.list[index];
					currentWasRemoved = false;
					return true;
				}
				else
					return false;
			}
			#endregion
		}

		public IEnumerator<T> GetEnumerator()
		{
			Enumerator<T> enumerator = new Enumerator<T>(this);
			enumerators.Add(enumerator);
			enumerator.DisposeEvent += EnumerationEnded;
			return enumerator;
		}
		System.Collections.IEnumerator System.Collections.IEnumerable.GetEnumerator() { return GetEnumerator(); }
		#endregion
	}
}

/*
class was tested with the following code:

ToughSet<int> ts = new ToughSet<int>();
for (int i = 0; i < 20; i++)
	ts.Add(i);

foreach (int i in ts)
{ // should iterate 0-1-2-3-5-6-7-8-9-11-13-14-15-16-17
	if (i == 3)
	{
		foreach (int j in ts)
		{
			if (j == 1 || j == 4 || j ==12)
				ts.Remove();
			if (j == 14)
				break;
		}
	}
	if (i == 9)
	{
		foreach (int j in ts)
		{
			if (j == 0 || j == 9 || j == 10)
				ts.Remove();
			if (j == 16)
				break;
		}
	}
	if (i == 8 || i == 9 || i == 16)
		ts.Remove();
	if (i == 17)
		break;
}
foreach (int i in ts)
{ // should iterate 2-3-5-6-7-11-13-14-15-17-18-19
}
ts.Remove(); // should throw exception
*/
