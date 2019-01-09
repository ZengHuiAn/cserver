#include <assert.h>
#include <string.h>

#include "network.h"
#include "log.h"
#include "message.h"
#include "player.h"
#include "package.h"
#include "mtime.h"
#include "build_message.h"
#include "dlist.h"

#include "logic/aL.h"
#include "protocol.h"
#include "do.h"
#include "config.h"
#include "modules/quest.h"
#include "config/quest.h"

void do_pbc_quest_query_info(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PGetPlayerQuestInfoRequest", "PGetPlayerQuestInfoRespond");

	if (channel != 0) {
		WRITE_DEBUG_LOG("!!!!! RET_PERMISSION");
		result = RET_PERMISSION;
	} else {
		READ_INT64(pid);
		READ_INT(include_finished_and_canceled);

		// READ_INT(type);

		// WRITE_DEBUG_LOG("service query quest %llu, %d", pid, include_finished_and_canceled, type)

		struct Player * player = player_get(pid);
		if (player == 0) {
			result = RET_NOT_EXIST;
		} else {
			result = RET_SUCCESS;

			int i, ntype = pbc_rmessage_size(request, "types");
			int types[ntype];
			for (i = 0 ; i < ntype; i++) {
				types[i] = pbc_rmessage_integer(request, "types", i, 0);
			}

			struct Quest * ite = 0;
			while ((ite = quest_next(player, ite)) != 0) {
				aL_update_quest_status(ite, 0);

				if (!include_finished_and_canceled && ite->status != QUEST_STATUS_INIT) {
					continue;
				}

				struct QuestConfig * cfg = get_quest_config(ite->id);
				if (cfg == 0) {
					continue;
				}

				if (ntype > 0) {
					int match = 0;
					for (i = 0; i < ntype; i++) {
						if (types[i] == cfg->type) {
							match = 1;
							break;
						}
					}

					if (!match) {
						continue;	
					}
				}

				WRITE_DEBUG_LOG(" --> %d, %d, %d", ite->id, ite->id, ite->status);

				struct pbc_wmessage * quest = pbc_wmessage_message(respond, "quests");

				pbc_wmessage_int64(quest, "uuid", ite->id);
				pbc_wmessage_int64(quest, "id",   ite->id);
				pbc_wmessage_integer(quest, "status",  ite->status, 0);
				pbc_wmessage_integer(quest, "count",   ite->count, 0);
				pbc_wmessage_integer(quest, "records", ite->record_1, 0);
				pbc_wmessage_integer(quest, "records", ite->record_2, 1);
				pbc_wmessage_int64(quest, "accept_time", ite->accept_time);
				pbc_wmessage_int64(quest, "submit_time", ite->submit_time);

				pbc_wmessage_integer(quest, "type",    cfg->type, 0);
			}
		}
	}

	FINI_REQUET_RESPOND(C_QUERY_QUEST_RESPOND, result);
}

void do_pbc_quest_set_status(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PSetPlayerQuestRequest", "PSetPlayerQuestRespond");

	int from_client = (channel != 0) ? 1 : 0;

	READ_INT64(pid);
	READ_INT64(uuid);
	READ_INT(id);
	READ_INT(status);
	READ_INT(rich_reward);
	READ_INT(pool);

	int record_1 = pbc_rmessage_integer(request, "records", 0, 0);
	int record_2 = pbc_rmessage_integer(request, "records", 1, 0);

	if (uuid) { id = uuid; }

	WRITE_DEBUG_LOG("service set player %llu pool %d quest %d status %d, records %d,%d", pid, pool, id, status, record_1, record_2);

	struct Player * player = player_get(pid);
	if (player == 0) {
		result = RET_NOT_EXIST;
	} else {
		if (status == QUEST_STATUS_INIT) {
			if (pool != 0) {
				struct QuestConfig * cfg = get_quest_from_pool(pool, player_get_level(player));
				if (cfg == 0) {
					WRITE_DEBUG_LOG("  find quest from pool %d failed", pool);
				} else {
					id = cfg->id;
					result = aL_quest_accept(player, cfg->id, from_client);
				}
			} else if (id != 0) {
				result = aL_quest_accept(player, id, from_client);
			}
		} else if (status == QUEST_STATUS_CANCEL) {
			result = aL_quest_cancel(player, id, from_client);
		} else if (status == QUEST_STATUS_FINISH) {
			result = aL_quest_submit(player, id, rich_reward, from_client, 0);
		}

		uuid = id;
		WRITE_INT64(uuid);
	}

	FINI_REQUET_RESPOND(C_SET_QUEST_STATUS_RESPOND, result);
}



void do_pbc_quest_on_event(resid_t conn, unsigned long long channel, const char * data, size_t len)
{
	INIT_REQUET_RESPOND("PNotifyPlayerQuestEventRequest", "aGameRespond");

	if (channel != 0) {
		return;
	}

	result = RET_SUCCESS;

	READ_INT64(pid);

	struct Player * target_player = player_get(pid);
	if (target_player != 0) {
		int n = pbc_rmessage_size(request, "events");

		int i;
		for (i = 0; i < n; i++) {
			struct pbc_rmessage * event = pbc_rmessage_message(request, "events", i);
			int type  = pbc_rmessage_integer(event, "type",  0, 0);
			int id    = pbc_rmessage_integer(event, "id",    0, 0);
			int count = pbc_rmessage_integer(event, "count", 0, 0);

			aL_quest_on_event(target_player, type, id, count);
		}
	}

	FINI_REQUET_RESPOND(S_NOTIFY_QUSET_EVENT_RESPOND, result);
}
