# Digimon RPG para Game Boy Advance

Projeto homebrew original inspirado em RPGs de criaturas do Game Boy Advance. O objetivo é gerar uma ROM `.gba` executável em emuladores e hardware compatível, sem depender de uma ROM comercial.

## Estado atual

O esqueleto contém três cenas conectadas:

- Tela de título.
- Área de exploração com movimentação pelo direcional.
- Cena provisória de batalha.

História, regras, criaturas e sistemas definitivos serão descritos em [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

## Compilar a ROM

Requisitos: Git, Docker Desktop e Node.js/npm.

```powershell
git submodule update --init --recursive
npm run build:gba
```

A saída esperada é `digimon_rpg.gba`.

## Ferramenta de pesquisa

```powershell
npm run analyze:rom -- "C:\path\to\game.gba"
```

Relatórios gerados são gravados em `analysis/generated/` e ignorados pelo Git.

