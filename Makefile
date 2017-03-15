# vim: set tabstop=8:softtabstop=8:shiftwidth=8:noexpandtab

# This Makefile should be flexible enough to handle almost all simple projects.
# To adapt it, simply fill in the appropriate variables in the first 
# section. This has only been tested with the gcc compiler. 

# SYSTEM REQUIREMENTS:
#   1. GNU make. (Or other makes that happen to support.)
#   2. shell utils: mkdir -p, printf, sed, find or perl
#      Note: if find is not supported you must download the finder script
#      that comes with this. Just leave it in the directory with the Makefile.
#   3. A compiler that supports the -MT -MMD -MF options for automatically
#      generating dependency makefiles. This has only been tested on gcc.

# Note: As in any makefile,  variables can be overridden on the command
# 	line. For example, if you want to selectively control verbosity on 
# 	the command line rather than hard coding it into your project, then
# 	leave it empty in this file and use the following invocations:
# 	$ make 	    // quiet
# 	$ make v=1  // verbose


###############################################################################
# PROJECT SPECIFIC VARIABLES
###############################################################################

###############################################################################
# PROGRAM NAME
###############################################################################
release_program_name := a.out
debug_program_name := dbg.a.out

# Binary Directory. This is where you want the executables to land.
bin_dir := .

# default_build = debug|release
default_build = debug

###############################################################################
# COMPILER VARIABLES
###############################################################################
# These variables are only for convenience in defining the variables below.
warning_flags = -Wall -pedantic
debug_flags = -g
release_flags = -O3

# These are the compiler variables that matter. Set them as you like.
# The asm_compiler is the same as the c_compiler
asm_debug_flags =
asm_release_flags =

c_compiler = gcc
c_debug_flags = $(debug_flags) $(warning_flags)
c_release_flags = $(release_flags) $(warning_flags)

cpp_compiler = g++
cpp_debug_flags = -std=c++14 $(debug_flags) $(warning_flags)
cpp_release_flags = -std=c++14 $(release_flags) $(warning_flags)

###############################################################################
# DEBUG vs RELEASE support
###############################################################################
# Include this instead of <cassert> or <assert.h> to automatically turn
# off asserts in your release build. Also include it in any file that uses
# #NDEBUG guards. This header is automatically created and maintained by this
# Makefile. You can change its name here.
assert_header := project_assert.h

###############################################################################
# SOURCE FILES
###############################################################################
# The shell will expand these values. So globs are expanded. If you have 
# globstar enabled in your shell, then that will be expanded as well. Also 
# multiple entries separated by spaces are allowed.
# The exclusion variables match against the path starting with 
# whatever source directory that they are located in.
# Anything listed in loose_sources will be included whether or not it is in the 
# blacklist.
source_dirs :=
loose_sources :=
excluded_subdirs :=
blacklist :=
# Add $(source_dirs) to the list if you put header files in with your source 
# files.
includes :=

###############################################################################
# SUFFIXES
###############################################################################
asm_suffixes = s S
c_suffixes = c
cpp_suffixes = cpp C cc c++

###############################################################################
# LIBRARIES
###############################################################################
# Libraries. Their order here will be preserved for the linker.
# Do not prefix them with l or -l or -L. Jut put their names. For example, to
# link 'libm', just add 'm' to program_libs.
program_libs := 
program_libdirs := 

###############################################################################
# VERBOSITY
###############################################################################
# Verbosity. Put any value on the right hand side to printf shell commands.
# It is recommended to leave this blank and instead control it via the command 
# line. See above.
v =

###############################################################################
###############################################################################
####### DO NOT MODIFY ANYTHING BELOW UNLESS YOU KNOW WHAT YOU ARE DOING #######
###############################################################################
###############################################################################

# Configuration
SHELL := /bin/sh
.SHELLFLAGS := -euc
.DEFAULT_GOAL := all
.SUFFIXES:
.DELETE_ON_ERROR:
$(v).SILENT:
MAKECMDGOALS ?= $(.DEFAULT_GOAL)

# Constants
DEBUG := .dbg
build_dir := build
empty :=
space := $(empty) $(empty)

# Printing
print_list = printf '%s\n' $(1)
quiet_print = @if [ -z $(v) ]; then printf '%s\n' "$(1)"; fi;

# Assertions
assert_dir := .assert
assert_file := $(assert_dir)/$(assert_header)
assert_file_regexp := $(subst .,\.,$(assert_file))
filter_assert := sed 's!$(assert_file_regexp)\( *:\)\?!!'

# Default variable values
ifeq ($(bin_dir),)
  bin_dir = .
endif
ifeq ($(source_dirs),)
  source_dirs = .
