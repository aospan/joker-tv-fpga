
//
// USB 3.0/2.0 IP core MIF/descriptor generator
//
// Copyright (c) 2013 Marshall H.
// All rights reserved.
// This code is released under the terms of the simplified BSD license. 
// See LICENSE.TXT for details.
//

#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <math.h>
#include <stdlib.h>
#include <locale.h>
#include <iconv.h>
#include <unistd.h>
#include <getopt.h>

#define u8	unsigned char
#define u16	unsigned short
#define u32	unsigned int

// to add endpoints, change strings etc, just skip to main() at bottom
//
// warning: objectionable C code ahead
// proceed with extreme prejudice

char filename_usb2_mif[] = "usb2_descrip.mif";
char filename_usb3_mif[] = "usb3_descrip.mif";
char filename_usb2_bin[] = "usb2_descrip.bin";
char filename_usb3_bin[] = "usb3_descrip.bin";
char filename_descrip_vh[] = "usb_descrip.vh";


FILE *bin_2, *bin_3, *mif_2, *mif_3, *descrip_vh;
u32 i_2, i_3;
u32 c_2, c_3;

u8	*a;
u8	*z;
u8	buf_2[1024] = {0, };
u8	buf_3[1024] = {0, };
u32 bytes_pending_2;
u32 bytes_pending_3;
u8	bitwidth_2;
u8	bitwidth_3;
u32 bytes_written_2 = 0; 
u32 bytes_written_3 = 0;

void fail(void *ret, char *str)
{
	if(ret == NULL){
		printf("\n* FAIL: %s\n", str);
		exit(-1);
	}
}

void write_buf8(u8 *buf, u32 size)
{
	u32 i;
	for(i = 0; i < size; i++){
		fprintf(mif_2, "%d\t : %02X ;\n", i_2++, *buf++);
		fwrite(buf-1, 1, 1, bin_2);
		bytes_written_2 ++;
	}
}

void write_buf32(u32 *buf, u32 size)
{
	u32 i, w;
	for(i = 0; i < size; i+=4){
		w = *buf;
		w = (w & 0xff) << 24 | (w & 0xff00) << 8 | (w & 0xff0000) >> 8 | (w & 0xff000000) >> 24 ;
		fprintf(mif_3, "%d\t : %08X ;\n", i_3++, w);
		fwrite(buf, 4, 1, bin_3);
		*buf++;
		bytes_written_3 += 4;
	}
}

void write_buf(void *buf, u32 size)
{
	write_buf8(buf, size);
	write_buf32(buf, size);
}

void write_info(char *name, u8 u)
{
	FILE *fp = (u == 0) ? mif_2 : mif_3;
	fprintf(fp, "\n--\n-- Descriptor: %s\n-- \n", name);
}

void add_copyright()
{
	int i;
	FILE *fp;
	for(i = 0; i < 2; i++){
		fp = (i == 0) ? mif_2 : mif_3;
		fprintf(fp, "\n--\n-- usb %d.0 descriptor BRAM init values\n-- Generated with usb3_mifgen tool\n--", (i==0) ? 2 : 3);
		fprintf(fp, "\n-- Copyright (c) 2013 Marshall H.\n-- All rights reserved.");
		fprintf(fp, "\n-- This code is released under the terms of the simplified BSD license.");
		fprintf(fp, "\n-- See LICENSE.TXT for details.\n--\n\n");
		fprintf(fp, "WIDTH=%d;\n", i==0? 8 : 32);
		fprintf(fp, "DEPTH=%d;\n", i==0? (int)pow(2, bitwidth_2) : (int)pow(2, bitwidth_3));
		fprintf(fp, "ADDRESS_RADIX=DECIMAL;\n");
		fprintf(fp, "DATA_RADIX=HEX;\n");
		fprintf(fp, "CONTENT BEGIN\n");
	}
}
void add_close()
{
	int i;
	FILE *fp;
	for(i = 0; i < 2; i++){
		fp = (i == 0) ? mif_2 : mif_3;
		fprintf(fp, "END;\n");
	}
}

