#include <assert.h>
#include <string.h>

#include "log.h"
#include "message.h"
#include "player.h"
#include "package.h"
#include "amf.h"
#include "build_message.h"
#include "logic/aL.h"

#include "do.h"

BEGIN_FUNCTION(login, "LoginRequest", "LoginRespond")
	WRITE_INFO_LOG("player %llu login", channel);

	result = aL_login(channel, 0, 0);
END_FUNCTION(C_LOGIN_RESPOND)

BEGIN_FUNCTION(logout, "LogoutRequest", "LogoutRespond")
	READ_INT(reason);

	WRITE_INFO_LOG("player %llu logout, reason: %d", channel, reason);
	result = aL_logout(channel);

END_FUNCTION(C_LOGOUT_RESPOND)
