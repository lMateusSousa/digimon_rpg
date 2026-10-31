# Digimon RPG - Game Boy Advance homebrew project

TARGET          := digimon_rpg
BUILD           := build
LIBBUTANO       := vendor/butano/butano
PYTHON          := python3
SOURCES         := src
INCLUDES        := include vendor/butano/common/include
DATA            :=
GRAPHICS        := graphics vendor/butano/common/graphics
AUDIO           := audio
AUDIOBACKEND    := null
AUDIOTOOL       :=
DMGAUDIO        := dmg_audio
DMGAUDIOBACKEND := null
ROMTITLE        := DIGIMON RPG
ROMCODE         := DMRP
USERFLAGS       :=
USERCXXFLAGS    :=
USERASFLAGS     :=
USERLDFLAGS     :=
USERLIBDIRS     :=
USERLIBS        :=
DEFAULTLIBS     :=
STACKTRACE      :=
USERBUILD       :=
EXTTOOL         :=

ifndef LIBBUTANOABS
    export LIBBUTANOABS := $(realpath $(LIBBUTANO))
endif

include $(LIBBUTANOABS)/butano.mak