void print_offsets(char *name, u8 for_usb2, u8 for_usb3)
{
	if(for_usb2) fprintf(descrip_vh, "parameter\t[%d:0]\tDESCR_USB2_%s	= 'd%d;\n", bitwidth_2-1, name, i_2); 
	if(for_usb3) fprintf(descrip_vh, "parameter\t[%d:0]\tDESCR_USB3_%s	= 'd%d;\n", bitwidth_3-1, name, i_3);
	if(for_usb2) write_info(name, 0);
	if(for_usb3) write_info(name, 1);
}

void add_device_qual(u16 usb_spec, u8 class_code, u8 subclass, u8 protocol_code, u8 max_size_ep0,
					u8 num_possible_config)
{
	a = buf_2;
	print_offsets("DEVICE_QUAL", 1, 0);

	// usb spec 2.10
	// this is not included in USB3 descriptors
	*a++ = 0x0A;
	*a++ = 0x06;
	// *((u16 *)a)++ = (usb_spec == 0x300) ? 0x210 : 0x200;
	// aospan
	// *a++ = (usb_spec == 0x300) ? 0x10 : 0x00;
	*a++ = 0x00; /* FIXME */
	*a++ = 0x02;

	*a++ = class_code;
	*a++ = subclass;
	*a++ = protocol_code;
	*a++ = max_size_ep0;
	*a++ = num_possible_config;
	*a++ = 0;
	write_buf8(buf_2, 0xA); 
}

void add_device_descr(u16 usb_spec, u8 class_code, u8 subclass, u8 protocol_code, u8 max_size_ep0,
					 u16 vid, u16 pid, u16 dev_num, 
					 u8 idx_mfg, u8 idx_prod, u8 idx_serial, u8 num_possible_config)
{
	a = buf_2;
	print_offsets("DEVICE", 1, 1);

	// usb spec 2.10
	*a++ = 0x12;					// length
	*a++ = 0x01;					// descriptor ID
	// TODO: usb 3.0 fix !
	// *((u16 *)a)++ = (usb_spec == 0x300) ? 0x210 : 0x200; // bcdUSB
	*a++ = 0x00;
	*a++ = 0x02;

	write_buf8(buf_2, 4); a = buf_2+2;
	// usb spec 3.00
	// *((u16 *)a)++ = 0x0300;			// bcdUSB
	*a++ = 0x00;
	*a++ = 0x03;

	write_buf32(buf_2, 4); a = buf_2;

	*a++ = class_code;				// bDeviceClass
	*a++ = subclass;				// bDeviceSubClass	
	*a++ = protocol_code;			// bDeviceProtocol	
	*a++ = max_size_ep0;			// bMaxPacketSize0
	write_buf8(buf_2, 4); a--;
	*a++ = 0x09;					// USB3: 512 bytes fixed EP0
	write_buf32(buf_2, 4); a = buf_2;

	// *((u16 *)a)++ = vid;
	*a++ = (vid&0xff);
	*a++ = (vid >> 8);
	// *((u16 *)a)++ = pid;
	*a++ = (pid&0xff);
	*a++ = (pid >> 8);
	//*((u16 *)a)++ = dev_num;
	*a++ = (dev_num&0xff);
	*a++ = (dev_num >> 8);
	*a++ = idx_mfg;
	*a++ = idx_prod;
	*a++ = idx_serial;
	*a++ = num_possible_config;		// bNumConfigurations
	write_buf(buf_2, 10);

	add_device_qual(	usb_spec,		// USB spec number (2.xx only)
						class_code,		// Device Class
						subclass,		// Device subclass
						protocol_code,	// Device protocol code
						max_size_ep0,	// Endpoint0 Max packet
						num_possible_config
					);
}
				
