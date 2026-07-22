// SPDX-License-Identifier: AGPL-3.0-or-later
//
// OHOS musl declares GNU qsort_r() through zstd's feature detection but the
// API 12 NDK does not export it. Keep this portable, re-entrant implementation
// local to the native module until the dependency recognizes __OHOS__.

#include <stddef.h>

typedef int (*jidecards_comparator)(const void *, const void *, void *);

static void swap_bytes(unsigned char *left, unsigned char *right, size_t size)
{
    while (size-- > 0) {
        const unsigned char value = *left;
        *left++ = *right;
        *right++ = value;
    }
}

static void sift_down(unsigned char *base, size_t start, size_t count,
    size_t size, jidecards_comparator compare, void *context)
{
    size_t root = start;
    while (root <= (count - 2) / 2) {
        size_t child = root * 2 + 1;
        if (child + 1 < count && compare(base + child * size,
            base + (child + 1) * size, context) < 0) {
            ++child;
        }
        if (compare(base + root * size, base + child * size, context) >= 0) {
            return;
        }
        swap_bytes(base + root * size, base + child * size, size);
        root = child;
    }
}

/* 仅供本模块内部静态链接使用；隐藏符号避免与未来 NDK 导出的 qsort_r 冲突。 */
__attribute__((visibility("hidden")))
void qsort_r(void *base, size_t count, size_t size,
    jidecards_comparator compare, void *context)
{
    if (base == NULL || compare == NULL || size == 0 || count < 2) {
        return;
    }

    unsigned char *bytes = (unsigned char *)base;
    for (size_t start = count / 2; start > 0; --start) {
        sift_down(bytes, start - 1, count, size, compare, context);
    }
    for (size_t end = count - 1; end > 0; --end) {
        swap_bytes(bytes, bytes + end * size, size);
        sift_down(bytes, 0, end, size, compare, context);
    }
}
