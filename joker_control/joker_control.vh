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
				J_CMD_CI_READ_MEM=21, 
				J_CMD_CI_WRITE_MEM=22,
				J_CMD_SPI=30
				;
