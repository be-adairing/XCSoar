# This Makefile fragment builds the Android package (XCSoar.apk).
# We're not using NDK's Makefiles because our Makefile is so big and
# complex, we don't want to duplicate that for another platform.

ifeq ($(TARGET),ANDROID)

# When enabled, the package org.xcsoar.testing is created, with a red
# Activity icon, to allow simultaneous installation of "stable" and
# "testing".
# In the stable branch, this should default to "n".
TESTING = y

ANT = ant
JAVAH = javah
JARSIGNER = jarsigner
ANDROID_KEYSTORE = $(HOME)/.android/mk.keystore
ANDROID_KEY_ALIAS = mk
ANDROID_BUILD = $(TARGET_OUTPUT_DIR)/build
ANDROID_BIN = $(TARGET_BIN_DIR)
ANDROID_JNI = $(TARGET_OUTPUT_DIR)/jni

ifeq ($(HOST_IS_DARWIN),y)
  ANDROID_SDK ?= $(HOME)/opt/android-sdk-macosx
else
  ANDROID_SDK ?= $(HOME)/opt/android-sdk-linux_x86
endif
ANDROID_SDK_PLATFORM_DIR = $(ANDROID_SDK)/platforms/$(ANDROID_PLATFORM)
ANDROID_ABI = $(ANDROID_ABI3)
ANDROID_ABI_DIR = $(ANDROID_BUILD)/libs/$(ANDROID_ABI)
ANDROID_ALL_ABIS = armeabi armeabi-v7a
ANDROID_LIB_DIR = /opt/android/libs/$(ANDROID_ABI)

ANDROID_LIB_NAMES = xcsoar
ANDROID_LIB_BUILD = $(patsubst %,$(ANDROID_ABI_DIR)/lib%.so,$(ANDROID_LIB_NAMES))

ifneq ($(V),2)
ANT += -quiet
else
JARSIGNER += -verbose
endif

JAVA_PACKAGE = org.xcsoar
CLASS_NAME = $(JAVA_PACKAGE).NativeView
CLASS_SOURCE = $(subst .,/,$(CLASS_NAME)).java
CLASS_CLASS = $(patsubst %.java,%.class,$(CLASS_SOURCE))

NATIVE_CLASSES = NativeView EventBridge Timer InternalGPS NonGPSSensors Settings NativeInputListener
NATIVE_SOURCES = $(patsubst %,android/src/%.java,$(NATIVE_CLASSES))
NATIVE_PREFIX = $(TARGET_OUTPUT_DIR)/include/$(subst .,_,$(JAVA_PACKAGE))_
NATIVE_HEADERS = $(patsubst %,$(NATIVE_PREFIX)%.h,$(NATIVE_CLASSES))

