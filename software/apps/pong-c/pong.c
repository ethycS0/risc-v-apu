#include "debug.h"
#include "uart.h"
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define CPU_FREQ_HZ 27000000

#define ROWS 32
#define COLS 96

unsigned char grid[ROWS][COLS];

int PADDLE_X = 2;
int PADDLE_Y = 3;
int BALL_SIZE = 1;
int BOT_FOW = 6;
int UPDATE_FREQUENCY = 1;
int _UPDATE_FREQUENCY;

unsigned long long updates = 0;
bool pvp = false;
bool eve = true;
bool debug = false;

unsigned long get_cycles(void) {
        unsigned long cycles;
        __asm__ volatile("csrr %0, mcycle" : "=r"(cycles));
        return cycles;
}

void delay(unsigned int ms) {
        unsigned long start_time = get_cycles();
        unsigned long cycles_to_wait = ms * (CPU_FREQ_HZ / 1000);
        while ((get_cycles() - start_time) < cycles_to_wait) {
                __asm__("NOP");
        }
}

struct paddle {
        int x, y;
        unsigned long long score;
} player[2];

struct _ball {
        int x, y;
        int dx, dy; // changed to int for consistency
} ball;

void generate_grid(unsigned char grid[ROWS][COLS]) {
        // Use int for loop iterators
        for (int y = 0; y < ROWS; y++) {
                for (int x = 0; x < COLS; x++) {
                        if (y == 0 || y == ROWS - 1)
                                grid[y][x] = 1;
                        else
                                grid[y][x] = 0;
                }
        }
}

int get_score_len(unsigned long long score) {
        if (score == 0)
                return 1;
        int len = 0;
        while (score > 0) {
                score /= 10;
                len++;
        }
        return len;
}

void draw_game(unsigned char grid[ROWS][COLS]) {
        printf("\033[H");

        // Insert players (with bounds checking)
        for (int i = 0; i < 2; i++) {
                for (int y = player[i].y; y < player[i].y + PADDLE_Y; y++) {
                        for (int x = player[i].x; x < player[i].x + PADDLE_X; x++) {
                                if (y < ROWS && x < COLS) // Safety check
                                        grid[y][x] = 2;
                        }
                }
        }

        // Insert ball (with bounds checking)
        for (int y = ball.y; y < ball.y + BALL_SIZE; y++) {
                for (int x = ball.x; x < ball.x + BALL_SIZE; x++) {
                        if (y < ROWS && x < COLS && y >= 0 && x >= 0) // Safety check
                                grid[y][x] = 3;
                }
        }

        // Draw grid
        for (int y = 0; y < ROWS; y++) {
                for (int x = 0; x < COLS; x++) {
                        switch (grid[y][x]) {
                        case 0:
                                printf(" ");
                                break;
                        case 1:
                                printf("-");
                                break;
                        case 2:
                                printf("|");
                                break;
                        case 3:
                                printf("#");
                                break;
                        default:
                                printf("?");
                        }
                }
                printf("\n");
        }

        // Draw scores
        int score1_length = get_score_len(player[0].score);
        // Center calculation fixed to be safer
        int padding = (COLS / 2) - (score1_length + 2);
        for (int i = 0; i < padding; i++)
                printf(" ");

        printf("%llu | %llu", player[0].score, player[1].score);

        if (debug) {
                printf("\n");
                printf("P1: (%d, %d) | P2: (%d, %d)\n", player[0].x, player[0].y, player[1].x, player[1].y);
                printf("Ball: (%d, %d) d(%d, %d)\n", ball.x, ball.y, ball.dx, ball.dy);
                // Fixed: Use %llu for unsigned long long
                printf("Updates: %llu | Speed: %d", updates, _UPDATE_FREQUENCY);
        }
}