endif
ifeq ($(includes),)
  includes = $(source_dirs) 
endif
includes += $(assert_dir)
ifeq ($(MAKECMDGOALS),all)
  MAKECMDGOALS := $(default_build)
endif

.PHONY: all release debug clean 
.PHONY: assert-header-release assert-header-debug
.PHONY: build-title-release build-title-debug
.PHONY: asm_sources c_sources cpp_sources sources list

# Makefile debugging
THIS_FILE := $(lastword $(MAKEFILE_LIST))

# This will produce a list of all the targets used by this makefile.
# It is used for debugging this Makefile
list:
	@$(MAKE) -pRrq -f $(THIS_FILE) clean : 2>/dev/null |\
	 awk -v RS= -F: '/^# File/,/^# Finished Make database/ {if ($$1 !~ "^[#.]") {print $$1}}' |\
	  sort | grep -E -v -e '^[^[:alnum:]]' -e '^$@$$'

###############################################################################
# PROGRAM SOURCES
###############################################################################
# Source file regex
# $(2) = list of suffixes
suffix_regex = [^[:space:]]*\.\($(subst $(space),\|,$(2))\)

all_suffixes := $(asm_suffixes) $(c_suffixes) $(cpp_suffixes)
source_regex := $(call suffix_regex,,$(all_suffixes))

# This variable takes a list of path patterns and converts it into a matching
# expression that the find utility can use.
find_match0 = $(subst $(space), -o ,$(patsubst %,-path%,$(1)))
find_matcher = $(find_match0:-path%=-path %)

# This matches subdirectories we don't want.
is_pruned := $(call find_matcher,$(excluded_subdirs))
prune_directories :=
ifneq ($(strip $(is_pruned)),)
  prune_directories := -type d \( $(is_pruned) \) -prune -o
endif

# This matches files that are not excluded.
exclusions = $(call find_matcher,$(blacklist)) 
not_blacklisted :=
ifneq ($(strip $(exclusions)),)
  not_blacklisted := \( \! \( $(exclusions) \) \)
endif

# This is what gets passed to the system find utility
find_invocation = $(source_dirs) -regextype posix-basic\
  $(prune_directories) \
  -type f -regex '$(source_regex)' \
  ${not_blacklisted} \
  -print 2> /dev/null

# We generate the list of sources.
program_sources :=
ifneq ($(shell command -v find),)
  program_sources := $(shell find $(find_invocation)) $(loose_sources)
else ifneq ($(shell command -v perl),)
  program_sources := $(shell perl finder $(find_invocation)) $(loose_sources)
endif

language_filter = $(shell $(print_list) | sed -n '/$(suffix_regex)$$/p')

asm_sources := $(call language_filter,$(program_sources),$(asm_suffixes))
c_sources := $(call language_filter,$(program_sources),$(c_suffixes))
cpp_sources := $(call language_filter,$(program_sources),$(cpp_suffixes))

program_sources = $(asm_sources) $(c_sources) $(cpp_sources)

# To check whether you are getting all your intended sources.
cpp_sources :
	$(call print_list,$(cpp_sources))
c_sources :
	$(call print_list,$(c_sources))
asm_sources :
	$(call print_list,$(asm_sources))
sources :
	$(call print_list,$(program_sources))

###############################################################################
# PRIMARY TARGETS
###############################################################################

all: $(default_build)

release: $(release_program_name)

debug: $(debug_program_name)

###############################################################################
# TEMPLATE VARIABLES
###############################################################################
source_file = $(1)
build_type = $(2)	# {empty}|$(DEBUG)
language = $(3)		# asm|c|cpp

# Files
object_file = $(build_dir)/$(1)$(2).o
program_objects = $(foreach source,$(program_sources),\
		  $(call object_file,$(source),$(2)))
dependency_file = $(build_dir)/$(1)$(2).d
temp_dependency_file = $(build_dir)/$(1)$(2).Td

build_mode = $(if $(2),debug,release)

# Standard Variables
CC := $(c_compiler)
CXX := $(cpp_compiler)
CPPFLAGS += $(addprefix $(space)-I,$(includes))
CXXFLAGS :=
CCFLAGS :=
ASFLAGS :=
TARGET_MACH :=
TARGET_ARCH :=
LDFLAGS += $(addprefix $(space)-L,$(program_libdirs))
LDFLAGS += $(addprefix $(space)-l,$(program_libs))

###############################################################################
# LINK RULES TEMPLATE
###############################################################################

define build_mode_template
$(name) : $(program_objects) | $(bin_dir) build-title-$(build_mode)
	$(call quiet_print,LINK $(name))
	$(linker) $(link_time_flags) $$(OUTPUT_OPTION) $(program_objects)

