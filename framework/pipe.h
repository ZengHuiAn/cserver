#ifndef _A_GAME_COMM_MODULES_PIPE_H_
#define _A_GAME_COMM_MODULES_PIPE_H_

#include <stdlib.h>
//#include "module.h"

//DECLARE_MODULE(pipe);

struct pipe;

struct pipe * agP_open(size_t size);
void agP_close(struct pipe * p);

size_t agP_size(struct pipe * p);

int agP_write(struct pipe * p, const void * data, size_t len);
void * agP_buffer(struct pipe * p, size_t len);

const void * agP_peek(struct pipe * p, size_t len);
const void * agP_read(struct pipe * p, size_t len);

#endif
