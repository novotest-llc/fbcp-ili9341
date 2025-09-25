#include "config.h"

#if defined(ILI9488)
#include "spi.h"
#include <memory.h>
#include <stdio.h>

// Memory access control. Determines display orientation,
// display color filter and refresh order/direction.
#define ROTATE_0_DEGREES 0x08
#define ROTATE_90_DEGREES 0x68
#define ROTATE_180_DEGREES 0xc8
#define ROTATE_270_DEGREES 0xa8

//**************************************************************************************** 
void InitILI9488()
{
  // If a Reset pin is defined, toggle it briefly high->low->high to enable the device. Some devices do not have a reset pin, in which case compile with GPIO_TFT_RESET_PIN left undefined.
#if defined(GPIO_TFT_RESET_PIN) && GPIO_TFT_RESET_PIN >= 0
    printf("Resetting ili9488 display at reset GPIO pin %d\n", GPIO_TFT_RESET_PIN);
    SET_GPIO_MODE(GPIO_TFT_RESET_PIN, 1);
    SET_GPIO(GPIO_TFT_RESET_PIN);
    usleep(120 * 1000);
    CLEAR_GPIO(GPIO_TFT_RESET_PIN);
    usleep(120 * 1000);
    SET_GPIO(GPIO_TFT_RESET_PIN);   
    usleep(120 * 1000);
#endif

    spi->clk = 8; // Speed for init
  __sync_synchronize();
    BEGIN_SPI_COMMUNICATION();
    {
        SPI_TRANSFER(0xC0, 0x17, 0x17); 
        SPI_TRANSFER(0xC1, 0x44); 
        SPI_TRANSFER(0xC5, 0x00, 0x35, 0x80); 
        
        uint8_t madctl(ROTATE_0_DEGREES);
        SPI_TRANSFER(0x36, madctl);
        
        SPI_TRANSFER(0x3A, 0x66); //rgb666
        SPI_TRANSFER(0xB1, 0xA0);   //Frame rate 60HZ  
        SPI_TRANSFER(0xB4, 0x02); 
        SPI_TRANSFER(0xE9, 0x00); 
        SPI_TRANSFER(0XF7, 0xA9, 0x51, 0x2C, 0x82);    
        SPI_TRANSFER(0xE0, 0x01, 0x13, 0x1E, 0x00, 0x0D, 0x03, 0x3D, 0x55, 0x4F, 0x06, 0x10, 0x0B, 0x2C, 0x32, 0x0F);  
        SPI_TRANSFER(0xE1, 0x08, 0x10, 0x15, 0x03, 0x0E, 0x03, 0x32, 0x34, 0x44, 0x07, 0x10, 0x0E, 0x23, 0x2E, 0x0F); 
        //**********set rgb interface mode******************
        SPI_TRANSFER(0xB6, 0x00, 0x22, 0x3B, 0x2A, 0x00, 0x00, 0x01, 0x3F);
        SPI_TRANSFER(0x2B, 0x00, 0x00, 0x01, 0xDF);
        SPI_TRANSFER(0x21);
        SPI_TRANSFER(0x11);
        usleep(120*1000);
        SPI_TRANSFER(0x29); //display on 
        
#if defined(GPIO_TFT_BACKLIGHT) && defined(BACKLIGHT_CONTROL)
    printf("Setting TFT backlight on at pin %d\n", GPIO_TFT_BACKLIGHT);
    TurnBacklightOn();
#endif

    ClearScreen();
  }
  
#ifndef USE_DMA_TRANSFERS // For DMA transfers, keep SPI CS & TA active.
  END_SPI_COMMUNICATION();
#endif

  // And speed up to the desired operation speed finally after init is done.
  usleep(10 * 1000); // Delay a bit before restoring CLK, or otherwise this has been observed to cause the display not init if done back to back after the clear operation above.
  spi->clk = SPI_BUS_CLOCK_DIVISOR;
}
//**************************************************************************************** 
void TurnBacklightOff()
{
#if defined(GPIO_TFT_BACKLIGHT) && defined(BACKLIGHT_CONTROL)
    SET_GPIO_MODE(GPIO_TFT_BACKLIGHT, 0x01); // Set backlight pin to digital 0/1 output mode (0x01) in case it had been PWM controlled
    CLEAR_GPIO(GPIO_TFT_BACKLIGHT); // And turn the backlight off.
#endif
}

//**************************************************************************************** 
void TurnBacklightOn()
{
#if defined(GPIO_TFT_BACKLIGHT) && defined(BACKLIGHT_CONTROL)
  SET_GPIO_MODE(GPIO_TFT_BACKLIGHT, 0x01); // Set backlight pin to digital 0/1 output mode (0x01) in case it had been PWM controlled
  SET_GPIO(GPIO_TFT_BACKLIGHT); // And turn the backlight on.
#endif
}

void TurnDisplayOff()
{
  TurnBacklightOff();
  QUEUE_SPI_TRANSFER(0x28/*Display OFF*/);
  QUEUE_SPI_TRANSFER(0x10/*Enter Sleep Mode*/);
  usleep(120*1000); // Sleep off can be sent 120msecs after entering sleep mode the earliest, so synchronously sleep here for that duration to be safe.
}

void TurnDisplayOn()
{
  TurnBacklightOff();
  QUEUE_SPI_TRANSFER(0x11/*Sleep Out*/);
  usleep(120 * 1000);
  QUEUE_SPI_TRANSFER(0x29/*Display ON*/);
  usleep(120 * 1000);
  TurnBacklightOn();
}

void DeinitSPIDisplay()
{
  ClearScreen();
  TurnDisplayOff();
}

#endif