void add_config_start(u16 usb_spec, u8 attrib, u32 power_ma, u8 num_endpoints)
{
	a = buf_2;
	z = buf_3;
	c_2 = i_2;
	c_3 = i_3;
	print_offsets("CONFIG", 1, 1);
	bytes_pending_2 = 0;
	bytes_pending_3 = 0;

	// write Config descriptor
	*a++ = 0x09;				// length
	*a++ = 0x02;				// descriptor ID

	// aospan
	//*((u16 *)a)++ = 0xffff;		// total length, must be overwritten later
	*a++ = 0xFF;
	*a++ = 0xFF;
	*a++ = 0x01;				// bNumInterfaces
	*a++ = 0x01;				// bConfigurationValue
	*a++ = 0x00;				// iConfiguration
	*a++ = attrib;				// bmAttributes
	*a++ = (usb_spec == 0x300) ? power_ma / 8 : power_ma / 2;
	bytes_pending_2 += 0x9;
	bytes_pending_3 += 0x9;

	// write Interface descriptor
	*a++ = 0x09;				// length
	*a++ = 0x04;				// descriptor ID
	*a++ = 0x00;				// bInterfaceNumber	
	*a++ = 0x00;				// bAlternateSetting
	*a++ = num_endpoints;		// bNumEndpoints
	*a++ = 0xFF;				// bInterfaceClass
	*a++ = 0 /* 0xFF */;				// bInterfaceSubClass
	*a++ = 0 /* 0xFF */;				// bInterfaceProtocol
	*a++ = 0x02;				// iInterface
	bytes_pending_2 += 0x9;
	bytes_pending_3 += 0x9;

	// now here's the annoying part...
	// create a second buffer just for usb3
	// since it has companion descriptors 
	memcpy(buf_3, buf_2, bytes_pending_2);
	z += bytes_pending_3;
}

void add_endpoint(u8 idx, u8 dir, u8 attrib, u16 max_pkt, u8 interval, u8 max_burst,
				 u8 attrib_3, u16 bytes_per_interval )
{
	u8 *c = a;

	// write Endpoint descriptor
	*a++ = 0x07;				// length
	*a++ = 0x05;				// descriptor ID
	*a++ = idx | (dir ? 0x80 : 0x0);				
	*a++ = attrib;				// bmAttributes
	// *((u16 *)a)++ = max_pkt;	// max packet size
	*a++ = (max_pkt&0xff);
	*a++ = (max_pkt >> 8); // aospan: bits 12..11 Number of transactions per microframe
	*a++ = interval;			// bInterval
	bytes_pending_2 += 0x7;
	bytes_pending_3 += 0x7;

	// copy this endpoint over to USB3
	memcpy(z, c, 0x7);
	z += 0x7;
	// patch max packet size to 1024
	*(z-2) = 0x04;
	*(z-3) = 0x00;	
	
	// add companion descriptor only to USB3 buffer
	*z++ = 0x06;				// length
	*z++ = 0x30;				// descriptor ID
	*z++ = max_burst-1;				
	*z++ = attrib_3;			// bmAttributes
	// *((u16 *)z)++ = bytes_per_interval;	// wBytesPerInterval
	*z++ = (bytes_per_interval&0xff);
	*z++ = (bytes_per_interval >> 8);
	bytes_pending_3 += 0x6;
	
}


void add_config_end()
{
	u8 *c = a;
	// add alternate interface
	// this is needed so that windows can select it if isoch. bandwidth
	// is not able to be reserved
	*a++ = 0x09;				// length
	*a++ = 0x04;				// descriptor ID
	*a++ = 0x00;				// bInterfaceNumber	
	*a++ = 0x01;				// bAlternateSetting
	*a++ = 0x0;					// bNumEndpoints
	*a++ = 0xFF;				// bInterfaceClass
	*a++ = 0xFF;				// bInterfaceSubClass
	*a++ = 0xFF;				// bInterfaceProtocol
	*a++ = 0x02;				// iInterface
	bytes_pending_2 += 0x9;
	bytes_pending_3 += 0x9;

	// copy this interface over to USB3
	memcpy(z, c, 0x9);
	z += 0x9;

	// patch total descriptor lengths
	memcpy(&buf_2[2], &bytes_pending_2, 2);
	memcpy(&buf_3[2], &bytes_pending_3, 2);

	write_buf8(buf_2, bytes_pending_2);
	write_buf32(buf_3, bytes_pending_3);
}

