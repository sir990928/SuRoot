API ?= 35
TARGET ?= pa3q-S9380ZHU1AYA1

# 设置CLANG编译器，优先使用环境变量，否则使用TARGET_CC
ifndef CLANG
    CLANG := $(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android$(API)-clang
endif

ROOT := .
SRC_ADB := $(ROOT)/src/adb
SRC_APP := $(ROOT)/src/app
ADB_TARGET_DIR := $(ROOT)/target/adb/$(TARGET)
APP_TARGET_DIR := $(ROOT)/target/app/$(TARGET)
INCLUDE_DIR := $(ROOT)/include
ADB_TARGET_INCLUDE := $(INCLUDE_DIR)/targets/$(TARGET)/target.h
APP_TARGET_INCLUDE := $(INCLUDE_DIR)/targets/app/$(TARGET)/target.h
BUILD_DIR := $(ROOT)/build/v6
OUT_DIR := $(BUILD_DIR)/artifact

TARGET_FLAGS := --target=aarch64-linux-android$(API)
COMMON_CFLAGS := $(TARGET_FLAGS) -O2 -g0 -Wall -Wextra -Wno-unused-parameter
ADB_CPPFLAGS := -I$(SRC_ADB) -I$(INCLUDE_DIR) -I$(ADB_TARGET_DIR) \
	-DTARGET_CONFIG_H=\"target.h\" -DAPP_PAYLOAD=0
APP_CPPFLAGS := -I$(SRC_APP) -I$(INCLUDE_DIR) -I$(APP_TARGET_DIR) \
	-DTARGET_CONFIG_H=\"target.h\" -DAPP_PAYLOAD=1
ADB_SOURCES := \
	$(SRC_ADB)/main.c \
	$(SRC_ADB)/util.c \
	$(SRC_ADB)/fops.c \
	$(SRC_ADB)/pipe.c \
	$(SRC_ADB)/preload_minimal.c \
	$(SRC_ADB)/root_compat_globals.c \
	$(SRC_ADB)/root.c \
	$(SRC_ADB)/slide.c

APP_SOURCES := \
	$(SRC_APP)/main.c \
	$(SRC_APP)/util.c \
	$(SRC_APP)/fops.c \
	$(SRC_APP)/pipe.c \
	$(SRC_APP)/preload_minimal.c \
	$(SRC_APP)/root_compat_globals.c \
	$(SRC_APP)/root.c \
	$(SRC_APP)/slide_app.c

ADB_HEADERS := \
	$(SRC_ADB)/common.h \
	$(SRC_ADB)/offset.h \
	$(wildcard $(SRC_ADB)/kernelsnitch/*.h)

APP_HEADERS := \
	$(SRC_APP)/common.h \
	$(SRC_APP)/offset.h \
	$(APP_TARGET_DIR)/p0_fingerprint.h \
	$(wildcard $(SRC_APP)/kernelsnitch/*.h)

ADB_PAYLOAD := $(OUT_DIR)/cve-2026-43499
APP_PAYLOAD := $(OUT_DIR)/cve-2026-43499-app.so
ROOT_HELPER := $(OUT_DIR)/cve-2026-43499-root

.PHONY: all clean hashes debug
.DEFAULT_GOAL := all

all: $(ADB_PAYLOAD) $(APP_PAYLOAD) $(ROOT_HELPER)

# 调试目标，显示变量值
debug:
	@echo "API = $(API)"
	@echo "TARGET = $(TARGET)"
	@echo "ANDROID_NDK_HOME = $(ANDROID_NDK_HOME)"
	@echo "CLANG = $(CLANG)"
	@echo "TARGET_FLAGS = $(TARGET_FLAGS)"
	@echo "ADB_PAYLOAD = $(ADB_PAYLOAD)"
	@echo "APP_PAYLOAD = $(APP_PAYLOAD)"
	@echo "ROOT_HELPER = $(ROOT_HELPER)"

$(ADB_TARGET_INCLUDE): $(ADB_TARGET_DIR)/target.h
	mkdir -p $(@D)
	cp $< $@

$(APP_TARGET_INCLUDE): $(APP_TARGET_DIR)/target.h
	mkdir -p $(@D)
	cp $< $@

$(OUT_DIR):
	mkdir -p $@


$(ADB_PAYLOAD): $(ADB_SOURCES) $(ADB_HEADERS) $(ADB_TARGET_INCLUDE) | $(OUT_DIR)
	$(CLANG) $(COMMON_CFLAGS) -fPIC $(ADB_CPPFLAGS) $(ADB_SOURCES) \
		-shared -fuse-ld=lld \
		-Wl,--no-undefined -Wl,-z,relro -Wl,-z,now \
		-pthread -ldl -o $@

$(APP_PAYLOAD): $(APP_SOURCES) $(APP_HEADERS) $(APP_TARGET_INCLUDE) | $(OUT_DIR)
	$(CLANG) $(COMMON_CFLAGS) -fPIC $(APP_CPPFLAGS) $(APP_SOURCES) \
		-shared -fuse-ld=lld \
		-Wl,--no-undefined -Wl,-z,relro -Wl,-z,now \
		-pthread -ldl -o $@

$(ROOT_HELPER): $(ROOT)/helper/su_daemon.c | $(OUT_DIR)
	$(CLANG) $(TARGET_FLAGS) -fPIE -pie -O2 -g0 -Wall -Wextra \
		$< -ldl -o $@

hashes: all
	sha256sum $(ADB_PAYLOAD) $(APP_PAYLOAD) $(ROOT_HELPER) \
		$(ADB_TARGET_DIR)/target.h $(APP_TARGET_DIR)/target.h

clean:
	rm -rf $(BUILD_DIR)
