#!/bin/sh
# Part of Wolf2000-Tools https://github.com/Wolf2000Pi/bigwolf2000-tools
# Version 1.9.5
# by Wolf2000




calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error 
  # output from tput. However in this case, tput detects neither stdout or 
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=22
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-10))
}

do_about() {
  whiptail --msgbox "\
Ich hoffe ihr seid zufrieden?
Für Schäden übernehme ich Keine Haftung!
@Wolf2000.
https://github.com/Wolf2000Pi/bigwolf2000-tools
\

" 11 70 1
}


set_config_var() {
  lua - "$1" "$2" "$3" <<EOF > "$3.bak"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
  if line:match("^#?%s*"..key.."=.*$") then
    line=key.."="..value
    made_change=true
  end
  print(line)
end

if not made_change then
  print(key.."="..value)
end
EOF
mv "$3.bak" "$3"
}

get_config_var() {
  lua - "$1" "$2" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
for line in file:lines() do
  local val = line:match("^#?%s*"..key.."=(.*)$")
  if (val ~= nil) then
    print(val)
    break
  end
end
EOF
}

do_change_pass() {
  whiptail --msgbox "Sie werden nun aufgefordert, ein neues Passwort für den Root-Benutzer einzugeben" 20 60 1
  passwd root &&
  whiptail --msgbox "Passwort wurde erfolgreich geändert" 20 60 1
}

do_configure_keyboard() {
  dpkg-reconfigure keyboard-configuration &&
  printf "Reloading keymap. This may take a short while\n" &&
  invoke-rc.d keyboard-setup start
}

do_change_locale() {
  dpkg-reconfigure locales
}

do_change_timezone() {
  dpkg-reconfigure tzdata
}

do_change_hostname() {
  whiptail --msgbox "\
Bitte beachten Sie: Das der Hostname!
Nur die ASCII-Buchstaben "a" bis "z" enthalten (Groß-und Kleinschreibung),
Die Ziffern '0' bis '9' und der Bindestrich.
Hostnamen-Labels können nicht mit einem Bindestrich beginnen oder enden.
Es sind keine anderen Symbole, Interpunktionszeichen oder Leerzeichen zulässig. 
\
" 20 70 1

  CURRENT_HOSTNAME=`cat /etc/hostname | tr -d " \t\n\r"`
  NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    ASK_TO_REBOOT=1
  fi
}

do_ssh() {
  if [ -e /var/log/regen_ssh_keys.log ] && ! grep -q "^finished" /var/log/regen_ssh_keys.log; then
    whiptail --msgbox "Initial ssh key generation still running. Please wait and try again." 20 60 2
    return 1
  fi
  whiptail --yesno "Would you like the SSH server enabled or disabled?" 20 60 2 \
    --yes-button Enable --no-button Disable
  RET=$?
  if [ $RET -eq 0 ]; then
    update-rc.d ssh enable &&
    invoke-rc.d ssh start &&
    whiptail --msgbox "SSH server enabled" 20 60 1
  elif [ $RET -eq 1 ]; then
    update-rc.d ssh disable &&
    whiptail --msgbox "SSH server disabled" 20 60 1
  else
    return $RET
  fi
}



# $1 = filename, $2 = key name
get_json_string_val() {
  sed -n -e "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*\"\(.*\)\"[[:space:]]*,$/\1/p" $1
}

do_apply_os_config() {
  [ -e /boot/os_config.json ] || return 0
  NOOBSFLAVOUR=$(get_json_string_val /boot/os_config.json flavour)
  NOOBSLANGUAGE=$(get_json_string_val /boot/os_config.json language)
  NOOBSKEYBOARD=$(get_json_string_val /boot/os_config.json keyboard)

  if [ -n "$NOOBSFLAVOUR" ]; then
    printf "Setting flavour to %s based on os_config.json from NOOBS. May take a while\n" "$NOOBSFLAVOUR"

    if printf "%s" "$NOOBSFLAVOUR" | grep -q "Scratch"; then
      disable_raspi_config_at_boot
      enable_boot_to_scratch
    else
      printf "Unrecognised flavour. Ignoring\n"
    fi
  fi

  # TODO: currently ignores en_gb settings as we assume we are running in a 
  # first boot context, where UK English settings are default
  case "$NOOBSLANGUAGE" in
    "en")
      if [ "$NOOBSKEYBOARD" = "gb" ]; then
        DEBLANGUAGE="" # UK english is the default, so ignore
      else
        DEBLANGUAGE="en_US.UTF-8"
      fi
      ;;
    "de")
      DEBLANGUAGE="de_DE.UTF-8"
      ;;
    *)
      printf "Language '%s' not handled currently. Run sudo raspi-config to set up" "$NOOBSLANGUAGE"
      ;;
  esac

  if [ -n "$DEBLANGUAGE" ]; then
    printf "Setting language to %s based on os_config.json from NOOBS. May take a while\n" "$DEBLANGUAGE"
    cat << EOF | debconf-set-elections
