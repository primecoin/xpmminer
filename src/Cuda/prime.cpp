/*
 * prime.cpp
 *
 *  Created on: 03.05.2014
 *      Author: mad
 */



#include "prime.h"



const unsigned int nFractionalBits = 24;
unsigned int nTargetInitialLength = 7; // initial chain length target
unsigned int nTargetMinLength = 6; // minimum chain length target
static const unsigned int TARGET_FRACTIONAL_MASK = (1u<<nFractionalBits) - 1;
static const unsigned int TARGET_LENGTH_MASK = ~TARGET_FRACTIONAL_MASK;

unsigned int TargetGetLength(unsigned int nBits)
{
  return ((nBits & TARGET_LENGTH_MASK) >> nFractionalBits);
}