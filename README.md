# Make-Anything

Yet another ultimate/canonical/one size fits all makefile for any small to 
medium C++/C/Assembly project.

## Introduction / Why I Posted Yet Another Makefile on the Internet

I got tired of the makefiles I was using in the past. They weren't flexible
enough, and every time I wanted to do something a little different with my 
project I had to adjust the makefile. So I decided to create one that
would work for all my basic projects without any more tinkering with build code.

I decided to post it here because it has some nice features that
I have not seen on other 
makefiles floating around the internet. Notably, it
automatically handles mixed language projects. It allows for a simple but 
flexible source file specification. And It enables very easy 
management of `NDEBUG` guards (assert!). It also supports whatever file suffixes
you want to use in your project. So if you have a mix of .cpp files and .C 
files, that is handled automatically. If you want to invent a new suffix for
your source files you can do that too. Finally, it does not annoyingly force
you to maintain a flat source "tree". And, in case you care, it does not 
employ recursive calls to make.

Please note that this Makefile is not primarily intended for use as a 
distribution tool. It does not even include typical targets such as 'install'. 
Its purpose is to enable incremental compilation during development. 
If your project has few outside dependencies, then maybe this could serve as a 
very basic distribution tool.

## Features

  1. EASE OF USE: You need only set a few simple variables and your project
     will be ready to build. Most of the time, you will only need to change
     the project name and maybe your source directory and includes. You will
     also need to specify any libraries that you would normally specify
     to the linker. The default build mode is debug. If you prefer to build
     release builds by default, then you can change that.
     
  2. AUTOMATIC DEPENDENCY GENERATION: See 1. If it didn't automatically keep
     track of your headers, it wouldn't be that easy to use would it?

  3. FLEXIBLE SOURCE FILE SPECIFICATION: If all your source files are in the
     project directory, make will automatically find them for you. Or, you 
     can selectively grab source files from all over your file system by
     specifying a few variables. Source files in subdirectories are 
     automatically found.

  4. MIXED LANGUAGE SUPPORT: This file works on projects with any combination
     of C, C++, and Assembly source files.

  5. AUTOMATIC SUPPORT FOR RELEASE/DEBUG builds: This file simultaneously
     maintains a debug build and a release build. You can specify whatever
     compilation flags you like for each build. These builds also support
     easy management of runtime asserts and `NDEBUG` guards.

  6. QUIET BY DEFAULT: You don't really want to see walls of text flash down
     your screen do you? If you do, then you can. But by default, only simple,
     informative messages are printed during compilation.

  7. DOES NOT TOUCH YOUR SOURCE TREE: Object files are built in their own 
     subdirectory. Your source tree will not be cluttered with object files.

  8. SUFFIX SUPPORT: By default this Makefile recognizes the following 
     suffixes: s, S, c, cpp, C, cc, c++
     You can add additional suffixes if you need to. Every source file
     must have a suffix that is listed in the Makefile.

  9. PARALLEL EXECUTION: Any makefile should correctly support the -j option,
     and this one does.

## Reasons to not just use a full-featured build system (with rebuttals)

  - It would have to be installed. ['sudo apt-get install cmake' is so hard.]

  - You don't need a sledgehammer. [Portability and flexibility are worth it.]

  - You would have to read documention. [... crickets]

  - Free software is awesome. [CMake is open source.]

  - Is anything really as easy as a makefile that just works? [Is it still easy
    when you are distributing the software and you have switch to something
    that supports that?]

## Requirements

  1. Your source files must be on your file system and they cannot contain
     spaces. Quotation marks would also probably screw something up.

  2. You might need GNU make. Or maybe not. It has only been tested on GNU 
     make 4.0. 

  3. Your shell must support the following utilities:
         printf, sed, mkdir -p, either find or perl.
     If your shell does not support find, but does have perl, then get the 
     finder script and put it in the same directory as this Makefile. This
     Makefile will automatically use it. If you don't know whether your
     shell supports find, you can find out by typing `command -v find`. If 
     it prints `/usr/bin/find` or something like that then you have it. If it
     gives nothing back, then you don't and you need the finder script. 
     Either way, you can get just get the finder script and not worry about it.

  4. You need a compiler that supports options `-MT -MMD -MF`. gcc does this.
     clang probably does as well. But I have not yet tested clang and their 
     documentation here is lacking.
     
  5. You need to know what libraries you are linking with and where they are
     on your system. Of course, this only applies to libraries that your 
     compiler/system does not already know about and handle automatically.

## Quick Start

If you know anything about makefiles, it is probably easiest to skip the 
documentation below and just download the makefile into your project directory, 
open it up, and take a look at the PROJECT SPECIFIC VARIABLES section. 
The comments in the file explain the variables there. If you want more details, 
or you want to know how this makefile manages NDEBUG guards, then check out 
the guide below.

If you don't know anything about makefiles, how did you get here?
You will probably want to check out the GNU make manual and read the
introduction there before doing anything.

## Configuration Guide

This guide will explain the purpose of the bundled scripts and will then
explain the user variables that you can set inside the makefile. If you would
like to know the details of how the makefile works, then please read the GNU
make manual. It's all in there.

For this guide, we define *project directory* to refer to the directory in 
which the Makefile resides.

#### Scripts

