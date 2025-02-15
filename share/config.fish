# Main file for fish command completions. This file contains various
# common helper functions for the command completions. All actual
# completions are located in the completions subdirectory.
#
# Set default field separators
#
set -g IFS \n\ \t
set -qg __fish_added_user_paths
or set -g __fish_added_user_paths

#
# Create the default command_not_found handler
#
function __fish_default_command_not_found_handler
    printf "fish: Unknown command: %s\n" (string escape -- $argv[1]) >&2
end

if status --is-interactive
    # Enable truecolor/24-bit support for select terminals
    # Ignore Screen and emacs' ansi-term as they swallow the sequences, rendering the text white.
    if not set -q STY
        and not string match -q -- 'eterm*' $TERM
        and begin
            set -q KONSOLE_PROFILE_NAME # KDE's konsole
            or string match -q -- "*:*" $ITERM_SESSION_ID # Supporting versions of iTerm2 will include a colon here
            or string match -q -- "st-*" $TERM # suckless' st
            or test -n "$VTE_VERSION" -a "$VTE_VERSION" -ge 3600 # Should be all gtk3-vte-based terms after version 3.6.0.0
            or test "$COLORTERM" = truecolor -o "$COLORTERM" = 24bit # slang expects this
        end
        # Only set it if it isn't to allow override by setting to 0
        set -q fish_term24bit
        or set -g fish_term24bit 1
    end
else
    # Hook up the default as the principal command_not_found handler
    # in case we are not interactive
    function __fish_command_not_found_handler --on-event fish_command_not_found
        __fish_default_command_not_found_handler $argv
    end
end

#
# Set default search paths for completions and shellscript functions
# unless they already exist
#

# __fish_data_dir, __fish_sysconf_dir, __fish_help_dir, __fish_bin_dir
# are expected to have been set up by read_init from fish.cpp

# Grab extra directories (as specified by the build process, usually for
# third-party packages to ship completions &c.
set -l __extra_completionsdir
set -l __extra_functionsdir
set -l __extra_confdir
if test -f $__fish_data_dir/__fish_build_paths.fish
    source $__fish_data_dir/__fish_build_paths.fish
end

# Set up function and completion paths. Make sure that the fish
# default functions/completions are included in the respective path.

if not set -q fish_function_path
    set fish_function_path $__fish_config_dir/functions $__fish_sysconf_dir/functions $__extra_functionsdir $__fish_data_dir/functions
else if not contains -- $__fish_data_dir/functions $fish_function_path
    set -a fish_function_path $__fish_data_dir/functions
end

if not set -q fish_complete_path
    set fish_complete_path $__fish_config_dir/completions $__fish_sysconf_dir/completions $__extra_completionsdir $__fish_data_dir/completions $__fish_user_data_dir/generated_completions
else if not contains -- $__fish_data_dir/completions $fish_complete_path
    set -a fish_complete_path $__fish_data_dir/completions
end

# This cannot be in an autoload-file because `:.fish` is an invalid filename on windows.
function : -d "no-op function"
    # for compatibility with sh, bash, and others.
    # Often used to insert a comment into a chain of commands without having
    # it eat up the remainder of the line, handy in Makefiles. 
end

#
# This is a Solaris-specific test to modify the PATH so that
# Posix-conformant tools are used by default. It is separate from the
# other PATH code because this directory needs to be prepended, not
# appended, since it contains POSIX-compliant replacements for various
# system utilities.
#

if test -d /usr/xpg4/bin
    not contains -- /usr/xpg4/bin $PATH
    and set PATH /usr/xpg4/bin $PATH
end

# Add a handler for when fish_user_path changes, so we can apply the same changes to PATH
function __fish_reconstruct_path -d "Update PATH when fish_user_paths changes" --on-variable fish_user_paths
    set -l local_path $PATH

    for x in $__fish_added_user_paths
        set -l idx (contains --index -- $x $local_path)
        and set -e local_path[$idx]
    end

    set -g __fish_added_user_paths
    if set -q fish_user_paths
        # Explicitly split on ":" because $fish_user_paths might not be a path variable,
        # but $PATH definitely is.
        for x in (string split ":" -- $fish_user_paths[-1..1])
            if set -l idx (contains --index -- $x $local_path)
                set -e local_path[$idx]
            else
                set -ga __fish_added_user_paths $x
            end
            set -p local_path $x
        end
    end

    set -xg PATH $local_path
end

