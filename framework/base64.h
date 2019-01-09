#ifndef _SGK_BASE64_H_
#define _SGK_BASE64_H_

int base64_encode(const char* input, int length_in, char * ouput);
int base64_decode(const char* input, char * output);

#endif
