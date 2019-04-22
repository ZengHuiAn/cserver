# mysql -uroot -p123456 -h172.16.3.97 aGameMobileConfig_sgk -B -e 'select gid,score,name from config_random_arena_ai' | sed 's/\t/,/g' > arena_enemy_config.csv

# awk -f gen_arena_enemy_config.awk arena_enemy_config.csv
