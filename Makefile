ARCHS = arm64
TARGET = iphone:clang:latest:10.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = FoxFeature

FoxFeature_FILES = $(wildcard Sources/*.m)
FoxFeature_FRAMEWORKS = UIKit Foundation
FoxFeature_CFLAGS = -fobjc-arc -ISources -Wno-deprecated-declarations -Wno-unused-function
FoxFeature_LDFLAGS = -undefined dynamic_lookup -not_for_dyld_shared_cache
FoxFeature_CODESIGN_FLAGS = -S

include $(THEOS)/makefiles/library.mk