locales   locales/locales_to_be_generated multiselect     $DEBLANGUAGE UTF-8
EOF
    rm /etc/locale.gen
    dpkg-reconfigure -f noninteractive locales
    update-locale LANG="$DEBLANGUAGE"
    cat << EOF | debconf-set-selections
locales   locales/default_environment_locale select       $DEBLANGUAGE
EOF
  fi

  if [ -n "$NOOBSKEYBOARD" -a "$NOOBSKEYBOARD" != "gb" ]; then
    printf "Setting keyboard layout to %s based on os_config.json from NOOBS. May take a while\n" "$NOOBSKEYBOARD"
    sed -i /etc/default/keyboard -e "s/^XKBLAYOUT.*/XKBLAYOUT=\"$NOOBSKEYBOARD\"/"
    dpkg-reconfigure -f noninteractive keyboard-configuration
    invoke-rc.d keyboard-setup start
  fi
  return 0
}


do_internationalisation_menu() {
  FUN=$(whiptail --title "Server Software Configuration Tool (Wolf2000-config)" --menu "Internationalisation Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Zurrück --ok-button Wählen \
    "I1 Change Locale               " "Wo bist Du zu Hause" \
    "I2 Change Timezone             " "Meine Uhr geht nach der Wiener Wasserleitungen" \
    "I3 Change Keyboard Layout      " "Tastatur-Einstellungen" \
	"I4 Tasksel                     " "Werkzeug um Pakete zu installieren" \
	"I5 Backup                      " "Captain OMV-xml root Docker" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then		
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      I1\ *) do_change_locale ;;
      I2\ *) do_change_timezone ;;
      I3\ *) do_configure_keyboard ;;
	  I4\ *) do_tasksel ;;
	  I5\ *) do_backup ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}
do_tasksel() {
  cd /root/
  if tasksel; then
    return 1
  fi 
  exec bigwolf2000-config
}
  do_backup() {
  cd /root/bigwolf2000-tools/ &&
  chmod +x backup.sh &&
  ./backup.sh
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}  
do_Openmediavault_menu() {
  FUN=$(whiptail --title "Server Software Configuration Tool (Bigwolf2000-config)" --menu "Openmediavault Optionen" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Zurrück --ok-button Wählen \
	"O1 Openmediavault Version 6      "     "Installation Unter Debian bullseye" \
    "O2 Openmediavault Plugins        "     "Nur für OMV" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      O1\ *) do_omv6 ;;
      O2\ *) do_omv_plugins ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}
do_docker_menu() {
  FUN=$(whiptail --title "Server Software Configuration Tool (Bigwolf2000-config)" --menu "Docker Optionen" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Zurrück --ok-button Wählen \
	"D1 Docker                  "    "Alte Img löschen" \
	"D2 CapRover                "    "CapRover Installation" \
	"D3 Docker ctop             "    "Docker-ctop installation" \
	"D4 ONLYOFFICE Example      "    "ONLYOFFICE Example reaktivieren" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      D1\ *) do_docker_purge ;;
	  D2\ *) do_capRover ;;
	  D3\ *) do_docker_ctop ;;
	  D4\ *) do_offi_example ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}
do_docker_purge() {
  docker system prune -a &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}  