void add_bos()
{
	z = buf_3;
	print_offsets("BOS    ", 0, 1);

	*z++ = 0x05;				// bLength
	*z++ = 0x0F;				// bDescriptorType
	*z++ = 0x16;				// wTotalLength
	*z++ = 0x00;				//

	*z++ = 0x02;				// bNumDeviceCaps

	*z++ = 0x07;				// bLength
	*z++ = 0x10;				// bDescriptorType
	*z++ = 0x02;				// bDevCapabilityType (USB 2.0 EXTENSION)
	//*((u32 *)z)++ = 0x2;		// 32bit field: LPM Supported (SS Required)
	*z++ = 0x02;
	*z++ = 0x00;
	*z++ = 0x00;
	*z++ = 0x00;
	
	*z++ = 0x0A;				// bLength
	*z++ = 0x10;				// bDescriptorType
	*z++ = 0x03;				// bDevCapabilityType (SUPERSPEED_USB)
	*z++ = 0x00;				// bmAttributes (8bit) (LTM Generation Incapable)
	// *((u16 *)z)++ = 0xE;		// wSpeedsSupported (Operation supported FS, HS, SS)
	*z++ = 0x0E;
	*z++ = 0x00;

	*z++ = 0x02;				// bFunctionalitySupported (Valid operation starts with HS)
	*z++ = 0x08;				// bU1DevExitLat (Less than 8uS)
	// *((u16 *)z)++ = 0x64;		// wU2DevExitLat (Less than 100uS)
	*z++ = 0x64;
	*z++ = 0x00;

	write_buf32(buf_3, z - buf_3);
}

#define BUFSZ 512

void add_string(u8 idx, char* str)
{
	char temp[32];
	wchar_t w_str[BUFSZ];
	char * dst_str = (char*) w_str;
	int ret = 0;
	size_t dstlen = BUFSZ, inlen = 0;
	u32 len;
	iconv_t conv = iconv_open("UCS2", "ASCII");
	if(conv < 0) {
		printf("can't open iconv ! \n");
		exit(1);
	}

	if(idx == 0) 
		len = 4;		// string0 is fixed at 4 bytes for language code
	else
		len = strlen(str)*2+2;

	memset(buf_2, 0, sizeof(buf_2));
	a = buf_2;

	sprintf(temp, "STRING%d", idx);
	print_offsets(temp, 1, 1);

	if(idx > 0)  {
		/* can't use mbstowcs because produce 4 byte encoded UTF strings
		 * under Linux */
		inlen = strlen(str);
		ret = iconv(conv, &str, &inlen, &dst_str, &dstlen);
		if (ret)
		{
			printf("can't convert string \n");
			exit(1);
		}
	} else {
		memcpy(&w_str[0], str, 2);
	}

	*a++ = len;
	*a++ = 0x03;
	memcpy(a, w_str, len-2);
	write_buf(buf_2, len);
	printf("adding string len=%d \n", len);
	iconv_close(conv);
}

void add_langs()
{
	char temp[32];
	char buf[] = { 0x06, 0x03, /* len + const */
		0x09, 0x04, /* english */ 
		0x00, 0x00 /* OS string descriptors */ };

	memset(buf_2, 0, sizeof(buf_2));
	a = buf_2;

	sprintf(temp, "STRING0");
	print_offsets(temp, 1, 1);

	memcpy(a, buf, sizeof(buf));
	write_buf(buf_2, sizeof(buf));
	printf("adding langs. len=%d\n", sizeof(buf));
}

