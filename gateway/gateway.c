#include "service.h"

#include "account.h"
#include "client.h"
#include "world.h"
#include "backend.h"
#include "record.h"
#include "protocol.h"
#include "listener.h"
#include "database.h"
#include "authserver.h"

SERVICE_BEGIN()  
	// IMPORT_MODULE(profiler),
	IMPORT_MODULE(protocol),
	IMPORT_MODULE(listener),
	IMPORT_MODULE(account),
	IMPORT_MODULE(client),
	IMPORT_MODULE(world),
	IMPORT_MODULE(backend),
	IMPORT_MODULE(record),
	IMPORT_MODULE(database),
	IMPORT_MODULE(authserver),
SERVICE_END()  
