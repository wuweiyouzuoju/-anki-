// SPDX-License-Identifier: AGPL-3.0-or-later
#ifndef JIDECARDS_CORE_H
#define JIDECARDS_CORE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AnkiBuffer {
    uint8_t *ptr;
    size_t len;
    size_t cap;
} AnkiBuffer;

enum AnkiStatus {
    ANKI_STATUS_OK = 0,
    ANKI_STATUS_INVALID_ARGUMENT = 1,
    ANKI_STATUS_HANDLE_NOT_FOUND = 2,
    ANKI_STATUS_BACKEND_ERROR = 3,
    ANKI_STATUS_NATIVE_FATAL = 4,
};

int32_t anki_backend_open(
    const uint8_t *init_bytes,
    size_t init_len,
    uint32_t *out_handle,
    AnkiBuffer *out_error);

int32_t anki_backend_call(
    uint32_t handle,
    uint32_t service,
    uint32_t method,
    const uint8_t *input,
    size_t input_len,
    AnkiBuffer *out_result,
    AnkiBuffer *out_error);

int32_t anki_backend_close(uint32_t handle);
void anki_buffer_free(AnkiBuffer buffer);

#ifdef __cplusplus
}
#endif

#endif