void add_winusb_compat()
{
	char temp[32];

#if 1
	/* USB\MS_COMP_WINUSB */
	char buf[] = { 0x28, 0x00, 0x00, 0x00, /* length 40 bytes*/
		0x00, 0x01, /* version */
		0x04, 0x00, /* Extended compat ID descriptor */
		0x01, /* Number of function sections */
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* reserved */
		0x00, /*Interface number */
		0x01,  /* Reserved */
		0x57, 0x49, 0x4E, 0x55, 0x53, 0x42, 0x00, 0x00, /* WINUSB */
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* Secondary ID. */
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
#endif

#if 0
	char buf[] = { 0x58, 0x00, 0x00, 0x00, /* length 40 bytes*/
		0x00, 0x01, /* version */
		0x04, 0x00, /* Extended compat ID descriptor */
		0x03, /* Number of function sections */
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* reserved */
		0x00, /*Interface number */
		0x01,  /* Reserved */
		0x57, 0x49, 0x4E, 0x55, 0x53, 0x42, 0x00, 0x00, /* WINUSB */
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* Secondary ID. */
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x01, /*Interface number */
		0x01,  /* Reserved */
		0x57, 0x49, 0x4E, 0x55, 0x53, 0x42, 0x00, 0x00, /* WINUSB */
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* Secondary ID. */
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x02, /*Interface number */
		0x01,  /* Reserved */
		0x57, 0x49, 0x4E, 0x55, 0x53, 0x42, 0x00, 0x00, /* WINUSB */
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* Secondary ID. */
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
	};
#endif

	memset(buf_2, 0, sizeof(buf_2));
	a = buf_2;

	sprintf(temp, "MS_COMPAT");
	print_offsets(temp, 1, 1);

	memcpy(a, buf, sizeof(buf));
	write_buf(buf_2, sizeof(buf));
	printf("adding winusb composite. len=%d\n", sizeof(buf));
}

void add_set()
{
	print_offsets("CONFUNSET", 1, 1);
	write_buf("\x00", 1);
	print_offsets("CONFSET", 1, 1);
	write_buf("\x01", 1);
}

void add_status()
{
	print_offsets("STATUS", 1, 1);
	write_buf("\x00\x00", 2);
}

void help() {
        printf("Usage:\n");
	// can be checked:
	// $ lsusb -D /dev/bus/usb/002/008  | grep bcdDevice
	//       bcdDevice            0.20
        printf("        -r revision	Joker TV firmware revision\n");
	exit(0);
}

int main(int argc, char *argv[])
{
	u32 temp1, temp2;
	i_2 = 0;
	i_3 = 0;
	int c = 0;
	int fw_revision = -1; // mandatory

	printf("\n* Daisho USB 3.0 / USB 2.0 descriptor export tool\n  by marshallh, 2013\n");
	printf("\n* Joker TV modification by Abylay Ospan, 2017\n");

        while ((c = getopt (argc, argv, "r:")) != -1) {
                switch (c)
                {
                        case 'r':
                                fw_revision = atoi(optarg);
                                break;
                        default:
                                help();
                                return 0;
                }
        }

	if (fw_revision < 0)
		help();

	fail(mif_2 = fopen(filename_usb2_mif, "w"), "Failed opening USB2.0 MIF");
	fail(mif_3 = fopen(filename_usb3_mif, "w"), "Failed opening USB3.0 MIF");
	fail(bin_2 = fopen(filename_usb2_bin, "wb"), "Failed opening USB2.0 BIN");
	fail(bin_3 = fopen(filename_usb3_bin, "wb"), "Failed opening USB3.0 BIN");
	fail(descrip_vh = fopen(filename_descrip_vh, "w"), "Failed opening descriptor include");

	// set your BRAM address bit widths
	bitwidth_2 = 8;	// [7:0]
	bitwidth_3 = 7;	// [6:0]

	printf ("* Generating...\n");
	add_copyright();
	
	add_device_descr(	0x300,		// USB spec number (auto fixed 2.10 for 2.0)
									// put 0x200 if you only use USB 2.0 core
						// 0xFF,		// Class Code
						// 0xFF,		// Subclass
						// 0xFF,		// Protocol Code
						0x0 /* 239 */ /* 0xFF */,		// Class Code
						0x0 /* 2 */ /* 0xFF */,		// Subclass
						0x0 /* 1 */ /* 0xFF */,		// Protocol Code
						64,			// Endpoint0 Max packet (ignored for 3.0)
						0x2D6B,		// Vendor ID
						0x7777,		// Product ID
						fw_revision,		// Device release number
						1,			// Index of Manufacturer Str Descriptor
						2,			// Index of Product Str Descriptor
						3,			// Index of Serial Number Str Descriptor
						1			// Number of Possible Configs
					);

	add_config_start(	0x300,		// USB spec number (auto fixed 2.10 for 2.0),
						0x80,		// TODO attributes (self powered)
						500,		// Power draw in mA
						4			// Number of endpoints
					);

	add_endpoint(		1,			// EP1
						1,			// IN
						2,			// BULK
						512,		// Max packet size (autofixed to 1024 for USB3)
						0x1,		// Interval for isoch. endpoints
						16,			// Max burst packets for usb 3.0
						0x00,		// No stream support 
						0			// 0bytes per interval (BULK)
					);

	add_endpoint(		2,			// EP2
						0,			// OUT
						2,			// BULK
						512,		// Max packet size (autofixed to 1024 for USB3)
						0x1,		// Interval for isoch. endpoints
						16,			// Max burst packets for usb 3.0
						0x00,		// No stream support 
						0			// 0bytes per interval (BULK)
					);

	add_endpoint(		3,			// EP1
						1,			// IN
						1,			// ISOC
						// 2,			// BULK
						// 512,		// Max packet size (autofixed to 1024 for USB3)
						// for ISOC:
						// bits 12..11 Number of transactions per microframe
						// 0x200,		// 1 x 512 bytes
						// 0x400,		// 1 x 1024 bytes
						// 0x800 | 0x400,		// 2 x 1024 bytes
						0x1000 | 0x400,		// 3 x 1024 bytes
						
						0x1,		// Interval for isoch. endpoints
						16,			// Max burst packets for usb 3.0
						0x00,		// No stream support 
						0			// 0bytes per interval (BULK)
					);

	add_endpoint(		4,			// EP4 for TS from host, bulk
						0,			// OUT
						2,			// BULK
						512,		// Max packet size (autofixed to 1024 for USB3)
						0x1,		// Interval for isoch. endpoints
						16,			// Max burst packets for usb 3.0
						0x00,		// No stream support 
						0			// 0bytes per interval (BULK)
					);

	add_config_end();
	printf("aospan: add_config_end \n");

	// hack to print out CONFIG length
	temp1 = i_2;
	temp2 = i_3;
	i_2 = bytes_pending_2;
	i_3 = bytes_pending_3;
	print_offsets("CONFIG_LEN", 1, 1);
	i_2 = temp1;
	i_3 = temp2;

	add_bos();
	printf("aospan: add_bos\n");

	// hack to print out BOS length
	temp2 = i_3;
	i_3 = z - buf_3;
	print_offsets("BOS_LEN", 0, 1);
	i_3 = temp2;

	add_langs();
	// add_string(0, "\x09\x04\x00\x00\0");
	add_string(1, "Joker Systems Inc.");
	add_string(2, "Joker TV");
	add_string(3, "JOKERTV000");
	add_string(0xEE, "MSFT100\x77\x00");
	add_winusb_compat();

	add_set();

	add_status();

	print_offsets("EOF     ", 1, 1);

	// pad out files to their max address space
	while(bytes_written_2 < pow(2, bitwidth_2)) write_buf8("\0", 1);
	while(bytes_written_3 < pow(2, bitwidth_3)*4) write_buf32("\0\0\0\0", 1);

	add_close();
	printf("* Finished\n");
	fclose(bin_2);
	fclose(bin_3);
	fclose(mif_2);
	fclose(mif_3);
	fclose(descrip_vh);
	return 0;
}


