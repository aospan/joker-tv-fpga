// joker commands

parameter 	J_CMD_VERSION=0, /* return fw version */
				J_CMD_I2C_WRITE=10, /* i2c read/write */				
				J_CMD_I2C_READ=11,
				J_CMD_RESET_CTRL_WRITE=12, /* reset control register  r/w */
				J_CMD_RESET_CTRL_READ=13,
				J_CMD_TS_INSEL_WRITE=14, /* ts input select */
				J_CMD_TS_INSEL_READ=15,
				J_CMD_ISOC_LEN_WRITE_HI=16, /* USB isoc transfers length */
				J_CMD_ISOC_LEN_WRITE_LO=17,
				J_CMD_CI_STATUS=20, /* CI - common interface */
				J_CMD_CI_RW=22,  /* CAM IO/MEM RW */
				J_CMD_CI_TS=23,  /* enable/disable TS through CAM */
				J_CMD_SPI=30, /* SPI bus access */
				J_CMD_CLEAR_TS_FIFO=35, /* clear TS FIFO */
				J_CMD_REBOOT=36, /* start FPGA reboot */
				J_CMD_TS_FILTER=40 /* TS PID filtering */
				;
