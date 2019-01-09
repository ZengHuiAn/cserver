#include "network.h"
#include "service.h"

#include "listener.h"
#include "database.h"
#include "script.h"
#include "player.h"
#include "notify.h"
#include "protocol.h"
#include "logic_config.h"
#include "event_manager.h"
#include "realtime.h"
#include "addicted.h"
#include "timer.h"
#include "timeline.h"
#include "backend.h"
#include "channel.h"
#include "profiler.h"
#include "aiLevel.h"
#include "rankreward.h"

SERVICE_BEGIN()  
	//IMPORT_MODULE(profiler),
	IMPORT_MODULE(protocol),
	IMPORT_MODULE(logic_config),
	IMPORT_MODULE(listener),
	IMPORT_MODULE(event_manager),
	IMPORT_MODULE(timer),
	IMPORT_MODULE(database),
	IMPORT_MODULE(backend),
	IMPORT_MODULE(channel),
	IMPORT_MODULE(realtime),
	IMPORT_MODULE(timeline),
	IMPORT_MODULE(addicted),
	IMPORT_MODULE(notify),
	IMPORT_MODULE(player),
	IMPORT_MODULE(aiLevel),
	IMPORT_MODULE(rankreward),
SERVICE_END()  
