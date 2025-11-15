#ifndef __KSU_H_KERNEL_COMPAT
#define __KSU_H_KERNEL_COMPAT

#include <linux/fs.h>
#include <linux/version.h>

/*
 * ksu_copy_from_user_retry
 * try nofault copy first, if it fails, try with plain
 * paramters are the same as copy_from_user
 * 0 = success
 */
static long ksu_copy_from_user_retry(void *to, 
        const void __user *from, unsigned long count)
{
    long ret = copy_from_user_nofault(to, from, count);
    if (likely(!ret))
        return ret;

    // we faulted! fallback to slow path
    return copy_from_user(to, from, count);
}

// 新添加：兼容 strncpy_from_user_nofault
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5,8,0)
#define ksu_strncpy_from_user_nofault strncpy_from_user_nofault
#else
#define ksu_strncpy_from_user_nofault strncpy_from_user
#endif

#endif