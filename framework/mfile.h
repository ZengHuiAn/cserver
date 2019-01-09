#ifndef _AGAME_MFILE_H_
#define _AGAME_MFILE_H_

unsigned int mfile_write(unsigned int ref, const char * buff, size_t len, const char * prefix);
int          mfile_read (unsigned int ref,       char * buff, size_t len, const char * prefix);
const char * mfile_lasterror();

#endif