do_capRover() {
  docker run -p 80:80 -p 443:443 -p 3000:3000 -v /var/run/docker.sock:/var/run/docker.sock -v /captain:/captain caprover/caprover &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
  do_docker_ctop() {
  echo "deb http://packages.azlux.fr/debian/ buster main" | sudo tee /etc/apt/sources.list.d/azlux.list &&
  wget -qO - https://azlux.fr/repo.gpg.key | sudo apt-key add -
  apt update &&
  apt install docker-ctop &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}  
do_offi_example() {
  docker exec $(docker ps -l -q --filter "name=srv-captain--offi.1") supervisorctl start ds:example &&
  docker exec $(docker ps -l -q --filter "name=srv-captain--offi.1") sed 's,autostart=false,autostart=true,' -i /etc/supervisor/conf.d/ds-example.conf
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}  
do_omv_plugins() {
apt-get update &&
apt-get --yes --force-yes --allow-unauthenticated install openmediavault-resetperms openmediavault-locate openmediavault-apttool  
exec bigwolf2000-config
}

do_advanced_menu() {
  FUN=$(whiptail --title "Server Software Configuration Tool (Bigwolf2000-config)" --menu "Advanced Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Zurrück --ok-button Wählen \
    "A1 Hostname         " "Setzen Sie den sichtbaren Namen im Netzwerk" \
    "A2 SSH              " "Enable/Disable ein/aus um sich mit dem Putty zu verbinden zu können" \
	3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      A1\ *) do_change_hostname ;;
      A2\ *) do_ssh ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_omv7() {
#  chmod +x omv-install-6.x.sh
  omv-install-6.x.sh
  printf "Einen Moment ich starte in 1Sek Bigwolf2000-config\n" &&
  sleep 1 &&
  exec bigwolf2000-config
}
# test
do_omv6() {
if
  whiptail --yesno "OMV6 Installieren" 20 60 2 \
    --yes-button Ja --no-button Nein
  RET=$?
   [ $RET -eq 0 ]; then
    apt update &&
	omv-install-6.x.sh
    whiptail --msgbox "OMV6 wurde Installiert" 20 60 1
  elif [ $RET -eq 1 ]; then
    whiptail --msgbox "Die OMV6 Installation wurde abgebrochen" 20 60 1
  else
    return $RET
  fi
 } 
do_update() {
  apt update &&
  apt list --upgradable -a &&
  apt upgrade &&
  printf "Einen Moment ich starte in 1Sek Bigwolf2000-config\n" &&
  sleep 1 &&
  exec bigwolf2000-config
}

do_update_bigwolf2000() {
  cd /root/
  rm -r bigwolf2000-tools/ &&
  git clone https://github.com/Wolf2000Pi/bigwolf2000-tools.git &&
  cd /root/bigwolf2000-tools &&
  chmod +x bigwolf2000-config.sh omv-install-6.x.sh backup.sh &&
  cd /usr/bin/ &&
  rm -r omv-install-6.x.sh bigwolf2000-config &&
  cp /root/bigwolf2000-tools/bigwolf2000-config.sh /usr/bin/bigwolf2000-config &&
  cp /root/bigwolf2000-tools/omv-install-6.x.sh /usr/bin &&
  cd &&
  exec bigwolf2000-config
}
do_finish() {
#	  disable_raspi_config_at_boot
  if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Would you like to reboot now?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      reboot
    fi
  fi
  exit 0
}
do_deinstall() {
  ./deinstall-bigwolf2000-tools.sh &&
  printf "Einen Moment ich starte in 1Sek Bigwolf2000-config\n" &&
  sleep 1 &&
  exec bigwolf2000-config
}
#
# Interactive use loop
#
calc_wt_size
while true; do
  FUN=$(whiptail --title "Server Software Configuration Tool Bigwolf2000 Version 1.5.5" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Beenden --ok-button Wählen \
    "1 Docker" "Löschen, usw." \
	"2 Change User Password      " "Root Password ändern" \
    "3 Grund-optionen            " "Sprache-Zeit-Tastatur " \
    "4 Erweiterte Optionen       " "Hostname SSH " \
	"5 System Update             " "Update und upgrade" \
    "6 Openmediavault            " "Installation mit Plugins" \
	"7 Update                    " "Bigwolf2000-Tools Updaten" \
	"8 About Bigwolf2000         " "Bitte Lesen" \
	"9 Bigwolf2000 Tool          " "Deinstallieren" \
	3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_finish
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      1\ *) do_docker_menu ;;
	  2\ *) do_change_pass ;;
      3\ *) do_internationalisation_menu ;;
      4\ *) do_advanced_menu ;;
      5\ *) do_update ;; 	  
	  6\ *) do_Openmediavault_menu ;;
	  7\ *) do_update_bigwolf2000 ;;
	  8\ *) do_about ;;
	  9\ *) do_deinstall ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  else
    exit 1
  fi
done 
}