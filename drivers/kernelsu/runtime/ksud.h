#ifndef __KSU_H_KSUD
#define __KSU_H_KSUD

#include <asm/syscall.h>

#define KSUD_PATH "/data/adb/ksud"

#ifndef _USER_ARG_PTR_DEFINED
#define _USER_ARG_PTR_DEFINED
struct user_arg_ptr {
#ifdef CONFIG_COMPAT
	bool is_compat;
#endif
	union {
		const char __user *const __user *native;
#ifdef CONFIG_COMPAT
		const compat_uptr_t __user *compat;
#endif
	} ptr;
};
#endif

void ksu_ksud_init(void);
void ksu_ksud_exit(void);

void ksu_stop_input_hook_runtime(void);

int ksu_handle_execveat_ksud(int *fd, struct filename **filename_ptr,
                             struct user_arg_ptr *argv,
                             struct user_arg_ptr *envp, int *flags);

void ksu_handle_vfs_fstat(int fd, loff_t *kstat_size_ptr);

#endif
