#ifndef _HALLIST_H
#define _HALLIST_H

//Additional functions by Charles Nadolski, last revised 1/31/2003:
//Append
//InsertAtTop
//Remove

// *******************************************************************
// Last Revised: 8/14/98, abort changed to exit
//
// January 13,1998, added explicit to int constructor
// APCS vector class template
//
// implements "safe" (range-checked) arrays
// examples are given at the end of this file
// *******************************************************************

// If your compiler supports the keyword explicit, comment out the
// #define explicit line below, leaving the #define means explicit
// is ignored, but doesn't generate an error
//
//   This will disallow a typically erroneous implicit type-conversion:
//   vector<int> v( 10 );
//   v = 0; // Oops!! Allowed because of implicit type-con2lversion.

#define explicit

template <class itemType>
class HALnode
{
public:
	HALnode* prev;
	HALnode* next;
	itemType data;
	HALnode();
	~HALnode();
};

template <class itemType>
class HALlist
{
public:

	//constructors/destructor
	HALlist( );                        // default constructor (size==0)
//	HALlist( const HALlist & list );   // copy constructor
	~HALlist( );                       // destructor

	//accessors
    HALnode<itemType>* head( ) const;
	HALnode<itemType>* tail( ) const;
	int length( ) const;

	//assignment
//	const HALlist & operator = ( const HALlist & list );

	//modifiers
	void Append(itemType item);	//Append a new item to end of list
	void InsertAtTop(itemType item); //Insert a new item to the beginning of the list
	void InsertBefore(HALnode<itemType>* node,itemType item); //Insert a new item before this node
	void InsertAfter(HALnode<itemType>* node,itemType item); //Insert a new item after this node
	void Remove(HALnode<itemType>* node); //Delete an item indicated by the pointer

private:

	int myLength;
	HALnode<itemType>* myHead;
	HALnode<itemType>* myTail;

};

// *******************************************************************
//  Specifications for vector functions
//
//  The template parameter itemType must satisfy the following two conditions:
//   (1) itemType has a 0-argument constructor
//   (2) operator = is defined for itemType
//  Any violation of these conditions may result in compilation failure.
//
//  Any violation of a function's precondition will result in an error message
//  followed by a call to exit.
//
//  constructors/destructor
//
//   apvector( )
//     postcondition: vector has a capacity of 0 items, and therefore it will
//                    need to be resized
//
//   apvector( int size )
//     precondition: size >= 0
//     postcondition: vector has a capacity of size items
//
//   apvector( int size, const itemType & fillValue )
//     precondition: size >= 0
//     postcondition: vector has a capacity of size items, all of which are set
//                    by assignment to fillValue after default construction
//
//   apvector( const apvector & vec )
//     postcondition: vector is a copy of vec
//
//   ~apvector( )
//     postcondition: vector is destroyed
//
//  assignment
//
//   const apvector & operator = ( const apvector & rhs )
//     postcondition: normal assignment via copying has been performed;
//                    if vector and rhs were different sizes, vector
//                    has been resized to  match the size of rhs
//
//  accessor
//
//   int  length( ) const
//     postcondition: returns vector's size (number of memory cells
//                    allocated for vector)
//
//  indexing
//
//   itemType &       operator [ ] ( int k )       -- index into nonconst vector
//   const itemType & operator [ ] ( int k ) const -- index into const vector
//     description: range-checked indexing, returning kth item
//     precondition: 0 <= k < length()
//     postcondition: returns the kth item
//
//  modifier
//
//   void resize( int newSize )
//     description:  resizes the vector to newSize elements
//     precondition: the current capacity of vector is length; newSize >= 0
//
//     postcondition: the current capacity of vector is newSize; for each k
//                    such that 0 <= k <= min(length, newSize), vector[k]
//                    is a copy of the original; other elements of vector are
//                    initialized using the 0-argument itemType constructor
//                    Note: if newSize < length, elements may be lost
//
//  examples of use
//      apvector<int> v1;         // 0-element vector
//      apvector<int> v2(4);      // 4-element vector
//      apvector<int> v3(4, 22);  // 4-element vector, all elements == 22.

#include "HALlist.cpp"
#endif


