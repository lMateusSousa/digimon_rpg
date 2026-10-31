#include "game.h"

#include "bn_bg_palettes.h"
#include "bn_color.h"
#include "bn_keypad.h"

#include "common_variable_8x16_sprite_font.h"
#include "bn_sprite_items_heroi_azul_battle.h"
#include "bn_sprite_items_heroi_azul_icon.h"
#include "bn_sprite_items_heroi_azul_overworld.h"
#include "bn_sprite_items_heroi_vermelho_battle.h"
#include "bn_sprite_items_heroi_vermelho_icon.h"
#include "bn_sprite_items_heroi_vermelho_overworld.h"

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

            case scene_id::partner_select:
                update_partner_select_scene();
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
        _selection_cursor_index = -1;
        _state.scene = next_scene;

        switch(next_scene)
        {
            case scene_id::title:
                build_title_scene();
                break;

            case scene_id::partner_select:
                build_partner_select_scene();
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

    void game::build_partner_select_scene()
    {
        bn::bg_palettes::set_transparent_color(bn::color(3, 7, 15));
        _text_generator.generate(0, -58, "ESCOLHA SEU PARCEIRO", _scene_sprites);
        _scene_sprites.push_back(bn::sprite_items::heroi_vermelho_icon.create_sprite(-48, -4));
        _scene_sprites.push_back(bn::sprite_items::heroi_azul_icon.create_sprite(48, -4));
        _text_generator.generate(-48, 24, "VERMELHO", _scene_sprites);
        _text_generator.generate(48, 24, "AZUL", _scene_sprites);
        _text_generator.generate(0, 57, "D-PAD + A: CONFIRMAR", _scene_sprites);
        _text_generator.generate(-48, 42, "^", _scene_sprites);
        _selection_cursor_index = _scene_sprites.size() - 1;
    }

    void game::build_overworld_scene()
    {
        bn::bg_palettes::set_transparent_color(bn::color(5, 16, 8));
        _text_generator.generate(0, -64, "AREA DE TESTE", _scene_sprites);
        _text_generator.generate(0, 56, "D-PAD: MOVER  A: BATALHA", _scene_sprites);
        if(_state.player.selected_partner == partner_id::red_hero)
        {
            _scene_sprites.push_back(
                bn::sprite_items::heroi_vermelho_overworld.create_sprite(_player_x, _player_y, 0));
        }
        else
        {
            _scene_sprites.push_back(
                bn::sprite_items::heroi_azul_overworld.create_sprite(_player_x, _player_y, 0));
        }
        _player_sprite_index = _scene_sprites.size() - 1;
    }

    void game::build_battle_scene()
    {
        bn::bg_palettes::set_transparent_color(bn::color(15, 7, 4));
        _text_generator.generate(0, -62, "BATALHA", _scene_sprites);
        if(_state.player.selected_partner == partner_id::red_hero)
        {
            _scene_sprites.push_back(bn::sprite_items::heroi_vermelho_battle.create_sprite(-52, -5, 0));
            bn::sprite_ptr opponent = bn::sprite_items::heroi_azul_battle.create_sprite(52, -5, 0);
            opponent.set_horizontal_flip(true);
            _scene_sprites.push_back(opponent);
        }
        else
        {
            _scene_sprites.push_back(bn::sprite_items::heroi_azul_battle.create_sprite(-52, -5, 0));
            bn::sprite_ptr opponent = bn::sprite_items::heroi_vermelho_battle.create_sprite(52, -5, 0);
            opponent.set_horizontal_flip(true);
            _scene_sprites.push_back(opponent);
        }
        _text_generator.generate(0, 38, "SISTEMA A DEFINIR", _scene_sprites);
        _text_generator.generate(0, 56, "B: VOLTAR", _scene_sprites);
    }

    void game::update_title_scene()
    {
        if(bn::keypad::start_pressed() || bn::keypad::a_pressed())
        {
            change_scene(scene_id::partner_select);
        }
    }

    void game::update_partner_select_scene()
    {
        if(bn::keypad::left_pressed())
        {
            _state.player.selected_partner = partner_id::red_hero;
        }
        else if(bn::keypad::right_pressed())
        {
            _state.player.selected_partner = partner_id::blue_hero;
        }

        if(_selection_cursor_index >= 0)
        {
            int cursor_x = _state.player.selected_partner == partner_id::red_hero ? -48 : 48;
            _scene_sprites[_selection_cursor_index].set_x(cursor_x);
        }

        if(bn::keypad::a_pressed())
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

        bool moving = false;
        if(bn::keypad::left_held() && _player_x > -horizontal_limit)
        {
            _player_x -= movement_speed;
            _direction_base = 6;
            moving = true;
        }
        else if(bn::keypad::right_held() && _player_x < horizontal_limit)
        {
            _player_x += movement_speed;
            _direction_base = 3;
            moving = true;
        }

        if(bn::keypad::up_held() && _player_y > vertical_top)
        {
            _player_y -= movement_speed;
            _direction_base = 9;
            moving = true;
        }
        else if(bn::keypad::down_held() && _player_y < vertical_bottom)
        {
            _player_y += movement_speed;
            _direction_base = 0;
            moving = true;
        }

        update_player_marker();
        update_player_graphics(moving);

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

    void game::update_player_graphics(bool moving)
    {
        if(_player_sprite_index < 0)
        {
            return;
        }

        if(moving)
        {
            ++_animation_counter;
            if(_animation_counter >= 8)
            {
                _animation_counter = 0;
                _animation_phase = (_animation_phase + 1) % 4;
            }
        }
        else
        {
            _animation_counter = 0;
            _animation_phase = 0;
        }

        constexpr int frame_sequence[] = { 0, 1, 2, 1 };
        int graphics_index = _direction_base + frame_sequence[_animation_phase];
        if(_state.player.selected_partner == partner_id::red_hero)
        {
            _scene_sprites[_player_sprite_index].set_item(
                bn::sprite_items::heroi_vermelho_overworld, graphics_index);
        }
        else
        {
            _scene_sprites[_player_sprite_index].set_item(
                bn::sprite_items::heroi_azul_overworld, graphics_index);
        }
    }
}

