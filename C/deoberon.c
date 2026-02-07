#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/*
A program to convert an Oberon text file to an ASCII text file.

An Oberon text file consists of a variable-sized header followed
by the ASCII representation of the text. The header contains attribute
information like fonts and colors.

Notes :
OS EndOfLine
Unix 10
DOS 13,10
Mac 13,10
Oberon 13

https://lists.inf.ethz.ch/pipermail/oberon/2016/009433.html
17.4.2016 Srinivas Nayak

*/

int Eof = 0;
int skipTail = 0;

int RdCh(FILE* src)
{
	int byte;

	byte = fgetc(src);
	if(feof(src))
	{
		Eof = 1;
	}

	return byte;
}

void SkipHeader(FILE* src)
{
	int b, word[4];
	int skip;

	word[0] = RdCh(src);
	word[1] = RdCh(src); /* skip 2 bytes */
	if (word[0] != 0xF0 || word[1] != 0x01)
	{
  	if (word[0] != 0x01 || word[1] != 0xF0)
  	{
  	  printf("Unknown file format: %02X %02X\n", word[0], word[1]);
  	  return;
	  }
	}

	/* read a long word in little endian format */
	word[0] = RdCh(src);
	word[1] = RdCh(src);
	word[2] = RdCh(src);
	word[3] = RdCh(src);
	//printf("word[0] = %x\n", word[0]);
	//printf("word[1] = %x\n", word[1]);
	//printf("word[2] = %x\n", word[2]);
	//printf("word[3] = %x\n", word[3]);
	if(word[0] == 'T' && word[1] == 'e' && word[2] == 'x' && word[3] == 't') //if it is "TextDocs.NewDoc"
	{
		for (skip=96; skip > 0; skip--) RdCh(src); //skip 60 more bytes
		RdCh(src); RdCh(src); /* skip 2 bytes */
		/* read a long word in little endian format */
		word[0] = RdCh(src);
		word[1] = RdCh(src);
		word[2] = RdCh(src);
		word[3] = RdCh(src);

		printf("This is a TextDocs file\n");

	}

	/* seek to start of ascii text */
	skip =  (word[3]<<24) + (word[2]<<16) + (word[1]<<8) + (word[0]) - 6;
	printf("Header skip = %d bytes\n", skip);

	for (; skip > 0; skip--)
	{
	  RdCh(src);
	  if (Eof == 1)
	  {
  	  printf("unexpected Eof\n");
  	  fclose(src);
  	  exit(1);
	  }
  }
}


int main(int argc, char *argv[])
{
	FILE *src, *dst;
	int c;
	char dst_file_name[64];

	if(argc != 2)
	{
		printf("Usage: ./deoberon <file name>\n");
		printf("This will generate <file name>.txt\n");
		exit(1);
	}

	src = fopen(argv[1], "rb");
	if (src == NULL)
	{
		printf("Error opening file %s\n", argv[1]);
		exit(1);
	}


	if (strlen(argv[1]) > sizeof(dst_file_name) - 4 - 1)
	{
  	printf("File name too long %s\n", dst_file_name);
  	exit(1);
	}
	strcpy(dst_file_name, argv[1]);
	strcat(dst_file_name, ".txt");

	dst = fopen(dst_file_name, "wt");
	if (dst == NULL)
	{
		printf("Error creating file %s\n", dst_file_name);
		fclose(src);
		exit(1);
	}

	printf("Source file %s\n", argv[1]);

	SkipHeader(src);

	c = RdCh(src);
	while (Eof != 1)
	{
		if ( c == 13 )
		{
			c = '\n';
			fputc(c, dst);
		}
		else if ( c == '\t' )
		{
			fputc(' ', dst);
			fputc(' ', dst);
			fputc(' ', dst);
			fputc(' ', dst);
		}
		else if ( iscntrl(c) )
		{
			fputc(' ', dst);
		}
		else
		{
			if(c == 219)
			{
				skipTail = 1;
			}

			if(skipTail != 1)
			{
				fputc(c, dst);
			}
		}

		c = RdCh(src);
	}

	fclose(src);
	fclose(dst);

	printf("Generated file %s\n", dst_file_name);

	return 0;
}