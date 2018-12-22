using System;
using System.Collections.Generic;

// collection of non-negative integers (called addresses) with non-negative priorities (called distances)
// based on binary heap

// main operations:
// * Offer: offer distance to an address
// * TakeClosest: get and remove address with shortest offered distance

// only the shortest of multiple offered distances to a specific address is kept
// user must ensure not to offer a distance shorter than those of addresses already taken
// (easily achieved by the typical usage of this class)

// memory consumption: 4 bytes per potential address + 8 bytes per address in collection
// time consumption: O(log n) for both main operations, where n is the current size of the collection

namespace Common
{
	/// <summary>
	/// Priority queue on bounded integer address space.
	/// </summary>
	class AddressPriorityQueue
	{
		/// <summary>
		/// Creates an empty collection.
		/// </summary>
		/// <param name="maxAddress">maximum address allowed</param>
		public AddressPriorityQueue(int maxAddress)
		{
			if (maxAddress < 0 || maxAddress > 0x7FFFFFFE)
				throw new Exception("AddressPriorityQueue: Maximum capacity is 1<<31 addresses!");
			this.maxAddress = maxAddress;
			allocatedSize = 4 * (int)Math.Sqrt(maxAddress + 1); // good for addresses in a 2D-space
			binaryHeap = new HeapItem[allocatedSize];
			binaryHeapSize = 0;
			states = new uint[maxAddress + 1];
			lastTakenDistance = 0;
			taken = 0;
		}

		/// <summary>
		/// Offer address with distance. Might have been offered with same or different distance before.
		/// </summary>
		/// <param name="address">the address</param>
		/// <param name="distance">the distance</param>
		/// <returns>true if address was new or offer was better than all former offers for this address</returns>
		public bool Offer(int address, int distance)
		{
			if (address < 0 || address > maxAddress)
				throw new Exception(string.Format("AddressPriorityQueue.Offer: Address '{0}' is not in valid range!", address));
			uint state = states[address];
			if ((state & wasTakenFlag) != 0)
			{
				if (state == (Disallowed | wasTakenFlag))
					throw new Exception(string.Format("AddressPriorityQueue.Offer: Ambiguous usage! Address '{0}' was both offered and disallowed!", address));
				else
					return false; // if class is used correctly, the new offer must be worse than one before at this point
			}
			else
			{
				if (distance < 0 || distance >= Unknown)
					throw new Exception(string.Format("AddressPriorityQueue.Offer: Distance '{0}' is not in valid range!", distance));
				int index = (int)state - 1;
				bool isShorter = true;
				if (state > 0) // means address is already contained in binary heap
					isShorter = (distance < binaryHeap[index].distance);
				if (isShorter)
				{
					if (distance < lastTakenDistance)
						throw new Exception(string.Format("AddressPriorityQueue.Offer: Illegal order of operations! Can't offer distances shorter than those already taken. Last TakeClosest: '{0}' - this Offer: '{1}'.", lastTakenDistance, distance));

					#region binary heap grow algo
					if (index < 0)
					{ // address is not yet contained in binary heap, insert at bottom
						index = binaryHeapSize;
						binaryHeapSize++;
						if (binaryHeapSize > allocatedSize)
						{
							allocatedSize *= 2;
							if (allocatedSize > maxAddress + 1)
								allocatedSize = maxAddress + 1;
							Array.Resize<HeapItem>(ref binaryHeap, allocatedSize);
						}
					}

					// correct binary heap, new item can only move up (either shorter distance than before or at bottom)
					while (index > 0)
					{
						int parent = (index - 1) / 2;
						if (distance >= binaryHeap[parent].distance)
							break;
						binaryHeap[index] = binaryHeap[parent];
						states[binaryHeap[index].address] = (uint)index + 1;
						index = parent;
					}
					binaryHeap[index].distance = distance;
					binaryHeap[index].address = address;
					states[binaryHeap[index].address] = (uint)index + 1;
					#endregion

					return true;
				}
				else
					return false;
			}
		}

		/// <summary>
		/// Does nothing but returns same value as Offer(...) would.
		/// </summary>
		/// <param name="address">the address</param>
		/// <param name="distance">the distance</param>
		/// <returns>true if address was new or offer was better than all former offers for this address</returns>
		public bool TestOffer(int address, int distance)
		{
			if (address < 0 || address > maxAddress)
				throw new Exception(string.Format("AddressPriorityQueue.TestOffer: Address '{0}' is not in valid range!", address));
			uint state = states[address];
			if ((state & wasTakenFlag) != 0)
			{
				if (state == (Disallowed | wasTakenFlag))
					throw new Exception(string.Format("AddressPriorityQueue.TestOffer: Ambiguous usage! Address '{0}' was both offered and disallowed!", address));
				else
					return false;
			}
			else
			{
				if (distance < 0 || distance >= Unknown)
					throw new Exception(string.Format("AddressPriorityQueue.TestOffer: Distance '{0}' is not in valid range!", distance));
				if (state > 0) // means address is already contained in binary heap
					return distance < binaryHeap[state - 1].distance;
				else
					return true;
			}
		}

