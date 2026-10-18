// SPDX-License-Identifier: GPL-2.0-only
/*
 * Adreno Boost - Boosts GPU frequency scaling for Adreno GPUs
 * Originally developed by flar2
 */

#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/devfreq.h>
#include "adreno_boost.h"

unsigned int adrenoboost = 0;
module_param_named(adrenoboost, adrenoboost, uint, 0644);
MODULE_PARM_DESC(adrenoboost, "Adreno Boost level (0=off, 1=low, 2=med, 3=high)");

/* Support adreno_boost alias for parameters */
module_param_named(adreno_boost, adrenoboost, uint, 0644);
MODULE_PARM_DESC(adreno_boost, "Adreno Boost level alias");

void adreno_boost_eval(struct devfreq *df, unsigned long *freq)
{
	int lev, target_lev;
	unsigned int boost = adrenoboost;

	if (!boost || !df || !df->profile || !df->profile->freq_table)
		return;

	/* Find current level in freq_table (0 is max, max_state-1 is min) */
	for (lev = 0; lev < df->profile->max_state; lev++) {
		if (*freq == df->profile->freq_table[lev])
			break;
	}

	if (lev >= df->profile->max_state)
		return;

	target_lev = lev;

	switch (boost) {
	case 1: /* Low boost: step frequency up by 1 level */
		if (target_lev > 0)
			target_lev -= 1;
		break;
	case 2: /* Medium boost: step frequency up by 2 levels */
		if (target_lev > 1)
			target_lev -= 2;
		else
			target_lev = 0;
		break;
	case 3: /* High boost: step frequency to highest available (0) if not totally idle */
		if (df->last_status.busy_time > 0)
			target_lev = 0;
		else if (target_lev > 2)
			target_lev -= 2;
		break;
	default:
		break;
	}

	*freq = df->profile->freq_table[target_lev];
}
EXPORT_SYMBOL_GPL(adreno_boost_eval);

MODULE_DESCRIPTION("Adreno Boost for Devfreq");
MODULE_LICENSE("GPL v2");
