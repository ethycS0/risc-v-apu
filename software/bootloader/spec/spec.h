#ifndef SPEC_LIB
#define SPEC_LIB

#ifdef __cplusplus
extern "C" {
#endif

#include "pb.h"

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef enum {
        SPEC_SUCCESS = 0,
        SPEC_ERROR_CRC = -1,
        SPEC_ERROR_COBS = -2,
        SPEC_ERROR_BUFFER_TOO_SMALL = -3,
        SPEC_ERROR_INVALID_ARG = -4,
} spec_err_t;

typedef enum {
        MSG_SYNC = 0x01,  // Host → eSC-V: initiate session
        MSG_ACK = 0x02,   // eSC-V → Host: ready / chunk received OK
        MSG_NAK = 0x03,   // eSC-V → Host: error, resend last chunk
        MSG_SIZE = 0x04,  // Host → eSC-V: total binary size (4 bytes payload)
        MSG_CHUNK = 0x05, // Host → eSC-V: data chunk (up to 255 bytes payload)
        MSG_DONE = 0x06,  // Host → eSC-V: all chunks sent
        MSG_BOOT = 0x07,  // eSC-V → Host: jumping to app
} msg_type_t;

int spec_encode(const uint8_t *input, size_t input_len, uint8_t *output, size_t output_max, size_t *output_len);
int spec_decode(const uint8_t *input, size_t input_len, uint8_t *output, size_t output_max, size_t *output_len);

#ifdef __cplusplus
}
#endif

#endif
