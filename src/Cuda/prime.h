/*
 * prime.h
 *
 *  Created on: 03.05.2014
 *      Author: mad
 */

#ifndef PRIME_H_
#define PRIME_H_



#include <gmp.h>
#include <gmpxx.h>
#include "uint256.h"

extern const unsigned int nFractionalBits;
extern unsigned int nTargetInitialLength;
extern unsigned int nTargetMinLength;

unsigned int TargetGetLength(unsigned int nBits);
unsigned int TargetGetFractional(unsigned int nBits);
std::string TargetToString(unsigned int nBits);


inline void mpz_set_uint256(mpz_t r, uint256& u)
{
    mpz_import(r, 32 / sizeof(unsigned long), -1, sizeof(unsigned long), -1, 0, &u);
}

#endif /* PRIME_H_ */