void update_ball(unsigned char grid[ROWS][COLS]) {
        DEBUG_UPDATE();
        // Clear previous ball position
        for (int y = ball.y; y < ball.y + BALL_SIZE; y++) {
                for (int x = ball.x; x < ball.x + BALL_SIZE; x++) {
                        if (y >= 0 && y < ROWS && x >= 0 && x < COLS)
                                grid[y][x] = 0;
                }
        }

        // Horizontal collision
        for (int i = 0; i < 2; i++) {
                bool near_ball =
                    (player[i].x > COLS / 2) ? (ball.x >= player[i].x - PADDLE_X) : (ball.x <= player[i].x + PADDLE_X);

                if (near_ball) {
                        // Check if Y overlaps with paddle
                        if (ball.y + BALL_SIZE > player[i].y && ball.y < player[i].y + PADDLE_Y) {
                                ball.dx *= -1;
                                ball.x += ball.dx; // Move out of paddle immediately
                                if (_UPDATE_FREQUENCY > 1)
                                        _UPDATE_FREQUENCY--;
                        } else {
                                // Check score conditions
                                if (ball.x <= 1) { // Left wall hit
                                        ball.x = (COLS / 2) - BALL_SIZE;
                                        ball.y = (ROWS / 2) - BALL_SIZE;
                                        player[1].score++;
                                        ball.dx = 2; // Reset speed
                                        _UPDATE_FREQUENCY = UPDATE_FREQUENCY;
                                } else if (ball.x >= COLS - 2) { // Right wall hit
                                        ball.x = (COLS / 2) - BALL_SIZE;
                                        ball.y = (ROWS / 2) - BALL_SIZE;
                                        player[0].score++;
                                        ball.dx = -2; // Reset speed
                                        _UPDATE_FREQUENCY = UPDATE_FREQUENCY;
                                }
                        }
                }
        }

        if (ball.y <= 1 || ball.y + BALL_SIZE >= ROWS - 1)
                ball.dy *= -1;

        ball.y += ball.dy;
        ball.x += ball.dx;
}

void move_player(unsigned char index, bool direction, unsigned char grid[ROWS][COLS]) {
        DEBUG_UPDATE();
        if (!direction) { // Move UP
                if (player[index].y >= 2) {
                        player[index].y -= 1;
                        int clear_y = player[index].y + PADDLE_Y;
                        if (clear_y < ROWS) {
                                for (int x = player[index].x; x < player[index].x + PADDLE_X; x++) {
                                        if (x < COLS)
                                                grid[clear_y][x] = 0;
                                }
                        }
                }
        } else {
                if (player[index].y + PADDLE_Y <= ROWS - 2) {
                        player[index].y += 1;
                        int clear_y = player[index].y - 1;
                        if (clear_y >= 0) {
                                for (int x = player[index].x; x < player[index].x + PADDLE_X; x++) {
                                        if (x < COLS)
                                                grid[clear_y][x] = 0;
                                }
                        }
                }
        }
}

void automate_player(unsigned int index, unsigned char grid[ROWS][COLS]) {
        int diff = abs(player[index].x - ball.x);
        if (diff <= COLS / BOT_FOW) {
                bool direction = ((ball.y * 2 + BALL_SIZE) / 2 < (player[index].y * 2 + PADDLE_Y) / 2) ? 0 : 1;
                move_player(index, direction, grid);
        }
}

void end_game(int signum) {
        printf("\033[?25h\033[m");
        exit(signum);
}

int main() {
        setvbuf(stdout, NULL, _IONBF, 0); // Disable all buffering for stdout
        unsigned char c = 0x00;

        while (uart_getc(&c))
                ;

        printf("Welcome to Pong. Press SPACE to start.\n");
        while (c != 0x20) {
                uart_getc(&c);
        }

        player[0].x = 2;
        player[0].y = (ROWS / 2) - (PADDLE_Y / 2);
        player[0].score = 0;

        player[1].x = COLS - (PADDLE_X + 2);
        player[1].y = (ROWS / 2) - (PADDLE_Y / 2);
        player[1].score = 0;

        ball.x = COLS / 2 - BALL_SIZE;
        ball.y = ROWS / 2 - BALL_SIZE;
        ball.dx = 2;
        ball.dy = 1;

        _UPDATE_FREQUENCY = UPDATE_FREQUENCY;

        printf("\033[?25l\033[2J");
        generate_grid(grid);
        draw_game(grid);

        unsigned char m;

        while (true) {
                int result = uart_getc(&m);
                if (result) {
                        switch (m) {
                        case 0x77:
                                move_player(0, 0, grid);
                                break; // w
                        case 0x73:
                                move_player(0, 1, grid);
                                break; // s
                        case 0x69:
                                if (pvp)
                                        move_player(1, 0, grid);
                                break; // i
                        case 0x6B:
                                if (pvp)
                                        move_player(1, 1, grid);
                                break; // k
                        case 'q':
                                end_game(0);
                                break; // quit
                        }
                }

                if (updates % _UPDATE_FREQUENCY == 0) {
                        update_ball(grid);
                        if (!pvp || eve)
                                automate_player(1, grid);
                        if (eve)
                                automate_player(0, grid);
                }

                draw_game(grid);
                updates++;
                delay(1);
        }
        end_game(0);
}
