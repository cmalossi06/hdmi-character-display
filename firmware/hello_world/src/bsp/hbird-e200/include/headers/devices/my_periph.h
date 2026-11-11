/**
 * @file my_periph.h
 * @author your name (you@domain.com)
 * @brief 
 * @version 0.1
 * @date 2024-01-17
 * 
 * @copyright Copyright (c) 2024
 * 
 */

#ifndef _MY_PERIPH__H
#define _MY_PERIPH__H


#define MY_PERIPH_REG_INFO    0x00
#define MY_PERIPH_REG_DATA    0x04
#define MY_PERIPH_REG_IO      MY_PERIPH_REG_DATA
#define MY_PERIPH_REG_CURSOR  0x08
#define MY_PERIPH_REG_CMD     0x0C

#define MY_PERIPH_CMD_CLEAR   0x01
#define MY_PERIPH_CMD_NEWLINE 0x02
#define MY_PERIPH_CMD_CR      0x04
#define MY_PERIPH_CMD_BACKSPACE 0x08


#endif  //_MY_PERIPH__H
