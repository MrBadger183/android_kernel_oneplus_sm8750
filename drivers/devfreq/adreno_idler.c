// SPDX-License-Identifier: GPL-2.0-only
/*
 * Adreno Idler - An efficient idling algorithm for devfreq-based Adreno GPUs
 * Originally developed by arter97
 */

#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/devfreq.h>
#include "adreno_idler.h"

bool adreno_idler_active = false;
module_param_named(adreno_idler_active, adreno_idler_active, bool, 0644);
MODULE_PARM_DESC(adreno_idler_active, "Enable Adreno Idler");

unsigned int adreno_idler_idlewait = 15;
module_param_named(adreno_idler_idlewait, adreno_idler_idlewait, uint, 0644);
MODULE_PARM_DESC(adreno_idler_idlewait, "Number of events to wait before ramping down frequency");

unsigned int adreno_idler_idleworkload = 5000;
module_param_named(adreno_idler_idleworkload, adreno_idler_idleworkload, uint, 0644);
MODULE_PARM_DESC(adreno_idler_idleworkload, "Workload threshold for idling");

unsigned int adreno_idler_downdifferential = 20;
module_param_named(adreno_idler_downdifferential, adreno_idler_downdifferential, uint, 0644);
MODULE_PARM_DESC(adreno_idler_downdifferential, "Threshold for scaling frequency down");

static unsigned int idle_cnt = 0;

void adreno_idler_eval(struct devfreq *df, unsigned long *freq, unsigned long min_freq)
{
	u64 busy, total;

	if (!adreno_idler_active || !df)
		return;

	busy = (u64)df->last_status.busy_time;
	total = (u64)df->last_status.total_time;

	if (total == 0)
		return;

	/*
	 * Check whether GPU workload is within idle threshold
	 * (busy_time <= idleworkload or load percentage <= 10%)
	 */
	if (busy <= adreno_idler_idleworkload || (busy * 100) <= (total * 10)) {
		idle_cnt++;
		if (idle_cnt >= adreno_idler_idlewait) {
			*freq = min_freq;
		}
	} else {
		idle_cnt = 0;
	}
}
EXPORT_SYMBOL_GPL(adreno_idler_eval);

MODULE_DESCRIPTION("Adreno Idler for Devfreq");
MODULE_LICENSE("GPL v2");