#
# Launch debugger on SIGTRAP
#
function fish_sigtrap_handler --on-signal TRAP --no-scope-shadowing --description "Signal handler for the TRAP signal. Launches a debug prompt."
    breakpoint
end

#
# Whenever a prompt is displayed, make sure that interactive
# mode-specific initializations have been performed.
# This handler removes itself after it is first called.
#
function __fish_on_interactive --on-event fish_prompt
    __fish_config_interactive
    functions -e __fish_on_interactive
end

# Set the locale if it isn't explicitly set. Allowing the lack of locale env vars to imply the
# C/POSIX locale causes too many problems. Do this before reading the snippets because they might be
# in UTF-8 (with non-ASCII characters).
__fish_set_locale

# "." alias for source; deprecated
function . -d 'Evaluate a file (deprecated, use "source")' --no-scope-shadowing --wraps source
    if [ (count $argv) -eq 0 ] && isatty 0
        echo "source: using source via '.' is deprecated, and stdin doesn't work."\n"Did you mean 'source' or './'?" >&2
        return 1
    else
        source $argv
    end
end

# Upgrade pre-existing abbreviations from the old "key=value" to the new "key value" syntax.
# This needs to be in share/config.fish because __fish_config_interactive is called after sourcing
# config.fish, which might contain abbr calls.
if not set -q __fish_init_2_3_0
    if set -q fish_user_abbreviations
        set -l fab
        for abbr in $fish_user_abbreviations
            set -a fab (string replace -r '^([^ =]+)=(.*)$' '$1 $2' -- $abbr)
        end
        set fish_user_abbreviations $fab
    end
    set -U __fish_init_2_3_0
end

#
# Some things should only be done for login terminals
# This used to be in etc/config.fish - keep it here to keep the semantics
#
if status --is-login
    if command -sq /usr/libexec/path_helper
        # Adapt construct_path from the macOS /usr/libexec/path_helper
        # executable for fish; see
        # https://opensource.apple.com/source/shell_cmds/shell_cmds-203/path_helper/path_helper.c.auto.html .
        function __fish_macos_set_env -d "set an environment variable like path_helper does (macOS only)"
            set -l result

            # Populate path according to config files
            for path_file in $argv[2] $argv[3]/*
                if [ -f $path_file ]
                    while read -l entry
                        if not contains -- $entry $result
                            test -n "$entry"
                            and set -a result $entry
                        end
                    end <$path_file
                end
            end

            # Merge in any existing path elements
            for existing_entry in $$argv[1]
                if not contains -- $existing_entry $result
                    set -a result $existing_entry
                end
            end

            set -xg $argv[1] $result
        end

        __fish_macos_set_env 'PATH' '/etc/paths' '/etc/paths.d'
        if [ -n "$MANPATH" ]
            __fish_macos_set_env 'MANPATH' '/etc/manpaths' '/etc/manpaths.d'
        end
        functions -e __fish_macos_set_env
    end

    #
    # Put linux consoles in unicode mode.
    #
    if test "$TERM" = linux
        and string match -qir '\.UTF' -- $LANG
        and command -sq unicode_start
        unicode_start
    end
end

# Invoke this here to apply the current value of fish_user_path after
# PATH is possibly set above.
__fish_reconstruct_path

# Allow %n job expansion to be used with fg/bg/wait
# `jobs` is the only one that natively supports job expansion
function __fish_expand_pid_args
    for arg in $argv
        if string match -qr '^%\d+$' -- $arg
            # set newargv $newargv (jobs -p $arg)
            jobs -p $arg
            if not test $status -eq 0
                return 1
            end
        else
            printf "%s\n" $arg
        end
    end
end

for jobbltn in bg fg wait disown
    function $jobbltn -V jobbltn
        builtin $jobbltn (__fish_expand_pid_args $argv)
    end
end

function kill
    command kill (__fish_expand_pid_args $argv)
end

# As last part of initialization, source the conf directories.
# Implement precedence (User > Admin > Extra (e.g. vendors) > Fish) by basically doing "basename".
set -l sourcelist
for file in $__fish_config_dir/conf.d/*.fish $__fish_sysconf_dir/conf.d/*.fish $__extra_confdir/*.fish
    set -l basename (string replace -r '^.*/' '' -- $file)
    contains -- $basename $sourcelist
    and continue
    set sourcelist $sourcelist $basename
    # Also skip non-files or unreadable files.
    # This allows one to use e.g. symlinks to /dev/null to "mask" something (like in systemd).
    [ -f $file -a -r $file ]
    and source $file
end
