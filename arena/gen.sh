mysql -uagame -pagame@123 -h10.1.2.79 aGameMobileConfig_sgk -B -e 'select gid,score,name from config_random_arena_ai' | sed 's/\t/,/g' > arena_enemy_config.csv

awk -f gen_arena_enemy_config.awk arena_enemy_config.csv
