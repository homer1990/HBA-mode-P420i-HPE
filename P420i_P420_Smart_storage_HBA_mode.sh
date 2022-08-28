#!/bin/bash
#Setting up some things...
shopt -s xpg_echo
echo -e "\033[38;5;223;48;5;23m"
ru=0
er=0
slot=0
today="$(date +'%d/%m/%Y')"
now="$(date +'%H:%M:%S')"
function check_ssacli () {
    #Check if ssacli already exists on the system
    command -V ssacli
    er=$?
    if  [ $er -ne 0 ]; then
        echo "ssacli not found on system, assuming this is the first boot. Setting up..."
        setup
        er=$?
        if  [ $er -ne 0 ]; then
            echo "There was an error setting up the environment, quiting..."
            exit 1
        else echo "Setup complete!"
        fi
        return
    else
        echo "ssacli found on system, skipping setup..."
        return
    fi
}
function first_text () {
    echo "Today is $today and the time is $now."
    echo "This is Homer27081990's script for enabling HBA mode on the HP smart array P420i controllers, on DL380-360p HPE servers."
    echo "I don't care about who uses this or what for, just that:"
    echo "-You are using it on your own system"
    echo "-There is no danger of data loss to any pools on the server you are tinkering with"
    echo "-You understand that this is a simple bash execution script, it dosen't actually do anything by itself, so any problems are caused by programs in this script and not the script itself"
    echo "-You read and understand what the script does (more-or-less) and are not using it blindly without understanding what you are doing right now"
    echo "-Understand that this script is meant to be run only on a SystemRescue (the linux distro) live CD terminal and nowhere else"
    echo "-Understand that this was written in the 27th of August, 2022. Any newer, incompatible or missing software... Well... I can't do anything about that from the past..."
    echo "-Understand that you must !NOT! RUN THIS FROM INSIDE A VM! SystemRescue live CD MUST be running on bare metal"
    echo "-Accept all of the above"
}
function enabl () {
    check_ssacli
    echo "Setting controller in slot $slot to HBA-passtrough mode."
    ssacli controller slot=$slot modify hbamode=on
    er=$?
    if  [ $er -ne 0 ]; then
        echo "Command failed with error: $er\nBye!"
        return $er
    else echo ""
    fi
    echo "Verifying... Output of 'ssacli controller slot=$slot show | grep -i hba':"
    ssacli controller slot=$slot show | grep -i hba
    er=$?
    if  [ $er -ne 0 ]; then
        echo "Verify command failed with error: $er\nBye!"
        return $er
    else echo ""
    fi
    if [ $er!="HBA Mode Enabled: True" ]; then
        echo "HBA mode is not enabled. No clue as to why."
        return $er
    else echo "All good!"
    fi
    return
}
function disabl () {
    check_ssacli
    echo "Setting controller in slot $slot to HBA-passtrough disabled (HP Smart Storage Controller RAID ENABLED, CAUTION!!!)."
    ssacli controller slot=$slot modify hbamode=off
    er=$?
    if  [ $er -ne 0 ]; then
        echo "Command failed with error: $er\nBye!"
        return $er
    fi
    echo "Verifying... Output of 'ssacli controller slot=$slot show | grep -i hba':"
    ssacli controller slot=$slot show | grep -i hba
    er=$?
    if [ $er -eq 1 ]; then
        echo "Verify command failed with error: $er\nBye!"
        return $er
    fi
    if [ "$er" -ne "HBA Mode Enabled: False" ]; then
        echo "HBA mode is not disabled. No clue as to why."
        return $er
    else echo "All good!"
    fi
    return
}
function getslot () {
    re='^[0-9]+$'
    brk=0
    while [ $brk -eq 0 ] ; do
        read -p "Enter slot number (between 0 and 9) or x for exit:" num
        if [ "$num" = "x" ] ; then
            echo "Exiting..."
            exit
        elif ! [[ $num =~ $re ]] ; then
            echo "Must enter a positive number or x for exit!"
        elif [ $num -lt 0 ]; then
            echo "Number must be greater than or equal to 0!"
        else
            slot=$num
            brk=1
        fi
    done
    return
}
function interact () {
    echo "---If you have only one HP P420i or P420 controller, the slot you want is probably 0."
    echo "What would you like me to do?\n1: Enable HBA mode on slot $slot\n2: Disable HBA mode on slot $slot\n3: Select another slot"
    echo "4: Exit"
    read -p "Please select an option and press enter: " input
    if ! [[ $input =~ $re ]] ; then
        echo "Must enter a number!"
    elif [ $input -eq 4 ]; then
        $ru=-2
        return
    elif [ $input -eq 1 ]; then
        enabl
        er=$?
        if [ $er -ne 0 ]; then
            echo "Error enabling HBA mode on slot $slot, exiting..."
            return $er
        fi
        return
    elif [ $input -eq 2 ]; then
        disabl
        er=$?
        if [ $er -ne 0 ]; then
            echo "Error disabling HBA mode on slot $slot, exiting..."
            return $er
        fi
        return true
    elif [ $input -eq 3 ]; then
        getslot
    else
        echo "Not a valid option; just select a number, 1-4, and press ENTER."
        "$PROGNAME" | grep $1
        return
    fi
    interact
}
function setup () {
    #verify we have internet...
    echo "\n Verifying internet connectivity..."
    ping 8.8.8.8 -c 4
    er=$?
    if [ ! $er ] ; then
        echo "You have no internet connection! Try switching around the cables or the router/ip config... \n (REMEMBER, the RJ-45 port on the mobo is for iLO4, cannot be used as a NIC)"
        echo "Bye!"
        return $er
    fi
    echo "...OK!"
    #verify DNS...
    echo "Verifying DNS functionality..."
    ping google.com -c 4
    er=$?
    if [ ! $er ]; then
        echo "Check your DNS configuration, cannot resolve google.com. Bye!"
        return $er
    fi
    echo "...OK!"
    #Change login of "nobody" to /bin/bash...
    echo "Changing login of user Nobody to /bin/bash"
    sed -i "s/Nobody:\\/:\\/usr\\/bin\\/nologin/Nobody:\\/:\\/bin\\/bash/" /etc/passwd
    er=$?
    if [ $er -ne 0 ]; then
        echo "Something wrong with either /etc/passwd or the Nobody user. \n Error: \n $er \n Bye!"
        return $er
    fi
    echo "...OK!"
    #Package update before depedency installation...
    pacman -Sy
    er=$?
    if [ $er -ne 0 ]; then
        echo "Updating pacman failed. \n Error: \n $er \n Bye!"
        return $er
    fi
    echo "...OK!"
    #Checking packages one-by-one
    sudo pacman -Qi fakeroot > /dev/null
    er=$?
    if [ $er -ne 0 ] ; then
        sudo pacman -S --needed --noconfirm fakeroot
        er=$?
        if [ $er -ne 0 ] ; then
            echo "install of package fakeroot failed. Exiting..."
            exit
        fi
    fi
    sudo pacman -Qi git
    er=$?
    if [ $er -ne 0 ] ; then
        sudo pacman -S --needed --noconfirm git
        er=$?
        if [ $er -ne 0 ] ; then
            echo "install of package git failed. Exiting..."
            exit
        fi
    fi
    sudo pacman -Qi wget
    er=$?
    if [ $er -ne 0 ] ; then
        sudo pacman -S --needed --noconfirm wget
        er=$?
        if [ $er-ne 0 ] ; then
            echo "install of package wget failed. Exiting..."
            exit
        fi
    fi
    sudo pacman -Qi yajl
    er=$?
    if [ $er -ne 0 ] ; then
        sudo pacman -S --needed --noconfirm yajl
        er=$?
        if [ $er -ne 0 ] ; then
            echo "install of package yajl failed. Exiting..."
            exit
        fi
    fi
    echo "...OK!"
    #Change dir to /var/tmp...
    echo "Moving into /var/tmp ..."
    cd /var/tmp
    er=$?
    if [ $er -ne 0 ]; then
        echo "Cannot cd into tmp. \n Error: \n $er \n Bye!"
        return $er
    fi
    echo "...OK!"
    #Get ssacli from git...
    echo "Downloading ssacli (HPE firmware tools) from git ..."
    su nobody -c 'git clone https://aur.archlinux.org/ssacli.git'
    er=$?
    if [ $er -ne 0 ]; then
        echo "Could not get ssacli from git. \n Error: \n $er \n Bye!"
        return $er
    fi
    echo "...OK!"
    #CD to the newly created ssacli directory...
    echo "Moving into ssacli..."
    cd ssacli > /dev/null
    er=$?
    if [ $er -ne 0 ]; then
        echo "Could not move into ssacli. \n Error: \n $er \n Bye!"
        return $er
    fi
    echo "...OK!"
    #Build the package
    echo "Building the ssacli package..."
    su nobody -c 'makepkg -si' > /dev/null
    if [ $er -ne 0 ]; then
        echo "Could not complete building of the ssacli package. \n Error: \n $er \n Bye!"
        return $er
    fi
    echo "...OK!"
    #Copy ssacli to the system...
    echo "Copying ssacli into the system..."
    cp -vr pkg/ssacli/opt /
    er=$?
    if [ $er -ne 0 ]; then
        echo "One of the copy commands failed. \n Error: \n $er \n Bye!"
        return $er
    fi
    cp -vr pkg/ssacli/usr/share /usr/
    er=$?
    if [ $er -ne 0 ]; then
        echo "One of the copy commands failed. \n Error: \n $er \n Bye!"
        return $er
    fi
    cp -vr pkg/ssacli/usr/bin/* /usr/bin/
    er=$?
    if [ $er -ne 0 ]; then
        echo "One of the copy commands failed.\nError:\n$er\nBye!"
        return $er
    fi
    hash -r > /dev/null
    er=$?
    if [ $er -ne 0 ]; then
        echo "Could not re-hash (hash -r). \n Error: \n $er \n Bye!"
        return $er
    fi
    echo "...OK!"
}
clear
first_text
interact
exit