JAVA_SOURCES = $(wildcard android/src/*.java)
JAVA_CLASSES = $(patsubst android/src/%.java,bin/classes/org/xcsoar/%.class,$(JAVA_SOURCES))

DRAWABLE_DIR = $(ANDROID_BUILD)/res/drawable
RAW_DIR = $(ANDROID_BUILD)/res/raw

ifeq ($(TESTING),y)
$(ANDROID_BUILD)/res/drawable/icon.png: $(DATA)/graphics/xcsoarswiftsplash_red_160.png | $(ANDROID_BUILD)/res/drawable/dirstamp
	$(Q)$(IM_PREFIX)convert -scale 48x48 $< $@
else
$(ANDROID_BUILD)/res/drawable/icon.png: $(DATA)/graphics/xcsoarswiftsplash_160.png | $(ANDROID_BUILD)/res/drawable/dirstamp
	$(Q)$(IM_PREFIX)convert -scale 48x48 $< $@
endif

OGGENC = oggenc --quiet --quality 1

SOUNDS = fail insert remove beep_bweep beep_clear beep_drip
SOUND_FILES = $(patsubst %,$(RAW_DIR)/%.ogg,$(SOUNDS))

$(SOUND_FILES): $(RAW_DIR)/%.ogg: Data/sound/%.wav | $(RAW_DIR)/dirstamp
	@$(NQ)echo "  OGGENC  $@"
	$(Q)$(OGGENC) -o $@ $<

PNG1 := $(patsubst Data/bitmaps/%.bmp,$(DRAWABLE_DIR)/%.png,$(wildcard Data/bitmaps/*.bmp))
$(PNG1): $(DRAWABLE_DIR)/%.png: Data/bitmaps/%.bmp | $(DRAWABLE_DIR)/dirstamp
	$(Q)$(IM_PREFIX)convert $< $@

PNG2 := $(patsubst $(DATA)/graphics/%.bmp,$(DRAWABLE_DIR)/%.png,$(BMP_LAUNCH_FLY_224) $(BMP_LAUNCH_SIM_224))
$(PNG2): $(DRAWABLE_DIR)/%.png: $(DATA)/graphics/%.bmp | $(DRAWABLE_DIR)/dirstamp
	$(Q)$(IM_PREFIX)convert $< $@

PNG3 := $(patsubst $(DATA)/graphics/%.bmp,$(DRAWABLE_DIR)/%.png,$(BMP_SPLASH_80) $(BMP_SPLASH_160) $(BMP_TITLE_110) $(BMP_TITLE_320))
$(PNG3): $(DRAWABLE_DIR)/%.png: $(DATA)/graphics/%.bmp | $(DRAWABLE_DIR)/dirstamp
	$(Q)$(IM_PREFIX)convert $< $@

PNG4 := $(patsubst $(DATA)/icons/%.bmp,$(DRAWABLE_DIR)/%.png,$(BMP_ICONS) $(BMP_ICONS_160))
$(PNG4): $(DRAWABLE_DIR)/%.png: $(DATA)/icons/%.bmp | $(DRAWABLE_DIR)/dirstamp
	$(Q)$(IM_PREFIX)convert $< $@

PNG5 := $(patsubst $(DATA)/graphics/%.bmp,$(DRAWABLE_DIR)/%.png,$(BMP_DIALOG_TITLE) $(BMP_PROGRESS_BORDER))
$(PNG5): $(DRAWABLE_DIR)/%.png: $(DATA)/graphics/%.bmp | $(DRAWABLE_DIR)/dirstamp
	$(Q)$(IM_PREFIX)convert $< $@

PNG_FILES = $(DRAWABLE_DIR)/icon.png $(PNG1) $(PNG2) $(PNG3) $(PNG4) $(PNG5)

ifeq ($(TESTING),y)
MANIFEST = android/testing/AndroidManifest.xml
else
MANIFEST = android/AndroidManifest.xml
endif

# symlink some important files to $(ANDROID_BUILD) and let the Android
# SDK generate build.xml
$(ANDROID_BUILD)/build.xml: $(MANIFEST) $(PNG_FILES) build/r.sed | $(TARGET_BIN_DIR)/dirstamp
	@$(NQ)echo "  ANDROID $@"
	$(Q)rm -r -f $@ $(@D)/AndroidManifest.xml $(@D)/src $(@D)/bin $(@D)/res/values
	$(Q)mkdir -p $(ANDROID_BUILD)/res $(ANDROID_BUILD)/src
	$(Q)ln -s ../../../$(MANIFEST) ../bin $(@D)/
	$(Q)ln -s ../../../../android/src $(@D)/src/xcsoar
ifneq ($(IOIOLIB_DIR),)
	$(Q)ln -s $(abspath $(IOIOLIB_DIR)/src/ioio/lib/api) $(ANDROID_BUILD)/src/ioio_api
	$(Q)ln -s $(abspath $(IOIOLIB_DIR)/src/ioio/lib/spi) $(ANDROID_BUILD)/src/ioio_spi
	$(Q)ln -s $(abspath $(IOIOLIB_DIR)/src/ioio/lib/util) $(ANDROID_BUILD)/src/ioio_util
	$(Q)ln -s $(abspath $(IOIOLIB_DIR)/src/ioio/lib/impl) $(ANDROID_BUILD)/src/ioio_impl
	$(Q)ln -s ../../../../android/IOIOHelper $(@D)/src/ioio_xcsoar
endif
	$(Q)ln -s ../../../../android/res/values $(@D)/res/
	$(Q)$(ANDROID_SDK)/tools/android update project --path $(@D) --target $(ANDROID_PLATFORM)
ifeq ($(TESTING),y)
ifeq ($(HOST_IS_DARWIN),y)
	$(Q)sed -i "" -f build/r.sed $@
else
	$(Q)sed -i -f build/r.sed $@
endif
endif
	@touch $@

ifeq ($(FAT_BINARY),y)

# generate a "fat" APK file with binaries for all ABIs

ALL_SO =

# Example: $(eval $(call generate-abi,xcsoar,armeabi-v7a,ANDROID7))
define generate-abi

ALL_SO += $$(ANDROID_BUILD)/libs/$(2)/lib$(1).so

$$(ANDROID_BUILD)/libs/$(2)/lib$(1).so: $$(OUT)/$(3)/bin/lib$(1).so | $$(ANDROID_BUILD)/libs/$(2)/dirstamp
	$$(Q)cp $$< $$@

$$(OUT)/$(3)/bin/lib$(1).so:
	$$(Q)$$(MAKE) TARGET=$(3) DEBUG=$$(DEBUG) IOIOLIB_DIR=$$(IOIOLIB_DIR) $$@

endef

# Example: $(eval $(call generate-abi,xcsoar))
define generate-all-abis
$(eval $(call generate-abi,$(1),armeabi,ANDROID))
$(eval $(call generate-abi,$(1),armeabi-v7a,ANDROID7))
endef

$(foreach NAME,$(ANDROID_LIB_NAMES),$(eval $(call generate-all-abis,$(NAME))))

$(ANDROID_BIN)/XCSoar-debug.apk: $(ALL_SO) $(ANDROID_BUILD)/build.xml $(ANDROID_BUILD)/res/drawable/icon.png $(SOUND_FILES) android/src/*.java
	@$(NQ)echo "  ANT     $@"
	$(Q)cd $(ANDROID_BUILD) && $(ANT) debug

$(ANDROID_BIN)/XCSoar-release-unsigned.apk: $(ALL_SO) $(ANDROID_BUILD)/build.xml $(ANDROID_BUILD)/res/drawable/icon.png $(SOUND_FILES) android/src/*.java
	@$(NQ)echo "  ANT     $@"
	$(Q)cd $(ANDROID_BUILD) && $(ANT) release

$(ANDROID_BIN)/XCSoar.apk: $(ANDROID_BIN)/XCSoar-release-unsigned.apk
	@$(NQ)echo "  SIGN    $@"
	$(Q)$(JARSIGNER) -keystore $(ANDROID_KEYSTORE) -signedjar $(ANDROID_BIN)/XCSoar.apk $(ANDROID_BIN)/XCSoar-release-unsigned.apk $(ANDROID_KEY_ALIAS)

else # !FAT_BINARY

# add dependency to this source file
$(call SRC_TO_OBJ,$(SRC)/Android/Main.cpp): $(NATIVE_HEADERS)
$(call SRC_TO_OBJ,$(SRC)/Android/EventBridge.cpp): $(NATIVE_HEADERS)
$(call SRC_TO_OBJ,$(SRC)/Android/Timer.cpp): $(NATIVE_HEADERS)
$(call SRC_TO_OBJ,$(SRC)/Android/InternalSensors.cpp): $(NATIVE_HEADERS)
$(call SRC_TO_OBJ,$(SRC)/Android/Battery.cpp): $(NATIVE_HEADERS)
$(call SRC_TO_OBJ,$(SRC)/Android/NativeInputListener.cpp): $(NATIVE_HEADERS)

$(ANDROID_LIB_BUILD): $(ANDROID_ABI_DIR)/lib%.so: $(TARGET_BIN_DIR)/lib%.so $(ANDROID_ABI_DIR)/dirstamp
	cp $< $@

ANDROID_JAVA_SOURCES = android/src/*.java
ifneq ($(IOIOLIB_DIR),)
ANDROID_JAVA_SOURCES += android/IOIOHelper/*.java
endif

$(ANDROID_BIN)/XCSoar-debug.apk: $(ANDROID_LIB_BUILD) $(ANDROID_BUILD)/build.xml $(ANDROID_BUILD)/res/drawable/icon.png $(SOUND_FILES) $(ANDROID_JAVA_SOURCES)
	@$(NQ)echo "  ANT     $@"
	@rm -f $@ $(patsubst %.apk,%-unaligned.apk,$@) $(@D)/classes.dex
	$(Q)cd $(ANDROID_BUILD) && $(ANT) debug

$(ANDROID_JNI)/build.xml $(ANDROID_JNI)/AndroidManifest.xml: | $(ANDROID_JNI)/dirstamp
	@$(NQ)echo "  ANDROID $@"
	$(Q)ln -s ../../../android/$(@F) $@

$(ANDROID_JNI)/classes/$(CLASS_CLASS): $(NATIVE_SOURCES) $(ANDROID_JNI)/build.xml $(ANDROID_JNI)/AndroidManifest.xml $(ANDROID_BUILD)/build.xml
	@$(NQ)echo "  ANT     $@"
	$(Q)cd $(ANDROID_JNI) && $(ANT) compile-jni-classes

$(patsubst %,$(NATIVE_PREFIX)%.h,$(NATIVE_CLASSES)): $(NATIVE_PREFIX)%.h: $(ANDROID_JNI)/classes/$(CLASS_CLASS)
	@$(NQ)echo "  JAVAH   $@"
	$(Q)javah -classpath $(ANDROID_SDK_PLATFORM_DIR)/android.jar:$(ANDROID_JNI)/classes -d $(@D) $(subst _,.,$(patsubst $(patsubst ./%,%,$(TARGET_OUTPUT_DIR))/include/%.h,%,$@))
	@touch $@

$(ANDROID_BIN)/XCSoar-unsigned.apk: $(ANDROID_ABI_DIR)/libxcsoar.so $(ANDROID_SO_FILES) $(ANDROID_BUILD)/build.xml $(ANDROID_BUILD)/res/drawable/icon.png $(SOUND_FILES) $(ANDROID_JAVA_SOURCES)
	@$(NQ)echo "  ANT     $@"
	@rm -f $@ $(patsubst %.apk,%-unaligned.apk,$@) $(@D)/classes.dex
	$(Q)cd $(ANDROID_BUILD) && $(ANT) release

$(ANDROID_BIN)/XCSoar.apk: $(ANDROID_BIN)/XCSoar-unsigned.apk
	@$(NQ)echo "  SIGN    $@"
	$(Q)$(JARSIGNER) -keystore $(ANDROID_KEYSTORE) -signedjar $(ANDROID_BIN)/XCSoar.apk $(ANDROID_BIN)/XCSoar-unsigned.apk $(ANDROID_KEY_ALIAS)

endif # !FAT_BINARY

endif