build-title-$(build_mode):
	printf '%s\n' "$(build_mode) build"

assert-header-$(build_mode):
	mkdir -p $(assert_dir)
	printf '%s\n' $(ndebug) $(std_header) > $(assert_file)
endef

$(bin_dir):
	mkdir -p $@

name = $($(build_mode)_program_name)

ifeq ($(cpp_sources),)
  linker := $(CC)
else
  linker := $(CXX)
endif
link_time_flags = $(lang_flags) $(CPPFLAGS) $(LDFLAGS) $(link_target)

ifeq ($(c_sources)$(cpp_sources),)
  link_target := $(TARGET_MACH)
else
  link_target := $(TARGET_ARCH)
endif
ifneq ($(asm_sources),)
  lang_flags += $(asm_$(build_mode)_flags) $(ASFLAGS)
endif
ifneq ($(c_sources),)
  lang_flags += $(c_$(build_mode)_flags) $(CFLAGS)
endif
ifneq ($(cpp_sources),)
  lang_flags += $(cpp_$(build_mode)_flags) $(CXXFLAGS)
endif

ndebug = $(if $(2),,"\#define NDEBUG")
std_header = "\#include <assert.h>"

###############################################################################
# COMPILATION RULES TEMPLATE
###############################################################################

define compilation_template
$(object_file): | assert-header-$(build_mode) $(dir $(object_file)) \
  build-title-$(build_mode)
$(object_file): $(1) $(dependency_file)
	$(call quiet_print,$(compiler) $(1))
	$($(compiler)) $(compile_time_flags) $$(OUTPUT_OPTION) $(1)
	$(rename_dependency) 
	touch $(object_file)
	$(RM) $(temp_dependency_file)

$(dependency_file): ;

$(1): ;
endef

$(build_dir)/%/:
	mkdir -p $(dir $@)

compiler = $(if $(filter cpp,$(3)),CXX,CC)

compile_time_flags = $(dependency_flags) $(compilation_flags) \
		     $(CPPFLAGS) $(compile_target) -c

compile_target = $(if $(filter asm,$(3)),$(TARGET_MACH),$(TARGET_ARCH))
dependency_flags = -MT $(object_file) -MMD -MF $(temp_dependency_file)

compilation_flags = $(file_flags) $(command_line_flags)
file_flags = $($(3)_$(build_mode)_flags)
command_line_flags = $(if $(filter asm,$(3)),$(ASFLAGS),\
		     $(if $(filter c,$(3)),$(CFLAGS),$(CXXFLAGS)))

# Dependency Management
rename_dependency = $(filter_assert) $(temp_dependency_file) \
		    > $(dependency_file)

###############################################################################
# COMPILATION RULES TEMPLATE
###############################################################################

# Release builds
ifneq ($(filter release,$(MAKECMDGOALS)),)
 $(eval $(call build_mode_template,$(empty),$(empty),$(empty)))
ifneq ($(asm_sources),)
$(foreach src,$(program_sources),\
  $(eval $(call compilation_template,$(src),$(empty),asm)))
endif
ifneq ($(c_sources),)
$(foreach src,$(program_sources),\
  $(eval $(call compilation_template,$(src),$(empty),c)))
endif
ifneq ($(cpp_sources),)
$(foreach src,$(program_sources),\
  $(eval $(call compilation_template,$(src),$(empty),cpp)))
endif
endif

# Debug builds
ifneq ($(filter debug,$(MAKECMDGOALS)),)
 $(eval $(call build_mode_template,$(empty),$(DEBUG),$(empty)))
ifneq ($(asm_sources),)
$(foreach src,$(program_sources),\
  $(eval $(call compilation_template,$(src),$(DEBUG),asm)))
endif
ifneq ($(c_sources),)
$(foreach src,$(program_sources),\
  $(eval $(call compilation_template,$(src),$(DEBUG),c)))
endif
ifneq ($(cpp_sources),)
$(foreach src,$(program_sources),\
  $(eval $(call compilation_template,$(src),$(DEBUG),cpp)))
endif
endif

# Suppress the search for implicit rules.
%h : ;

clean : 
	-$(RM) $(release_program_name)
	-$(RM) $(debug_program_name)
	-$(RM) -r $(build_dir)
	-$(RM) -r $(assert_dir)

# These included files establish the dependency of source files on headers.
# We don't bother to include them when running 'make clean'
ifneq ($(MAKECMDGOALS),clean)
-include $(patsubst %,$(build_dir)/%.d,$(program_sources))
-include $(patsubst %,$(build_dir)/%$(DEBUG).d,$(program_sources))
endif
