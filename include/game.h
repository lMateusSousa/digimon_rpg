#ifndef DIGIMON_RPG_GAME_H
#define DIGIMON_RPG_GAME_H

#include "bn_sprite_ptr.h"
#include "bn_sprite_text_generator.h"
#include "bn_vector.h"

#include "game_state.h"

namespace digimon_rpg
{
    class game
    {
    public:
        game();

        void update();

    private:
        static constexpr int max_scene_sprites = 64;

        game_state _state;
        bn::sprite_text_generator _text_generator;
        bn::vector<bn::sprite_ptr, max_scene_sprites> _scene_sprites;
        int _player_sprite_index = -1;
        int _player_x = 0;
        int _player_y = 16;

        void change_scene(scene_id next_scene);
        void build_title_scene();
        void build_overworld_scene();
        void build_battle_scene();
        void update_title_scene();
        void update_overworld_scene();
        void update_battle_scene();
        void update_player_marker();
    };
}

#endif

