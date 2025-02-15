# RUN: env FISH=%fish %fish %s

# Environment variable tests

# Test if variables can be properly set

set smurf blue

if test $smurf = blue
    echo Test 1 pass
else
    echo Test 1 fail
end
# CHECK: Test 1 pass

# Test if variables can be erased

set -e smurf
if set -q smurf
    echo Test 2 fail
else
    echo Test 2 pass
end
# CHECK: Test 2 pass

# Test if local variables go out of scope

set -e t3
if true
    set -l t3 bar
end

if set -q t3
    echo Test 3 fail
else
    echo Test 3 pass
end
# CHECK: Test 3 pass

# Test if globals can be set in block scope

if true
    set -g baz qux
end

if test $baz = qux
    echo Test 4 pass
else
    echo Test 4 fail
end
# CHECK: Test 4 pass


#Test that scope is preserved when setting a new value

set t5 a

if true
    set t5 b
end

if test $t5 = b
    echo Test 5 pass
else
    echo Test 5 fail
end
# CHECK: Test 5 pass

# Test that scope is preserved in double blocks

for i in 1
    set t6 $i
    for j in a
        if test $t6$j = 1a
            echo Test 6 pass
        else
            echo Test 6 fail
        end
    end
end
# CHECK: Test 6 pass


# Test if variables in for loop blocks do not go out of scope on new laps

set res fail

set -e t7
for i in 1 2
    if test $i = 1
        set t7 lala
    else
        if test $t7
            set res pass
        end
    end
end

echo Test 7 $res
# CHECK: Test 7 pass

# Test if variables are properly exported

set -e t8
if true
    set -lx t8 foo
    if test ($FISH -c "echo $t8") = foo
        echo Test 8 pass
    else
        echo Test 8 fail
    end
end
# CHECK: Test 8 pass

# Test if exported variables go out of scope

if $FISH -c "set -q t8; and exit 0; or exit 1"
    echo Test 9 fail
else
    echo Test 9 pass
end
# CHECK: Test 9 pass

# Test erasing variables in specific scope

set -eU __fish_test_universal_variables_variable_foo
set -g __fish_test_universal_variables_variable_foo bar
begin
    set -l __fish_test_universal_variables_variable_foo baz
    set -eg __fish_test_universal_variables_variable_foo
end

if set -q __fish_test_universal_variables_variable_foo
    echo Test 10 fail
else
    echo Test 10 pass
end
# CHECK: Test 10 pass

set __fish_test_universal_variables_variable_foo abc def
set -e __fish_test_universal_variables_variable_foo[1]
if test $__fish_test_universal_variables_variable_foo '=' def
    echo Test 11 pass
else
    echo Test 11 fail
end
# CHECK: Test 11 pass

# Test combinations of export and scope

set -ge __fish_test_universal_variables_variable_foo
set -Ue __fish_test_universal_variables_variable_foo
set -Ux __fish_test_universal_variables_variable_foo bar
set __fish_test_universal_variables_variable_foo baz
if test (/bin/sh -c 'echo $__fish_test_universal_variables_variable_foo') = baz -a ($FISH -c 'echo $__fish_test_universal_variables_variable_foo') = baz
    echo Test 12 pass
else
    echo Test 12 fail
end
# CHECK: Test 12 pass

set -Ue __fish_test_universal_variables_variable_foo

# Should no longer be in environment (#2046)
env | string match '__fish_test_universal_variables_variable_foo=*'

set -Ux __fish_test_universal_variables_variable_foo bar
set -U __fish_test_universal_variables_variable_foo baz
if test (/bin/sh -c 'echo $__fish_test_universal_variables_variable_foo') = baz -a ($FISH -c 'echo $__fish_test_universal_variables_variable_foo') = baz
    echo Test 13 pass
else
    echo Test 13 fail
end
# CHECK: Test 13 pass

set -Ux __fish_test_universal_variables_variable_foo bar
set -u __fish_test_universal_variables_variable_foo bar
if test (/bin/sh -c 'echo $__fish_test_universal_variables_variable_foo') = '' -a ($FISH -c 'echo $__fish_test_universal_variables_variable_foo') = bar
    echo Test 14 pass
else
    echo Test 14 fail
end
# CHECK: Test 14 pass

set -Ux __fish_test_universal_variables_variable_foo bar
set -Uu __fish_test_universal_variables_variable_foo baz
if test (/bin/sh -c 'echo $__fish_test_universal_variables_variable_foo') = '' -a ($FISH -c 'echo $__fish_test_universal_variables_variable_foo') = baz
    echo Test 15 pass
else
    echo Test 15 fail
end
# CHECK: Test 15 pass

set -eU __fish_test_universal_variables_variable_foo
function watch_foo --on-variable __fish_test_universal_variables_variable_foo
    echo Foo change detected
