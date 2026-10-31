#include "bn_core.h"

#include "game.h"

int main()
{
    bn::core::init();
    digimon_rpg::game game;

    while(true)
    {
        game.update();
        bn::core::update();
    }
}

