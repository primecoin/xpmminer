/*
 * Copyright 2012-2013 Luke Dashjr
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the standard MIT license.  See COPYING for more details.
 */

#define _BSD_SOURCE

#include <limits.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include <blktemplate.h>

static const char *capnames[] = {
	"coinbasetxn",
	"coinbasevalue",
	"workid",
	
	"longpoll",
	"proposal",
	"serverlist",
	                                     NULL, NULL,
	NULL, NULL, NULL, NULL,  NULL, NULL, NULL, NULL,
	
	"coinbase/append",
	"coinbase",
	"generate",
	"time/increment",
	"time/decrement",
	"transactions/add",
	"prevblock",
	"version/force",
	"version/reduce",
	
	"submit/hash",
	"submit/coinbase",
	"submit/truncate",
	"share/coinbase",
	"share/merkle",
	"share/truncate",
};

const char *blktmpl_capabilityname(gbt_capabilities_t caps) {
	for (unsigned int i = 0; i < GBT_CAPABILITY_COUNT; ++i)
		if (caps & (1 << i))
			return capnames[i];
	return NULL;
}

gbt_capabilities_t blktmpl_getcapability(const char *n) {
	for (unsigned int i = 0; i < GBT_CAPABILITY_COUNT; ++i)
		if (capnames[i] && !strcasecmp(n, capnames[i]))
			return 1 << i;
	return 0;
}

blktemplate_t *blktmpl_create() {
	blktemplate_t *tmpl;
	tmpl = calloc(1, sizeof(*tmpl));
	if (!tmpl)
		return NULL;
	
	tmpl->sigoplimit = USHRT_MAX;
	tmpl->sizelimit = ULONG_MAX;
	
	tmpl->maxtime = 0xffffffff;
	tmpl->maxtimeoff = 0x7fff;
	tmpl->mintimeoff = -0x7fff;
	tmpl->maxnonce = 0xffffffff;
	tmpl->expires = 0x7fff;
	
	return tmpl;
}

gbt_capabilities_t blktmpl_addcaps(const blktemplate_t *tmpl) {
	// TODO: make this a lot more flexible for merging
	// For now, it's a simple "filled" vs "not filled"
	if (tmpl->version)
		return 0;
	return GBT_CBTXN | GBT_WORKID | BMM_TIMEINC | BMM_CBAPPEND | BMM_VERFORCE | BMM_VERDROP | BMAb_COINBASE | BMAb_TRUNCATE;
}

const struct blktmpl_longpoll_req *blktmpl_get_longpoll(blktemplate_t *tmpl) {
	if (!tmpl->lp.id)
		return NULL;
	return &tmpl->lp;
}

bool blktmpl_get_submitold(blktemplate_t *tmpl) {
	return tmpl->submitold;
}

void _blktxn_free(struct blktxn_t *bt) {
	free(bt->data);
	free(bt->hash);
	free(bt->depends);
}
#define blktxn_free  _blktxn_free

void blktmpl_free(blktemplate_t *tmpl) {
	for (unsigned long i = 0; i < tmpl->txncount; ++i)
		blktxn_free(&tmpl->txns[i]);
	free(tmpl->txns);
	if (tmpl->cbtxn)
	{
		blktxn_free(tmpl->cbtxn);
		free(tmpl->cbtxn);
	}
	// TODO: maybe free auxnames[0..n]? auxdata too
	free(tmpl->auxnames);
	free(tmpl->auxdata);
	free(tmpl->workid);
	free(tmpl->lp.id);
	free(tmpl->lp.uri);
	free(tmpl);
}

void blktxn_copy(struct blktxn_t *out, struct blktxn_t *in) {
  memcpy(out, in, sizeof(struct blktxn_t));
  if (in->data) {
    out->data = malloc(in->datasz);
    memcpy(out->data, in->data, in->datasz);
  }
  
  if (in->hash) {
    out->hash = malloc(sizeof(libblkmaker_hash_t));
    memcpy(out->hash, in->hash, sizeof(libblkmaker_hash_t));
  }
  
  if (in->depends) {
    out->depends = malloc(sizeof(unsigned long)*in->dependcount);
    memcpy(out->depends, in->depends, sizeof(unsigned long)*in->dependcount);
  }
}

blktemplate_t *blktmpl_duplicate(blktemplate_t *tmpl) {
  blktemplate_t *result = malloc(sizeof(blktemplate_t));
  
  printf("to memcpy\n");
  memcpy(result, tmpl, sizeof(blktemplate_t));
  printf("after memcp\n");
  if (tmpl->lp.uri)
    result->lp.uri = strdup(tmpl->lp.uri);
  printf("after tmpl->lp.uri\n");
  if (tmpl->lp.id)
    result->lp.id = strdup(tmpl->lp.id);
  if (tmpl->workid)
    result->workid = strdup(tmpl->workid);
  
  result->auxdata = 0;
  result->auxnames = 0;
  if (tmpl->cbtxn) {
    result->cbtxn = malloc(sizeof(struct blktxn_t));
    blktxn_copy(result->cbtxn, tmpl->cbtxn);
  }
  
  if (tmpl->txncount) {
    result->txns = malloc(sizeof(struct blktxn_t)*tmpl->txncount);
    for (unsigned long i = 0; i < tmpl->txncount; i++)
      blktxn_copy(&result->txns[i], &tmpl->txns[i]);
  } else {
    result->txns = 0;
  }
  printf("finished dup\n");
  
  return result;
}