end

set -U __fish_test_universal_variables_variable_foo 1234
# CHECK: Foo change detected
set -eU __fish_test_universal_variables_variable_foo
# CHECK: Foo change detected
# WTF set -eg __fish_test_universal_variables_variable_foo

functions -e watch_foo

# test erasing variables without a specified scope

set -g test16res
set -U __fish_test_universal_variables_variable_foo universal
set -g __fish_test_universal_variables_variable_foo global

begin
    set -l __fish_test_universal_variables_variable_foo blocklocal

    function test16
        set -l __fish_test_universal_variables_variable_foo function
        begin
            set -l __fish_test_universal_variables_variable_foo functionblock
            set test16res $test16res $__fish_test_universal_variables_variable_foo

            # This sequence seems pointless but it's really verifying that we
            # succesfully expose higher scopes as we erase the closest scope.
            set -e __fish_test_universal_variables_variable_foo
            set test16res $test16res $__fish_test_universal_variables_variable_foo

            set -e __fish_test_universal_variables_variable_foo
            set test16res $test16res $__fish_test_universal_variables_variable_foo

            set -e __fish_test_universal_variables_variable_foo
            set test16res $test16res $__fish_test_universal_variables_variable_foo

            set -e __fish_test_universal_variables_variable_foo
            set -q __fish_test_universal_variables_variable_foo
            and set test16res $test16res $__fish_test_universal_variables_variable_foo
        end

        set -q __fish_test_universal_variables_variable_foo
        and echo __fish_test_universal_variables_variable_foo should set after test16 inner begin..end
    end

    test16
    set test16res $test16res $__fish_test_universal_variables_variable_foo
end
# CHECK: count:5 content:[functionblock function global universal blocklocal]

set -q __fish_test_universal_variables_variable_foo
and echo __fish_test_universal_variables_variable_foo should set after test16 outer begin..end

echo count:(count $test16res) "content:[$test16res]"
if test (count $test16res) = 5 -a "$test16res" = "functionblock function global universal blocklocal"
    echo Test 16 pass
else
    echo Test 16 fail
end
# CHECK: Test 16 pass

# Test that shadowing with a non-exported variable works
set -gx __fish_test_env17 UNSHADOWED
env | string match '__fish_test_env17=*'
# CHECK: __fish_test_env17=UNSHADOWED

function __fish_test_shadow
    set -l __fish_test_env17
    env | string match -q '__fish_test_env17=*'; or echo SHADOWED
end
__fish_test_shadow
# CHECK: SHADOWED

# Test that the variable is still exported (#2611)
env | string match '__fish_test_env17=*'
# CHECK: __fish_test_env17=UNSHADOWED

# Test that local exported variables are copied to functions (#1091)
function __fish_test_local_export
    echo $var
    set var boo
    echo $var
end
set -lx var wuwuwu
__fish_test_local_export
# CHECK: wuwuwu
# CHECK: boo
echo $var
# CHECK: wuwuwu

# Test that we don't copy local-exports to blocks.
set -lx var foo
begin
    echo $var
    # CHECK: foo
    set var bar
    echo $var
    # CHECK: bar
end
echo $var # should be "bar"
# CHECK: bar

# clear for other shells
set -eU __fish_test_universal_variables_variable_foo

# Test behavior of universals on startup (#1526)
echo Testing Universal Startup
# CHECK: Testing Universal Startup
set -U testu 0
$FISH -c 'set -U testu 1'
echo $testu
# CHECK: 1
$FISH -c 'set -q testu; and echo $testu'
# CHECK: 1

$FISH -c 'set -U testu 2'
echo $testu
# CHECK: 2
$FISH -c 'set -q testu; and echo $testu'
# CHECK: 2

$FISH -c 'set -e testu'
set -q testu
or echo testu undef in top level shell
# CHECK: testu undef in top level shell
$FISH -c 'set -q testu; or echo testu undef in sub shell'
# CHECK: testu undef in sub shell

# test SHLVL
# use a subshell to ensure a clean slate
env SHLVL= $FISH -c 'echo SHLVL: $SHLVL; $FISH -c \'echo SHLVL: $SHLVL\''
# CHECK: SHLVL: 1
# CHECK: SHLVL: 2

# exec should decrement SHLVL
env SHLVL= $FISH -c 'echo SHLVL: $SHLVL; exec $FISH -c \'echo SHLVL: $SHLVL\''
# CHECK: SHLVL: 1
# CHECK: SHLVL: 1

# garbage SHLVLs should be treated as garbage
env SHLVL=3foo $FISH -c 'echo SHLVL: $SHLVL'
# CHECK: SHLVL: 1

