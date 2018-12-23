//#include <stdlib.h>
//#include <assert.h>
//#include <iostream.h>
#include "HALlist.h"


template <class itemType>
HALnode<itemType>::HALnode()
	:	prev(NULL),
		next(NULL)	{;}

template <class itemType>
HALnode<itemType>::~HALnode()
//postcondition: list has a capacity of 0 items, and therefore it will
//               need to be resized
{}

template <class itemType>
HALlist<itemType>::HALlist()
//postcondition: list has a capacity of 0 items, and therefore it will
//               need to be resized
	:	myLength(0),
		myHead(NULL),
		myTail(NULL)	{;}
/*
template <class itemType>
HALlist<itemType>::HALlist(const HALlist<itemType> & list)
// postcondition: list is a copy of vec
{
	this.myLength = list.myLength;
	this.myHead = new HALnode<itemType>;
    HALnode<itemType>* current2,current1=this.myHead;
        // copy elements
    for(current2 = list.head; current2 != NULL; current2 = current2->next)
	{
		this.myTail=current1;
		current1->data=current2->data;
		if(current2->next!=NULL)
		{
			current1->next=new HALnode<itemType>;
			current1=current1->next;
		}
    }
}*/

template <class itemType>
HALlist<itemType>::~HALlist ()
// postcondition: list is destroyed
{
	HALnode<itemType>* tempcurrent;
	HALnode<itemType>* current;
	for(current=myHead;current!=NULL;current=tempcurrent)
	{
		tempcurrent=current->next;
		delete current;
	}
}

template <class itemType>
HALnode<itemType>* HALlist<itemType>::head() const
// postcondition: returns vector's head pointer
{
    return myHead;
}

template <class itemType>
HALnode<itemType>* HALlist<itemType>::tail() const
// postcondition: returns vector's tail pointer
{
    return myTail;
}

template <class itemType>
int HALlist<itemType>::length() const
// postcondition: returns list's length
{
    return myLength;
}

//Add an item to the end of an list
template <class itemType>
void HALlist<itemType>::Append(itemType item)
{
	myLength++;
	if(myHead==NULL)
	{
		myHead=new HALnode<itemType>;
		myHead->data=item;
		myTail=myHead;
	}
	else
	{
		myTail->next=new HALnode<itemType>;
		myTail->next->prev=myTail;
		myTail=myTail->next;
		myTail->data=item;
	}
}

template <class itemType>
void HALlist<itemType>::InsertAtTop(itemType item)
// description:  inserts an element at the beginning of the list
{
	myLength++;
	if(myHead==NULL)
	{
		myHead=new HALnode<itemType>;
		myHead->data=item;
		myTail=myHead;
	}
	else
	{
		myHead->prev=new HALnode<itemType>;
		myHead->prev->next=myHead;
		myHead=myHead->prev;
		myHead->data=item;
	}
}

template <class itemType>
void HALlist<itemType>::InsertBefore(HALnode<itemType>* node,itemType item)
// description:  inserts element before node indicated by pointer node
{
	myLength++;
	if(myHead==NULL)
	{
		myHead=new HALnode<itemType>;
		myHead->data=item;
		myTail=myHead;
	}
	else if(node==myHead)
	{
		myHead->prev=new HALnode<itemType>;
		myHead->prev->next=myHead;
		myHead=myHead->prev;
		myHead->data=item;
	}
	else
	{
		HALnode<itemType>* temp=new HALnode<itemType>;
		temp->data=item;
		temp->next=node;
		temp->prev=node->prev;
		temp->prev->next=temp;
		node->prev=temp;
	}
}

template <class itemType>
void HALlist<itemType>::InsertAfter(HALnode<itemType>* node,itemType item)
// description:  inserts element after node indicated by pointer node
{
	myLength++;
	if(myHead==NULL)
	{
		myHead=new HALnode<itemType>;
		myHead->data=item;
		myTail=myHead;
	}
	else if(node==myTail)
	{
		myTail->next=new HALnode<itemType>;
		myTail->next->prev=myTail;
		myTail=myTail->next;
		myTail->data=item;
	}
	else
	{
		HALnode<itemType>* temp=new HALnode<itemType>;
		temp->data=item;
		temp->prev=node;
		temp->next=node->next;
		temp->next->prev=temp;
		node->next=temp;
	}
}

template <class itemType>
void HALlist<itemType>::Remove(HALnode<itemType>* node) //Delete this node
{
	//assumes you were able to access the node in order to delete it
	myLength--;

	if(myHead==myTail)
		myTail=NULL;
	else if(node==myTail)
		myTail=node->prev;
	else
		node->next->prev=node->prev;

	if(myHead==myTail)
		myHead=NULL;
	else if(node==myHead)
		myHead=node->next;
	else
		node->prev->next=node->next;

	delete node;
}
