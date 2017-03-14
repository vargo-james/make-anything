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
program_name := cpp-lexer
debug_program_name := dbg-cpp-lexer

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
asm_compiler = gcc
asm_flags =

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
source_dirs := src
loose_sources :=
excluded_subdirs := src/legacy_test
blacklist :=
# Add $(source_dirs) to the list if you put header files in with your source 
# files.
includes := include src/test_headers

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

# Configuration variables
SHELL := /bin/sh
.SHELLFLAGS := -euc
.DEFAULT_GOAL := all
.SUFFIXES:
.DELETE_ON_ERROR:
$(v).SILENT:
MAKECMDGOALS ?= $(.DEFAULT_GOAL)

DEBUG = .dbg
.PHONY: all release debug clean assert-file assert-file$(DEBUG)
.PHONY: asm_sources c_sources cpp_sources sources list

empty :=
space := $(empty) $(empty)
print_list = printf '%s\n' $(1)

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

ifeq ($(source_dirs),)
  source_dirs = .
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

program_sources := $(asm_sources) $(c_sources) $(cpp_sources)

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
# PROGRAM OBJECTS
###############################################################################
# ENUMERATING program_objects 
build_dir = build
# $(1) = source_file, $(2) = {empty}|$(DEBUG)
src_to_obj = $(build_dir)/$(basename $(1))$(2).o
ccpp_objects = $(foreach source,$(c_sources) $(cpp_sources),\
  $(call src_to_obj,$(source),$(2)))

asm_objects = $(foreach source,$(asm_sources),\
	      $(call src_to_obj,$(source),$(2)))

program_objects = $(asm_objects) $(ccpp_objects)

###############################################################################
# DEPENDENCY FILES
###############################################################################
dependency_dir := $(build_dir)
# $(1) = source_file, $(2) = {empty}|$(DEBUG)
temp_dep_file = $(dependency_dir)/$(basename $(1))$(2).Td
dependency_file = $(dependency_dir)/$(basename $(1))$(2).d

###############################################################################
# PRIMARY TARGETS
###############################################################################
ifeq ($(bin_dir),)
bin_dir = .
endif

all : $(default_build)

release : $(program_name) | $(bin_dir)

debug : $(debug_program_name) | $(bin_dir)

ifeq ($(MAKECMDGOALS),all)
MAKECMDGOALS := $(default_build)
endif

###############################################################################
# COMPILATION VARIABLES
###############################################################################
ifeq ($(includes),)
includes = .
endif
CPPFLAGS += $(addprefix $(space)-I,$(includes))
LDFLAGS += $(addprefix $(space)-L,$(program_libdirs))
LDFLAGS += $(addprefix $(space)-l,$(program_libs))
TARGET_ARCH :=
CXXFLAGS :=

# Compilation instructions
CC := $(c_compiler)
CXX := $(cpp_compiler)

assert_dir := .assert
includes += $(assert_dir)
assert_file := $(assert_dir)/$(assert_header)
assert_file_regexp := $(subst .,\.,$(assert_file))
filter_assert := sed 's!$(assert_file_regexp)\( *:\)\?!!'

# $(1) = source_file, $(2) = {empty}|$(DEBUG)
compiler = $(if $(filter %.c,$(1)),CC,CXX)
passed_flags = $(if $(filter %.c,$(1)),$(CFLAGS),$(CXXFLAGS))
dep_flags = -MT $(src_to_obj) -MMD -MF $(temp_dep_file)
rls_flags = $(if $(filter %.c,$(1)),$(c_release_flags),$(cpp_release_flags))
dbg_flags = $(if $(filter %.c,$(1)),$(c_debug_flags),$(cpp_debug_flags))
flags = $(if $(2),$(dbg_flags),$(rls_flags))

do_compile = $($(compiler)) $(CPPFLAGS) $(dep_flags) \
	     $(flags) $(passed_flags) $(TARGET_ARCH) -c

rename_dep = $(filter_assert) $(temp_dep_file) > $(dependency_file)

define build_template =
$(src_to_obj): $(1) $(dependency_file) \
  | assert-file$(2) $(dir $(dependency_dir)/$(1)) $(dir $(build_dir)/$(1))
	@if [ -z $(v) ]; then printf '%s\n' "$(compiler) $(1)"; fi;
	$(do_compile) $$(OUTPUT_OPTION) $(1)
	$(rename_dep) 
	touch $(src_to_obj)
	$(RM) $(temp_dep_file)
endef

# Assembly compilation
define asm_build_template =
$(src_to_obj): $(1) $(dependency_file) \
  | assert-file$(2) $(dir $(dependency_dir)/$(1)) $(dir $(build_dir)/$(1))
	@if [ -z $(v) ]; then printf '%s\n' "$(CC) $(1)"; fi;
	$(CC) $(dep_flags) $(asm_flags) $(ASFLAGS) $(CPPFLAGS) $(TARGET_MACH) \
	  -c $$(OUTPUT_OPTION) $(1)
endef

# Linking rules
ifeq ($(cpp_sources),)
linker = $(CC)
else
linker = $(CXX)
endif


linker:
	@printf '$(linker)\n'

# $(2) = {empty}|$(DEBUG)
prog_name = $(bin_dir)/$(if $(2),$(debug_program_name),$(program_name))

define link_template =
$(prog_name) : $(program_objects)
	@if [ -z $(v) ]; then printf '%s\n' "LINK $(prog_name)"; fi;
	$(linker) $(flags) $(CPPFLAGS) $(LDFLAGS) \
	  $(TARGET_ARCH) $(ccpp_objects) $$(OUTPUT_OPTION)
endef

$(foreach src,$(asm_sources),$(eval $(call asm_build_template,$(src))))

# Release builds
ifneq ($(filter release,$(MAKECMDGOALS)),)
# Compile
$(foreach src,$(program_sources),$(eval $(call build_template,$(src),)))
# Link
$(eval $(call link_template,,))
# Assert file
assert-file:
	mkdir -p $(assert_dir)
	printf '%s\n' "#define NDEBUG" "#include <assert.h>" > $(assert_file)
endif

# Debug builds
ifneq ($(filter debug,$(MAKECMDGOALS)),)
# Compile
$(foreach src,$(program_sources),$(eval $(call build_template,$(src),$(DEBUG))))
# Link
$(eval $(call link_template,,$(DEBUG)))
# Assert file
assert-file$(DEBUG):
	mkdir -p $(assert_dir)
	printf '%s\n' "#include <assert.h>" > $(assert_file)
endif

$(bin_dir):
	mkdir -p $@
$(dependency_dir)/%:
	mkdir -p $(dir $@)
$(build_dir)/%:
	mkdir -p $(dir $@)

# Suppress the search for implicit rules.
%.cpp : ;
%.c : ;
%h : ;

# Dependency files need not be present.
$(dependency_dir)/%.d: ;

clean : 
	-$(RM) $(call prog_name,)
	-$(RM) $(call prog_name,$(DEBUG))
	-$(RM) -r $(build_dir)
	-$(RM) -r $(dependency_dir)
	-$(RM) -r $(assert_dir)

# These included files establish the dependency of source files on headers.
# We don't bother to include them when running 'make clean'
ifneq ($(MAKECMDGOALS),clean)
-include $(patsubst %,$(dependency_dir)/%.d,$(basename $(program_sources)))
-include \
  $(patsubst %,$(dependency_dir)/%$(DEBUG).d,$(basename $(program_sources)))
endif
