#ifndef _SGK_CONFIG_TITLE_H_
#define _SGK_CONFIG_TITLE_H_

struct TitleConfig
{
	struct TitleConfig * prev;
	struct TitleConfig * next;

	int id;
	int type;
	int condition1;
	int condition2;
	int condition3;
	int being_icon;
};


struct TitleConfig * get_title_config(int id);
struct TitleConfig * title_config_next(TitleConfig * cfg);

int load_title_config();

#endif
