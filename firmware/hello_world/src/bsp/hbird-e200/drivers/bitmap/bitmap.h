
#ifndef BITMAP_H_
#define BITMAP_H_

#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define bitmap_NUM 96
#define bitmap_HEIGHT 16
#define bitmap_WIDTH 16

extern uint16_t bitmap[bitmap_NUM][bitmap_HEIGHT];

#endif 