# whitespace is allowed though (for bash compatibility)
env SHLVL="3  " $FISH -c 'echo SHLVL: $SHLVL'
env SHLVL="  3" $FISH -c 'echo SHLVL: $SHLVL'
# CHECK: SHLVL: 4
# CHECK: SHLVL: 4

# Test transformation of inherited variables
env DISPLAY="localhost:0.0" $FISH -c 'echo Elements in DISPLAY: (count $DISPLAY)'
# CHECK: Elements in DISPLAY: 1

# We can't use PATH for this because the global configuration will modify PATH
# based on /etc/paths and /etc/paths.d.
# Exported arrays are colon delimited; they are automatically split on colons if they end in PATH.
set -gx FOO one two three four
set -gx FOOPATH one two three four
$FISH -c 'echo Elements in FOO and FOOPATH: (count $FOO) (count $FOOPATH)'
# CHECK: Elements in FOO and FOOPATH: 1 4

# some must use colon separators!
set -lx MANPATH man1 man2 man3
env | grep '^MANPATH='
# CHECK: MANPATH=man1:man2:man3

# ensure we don't escape space and colon values
set -x DONT_ESCAPE_COLONS 1: 2: :3:
env | grep '^DONT_ESCAPE_COLONS='
# CHECK: DONT_ESCAPE_COLONS=1: 2: :3:

set -x DONT_ESCAPE_SPACES '1 ' '2 ' ' 3 ' 4
env | grep '^DONT_ESCAPE_SPACES='
# CHECK: DONT_ESCAPE_SPACES=1  2   3  4

set -x DONT_ESCAPE_COLONS_PATH 1: 2: :3:
env | grep '^DONT_ESCAPE_COLONS_PATH='
# CHECK: DONT_ESCAPE_COLONS_PATH=1::2:::3:


# Path universal variables
set -U __fish_test_path_not a b c
set -U __fish_test_PATH 1 2 3
echo "$__fish_test_path_not $__fish_test_PATH" $__fish_test_path_not $__fish_test_PATH
# CHECK: a b c 1:2:3 a b c 1 2 3

set --unpath __fish_test_PATH $__fish_test_PATH
echo "$__fish_test_path_not $__fish_test_PATH" $__fish_test_path_not $__fish_test_PATH
# CHECK: a b c 1 2 3 a b c 1 2 3

set --path __fish_test_path_not $__fish_test_path_not
echo "$__fish_test_path_not $__fish_test_PATH" $__fish_test_path_not $__fish_test_PATH
# CHECK: a:b:c 1 2 3 a b c 1 2 3

set --path __fish_test_PATH $__fish_test_PATH
echo "$__fish_test_path_not $__fish_test_PATH" $__fish_test_path_not $__fish_test_PATH
# CHECK: a:b:c 1:2:3 a b c 1 2 3

set -U __fish_test_PATH 1:2:3
echo "$__fish_test_PATH" $__fish_test_PATH
# CHECK: 1:2:3 1 2 3

set -e __fish_test_PATH
set -e __fish_test_path_not

set -U --path __fish_test_path2 a:b
echo "$__fish_test_path2" $__fish_test_path2
# CHECK: a:b a b

set -e __fish_test_path2

# Test empty uvars (#5992)
set -Ux __fish_empty_uvar
set -Uq __fish_empty_uvar
echo $status
# CHECK: 0
$FISH -c 'set -Uq __fish_empty_uvar; echo $status'
# CHECK: 0
env | grep __fish_empty_uvar
# CHECK: __fish_empty_uvar=

# Variable names in other commands
# Test invalid variable names in loops (#5800)
for a,b in y 1 z 3
    echo $a,$b
end
# CHECKERR: {{.*}} for: Variable name 'a,b' is not valid. See `help identifiers`.
# CHECKERR:
# CHECKERR: for a,b in y 1 z 3
# CHECKERR:     ^


# Global vs Universal Unspecified Scopes
set -U __fish_test_global_vs_universal universal
echo "global-vs-universal 1: $__fish_test_global_vs_universal"
# CHECK: global-vs-universal 1: universal

set -g __fish_test_global_vs_universal global
echo "global-vs-universal 2: $__fish_test_global_vs_universal"
# CHECK: global-vs-universal 2: global


set __fish_test_global_vs_universal global2
echo "global-vs-universal 3: $__fish_test_global_vs_universal"
# CHECK: global-vs-universal 3: global2

set -e -g __fish_test_global_vs_universal
echo "global-vs-universal 4: $__fish_test_global_vs_universal"
# CHECK: global-vs-universal 4: universal

set -e -U __fish_test_global_vs_universal
echo "global-vs-universal 5: $__fish_test_global_vs_universal"
# CHECK: global-vs-universal 5: 

true
