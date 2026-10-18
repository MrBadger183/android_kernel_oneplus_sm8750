/* SPDX-License-Identifier: GPL-2.0-only */
#ifndef _ADRENO_IDLER_H
#define _ADRENO_IDLER_H

#include <linux/devfreq.h>

extern bool adreno_idler_active;
extern unsigned int adreno_idler_idlewait;
extern unsigned int adreno_idler_idleworkload;
extern unsigned int adreno_idler_downdifferential;

void adreno_idler_eval(struct devfreq *df, unsigned long *freq, unsigned long min_freq);

#endif /* _ADRENO_IDLER_H */
