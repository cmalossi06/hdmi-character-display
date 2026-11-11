/*
 ============================================================================
 Name        : main.c
 Description : UART to HDMI interactive text terminal
 ============================================================================
 */

#include "platform.h"
#include "init.h"

#define UART_RX_EMPTY 0x80000000u

static void hdmi_cmd(uint32_t cmd)
{
    MY_PERIPH_REG(MY_PERIPH_REG_CMD) = cmd;
}

static void hdmi_put_char(uint8_t ch)
{
    MY_PERIPH_REG(MY_PERIPH_REG_DATA) = ch;
}

static void hdmi_set_cursor(uint8_t x, uint8_t y)
{
    MY_PERIPH_REG(MY_PERIPH_REG_CURSOR) = (((uint32_t)y) << 8) | x;
}

static void hdmi_puts(const char *s)
{
    while (*s != '\0') {
        hdmi_put_char((uint8_t)*s);
        s++;
    }
}

static void hdmi_wait_clear(void)
{
    for (volatile uint32_t i = 0; i < 100000u; i++) {
    }
}

int main(void)
{
    uint8_t last_was_cr = 0;

    _init();

    hdmi_cmd(MY_PERIPH_CMD_CLEAR);
    hdmi_wait_clear();
    hdmi_set_cursor(0, 0);
    hdmi_puts("HDMI terminal ready");
    hdmi_cmd(MY_PERIPH_CMD_NEWLINE);
    hdmi_puts("Type on UART0. Backspace and Enter are handled in hardware.");
    hdmi_cmd(MY_PERIPH_CMD_NEWLINE);
    hdmi_puts("> ");

    while (1) {
        uint32_t rx = UART0_REG(UART_REG_RXFIFO);

        if ((rx & UART_RX_EMPTY) != 0u) {
            continue;
        }

        uint8_t ch = (uint8_t)rx;

        if ((ch == 0x08u) || (ch == 0x7fu)) {
            hdmi_cmd(MY_PERIPH_CMD_BACKSPACE);
            last_was_cr = 0;
        } else if (ch == '\r') {
            hdmi_cmd(MY_PERIPH_CMD_NEWLINE);
            last_was_cr = 1;
        } else if (ch == '\n') {
            if (last_was_cr == 0) {
                hdmi_cmd(MY_PERIPH_CMD_NEWLINE);
            }
            last_was_cr = 0;
        } else if ((ch >= 32u) && (ch <= 126u)) {
            hdmi_put_char(ch);
            last_was_cr = 0;
        } else {
            last_was_cr = 0;
        }
    }

    return 0;
}
