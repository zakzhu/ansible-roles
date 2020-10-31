# This file is used to include alias.d/*.sh

# Note: Don't change this file!
# If you want to create a command alias, please 
# write a custom.sh shell script in /etc/profile.d/alias.d/

for i in /etc/profile.d/alias.d/*.sh ; do
    if [ -r "$i" ]; then
        if [ "${-#*i}" != "$-" ]; then 
            . "$i"
        else
            . "$i" >/dev/null
        fi
    fi
done
