#include "game.h"

#include "bn_bg_palettes.h"
#include "bn_color.h"
#include "bn_keypad.h"

#include "common_variable_8x16_sprite_font.h"

namespace digimon_rpg
{
    game::game() :
        _text_generator(common::variable_8x16_sprite_font)
    {
        _text_generator.set_center_alignment();
        change_scene(scene_id::title);
    }

    void game::update()
    {
        switch(_state.scene)
        {
            case scene_id::title:
                update_title_scene();
                break;

            case scene_id::overworld:
                update_overworld_scene();
                break;

            case scene_id::battle:
                update_battle_scene();
                break;
        }
    }

    void game::change_scene(scene_id next_scene)
    {
        _scene_sprites.clear();
        _player_sprite_index = -1;
        _state.scene = next_scene;

        switch(next_scene)
        {
            case scene_id::title:
                build_title_scene();
                break;

            case scene_id::overworld:
                build_overworld_scene();
                break;

            case scene_id::battle:
                build_battle_scene();
                break;
        }
    }

    void game::build_title_scene()
    {
        bn::bg_palettes::set_transparent_color(bn::color(3, 7, 15));
        _text_generator.generate(0, -28, "DIGIMON RPG", _scene_sprites);
        _text_generator.generate(0, -4, "PROTOTIPO GBA", _scene_sprites);
        _text_generator.generate(0, 40, "START: INICIAR", _scene_sprites);
    }

    void game::build_overworld_scene()
    {
        bn::bg_palettes::set_transparent_color(bn::color(5, 16, 8));
        _text_generator.generate(0, -64, "AREA DE TESTE", _scene_sprites);
        _text_generator.generate(0, 56, "D-PAD: MOVER  A: BATALHA", _scene_sprites);
        _text_generator.generate(_player_x, _player_y, "@", _scene_sprites);
        _player_sprite_index = _scene_sprites.size() - 1;
    }

    void game::build_battle_scene()
    {
        bn::bg_palettes::set_transparent_color(bn::color(15, 7, 4));
        _text_generator.generate(0, -52, "BATALHA", _scene_sprites);
        _text_generator.generate(-52, -8, "PARCEIRO", _scene_sprites);
        _text_generator.generate(52, -8, "INIMIGO", _scene_sprites);
        _text_generator.generate(0, 30, "SISTEMA A DEFINIR", _scene_sprites);
        _text_generator.generate(0, 56, "B: VOLTAR", _scene_sprites);
    }

    void game::update_title_scene()
    {
        if(bn::keypad::start_pressed() || bn::keypad::a_pressed())
        {
            change_scene(scene_id::overworld);
        }
    }

    void game::update_overworld_scene()
    {
        constexpr int movement_speed = 1;
        constexpr int horizontal_limit = 108;
        constexpr int vertical_top = -42;
        constexpr int vertical_bottom = 40;

        if(bn::keypad::left_held() && _player_x > -horizontal_limit)
        {
            _player_x -= movement_speed;
        }
        else if(bn::keypad::right_held() && _player_x < horizontal_limit)
        {
            _player_x += movement_speed;
        }

        if(bn::keypad::up_held() && _player_y > vertical_top)
        {
            _player_y -= movement_speed;
        }
        else if(bn::keypad::down_held() && _player_y < vertical_bottom)
        {
            _player_y += movement_speed;
        }

        update_player_marker();

        if(bn::keypad::a_pressed())
        {
            _state.player.x = _player_x;
            _state.player.y = _player_y;
            change_scene(scene_id::battle);
        }
    }

    void game::update_battle_scene()
    {
        if(bn::keypad::b_pressed())
        {
            change_scene(scene_id::overworld);
        }
    }

    void game::update_player_marker()
    {
        if(_player_sprite_index >= 0)
        {
            _scene_sprites[_player_sprite_index].set_position(_player_x, _player_y);
        }
    }
}

