TOP_DIR        := /mnt/c/Users/andy/source/repos/asheimo/ffmpeg-windows-build-helpers/build/freetype-2.13.3
OBJ_DIR        := /mnt/c/Users/andy/source/repos/asheimo/ffmpeg-windows-build-helpers
OBJ_BUILD      := $(OBJ_DIR)
DOC_DIR        := $(OBJ_DIR)/docs
FT_LIBTOOL_DIR := $(OBJ_DIR)
ifndef FT2DEMOS
  include $(TOP_DIR)/Makefile
else
  TOP_DIR_2 := $(TOP_DIR)/../ft2demos
  PROJECT   := freetype
  CONFIG_MK := $(OBJ_DIR)/config.mk
  include $(TOP_DIR_2)/Makefile
endif
