#include "base64.h"
#include "cencode.h"
#include "cdecode.h"
#include "string.h"

int base64_encode(const char* input, int length_in, char * output)
{
	/* set up a destination buffer large enough to hold the encoded data */
	//char* output = (char*)malloc(SIZE);
	/* keep track of our encoded position */
	char* c = output;
	/* store the number of bytes encoded by a single call */
	int cnt = 0;
	/* we need an encoder state */
	base64_encodestate s;
	
	/*---------- START ENCODING ----------*/
	/* initialise the encoder state */
	base64_init_encodestate(&s);
	/* gather data from the input and send it to the output */
	cnt = base64_encode_block(input, length_in, c, &s);
	c += cnt;
	/* since we have encoded the entire input string, we know that 
	   there is no more input data; finalise the encoding */
	cnt = base64_encode_blockend(c, &s);
	c += cnt;
	/*---------- STOP ENCODING  ----------*/
	
	/* we want to print the encoded data, so null-terminate it: */
	*c = 0;
	
	return 0;	
}

int base64_decode(const char* input, char * output)
{
	/* set up a destination buffer large enough to hold the encoded data */
	//char* output = (char*)malloc(SIZE);
	/* keep track of our decoded position */
	char* c = output;
	/* store the number of bytes decoded by a single call */
	int cnt = 0;
	/* we need a decoder state */
	base64_decodestate s;
	
	/*---------- START DECODING ----------*/
	/* initialise the decoder state */
	base64_init_decodestate(&s);
	/* decode the input data */
	cnt = base64_decode_block(input, strlen(input), c, &s);
	c += cnt;
	/* note: there is no base64_decode_blockend! */
	/*---------- STOP DECODING  ----------*/
	
	/* we want to print the decoded data, so null-terminate it: */
	*c = 0;
	
	return cnt;
}