		/// <summary>
		/// Marks address as disallowed, which changes the Distance(address) query result and forbids Offer calls for this address.
		/// </summary>
		/// <param name="address">the address</param>
		public void Disallow(int address)
		{
			if (address < 0 || address > maxAddress)
				throw new Exception(string.Format("AddressPriorityQueue.Disallow: Address '{0}' is not in valid range!", address));
			uint state = states[address];
			if (state != (Disallowed | wasTakenFlag))
			{
				if (state != 0)
					throw new Exception(string.Format("AddressPriorityQueue.Disallow: Ambiguous usage! Address '{0}' was both offered and disallowed!", address));
				states[address] = (Disallowed | wasTakenFlag);
			}
		}

		/// <summary>
		/// Get and remove address with shortest offered distance.
		/// </summary>
		/// <param name="address">the address</param>
		/// <param name="distance">the distance</param>
		/// <returns>true if operation was successful, false for empty collection</returns>
		public bool TakeClosest(out int address, out int distance)
		{
			if (binaryHeapSize == 0)
			{
				address = 0;
				distance = 0;
				return false;
			}

			address = binaryHeap[0].address;
			distance = binaryHeap[0].distance;
			states[address] = (uint)distance | wasTakenFlag;
			lastTakenDistance = distance;
			taken++;

			#region binary heap shrink algo
			binaryHeapSize--;
			if (binaryHeapSize > 0)
			{
				HeapItem last = binaryHeap[binaryHeapSize];
				int index = 0;
				int child = 1;
				while (child < binaryHeapSize)
				{
					if (child < binaryHeapSize - 1 && binaryHeap[child].distance > binaryHeap[child + 1].distance)
						child++; // right child instead of left
					if (last.distance <= binaryHeap[child].distance)
						break;

					binaryHeap[index] = binaryHeap[child];
					states[binaryHeap[index].address] = (uint)index + 1;
					index = child;
					child = 2 * child + 1;
				}
				binaryHeap[index] = last;
				states[last.address] = (uint)index + 1;
			}
			#endregion

			return true;
		}

		/// <summary>
		/// Remove all addresses from collection and delete calculations. Collection returns to state as after 
		/// new except that possibly resized memory is kept.
		/// </summary>
		public void Clear()
		{
			if (binaryHeapSize + taken > 0)
			{
				binaryHeapSize = 0;
				Array.Clear(states, 0, maxAddress + 1);
				lastTakenDistance = 0;
				taken = 0;
			}
		}

		/// <summary>
		/// Status tracker. Returns shortest distance to an address, if that address was already taken.
		/// Otherwise, returns Unknown.
		/// If address was disallowed, returns Disallowed.
		/// </summary>
		/// <param name="address">address</param>
		/// <returns>shortest distance to address</returns>
		public int Distance(int address)
		{
			uint state = states[address];
			if ((state & wasTakenFlag) != 0)
				return (int)(state & stateDataMask);
			else
				return Unknown;
		}
		public const int Disallowed = 0x7FFFFFFF;
		public const int Unknown = 0x7FFFFFFE;

		/// <summary>
		/// Number of different addresses offered.
		/// </summary>
		public int Count { get { return binaryHeapSize + taken; } }

		/// <summary>
		/// Number of addresses taken from the collection using TakeClosest.
		/// </summary>
		public int Taken { get { return taken; } }

		#region private stuff
		protected const uint wasTakenFlag = 0x80000000;
		protected const uint stateDataMask = 0x7FFFFFFF;

		protected struct HeapItem
		{
			public int address;
			public int distance;
		}

		protected HeapItem[] binaryHeap;
		protected int binaryHeapSize;

		// multiple funtion memory with address as index:
		// wasTakenFlag indicates that address should not be taken anymore, 
		// flag is set after address was returned by TakeClosest or disallowed
		// if wasTakenFlag is not set, lower 31 bits contain index in binaryHeap + 1 (0 meaning not contained)
		// if wasTakenFlag is set, lower 31 bits contain shortest distance resp. Disallowed
		protected uint[] states;

		protected int maxAddress;
		protected int allocatedSize;
		protected int lastTakenDistance;
		protected int taken;
		#endregion
	}
}
