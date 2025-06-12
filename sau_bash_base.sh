# sau_bash_base.sh
# Meant to be sourced in other scripts
# or just copy to what you have.
#
# Use this all the time in my sysadmin scripts
#
# rev 2021-08-02

# sau_is_interactive
#   return 0 if session is assumed Interactive
#   return 1 if session is assumed scripted/non-interactive (skip prompts etc)
sau_is_interactive() {
    # Check multiple conditions for interactive mode
    if [[ -t 0 && -t 1 && -t 2 ]]; then
        # stdin, stdout, and stderr are all terminals
        return 0  # Interactive
    elif [[ $- == *i* ]]; then
        # Shell was invoked with -i flag (interactive)
        return 0  # Interactive
    elif [[ -n "$PS1" ]]; then
        # PS1 is set (usually indicates interactive shell)
        return 0  # Interactive
    else
        return 1  # Non-interactive
    fi
}

# Function to check if script is running with root privileges, hard exit if not
#   Optional Arg1 as error message if not root
#
# Example:
#   sau_exit_if_not_root "Should have used sudo"
#   ls -l /root
#
# Be aware to not run this in a subshell, as it will not exit more than subshell
sau_exit_if_not_root() {
    local arg1=${1:-"Abort, running with root privileges required."}
    if [[ $EUID -eq 0 ]]; then
        return 0  # Running as root - all is well
    else
        echo "$arg1" >&2
        exit 1  # Not running as root
    fi
}


# Function to check result value, non-zero will exit with error message
# Example:
#    test -E /my/symlink
#    sau_exit_nonzero $? "The symlink is broken - abort"
#    echo "Symlink is fine"
#
# Be aware to not run this in a subshell, as it will not exit more than subshell
sau_exit_nonzero() {
  local arg2=${2:-"Unknown Error, Reason Not provided."}
  if [[ "$1" -ne 0 ]]; then
     echo "==xx==xx==xx==xx==xx==xx==xx==" >&2
     echo " Result code $1: $arg2" >&2
     echo "==xx==xx==xx==xx==xx==xx==xx==" >&2
     exit $1
  fi
  return 0
}
