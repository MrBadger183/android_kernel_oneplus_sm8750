/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _ADRENO_BOOST_H
#define _ADRENO_BOOST_H

#include <linux/devfreq.h>

extern unsigned int adrenoboost;

void adreno_boost_eval(struct devfreq *df, unsigned long *freq);

#endif /* _ADRENO_BOOST_H */