The GNU make manual recommends against using find and mkdir -p in a makefile.
Apparently these are not as portable as other shell commands. So if your 
system does not have the find utility or if your find utility does not 
support --regextype -regex and -path, then you should get the finder perl 
script. Obviously running a perl script requires perl on your system. The
script will be completely ignored on systems with a find utility.

I have not yet made a perl script to support systems without mkdir -p.

#### Program Name Variables

*release_program_name*, *debug_program_name*:
  These are the names for your release build and debug build executables.

*bin_dir*:
  The directory where your executables are put. By default this is the 
project directory. You can specify a directory by an absolute path or by a 
relative path from the project directory. A directory by this name will be
created automatically if it does not already exist. While you are welcome to
create it yourself, it is not necessary.

*default_build*:
  You can set this to debug or release. Its value is the default target of the
makefile.

#### Compiler Variables

*c_compiler*, *cpp_compiler*:
  Your compilers. If your project only has C++ files, the value of c_compiler
is irrelevant. You don't need valid values for variables that will never be
used. You can override the actual values with the usual command line 
invocations:

    $ make CXX=clang CC=cc

*debug_flags*, *release_flags*:
  These are the compilation flags used for your builds. You can add flags to 
them on the command line with:

    $ make CFLAGS=-pg CXXFLAGS=-O2

#### Debug vs Release support

*assert_header*:
  This is the name of a file that is created and managed by this makefile.
Its purpose is to allow automatic support for managing all the `NDEBUG` guards
in your code. It is a very simple file with at most 2 lines:

    #define NDEBUG      // This line is only here in release builds.
    #include <assert.h>

It is placed in a subdirectory of the project directory that is then added to
the include path. Suppose you run

    $ make debug

Then this file will be overwritten without the `NDEBUG` defined, and your 
compilation will proceed. If you then run

    $ make release

the file is overwritten again with the `NDEBUG` definition. This file is
excluded as a dependency of your source files, so this will not interfere with
incremental compilation. If you want your `NDEBUG` guarded code to automatically
be toggled out of existence in your release build, then you must include this
file anywhere you have `NDEBUG` guards. If you have assertions, then you should
replace your inclusions of `<cassert>` or `<assert.h>` with 
`"project_assert.h"`.

#### Source Files

Typically, all you need to do is set 

    source_dirs := src 

and you are done here.  If your source files live in the root project 
directory, then set

    source_dirs := .

Or just leave it blank and the Makefile will fill in the default '.'.
If you want to understand the algorithm by which the source files are
generated then take a look at the find_invocation variable in the
implementation part of the Makefile.

If you would like to make sure that the Makefile is finding all the sources
you want, you can print a list with

    $ make sources

IMPORTANT: directories that end with a trailing slash will not be recognized!

*source_dirs*:
All source files in these directories and all subdirectories will be found.
You can exclude some of those by using the other variables. If this varialble
is set to nothing, then the makefile will use the project directory.

These directories can be specified by absolute paths or paths relative to the 
project directory. Shell file expansions will occur only if your system has the 
find utility.

*loose_sources*:
You can put a list of source files here. You must either specify absolute 
paths or relative paths from the project directory. Shell expansions occur. 
For example,

    loose_sources := ~/myfile.cpp ../foo.asm ~/other_project/*.c

Files listed here cannot be excluded by the blacklist.

*excluded_subdirs*:
These are subdirectories of directories listed in source_dirs. They must
be specified by a path relative to one of the included source directories.
For example, if you have `source_dirs := src` and you want to exclude the 
directory `src/this/subdirectory`, then set

    excluded_subdirs := src/this/subdirectory

If all your source files are in the directory src and you want to exclude
all the source files in any subdirectories of src, you can set

    excluded_subdirs := src/*

The star expands to include all subdirectories of src.

*blacklist*:
  Any file listed here will not be used. So if you no longer want to compile
`legacy_code.cpp`, but you want to keep it around because it has useful code
snippets, then add it to the blacklist. The blacklist does not exclude files
added in through the loose_sources variable.

    blacklist := legacy_code.cpp 

These files must be specified by absolute paths or by paths relative to the 
source directory in which they live. So for example, if I want to 

includes:
  This tells the compiler where to look for headers. Paths relative to the 
project directory and absolute paths are accepted. These will be expanded
by the shell. If you tend to put headers in the same folders with your 
source files, then add `$(source_dirs)`. If you would need to put -Idir when
you compile, then you need dir in this list. If you leave this blank, 
then it will automatically be converted to `$(source_dirs)`.

#### Suffixes

  A file with an unlisted suffix or no suffix will not be recognized as
a source file. If you need to support suffixes that is not listed by default, 
you can add them in this section.

#### Libraries

program_libs:
  List any libraries that will need to link here. For example, if you want to
link GMP (multi-precision arithmetic), add `gmp` to the list. 

    program_libs := gmp

program_libdirs
  If you are linking with a library and your system does not know about that
library, then you need to add its location here. e.g.

    program_libdirs := ~/lib

#### Verbosity

  If you always want to see all the shell commands when you run make, then set
this variable to any non-empty value:

    v := 1

If you prefer to not see the fast scrolling wall of text every time you run
make, then leave v set to nothing. On the command line, when you want to
see the shell commands, run

    $ make v=1

