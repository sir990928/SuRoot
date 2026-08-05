API ?= 35
TARGET ?= pa3q-S9380ZHU1AYA1

ifndef CLANG
    CLANG := $(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android$(API)-clang
endif

ROOT := .
SRC_ORIGINAL := $(ROOT)/src
TARGET_DIR := $(ROOT)/target/$(TARGET)
INCLUDE_DIR := $(ROOT)/include
TARGET_INCLUDE := $(INCLUDE_DIR)/targets/$(TARGET)/target.h
BUILD_DIR := $(ROOT)/build/v6
OBJ_DIR := $(BUILD_DIR)/obj
OUT_DIR := $(BUILD_DIR)/artifact

TARGET_FLAGS := --target=aarch64-linux-android$(API)
COMMON_CFLAGS := $(TARGET_FLAGS) -O2 -g0 -Wall -Wextra -Wno-unused-parameter
CPPFLAGS := -I$(SRC_ORIGINAL) -I$(INCLUDE_DIR) -I$(TARGET_DIR) -DTARGET_CONFIG_H=\"target.h\"

OBJECTS := \
	$(OBJ_DIR)/main.o \
	$(OBJ_DIR)/util.o \
	$(OBJ_DIR)/slide.o \
	$(OBJ_DIR)/fops.o \
	$(OBJ_DIR)/pipe.o \
	$(OBJ_DIR)/preload.o \
	$(OBJ_DIR)/root.o

PAYLOAD := $(OUT_DIR)/preload.so

.PHONY: all debug clean

all: $(PAYLOAD)

debug:
	@echo "API = $(API)"
	@echo "TARGET = $(TARGET)"
	@echo "ANDROID_NDK_HOME = $(ANDROID_NDK_HOME)"
	@echo "CLANG = $(CLANG)"

$(TARGET_INCLUDE): $(TARGET_DIR)/target.h
	mkdir -p $(@D)
	cp $< $@

$(OBJ_DIR) $(OUT_DIR):
	mkdir -p $@

$(OBJ_DIR)/%.o: $(SRC_ORIGINAL)/%.c $(TARGET_INCLUDE) | $(OBJ_DIR)
	$(CLANG) $(COMMON_CFLAGS) -fPIC $(CPPFLAGS) -c $< -o $@

$(PAYLOAD): $(OBJECTS) | $(OUT_DIR)
	$(CLANG) $(TARGET_FLAGS) -shared -fuse-ld=lld \
		-Wl,--no-undefined -Wl,-z,relro -Wl,-z,now \
		$(OBJECTS) -pthread -ldl -o $@

clean:
	rm -rf $(BUILD_DIR)