
��
agame.protocom.agame.protocol"�
Player

id (
name (	
level (
country (
sex (
login (
logout
 (
status
exp (
vip (
today_online (
tower (
avatar (2.com.agame.protocol.Avatar
salary (

ip (	
create (
money (
Morale
attack (
defense (
init (
HeroSpellResult
cast (
selector (2,.com.agame.protocol.HeroSpellResult.Selector:
change (2*.com.agame.protocol.HeroSpellResult.Change
view (
Selector
type (
count (
Change
type (
value ("j
	HeroSpell
name (	3
result (2#.com.agame.protocol.HeroSpellResult

id (
effect (
Hero

id (
name (	
level (
attack (
defense (
morale (2.com.agame.protocol.Morale,
spell (2.com.agame.protocol.HeroSpell"�
Relation
target (
attack (
hurtIncrease (

hurtReduce (
hit (
dodge (
block (
crit ("�
Soldier
type (
level (
count (
health (
range (
move (
speed (
	relations (2.com.agame.protocol.Relation
dead	 (
max
 (
morale (2.com.agame.protocol.Morale"_
	TowerTool

id (
target (
count (
used (
per (
hurt (
Tower
pos (
level (

hp (
tools (2.com.agame.protocol.TowerTool"�
Avatar
	banner_id (
scale (
hero_skin_id (
hero_body_type (	
weapon_skin_id (
weapon_body_type (	

mount_body_type (	
pet_skin_id	 (

 (	"�
Army
pos (
hero (2.com.agame.protocol.Hero,
soldier (2.com.agame.protocol.Soldier*
avatar (2.com.agame.protocol.Avatar"%
Resource

id (
value (
Reward
type (
value (

id (
uuid (
uuids ("
aGameRequest

sn (
aGameRespond

sn (
result ("6
LoginRequest

sn (
name (	
auth (	"6
LoginRespond

sn (
result (

id (


sn (
reason (


sn (
result (",
QueryPlayerRequest

sn (

id ("�
QueryPlayerRespond

sn (
result (
	skill_id0 (
	skill_id1 (
	skill_id2 (
	skill_id3 (
	skill_id4 (
star (
CreatePlayerRequest

sn (
name (	
county (
sex (
UpgradeBuildingRequest

sn (

id (
UpgradeBuildingRespond

sn (
result (

id (
QueryBuildingRequest

sn (
QueryBuildingRespond

sn (
result (E

_buildings (21.com.agame.protocol.QueryBuildingRespond.Building5
Building

id (
level (
cd (
QueryResourceRequest

sn (
QueryResourceRespond

sn (
result (E

_resources (21.com.agame.protocol.QueryResourceRespond.ResourceM
Resource

id (
value (
limit (
speed (
QueryTechnologyRequest

sn (
QueryTechnologyRespond

sn (
result (K
_technologys (25.com.agame.protocol.QueryTechnologyRespond.Technology7

Technology

id (
level (
cd (
UpgradeTechnologyRequest

sn (

id (
UpgradeTechnologyRespond

sn (
result (

id (
level (
QueryHeroRequest

sn (
type (
heroid (
QueryHeroRespond

sn (
result (
type (
_heros (2).com.agame.protocol.QueryHeroRespond.Hero�
Hero

id (
exp (
level (
grow (
stat (
stype (
scount (

train_type (
train_start	 (
train_delay
 (
title (
employ_time (
EmployHeroRequest

sn (

id (
EmployHeroRespond

sn (
result (

id (
FireHeroRequest

sn (

id (
FireHeroRespond

sn (
result (

id (
TickRequest

sn (
TickRespond

sn (
result (
now (
QueryCooldowRequest

sn (
QueryCooldownRespond

sn (
result (?
_cds (21.com.agame.protocol.QueryCooldownRespond.CooldownB
Cooldown

id (
limit (
value (
type (
VisitHeroRequest

sn (

id (
type (
VisitHeroRespond

sn (
result (

id (
get (
	orelation (
	nrelation (
ExchangeHeroRequest

sn (

h1 (

h2 (
type (
ExchangeHeroRespond

sn (
result (

h1 (

h2 (
GrowHeroRequest

sn (

id (
type (
GrowHeroRespond

sn (
result (

id (
grow (
QueryEquipRequest

sn (
type (
QueryEquipRespond

sn (
result (
type (
_equips (2+.com.agame.protocol.QueryEquipRespond.Equipz
Equip
uuid (

id (
limit (
level (
gem1 (
gem2 (
gem3 (
hid (
UseEquipRequest

sn (
hero (
weapon (
mount (
chest (
head (
trink (
UseEquipRespond

sn (
result (
hero (
old (2,.com.agame.protocol.UseEquipRespond.HeroEuip9
new (2,.com.agame.protocol.UseEquipRespond.HeroEuipU
HeroEuip
weapon (
mount (
chest (
head (
trink (
UpgradeEquipRequest

sn (
uuid (
type (
UpgradeEquipRespond

sn (
result (
type (
uuid (
level (
EquipSetGemRequest

sn (
uuid (
gem1 (
gem2 (
gem3 (
EquipSetGemRespond

sn (
result (
uuid (
old (2/.com.agame.protocol.EquipSetGemRespond.EquipGem<
new (2/.com.agame.protocol.EquipSetGemRespond.EquipGem4
EquipGem
gem1 (
gem2 (
gem3 (
BuyEquipRequest

sn (

id (
BuyEquipRespond

sn (
result (
uuid (

id (
SellEquipRequest

sn (
uuid (
SellEquipRespond

sn (
result (
uuid (
QueryItemRequest

sn (
QueryItemRepond

sn (
result (8
_items (2(.com.agame.protocol.QueryItemRepond.Item!
Item

id (
limit (
BuyItemRequest

sn (

id (
count (
BuyItemRespond

sn (
result (

id (
count (
SellItemRequest

sn (

id (
count (
SellItemRespond

sn (
result (

id (
count (
UseItemRequest

sn (

id (
count (
UseItemRespond

sn (
result (

id (
count (
TrainHeroRequest

sn (

id (
type (
time (
TrainHeroRespond

sn (
result (

id (
FinishTrainHeroRequest

sn (

id (
FinishTrainHeroRespond

sn (
result (

id (
GemstoneComposeRequest

sn (

id (
GemstoneComposeRespond

sn (
result (

id (
QueryFarmRequest

sn (
QueryFarmRespond

sn (
result (9
_farms (2).com.agame.protocol.QueryFarmRespond.Farm0
Farm

id (
seed (
growed (
FarmPlantRequest

sn (

id (
seed (
FarmPlantRespond

sn (
result (

id (
seed (
FarmGainRequest

sn (
force (

id (
FarmGainRespond

sn (
result (
force (>
info (20.com.agame.protocol.FarmGainRespond.FarmGainInfo�
FarmGainInfo

id (
_rewards (2?.com.agame.protocol.FarmGainRespond.FarmGainInfo.FramGainReward-
FramGainReward
type (
value (
SetKingTitleRequest

sn (
title (
SetKingTitleRespond

sn (
result (
title (
SetHeroTitleRequest

sn (

id (
title (
SetHeroTitleRespond

sn (
result (

id (
title (
SetHeroComposeRequest

sn (
id (
h1 (2..com.agame.protocol.SetHeroComposeRequest.Hero:
h2 (2..com.agame.protocol.SetHeroComposeRequest.Hero:
h3 (2..com.agame.protocol.SetHeroComposeRequest.Hero:
h4 (2..com.agame.protocol.SetHeroComposeRequest.Hero:
h5 (2..com.agame.protocol.SetHeroComposeRequest.Hero!
Hero

id (
stype (
SetHeroComposeRespond

sn (
result (
id (
h1 (2..com.agame.protocol.SetHeroComposeRespond.Hero:
h2 (2..com.agame.protocol.SetHeroComposeRespond.Hero:
h3 (2..com.agame.protocol.SetHeroComposeRespond.Hero:
h4 (2..com.agame.protocol.SetHeroComposeRespond.Hero:
h5 (2..com.agame.protocol.SetHeroComposeRespond.Hero!
Hero

id (
stype (
QueryHeroCompseRequest

sn (
QueryHeroCompseRespond

sn (
result (I
	_composes (26.com.agame.protocol.QueryHeroCompseRespond.HeroCompose�
HeroCompose
id (
h1 (2;.com.agame.protocol.QueryHeroCompseRespond.HeroCompose.HeroG
h2 (2;.com.agame.protocol.QueryHeroCompseRespond.HeroCompose.HeroG
h3 (2;.com.agame.protocol.QueryHeroCompseRespond.HeroCompose.HeroG
h4 (2;.com.agame.protocol.QueryHeroCompseRespond.HeroCompose.HeroG
h5 (2;.com.agame.protocol.QueryHeroCompseRespond.HeroCompose.Hero!
Hero

id (
stype (
QueryStoryRequest

sn (
QueryStoryRespond

sn (
result (<
_storys (2+.com.agame.protocol.QueryStoryRespond.Story5
Story

id (
flag (

daily_left (
DoStoryRequest

sn (

id (
DoStoryRespond

sn (
result (

id (
winner (
fightid (
LevyTaxRequest

sn (
force ("H
LevyTaxRespond

sn (
result (
tax (
event (
GetSalaryRequest

sn (
GetSalaryRespond

sn (
result (
salary (
ExchangeEquipRequeset

sn (

h1 (

h2 (
pos (
ExchangeEquipRespond

sn (
result (

h1 (

h2 (
pos (
QueryQuestRequest

sn (
QueryQuestRespond

sn (
result (<
_quests (2+.com.agame.protocol.QueryQuestRespond.Quest2
Quest

id (
status (
count (
SubmitQuestRequest

sn (

id (
SubmitQuestRespond

sn (
result (

id (
ChangeBIORequest

sn (
bio (	"0
ChangeHeadRequest

sn (
head (
FinishTaxEventRequest

sn (
event (
option (
FinishTaxEventRespond

sn (
result (
event (
option (
QueryFlagRequest

sn (
QueryFlagRespond

sn (
result (
flags (	"*
SetFlagRequest

sn (
flag (
SetFlagRespond

sn (
result (
flag (
FarmGainAllRequest

sn (
force ("�
FarmGainAllRespond

sn (
result (
force (A
info (23.com.agame.protocol.FarmGainAllRespond.FarmGainInfo�
FarmGainInfo

id (
_rewards (2B.com.agame.protocol.FarmGainAllRespond.FarmGainInfo.FramGainReward-
FramGainReward
type (
value (
SetCountryRequest

sn (
country (
SetCountryRespond

sn (
result (
country (
CleanCooldownRequest

sn (

id (
CleanCooldownRespond

sn (
result (

id (
FireQueryRequest

sn (
FireQueryRespond

sn (
result (
max (
cur (
left (
FireResetRequest

sn (
FireAttackRequest

sn (
layer (
FireAttackRespond

sn (
result (
max (
cur (
winner (
fightid (
FireAutoRequest

sn (
FireAutoRespond

sn (
result (@
_rewards (2..com.agame.protocol.FireAutoRespond.FireReward

FireReward

id (
TacticQueryRequest

sn (
TacticQueryRespond

sn (
result (
exp (
teacher (
_tactics (2-.com.agame.protocol.TacticQueryRespond.TacticO
Tactic
uuid (

id (
level (
hero (
pos (
TacticVistRequest

sn (
teacher (
TacticVistRespond

sn (
result (
vteacher (
uuid (

id (
rteacher (
point (
TacticMoveRequest

sn (
_moves (2..com.agame.protocol.TacticMoveRequest.MoveInfoA
MoveInfo
uuid (
hero (
pos (
flag (
TacticMoveRespond

sn (
result (
uuid (
hero (
pos (
TacticLearnRequest

sn (
_uuid (
TacticLearnRespond

sn (
result (
exp (
TacticLevelupRequest

sn (
uuid (
TacticLevelupRespond

sn (
result (
uuid (
level (
SetKingAvatarRequest

sn (
	banner_id (
scale (
hero_skin_id (
hero_body_type (	
weapon_skin_id (
weapon_body_type (	

mount_body_type	 (	
flag_skin_id
 (
pet_skin_id (

SetKingAvatarRespond

sn (
result ("+
InviteHeroRequest

sn (

id (
InviteHeroRespond

sn (
result (

id (
QueryGemRequest

sn (
QueryGemRepond

sn (
result (5
_gems (2&.com.agame.protocol.QueryGemRepond.Gem 
Gem

id (
count (


sn (

id (
count (


sn (
result (

id (
count (
SellGemRequest

sn (

id (
count (
SellGemRespond

sn (
result (

id (
count (
BagMoveRequest

sn (
from (

to (
ResetStoryFightCountRequest

sn (
battleid (
SetKingFlagRequest

sn (
flag (
SetKingFlagRespond

sn (
result (
flag (
UpgradeEquipRankRequest

sn (
uuid (
UpgradeEquipRankRespond

sn (
result (
uuid (

id (
BagMoveAdvanceRequest

sn (
from (2..com.agame.protocol.BagMoveAdvanceRequest.Item:
to (2..com.agame.protocol.BagMoveAdvanceRequest.Item!
Item
bag (
slot (
BagMoveAdvanceRespond

sn (
result (<
from (2..com.agame.protocol.BagMoveAdvanceRespond.Item:
to (2..com.agame.protocol.BagMoveAdvanceRespond.Item!
Item
bag (
slot (
ExchangeRequest

sn (

id (
count (
ExchangeRespond

sn (
result (

id (
count (
PArenaQueryRequest

sn (
pid ("L
PArenaQueryRespond

sn (
result (
pid (
order (
PArenaQueryListRequest

sn (
PArenaQueryListRespond

sn (
result (
list (
GuildQueryByPlayerRequest

sn (
playerid ("�
GuildQueryByPlayerRespond

sn (
result (

id (
title (
guild (23.com.agame.protocol.GuildQueryByPlayerRespond.Guild�
Guild

id (
name (	J
leader (2:.com.agame.protocol.GuildQueryByPlayerRespond.Guild.Leader
rank (
member (
exp (
level (

members_id	 ("
Leader

id (
name (	"


sn (
ServiceRegisterRequest

sn (
type (2.com.agame.protocol.ServiceType
id (
players (B"4
ServiceRegisterRespond

sn (
result ("]
ServiceBroadcastRequest

sn (
cmd (
flag (
msg (	
pid ("5
ServiceBroadcastRespond

sn (
result (",
RunScriptRequest

sn (
file (	"P
ChatMessageRequest

sn (
from (
channel (
message (	">
ChatMessageRespond

sn (
result (
info (	"O
RecordNotifyMessageRequest

sn (

to (
cmd (
data (	"c
ChannelMessageRequest

sn (
channel (
cmd (
message (	
flag (
ChangeChatChannelRequest

sn (
pid (
join (
leave (
PGetPlayerArmyRequest

sn (
playerid ("�
PGetPlayerArmyRespond

sn (
result (
info (	'
armys (2.com.agame.protocol.Army(
tower (2.com.agame.protocol.Tower"C
PGetPlayerInfoRequest

sn (
playerid (
name (	"m
PGetPlayerInfoRespond

sn (
result (
info (	*
player (2.com.agame.protocol.Player"Y
PAddPlayerNotificationRequest

sn (
playerid (
type (
data (	"I
PAddPlayerNotificationRespond

sn (
result (
info (	"�
PAdminRewardRequest

sn (
playerid (*
reward (2.com.agame.protocol.Reward@
consume (2/.com.agame.protocol.PAdminRewardRequest.Consume
reason (
manual (
limit (
name (	D
	condition	 (21.com.agame.protocol.PAdminRewardRequest.Condition;
drops
 (2,.com.agame.protocol.PAdminRewardRequest.Drop
heros (

first_time (
send_reward
Consume
type (

id (
value (
uuid (
empty (
	Condition
level (
vip (
item (
armament (
fire (
star (
power (
	level_max (
vip_max	 (
fire_max
 (
star_max (
	power_max (
relationship
daily_id (
daily_max_count (
Drop

id (
level (
PAdminRewardRespond

sn (
result (
info (	+
rewards (2.com.agame.protocol.Reward"E
PSetPlayerLocationRequest

sn (
playerid (

id (
PSetPlayerLocationRespond

sn (
result (
playerid (

id (
PGetPlayerStoryRequest

sn (
playerid (
storys (
PGetPlayerStoryRespond

sn (
result (
storys (
PSetPlayerStatusRequest

sn (
playerid (
status (
PSetPlayerStatusRespond

sn (
result ("7
PAdminPlayerKickRequest

sn (
playerid ("5
PAdminPlayerKickRespond

sn (
result ("9
PGetPlayerBuildingRequest

sn (
playerid ("�
PGetPlayerBuildingRespond

sn (
result (
playerid (H
building (26.com.agame.protocol.PGetPlayerBuildingRespond.Building%
Building

id (
level (
PGetPlayerTechnologyRequest

sn (
playerid ("�
PGetPlayerTechnologyRespond

sn (
result (
playerid (N

technology (2:.com.agame.protocol.PGetPlayerTechnologyRespond.Technology'

Technology

id (
level (
PAdminSetAdultRequest

sn (
pid (
adult (


sn (
pid (5
cards (2&.com.agame.protocol.PAdminSetCard.Card?
Card

id (
content (2.com.agame.protocol.Reward".
GetFormationRequest

sn (
pid ("?
GetFormationRespond

sn (
result (
data (	")
GetKingRequest

sn (
pid (":
GetKingRespond

sn (
result (
data (	"R
GetBossFormationRequest

sn (
fight_id (
level (

hp (
GetMonsterFormationRequest

sn (
fight_id (
level (
GetNpcKingRequest

sn (
fight_id (
level (
PGetPlayerReturnInfoRequest

sn (
playerid (
name (	"�
PGetPlayerReturnInfoRespond

sn (
result (

return_15_time (
return_30_time ("B
PSetPlayerSalaryRequest

sn (
pid (
salary (
PAdminAddActivityInfoRequest

sn (
pid (

id (
value (
PAdminAddVIPExpRequest

sn (
pid (
exp (
SPlayerChangeNotify>
player (2..com.agame.protocol.SPlayerChangeNotify.Player�
Player
pid (
flag (
level (
vip (
charge (
consume (
tower (
records (2;.com.agame.protocol.SPlayerChangeNotify.Player.ChangeRecord8
ChangeRecord
type (
key (
value (
PBossCreateRequest

sn (
type (2".com.agame.protocol.BossCreateType

id (
boss (
time (
PBossCreateRespond

sn (
result (0
type (2".com.agame.protocol.BossCreateType

id (
TimingNotifyAddRequest

sn (
start (
duration (
interval (
type (
message (	
gm_id (
TimingNotifyAddRespond

sn (
result (

id (
TimingNotifyQueryRequest

sn (
TimingNotifyQueryRespond

sn (
result (R
allTimingNotify (29.com.agame.protocol.TimingNotifyQueryRespond.TimingNotifyl
TimingNotify

id (
start (
duration (
interval (
type (
message (	"?
TimingNotifyDelRequest

sn (

id (
gm_id (
S_ROOM_CHECK_REQUEST

sn (
roomType (
roomId (
S_ROOM_CLEAN_REQUEST

sn (
roomType (
roomId (
S_ROOM_CLOSE_REQUEST

sn (
roomType (
roomId (
S_ROOM_CREATE_REQUEST

sn (
roomType (
roomId (
maximum (
S_ROOM_RECREATE_REQUEST

sn (
roomType (
roomId (
maximum (
players (27.com.agame.protocol.S_ROOM_RECREATE_REQUEST.ROOM_PLAYERH
ROOM_PLAYER

id (
startX (
startY (
speed (
S_ROOM_GETPOS_REQUEST

sn (
playerId ("I
S_ROOM_GETPOS_RESPOND

sn (
result (	
x (
y (
S_ROOM_MOVE_REQUEST

sn (
playerId (	
x (
y (
S_ROOM_ENTER_REQUEST

sn (
roomType (
roomId (
playerId (
startX (
startY (
speed (
S_ROOM_GET_ROOMIDS_REQUEST

sn (
roomType (
S_ROOM_GET_ROOMIDS_RESPOND

sn (
result (
roomIds (
S_ROOM_GET_PLAYERIDS_REQUEST

sn (
roomType (
roomId (
S_ROOM_GET_PLAYERIDS_RESPOND

sn (
result (
	playerIds (
AdminAddMailRequest

sn (
from (

to (
type (
title (	
content (	B
appendix (20.com.agame.protocol.AdminAddMailRequest.Appendix3
Appendix
type (

id (
value ("0
AdminQueryMailRequest

sn (
pid ("�
AdminQueryMailRespond

sn (
result (=
mails (2..com.agame.protocol.AdminQueryMailRespond.Mail"
Player

id (
name (	3
Appendix
type (

id (
value (�
Mail

id (
from (20.com.agame.protocol.AdminQueryMailRespond.Player<
to (20.com.agame.protocol.AdminQueryMailRespond.Player
type (
title (	
content (	D
appendix	 (22.com.agame.protocol.AdminQueryMailRespond.Appendix
time (
status (
AdminDelMailRequest

sn (

id (
PGuildAddExpRequest

sn (
gid (
exp (
pid ("/
MailContactGetRequest

sn (

id (
MailContactGetRespond

sn (
result (C
contacts (21.com.agame.protocol.MailContactGetRespond.Contact_
Contact

id (
type (
name (	
online (
level (
rtype (
PvpFightRequest

sn (

attack_pid (

defend_pid (
PvpFightRespond

sn (
result (
winner (

fight_data (	
fight_record_id (
	cool_down ("c
PveFightPrepareRequest

sn (
playerid (
fight_id (
level (

hp ("a
PveFightPrepareRespond

sn (
result (

fight_data (	
fight_record_id ("a
PveFightCheckRequest

sn (
playerid (

fight_data (	
fight_record_id ("�
PveFightCheckRespond

sn (
result (

hp (
winner (
	cool_down (D
reward_list (2/.com.agame.protocol.PveFightCheckRespond.Reward1
Reward
type (

id (
value ("s
PveFightRequest

sn (
playerid (
fight_id (
level (

hp (

PveFightRespond

sn (
result (

hp (
winner (

fight_data (	
	cool_down (
fight_record_id (/
reward_list (2.com.agame.protocol.Reward"*
GetOnlinePlayerRequest
world_id (
GetOnlinePlayerRespond
world_id (
players (
TemplateLoginNotify
from_server_id (
pid (";
TemplateLogoutNotify
from_server_id (
pid ("N
TemplateActionNotify
from_server_id (
pid (
	action_id ("h
AIActionNotify
FromServerId (
FromPid (
ActionId (
Args (
StrArgs (	"S
QueryFormationFightInfoRequest

sn (
playerid (
placeholder ("�
QueryFormationFightInfoRespond

sn  (
pos (
hero_id" (
active! (
level (
attack (
defend (
max_hp (

hp (
fix_hurt (
fix_reduce_hurt (

crit_ratio (
crit_immune_ratio	 (
	crit_hurt
 (
crit_immune_hurt (
disparry_ratio (
parry_ratio

init_power (

incr_power (
attack_speed (

move_speed (

true_blood_ratio (
	skill0_id (
	skill1_id (
scale (
hero_skin_id (
hero_body_type (	
weapon_skin_id (
weapon_body_type (	

mount_body_type (	
name (	
quality (
	weapon_id# (
flag_skin_id$ (
tenacity% (
strength& (
buffs' (
pet_skin_id( (

GuildStoryFightRequest

sn (
player_character_infos (22.com.agame.protocol.QueryFormationFightInfoRespond
guild_leader_pid (
fight_id (
force_lv (
npc_hp ("�
GuildStoryFightRespond

sn (
result (

fight_data (	
fight_record_id (
winner (
	cool_down (
npc_hp (F
reward_list (21.com.agame.protocol.GuildStoryFightRespond.Reward1
Reward
type (

id (
value ("3
UnloadPlayerRequest

sn (
playerid ("3
BuyMonthCardRequest

sn (
playerid ("9
AuthRequest

sn (
account (	
token (	":
AuthRespond

sn (
result (
account (	"A
FightServerTestRequest

sn (
left (
right ("C
FightServerTestRespond

sn (
result (
value ("g
FightServerRunRequest

sn (
uuid (
client_fight_data (	
server_fight_data (	"\
FightServerRunRespond

sn (
result (
uuid (
result_fight_data (	"?
CompensationAddRequest

sn (
pid (
gold (
QueryAllBonusRequest

sn (
QueryAllBonusRespond

sn (
result (=
bonus (2..com.agame.protocol.QueryAllBonusRespond.BonusN
	TimeRange
uuid (
ratio (

begin_time (
end_time (�
Bonus
bonus_id (B
reward (22.com.agame.protocol.QueryAllBonusRespond.TimeRangeA
count (22.com.agame.protocol.QueryAllBonusRespond.TimeRange"1
QueryBonusRequest

sn (
bonus_id ("�
QueryBonusRespond

sn (
result (
bonus_id (?
reward (2/.com.agame.protocol.QueryBonusRespond.TimeRange>
count (2/.com.agame.protocol.QueryBonusRespond.TimeRangeN
	TimeRange
uuid (
ratio (

begin_time (
end_time ("�
ReplaceBonusRequest

sn (
bonus_id (A
reward (21.com.agame.protocol.ReplaceBonusRequest.TimeRange@
count (21.com.agame.protocol.ReplaceBonusRequest.TimeRange@
	TimeRange
ratio (

begin_time (
end_time ("@
RemoveBonusRequest

sn (
bonus_id (
uuid ("{
AddBonusTimeRangeRequest

sn (
bonus_id (
flag (
ratio (

begin_time (
end_time ("D
AddBonusTimeRangeRespond

sn (
result (
uuid ("{
SetBonusTimeRangeRequest

sn (
bonus_id (
uuid (
ratio (

begin_time (
end_time ("F
DelBonusTimeRangeRequest

sn (
bonus_id (
uuid ("7
GmHotUpdateBonusRequest

sn (
bonus_id (",
QueryExchangeGiftRewardRequest

sn (
QueryExchangeGiftRewardRespond

sn (
result (
	open_time (I
reward (29.com.agame.protocol.QueryExchangeGiftRewardRespond.RewardV
Reward

type (

id (
value (
flag ("�
 ReplaceExchangeGiftRewardRequest

sn (
	open_time (K
reward (2;.com.agame.protocol.ReplaceExchangeGiftRewardRequest.RewardV
Reward

type (

id (
value (
flag ("5
'QueryAccumulateConsumeGoldRewardRequest

sn (
'QueryAccumulateConsumeGoldRewardRespond

sn (
result (

begin_time (
end_time (R
reward (2B.com.agame.protocol.QueryAccumulateConsumeGoldRewardRespond.RewardV
Reward

type (

id (
value (
flag ("�
)ReplaceAccumulateConsumeGoldRewardRequest

sn (

begin_time (
end_time (T
reward (2D.com.agame.protocol.ReplaceAccumulateConsumeGoldRewardRequest.RewardV
Reward

type (

id (
value (
flag ("%
QueryItemPackageRequest

sn (
QueryItemPackageRespond

sn (
result (D
package (23.com.agame.protocol.QueryItemPackageRespond.Package/
Item
type (

id (
value (]
Package

package_id (>
item (20.com.agame.protocol.QueryItemPackageRespond.Item"�
SetItemPackageRequest

sn (

package_id (<
item (2..com.agame.protocol.SetItemPackageRequest.Item/
Item
type (

id (
value ("7
DelItemPackageRequest

sn (

package_id ("�
AdminFreshPointRewardRequest

sn (
items (25.com.agame.protocol.AdminFreshPointRewardRequest.Item?
Item
	pool_type (

begin_time (
end_time ("*
AdminQueryPointRewardRequest

sn (
AdminQueryPointRewardRespond

sn (
result (D
items (25.com.agame.protocol.AdminQueryPointRewardRespond.Item?
Item
	pool_type (

begin_time (
end_time ("(
QueryFestivalRewardRequest

sn (
QueryFestivalRewardRespond

sn (
result (E
reward (25.com.agame.protocol.QueryFestivalRewardRespond.RewardO
Reward
offset (
date (
type (

id (
value ("�
ReplaceFestivalRewardRequest

sn (
reward (27.com.agame.protocol.ReplaceFestivalRewardRequest.RewardO
Reward
offset (
date (
type (

id (
value ("2
$QueryAccumulateExchangeRewardRequest

sn (
$QueryAccumulateExchangeRewardRespond

sn (
result (

begin_time (
end_time (O
reward (2?.com.agame.protocol.QueryAccumulateExchangeRewardRespond.RewardI
Reward
exchange_value (
type (

id (
value ("�
&ReplaceAccumulateExchangeRewardRequest

sn (

begin_time (
end_time (Q
reward (2A.com.agame.protocol.ReplaceAccumulateExchangeRewardRequest.RewardI
Reward
exchange_value (
type (

id (
value ("z
GuildPvpFightRequest

sn (

attack_pid (
attack_inspire (

defend_pid (
defend_inspire (
GuildPvpFightRespond

sn (
result (
winner (

fight_data (	
fight_record_id (
	cool_down ("z
PvpFightAndCheckRequest

sn (
playerid (
no_check (
fight_encode_data (	
cli_opt_data (	"�
PvpFightAndCheckRespond

sn (
result (
winner (
fight_record_id (
	cool_down (/
reward_list (2.com.agame.protocol.Reward
npc_hp ("P
AdminFreshLimitedShopRequest

sn (

begin_time (
end_time (
AdminGetLimitedShopTimeRequest

sn (
AdminGetLimitedShopTimeRespond

sn (

begin_time (
end_time (
Bind7725Request

sn (
pid ("4
SortMilitaryPowerRequest

sn (
pids ("]
SortMilitaryPowerRespond

sn (
result (
pids (
military_powers ("3
GetMilitaryPowerRequest

sn (
pids ("\
GetMilitaryPowerRespond

sn (
result (
pids (
military_powers ("j
 ChangeArmamentPlaceholderRequest

sn (
playerid (
placeholder (
armament_id ("M
QueryArmamentInfoRequest

sn (
playerid (
armament_id ("�
QueryArmamentInfoRespond

sn (
result (
armament_id (
placeholder (
level (
stage (
quality (":
QueryFightFormationRequest

sn (
playerid ("�

level (
attack (
defend (
max_hp (

hp (
fix_hurt (
fix_reduce_hurt (

crit_ratio (
crit_immune_ratio	 (
	crit_hurt
 (
crit_immune_hurt (
disparry_ratio (
parry_ratio

init_power (

incr_power (
attack_speed (

move_speed (

true_blood_ratio (
	skill0_id (
	skill1_id (
scale (
hero_skin_id (
hero_body_type (	
weapon_skin_id (
weapon_body_type (	

mount_body_type (	
name (	
quality (
flag_skin_id (
tenacity  (
strength! (
active" (
buffs# (
hero_id$ (
pet_skin_id% (

QueryFightFormationRespond

sn (
result (6
placeholder (2!.com.agame.protocol.CharacterInfo"9
QueryKingFightInfoRequest

sn (
playerid ("�

name (	
level (
skill_id (
	banner_id (
scale (
hero_skin_id (
hero_body_type (	
weapon_skin_id (
weapon_body_type	 (	

 (
mount_body_type (	
flag_skin_id (
quality
ensign (
pet_skin_id (

QueryKingFightInfoRespond

sn (
result (/
info (2!.com.agame.protocol.KingFightInfo":
QueryStoryFightInfoRequest

sn (
story_id (
QueryStoryFightInfoRespond

sn (
result (
pid (/
king (2!.com.agame.protocol.KingFightInfo0
heros (2!.com.agame.protocol.CharacterInfo"@
SetStoryPassRequest

sn (
pid (
story_id (
SetStoryPassRespond

sn (
result (/
reward_list (2.com.agame.protocol.Reward"D
QueryStoryStatusRequest

sn (
pid (
story_id (
QueryStoryStatusRespond

sn (
result (
status (
CrossArenaFightRequest

sn (
attacker_pid (
defender_formation (2!.com.agame.protocol.CharacterInfo8

defender_level ( 
defender_attack_addition ( 
defender_defend_addition ( 
attacker_attack_addition ("�
CrossArenaFightRespond

sn (
result (
winner (

fight_data (	
fight_record_id (
	cool_down ("M
CrossArenaServerConfig

id (
name (	
defender_addition ("�
CrossArenaSetArenaRequest

sn (
arena_id (

begin_time (
end_time (
reward_time (?
server_list (2*.com.agame.protocol.CrossArenaServerConfig"9
CrossArenaDelArenaRequest

sn (
arena_id ("�
CrossArenaConfig

id (

begin_time (
end_time (
reward_time (?
server_list (2*.com.agame.protocol.CrossArenaServerConfig")
CrossArenaQueryArenaRequest

sn (
CrossArenaQueryArenaRespond

sn (
result (8

arena_list (2$.com.agame.protocol.CrossArenaConfig"T
NotifyArmament
playerid (
gid (
placeholder (
action (
NotifyADSupportEventRequest

sn (
pid (
eventid (
value (
ADSupportAddGroupRequest

sn (
gid (
	begintime (
endtime (
period (
	sumreward (23.com.agame.protocol.ADSupportAddGroupRequest.Reward1
Reward
type (

id (
value (
ADSupportAddQuestRequest

sn (
gid (
questid (
eventid (

eventvalue (
eventreward (23.com.agame.protocol.ADSupportAddQuestRequest.Reward1
Reward
type (

id (
value (
ADSupportGetGroupidRequest

sn (
gid (
ADSupportreloadConfigRequest

sn (
ADSupportAddLoginGroupRequest

sn (
gid (
	begintime (
endtime (
viewtime (
period (
reward (28.com.agame.protocol.ADSupportAddLoginGroupRequest.Reward1
Reward
type (

id (
value (
ADSupportAddInvestGroupRequest

sn (
gid (
	begintime (
endtime (
rid (
AdminFreshPetGradeRankConfig

sn (

begin_time (
end_time (
	pool_type (
petid (
TranspondLuckyDraw

sn (
	pool_type (
pid (
result (
reward (2-.com.agame.protocol.TranspondLuckyDraw.Reward1
Reward
type (

id (
value (

type (
value ("�
	FightRole
refid (

id (
level (
	propertys (2!.com.agame.protocol.FightProperty
pos (
wave (
mode (
skills	 (
x
 (	
y (	
z (

share_mode
share_count (

	assist_cd (
equips (
uuid (
drop_id (

grow_stage (
	grow_star (
AssistSkill

id (
weight (
FightPlayer
pid (
name (	,
roles (2.com.agame.protocol.FightRole
npc (:false
level (
assists (2.com.agame.protocol.FightRole"�
	FightData

id (1
attacker (2.com.agame.protocol.FightPlayer1
defender (2.com.agame.protocol.FightPlayer
scene (	
seed (
star (2+.com.agame.protocol.FightData.StarCondition

fight_type (
win_type (
win_para	 (
duration
 (

type (

v1 (

v2 (
FightCommand
tick (:
commands (2(.com.agame.protocol.FightCommand.Command�
Command
tick (
type (2,.com.agame.protocol.FightCommand.CommandType
pid (
s_index (
refid (
sync_id (
skill (
target (
value	 ("�
CommandType
UNKNOWN	
INPUT

MONSTER_COUNT_CHANGE
MONSTER_HP_CHANGE
PLAYER_STATUS_CHANGE"�

FightInput<

operations (2(.com.agame.protocol.FightInput.Operation9
	Operation
refid (
skill (
target (
QueryPlayerFightInfoRequest

sn (
pid (
npc (:false
ref (
check_player_id (
heros (
assists (
level (
target_fight	 (
QueryPlayerFightInfoRespond

sn (
result (/
player (2.com.agame.protocol.FightPlayer"�
QueryRecommendFightInfoRequest

sn (
pid (
fight_id (
ref (
check_player_id (
heros (
assists ("t
PlayerFightPrepareRequest

sn (
pid (
fightid (
heros (
assists (
level (
PlayerFightPrepareRespond

sn (
result (1

fight_data (2.com.agame.protocol.FightData"b
PlayerFightConfirmRequest

sn (
pid (
fightid (
heros (
star (
PlayerFightConfirmRespond

sn (
result (+
rewards (2.com.agame.protocol.Reward"
DatabaseRequest
sql (	"�
DatabaseRespond
errno (
fields (	7
rows (2).com.agame.protocol.DatabaseRespond.Value
last_id (w
Value6
type (2(.com.agame.protocol.DatabaseRespond.Type
intValue (
strValue (	

floatValue (?
Row8
value (2).com.agame.protocol.DatabaseRespond.Value"*
Type
INTEGER

STRING	
FLOAT"T
PGetPlayerHeroInfoRequest

sn (
playerid (
gid (
uuid ("�
PGetPlayerHeroInfoRespond

sn (
result (@
hero (22.com.agame.protocol.PGetPlayerHeroInfoRespond.HeroA
heros (22.com.agame.protocol.PGetPlayerHeroInfoRespond.Hero�
Hero
gid (
uuid (
exp (
level (
stage (
star (

stage_slot (
weapon_stage (
weapon_star	 (
weapon_level
 (
weapon_stage_slot (

weapon_exp (
placeholder
PGetPlayerQuestInfoRequest

sn (
pid (%
include_finished_and_canceled (
types ("�
PGetPlayerQuestInfoRespond

sn (
result (D
quests (24.com.agame.protocol.PGetPlayerQuestInfoRespond.Questz
Quest
uuid (

id (
status (
type (
records (
accept_time (
submit_time ("�
PSetPlayerQuestRequest

sn (
pid (
uuid (

id (
status (
records (
rich_reward (:false
expired_time (
pool	 (
PSetPlayerQuestRespond

sn (
result (
uuid ("U
GuildQueryBuildingLevelRequest

sn (
playerid (

GuildQueryBuildingLevelRespond

sn (
result (
gid (
level (
event
type (

id (
count (
PNotifyPlayerQuestEventRequest

sn (
pid ()
events (2.com.agame.protocol.event"5
ArenaGetRankListRequest

sn (
topcnt (
Rank
pid (
level (
name (	
rank (
ArenaGetRankListRespond

sn (
result (
ranks (2.com.agame.protocol.Rank"*
MapLoginRequest

sn (
pid ("+
MapLogoutRequest

sn (
pid ("-
MapQueryPosRequest

sn (
pid ("
MapQueryPosRespond

sn (
result (
mapid (
x (	
y (	
z (
channel (
room ("x
MapMoveRequest

sn (
pid (	
x (	
y (	
z (
mapid (
channel (
room ("<
TeamQueryInfoRequest

sn (
pid (
tid ("�
TeamQueryInfoRespond

sn (
result (
teamid (
grup (
leader (
inplace_checking (
members (2/.com.agame.protocol.TeamQueryInfoRespond.member
auto_confirm (

auto_match	 (3
member
pid (
level (
ready (
TeamCreateRequest

sn (
pid (
grup (
lower_limit (
upper_limit (
TeamCreateRespond

sn (
result (
teamid (
leader_level (
TeamLeaveRequest

sn (
opt_id (
pid (".
TeamDissolveRequest

sn (
pid ("d
NotifyAITeamPlayerEnterRequest

sn (

id (
teamid (
pid (
level (
NotifyAITeamPlayerLeaveRequest

sn (

id (
teamid (
pid (
opt_pid (	
x (	
y (	
z (
mapid	 (
channel
 (
room ("D
TeamSetAutoConfirmRequest

sn (
pid (
teamid ("P
TeamInplaceCheckRequest

sn (
pid (
teamid (
type ("_
TeamInplaceReadyRequest

sn (
pid (
teamid (
ready (
type ("d
NotifyAITeamPlayerReadyRequest

sn (

id (
teamid (
pid (
ready ("B
TeamStartFightRequest

sn (
pid (
fight_id ("0
TeamFightReadyRequest

sn (
pid ("Z
NotifyAITeamFightFinishRequest

sn (

id (
winner (
fight_id (
TeamSyncRequest

sn (
pid (
cmd (
data ("W
NotifyAIRollGameCreate

sn (

id (
game_id (
reward_count (
NotifyAIRollGameFinish

sn (

id (
game_id ("\
TeamRollRewardRequest

sn (
pid (
game_id (
idx (
want ("U
TeamGetTeamProgressRequest

sn (
pid (
teamid (
fights (
TeamGetTeamProgressRespond

sn (
result (D
progress (22.com.agame.protocol.TeamGetTeamProgressRespond.pro)
pro
fight_id (
progress (
TeamChangeLeaderRequest

sn (
pid (

new_leader ("8
PQueryUnactiveAIRequest

sn (
	ref_level (
PQueryUnactiveAIRespond

sn (
result (
pid (
level (
PUpdateAIActiveTimeRequest

sn (
pid (
time (
TeamFindNpcRequest

sn (
pid (
fight_id ("E
AITeamAutomatchRequest

sn (
pid (

auto_match ("K
AIAutomatchRequest

sn (
pid (
grup (
teamid ("G
GetAutomatchTeamCountRequest

sn (
grup (
level (
GetAutomatchTeamCountRespond

sn (
result (
count (
QueryAutoMatchTeamRequest

sn (
QueryAutoMatchTeamRespond

sn (
result (
	team_list (26.com.agame.protocol.QueryAutoMatchTeamRespond.teamInfo(
teamInfo
grup (
teamid ("0
NotifyAITeamFightStart

sn (

id ("2
NotifyAITeamInplaceCheck

sn (

id ("�
NotifyAITeamLeaderChange

sn (

id (
leader (	
x (	
y (	
z (
mapid (
channel (
room	 ("?
NotifyAITeamGroupChange

sn (

id (
grup ("I
NotifyAITeamAutoMatchChange

sn (

id (

auto_match (".
PresentEnergyNotify

sn (
pid (".
AddFriendNotify

sn (
friends ("3
QueryResentRecordRequest

sn (
pid ("F
QueryResentRecordRespond

sn (
donors (
result ("1
QueryGuildByPidRequest

sn (
pid ("x
QueryGuildByPidRespond

sn (
result (
gid (
leader (

help_count (
	join_time ("+
ApplyGuildNotify

sn (
pid ("8
NotifyGuildApply

sn (
pid (
gid (
NotifyGuildDispear

sn (
pid (
gid (
DonateExpNotify

sn (
pid (

donateType (
SeekPrayHelpNotify

sn (
pid (")
HelpPrayNotify

sn (
pid ("B
BountyStartRequest

sn (
pid (
activity_id (
BountyStartRespond

sn (
result (
quest (
record (
next_fight_time (
BountyFightRequest

sn (
pid (
activity_id (
BountyFightRespond

sn (
result (
next_fight_time (
BountyQueryRequest

sn (
pid ("�
BountyQueryRespond

sn (
result (

quest_info (2,.com.agame.protocol.BountyQueryRespond.questT
quest
quest (
record (
next_fight_time (
activity_id (
NotifyAIBountyChange

sn (
result (

id (
quest (
record (
next_fight_time (
activity_id (
finish (
winner	 ("�
PVPFightPrepareRequest

sn (
attacker (
defender (
auto (:false
scene (	:18hao6


PVPFightPrepareRespond

sn (
result (

id (
winner (
seed (
roles (2/.com.agame.protocol.PVPFightPrepareRespond.Role!
Role
refid (

hp (
PVPFightCheckRequest

sn (

id ("B
PVPFightCheckRespond

sn (
result (
winner ("O
PChangeAINickNameRequest

sn (
pid (
name (	
head (
	GMRequest

sn (
command (	
json (	"5
	GMRespond

sn (
result (
json (	" 
ArenaAIEnterNotify

id (
AdminAddMultiMailRequest

sn (
from (
pids (
type (
title (	
content (	G
appendix (25.com.agame.protocol.AdminAddMultiMailRequest.Appendix3
Appendix
type (

id (
value ("K
PChangeBuffRequest

sn (
pid (
add (
buff_id (
GuildExploreNotify

sn (
pid ("-
DoLeaderWorkNotify

sn (
pid ("@
ArenaAddWealthRequest

sn (
pid (
wealth ("s
PVEFightPrepareRequest

sn (
attacker (
target (
npc (
heros (
assists ("X
PVEFightPrepareRespond

sn (
result (
fightID (
	fightData (	"a
PVEFightCheckRequest

sn (
pid (
fightid (
	starValue (
code (	"o
PVEFightCheckRespond

sn (
result (
winner (
rewards (2.com.agame.protocol.Reward"A
NotifyActiveAI

sn (
level (
first_target (
GetPlayerAIRatioRequest

sn (
result (
targets (
GetPlayerAIRatioRespond

sn (
result (
targets_priority (26.com.agame.protocol.GetPlayerAIRatioRespond.t_priority.

t_priority
target (
priority ("J
NotifyAIPlayerApplyToBeLeader

sn (

id (
	candidate ("L
TeamVoteRequest

sn (
pid (
	candidate (
agree (
NotifyAINewJoinRequest

sn (

id (
pid (
level (
TeamJoinConfirmRequest

sn (
opt_id (
pid ("D
QueryPlayerPropertyRequest

sn (
pid (
types (
QueryPlayerPropertyRespond

sn (
result (
data (
ModifyPlayerPropertyRequest

sn (
pid (
typa (
tab (
AddActivityRewardNotify

sn (
pid (
quest_id (
rewards (22.com.agame.protocol.AddActivityRewardNotify.Reward1
Reward
type (

id (
value ("(


sn (
pid (")
AILogoutNotify

sn (
pid ("�
PSaveHeroCapacityRequest

sn (
playerid (I
heros (2:.com.agame.protocol.PSaveHeroCapacityRequest.hero_capacity4

	hero_uuid (
capacity (
AddFavorNotify
pid1 (
pid2 (
source (
ShopBuyParam
consume_uuid (9
guild (2*.com.agame.protocol.ShopBuyParam.GuildInfo

	hero_uuid ((
	GuildInfo
type (
level (
ServerInfoRequest

sn (
ServerInfoRespond

sn (
result (
	max_level (
TeamFightStartRequest

sn (
pids (
fight_id (
fight_level (
TeamFightStartRespond

sn (
result (
winner ("H
QueryTeamBattleTimeRequest

sn (
pid (
	battle_id (
QueryTeamBattleTimeRespond

sn (
battle_begin_time (
battle_end_time (
TeamEnterBattleRequest

sn (
pid (
	battle_id (
NotifyAIBattleTimeChange

sn (

id (
battle_begin_time (
battle_end_time (
TradeWithSystemRequest

sn (
pid (
	equip_gid (

equip_uuid (
sell (
consume (22.com.agame.protocol.TradeWithSystemRequest.Consume6
Consume
type (

id (
value (
TradeWithSystemRespond

sn (
result (
level (
quality (
uuid (
int32
RET_SUCCESS 
	RET_ERROR
	RET_EXIST

RET_PARAM_ERROR
RET_INPROGRESS


RET_DEPEND

RET_FULL	
RET_NOT_ENOUGH

RET_PREMISSIONS
RET_COOLDOWN

RET_DATABASEERROR*�

NotifyType
NOTIFY_PROPERTY
NOTIFY_RESOURCE
NOTIFY_BUILDING
NOTIFY_TECHNOLOGY
NOTIFY_CITY
NOTIFY_HERO_LIST
NOTIFY_HERO
NOTIFY_ITEM_COUNT
NOTIFY_COOLDOWN	
NOTIFY_EQUIP_LIST

NOTIFY_EQUIP
NOTIFY_FARM
NOTIFY_STRATEGY
NOTIFY_STORY
NOTIFY_COMPOSE
NOTIFY_DAILY
NOTIFY_QUEST
NOTIFY_ARENA_ATTACK
NOTIFY_GUILD_INOUT
NOTIFY_GUILD_SETPOS
NOTIFY_GUILD_STATE*/
ServiceType
GATEWAY	
WORLD
CHAT*Q
BossCreateType
BOSS_TYPE_WORLD
BOSS_TYPE_COUNTRY
BOSS_TYPE_GUILD