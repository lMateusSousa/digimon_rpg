#ifndef DIGIMON_RPG_GAME_STATE_H
#define DIGIMON_RPG_GAME_STATE_H

#include <cstdint>

namespace digimon_rpg
{
    enum class scene_id : uint8_t
    {
        title,
        partner_select,
        overworld,
        battle,
    };

    enum class partner_id : uint8_t
    {
        red_hero,
        blue_hero,
    };

    struct creature_state
    {
        int species_id = 0;
        int level = 1;
        int current_hp = 10;
        int maximum_hp = 10;
    };

    struct player_state
    {
        int map_id = 0;
        int x = 0;
        int y = 0;
        partner_id selected_partner = partner_id::red_hero;
        creature_state partner;
    };

    struct game_state
    {
        scene_id scene = scene_id::title;
        player_state player;
    };
}

#endif

