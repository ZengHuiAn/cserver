BEGIN{
    FS=",";
    printf("enemyConfig = {\n") > "ArenaEnemyConfig.lua";
}
{
    if (NR > 1){
        printf("{pid = %d, power = %d, name = \"%s\"}, \n", $1,$2,$3) > "ArenaEnemyConfig.lua";
    }
}
END{
    printf("}") > "ArenaEnemyConfig.lua";
}

