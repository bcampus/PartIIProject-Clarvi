#include "tests.h"
#include "types.h"
#include "bubbleSort.h"
#include "debug.h"


#define FRAMEBUFFER_BASE 0x08000000
// our pixel format in memory is 5 bits of red, 6 bits of green, 5 bits of blue
#define PIXEL16(r,g,b) (((r & 0x1F)<<11) | ((g & 0x3F)<<5) | ((b & 0x1F)<<0))
// ... but for ease of programming we refer to colours in 8/8/8 format and discard the lower bits
#define PIXEL24(r,g,b) PIXEL16((r>>3), (g>>2), (b>>3))

#define PIXEL_WHITE PIXEL24(0xFF, 0xFF, 0xFF)
#define PIXEL_BLACK PIXEL24(0x00, 0x00, 0x00)
#define PIXEL_RED   PIXEL24(0xFF, 0x00, 0x00)
#define PIXEL_GREEN PIXEL24(0x00, 0xFF, 0x00)
#define PIXEL_BLUE  PIXEL24(0x00, 0x00, 0xFF)

#define DISPLAY_WIDTH	480
#define DISPLAY_HEIGHT	272

volatile int x=20;
int y=21;
int z=22;


void vid_set_pixel(int x, int y, int colour)
{
    // derive a pointer to the framebuffer described as 16 bit integers
    volatile short *framebuffer = (volatile short *) (FRAMEBUFFER_BASE);

    // make sure we don't go past the edge of the screen
    if ((x<0) || (x>DISPLAY_WIDTH-1))
        return;
    if ((y<0) || (y>DISPLAY_HEIGHT-1))
        return;

    framebuffer[x+y*DISPLAY_WIDTH] = colour;
}

void vid_set_bg(int colour){
    for (int x = 0; x < DISPLAY_WIDTH; x++){
        for (int y = 0; y < DISPLAY_HEIGHT; y++){
            vid_set_pixel(x, y, colour);
        }
    }
}

void hex_output(unsigned long value){
    volatile unsigned long *hex_leds = (unsigned long *) 0x04000080;
    *hex_leds = value;
}

void set_screen_mem(unsigned long value, unsigned long offset){
    volatile unsigned long *screen = (unsigned long *) 0x08000000;
    screen[offset] = value;
}
int mult(int a, int b){
    int result = 0;
    int c=b;
    for (int i = 0; c > 0; i++,c=c>>1){
        if (c%2) result += a << i;
    }
    return result;
}

int main(void) {
    hex_output(0);
    //test("load test", test_load);
    test_all();
    //dprint_str("Mult tst:\n");
    //dprint_intvar("x", x);
    //x = mult(x, x);
    //dprint_intvar("x^2", x);

    bubbleSortBenchMark();
    
    hex_output(1);
    char r = 255;
    char g = 255;
    char b = 0;
    char phase = 1;
    hex_output(2);
    while (1){
        if (phase == 0){
            if (++g == 255) phase = 1;
        } else if (phase == 1) {
            if (--r == 0) phase = 2;
        } else if (phase == 2) {
            if (++b == 255) phase = 3;
        } else if (phase == 3) {
            if (--g == 0) phase = 4;
        } else if (phase == 4) {
            if (++r == 255) phase = 5;
        } else if (phase == 5) {
            if (--b == 0) phase = 0;
        }
        dprint(phase);
        hex_output(((int) r << 16) | ((int) g << 8) | ((int) b));
        
        
        vid_set_bg(PIXEL24(r,g,b));
        for (int i = 0; i < 1000; i++){
            x=mult(i,i);
        }
        
    }
    
}
