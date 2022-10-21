#!/bin/sh
# Part of Wolf2000-Tools https://github.com/Wolf2000Pi/bigwolf2000-tools
# Version 2.8.0
# by Wolf2000
do_version() {
cat /root/bigwolf2000-tools/Version
}


calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error 
  # output from tput. However in this case, tput detects neither stdout or 
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=21
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

#ssh
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


# Grund-Menue
do_Grund_optionen_menu() {
  FUN=$(whiptail --title "Server Software Configuration Tool Bigwolf2000 Version 2.8.0" --menu "Grund-optionen" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Zurück --ok-button Wählen \
    "I1 Change Locale               " "Wo bist Du zu Hause" \
    "I2 Change Timezone             " "Meine Uhr geht nach der Wiener Wasserleitungen" \
    "I3 Change Keyboard Layout      " "Tastatur-Einstellungen" \
	"I4 Tasksel                     " "Werkzeug um Pakete zu installieren" \
	"I5 Backup                      " "Captain OMV-xml root Docker" \
	"I6 Crontab                     " "Crontab" \
	"I7 Arbeitsspeiche              " "Bereinigen" \
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
	  I6\ *) do_crontab ;;
	  I7\ *) do_drop_caches ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}
#tasksel
do_tasksel() {
  cd /root/
  if tasksel; then
    return 1
  fi 
  exec bigwolf2000-config
}
#crontab
do_crontab() {
  cd /root/ &&
  if crontab -e; then
    return 0
  fi 
}
#cache löschen
do_drop_caches() {
  cd /root/ &&
  sync; echo 3 > /proc/sys/vm/drop_caches &&
  exec bigwolf2000-config  
}
#Backup
  do_backup() {
  cd /root/bigwolf2000-tools/ &&
  chmod +x backup.sh &&
  ./backup.sh
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
#Openmediavault
do_Openmediavault_menu() {
  FUN=$(whiptail --title "Server Software Configuration Tool Bigwolf2000 Version 2.8.0" --menu "Openmediavault Optionen" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Zurück --ok-button Wählen \
	"O1 Openmediavault Version 6      "     "Installation Unter Debian bullseye" \
    "O2 Openmediavault Plugins        "     "OMV-Extras" \
	"O3 omv-firstaid                  "     "Config-Tool für OMV" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      O1\ *) do_omv6 ;;
      O2\ *) do_omv_plugins ;;
	  O3\ *) do_omv_firstaid ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}
# OMV6
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
do_omv_firstaid() {
  cd /root/
  if omv-firstaid; then	
    return 0
  fi 
}
do_omv_plugins() {
apt-get update &&
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install | bash &&  
exec bigwolf2000-config
}
#Programme
do_programme_menu() {
  FUN=$(whiptail --title "Server Software Configuration Tool Bigwolf2000 Version 2.8.0" --menu "Programme installieren" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Zurück --ok-button Wählen \
	"P1 Cockpit                    "    "installieren, u.s.w" \
	"P2 Net-Tools                  "    "installieren, u.s.w" \
	"P3 lm-sensors                 "    "installieren, u.s.w" \
	"P4 Midnight Commander         "    "installieren, u.s.w" \
	"P5 Deborphan             "    "installieren, u.s.w" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      P1\ *) do_cockpit_menu ;;
	  P2\ *) do_net_tools_menu ;;
	  P3\ *) do_lm_menu ;;
	  P4\ *) do_mc_menu ;;
	  P5\ *) do_debor_menu ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}
#cockpit
do_cockpit_menu() {
  FUN=$(whiptail --title "Cockpit" --menu "Bitte wählen sie aus" 9 40 2 --cancel-button Zurück --ok-button Wählen \
	 "PC1 Installieren  " "" \
	 "PC2 Deinstallieren" "" \
     3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      PC1\ *) do_cockpit ;;
	  PC2\ *) do_cockpit_purge ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}
do_cockpit_purge() {
  apt -y purge cockpit &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}  
  

do_cockpit() {
  echo "deb http://deb.debian.org/debian bullseye-backports main contrib non-free" | sudo tee -a /etc/apt/sources.list &&
  echo "deb-src http://deb.debian.org/debian bullseye-backports main contrib non-free" | sudo tee -a /etc/apt/sources.list &&
  apt update &&
  apt install cockpit cockpit-bridge cockpit-networkmanager cockpit-packagekit cockpit-pcp cockpit-podman cockpit-storaged cockpit-system cockpit-ws &&
  systemctl enable --now cockpit.socket &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
#net_tools
do_net_tools() {
  apt install net-tools &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
do_net_tools_menu() {
  FUN=$(whiptail --title "Net-Tools" --menu "Bitte wählen sie aus" 9 40 2 --cancel-button Zurück --ok-button Wählen \
	 "PN1 Installieren  " "" \
	 "PN2 Deinstallieren" "" \
     3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      PN1\ *) do_net_tools ;;
	  PN2\ *) do_net_tools_purge ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}
do_net_tools_purge() {
  apt -y purge net-tools &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
#lm_sensors  
do_lm_sensors() {
  apt install lm-sensors &&
  sensors-detect &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
do_lm_menu() {
  FUN=$(whiptail --title "Lm-Sensors" --menu "Bitte wählen sie aus" 10 35 3 --cancel-button Zurück --ok-button Wählen \
	 "PL1 Installieren  " "" \
	 "PL2 Deinstallieren" "" \
	 "PL3 Sensors-Detect" "" \
     3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      PL1\ *) do_lm_sensors ;;
	  PL2\ *) do_lm_purge ;;
	  PL3\ *) do_open_lm ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "Lm-Sensors ist nicht installiert!                      $FUN" 20 60 1
  fi
}
do_open_lm() {
  sensors-detect &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
do_lm_purge() {
  apt -y purge lm-sensors &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
#Midnight Commander
do_mc() {
  apt install mc --yes &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
do_mc_menu() {
  FUN=$(whiptail --title "Midnight Commander" --menu "Bitte wählen sie aus" 10 35 3 --cancel-button Zurück --ok-button Wählen \
	 "PM1 Installieren  " "" \
	 "PM2 Deinstallieren" "" \
	 "PM3 öffnen" "" \
     3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      PM1\ *) do_mc ;;
	  PM2\ *) do_mc_purge ;;
	  PM3\ *) do_open_mc ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "Midnight Commander ist nicht installiert!                      $FUN" 20 60 1
  fi
}
do_open_mc() {
  mc &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
do_mc_purge() {
  apt -y purge mc &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
#Deborphan
do_debor_menu() {
  FUN=$(whiptail --title "Deborphan" --menu "Bitte wählen sie aus" 10 35 3 --cancel-button Zurück --ok-button Wählen \
	 "PM1 Installieren  " "" \
	 "PM2 Deinstallieren" "" \
	 "PM3 öffnen" "" \
     3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      PM1\ *) do_debor ;;
	  PM2\ *) do_debor_purge ;;
	  PM3\ *) do_open_debor ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "Midnight Commander ist nicht installiert!                      $FUN" 20 60 1
  fi
}
o_debor() {
  apt install deborphan --yes &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
do_open_debor() {
  orphaner&&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
do_mc_debor() {
  apt -y purge deborphan &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
#Docker
do_docker_menu() {
  FUN=$(whiptail --title "Server Software Configuration Tool Bigwolf2000 Version 2.8.0" --menu "Docker Optionen" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Zurück \
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
	  D3\ *) do_docker_ctop_menu ;;
	  D4\ *) do_offi_example ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}
do_docker_purge() {
  docker system prune -a && docker image prune && 
#  docker volume prune &&
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
# Ctop
  do_docker_ctop() {
  echo "deb http://packages.azlux.fr/debian/ buster main" | sudo tee /etc/apt/sources.list.d/azlux.list &&
  wget -qO - https://azlux.fr/repo.gpg.key | sudo apt-key add -
  apt update &&
  apt install docker-ctop &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
do_docker_ctop_menu() {
  FUN=$(whiptail --title "Docker-Ctop" --menu "Bitte wählen sie aus" 10 35 3 --cancel-button Zurück --ok-button Wählen \
	 "DC1 Installieren  " "" \
	 "DC2 Deinstallieren" "" \
	 "DC3 öffnen" "" \
     3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      DC1\ *) do_docker_ctop ;;
	  DC2\ *) do_purge_ctop ;;
	  DC3\ *) do_open_ctop ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "Docker-Ctop ist nicht installiert!                            $FUN" 20 60 1
  fi
}
do_open_ctop() {
  ctop &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}
do_purge_ctop() {
  apt -y purge docker-ctop &&
  rm -r /etc/apt/sources.list.d/azlux.list &&
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}  
#Onlyofficer  
do_offi_example() {
  docker exec $(docker ps -l -q --filter "name=srv-captain--offi.1") supervisorctl start ds:example &&
  docker exec $(docker ps -l -q --filter "name=srv-captain--offi.1") sed 's,autostart=false,autostart=true,' -i /etc/supervisor/conf.d/ds-example.conf
  printf "Einen Moment ich starte in 10Sek Bigwolf2000-config\n" &&
  sleep 10 &&
  exec bigwolf2000-config
}  

#Advanced
do_advanced_menu() {
  FUN=$(whiptail --title "Server Software Configuration Tool Bigwolf2000 Version 2.8.0" --menu "Advanced Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Zurück \
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
#Reboot
do_reboot() {
  /sbin/reboot
  printf "Einen Moment ich starte in 1Sek Bigwolf2000-config\n" &&
  sleep 1 &&
  exec bigwolf2000-config
}
#Update
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
#  if [ $ASK_TO_REBOOT -eq 1 ]; then
#    whiptail --yesno "Would you like to reboot now?" 20 60 2
#    if [ $? -eq 0 ]; then # yes
#      sync
#      reboot
#    fi
#  fi
  exit 0
}
do_deinstall() {
  ./deinstall-bigwolf2000-tools.sh &&
   exit 0
}
#
# Interactive use loop
# Hauptmenue
calc_wt_size
while true; do
  FUN=$(whiptail --title "Server Software Configuration Tool Bigwolf2000 Version 2.8.0" --menu "Setup Options"  $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Beenden --ok-button Wählen \
    "1 Docker                    " "Löschen, usw." \
	"2 Change User Password      " "Root Password ändern" \
    "3 Grund-optionen            " "Sprache-Zeit-Tastatur Tasksel Backup " \
    "4 Erweiterte Optionen       " "Hostname SSH " \
	"5 System Update             " "Update und upgrade" \
    "6 Div.Programme             " "Programme" \
	"7 Openmediavault            " "Installation mit Plugins" \
	"8 Update                    " "Bigwolf2000-Tools Updaten" \
	"9 About Bigwolf2000         " "Bitte Lesen" \
	"10 Bigwolf2000 Tool         " "Deinstallieren" \
	"11 Reboot                   " "Reboot System" \
	3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    do_finish
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      1\ *) do_docker_menu ;;
	  2\ *) do_change_pass ;;
      3\ *) do_Grund_optionen_menu ;;
      4\ *) do_advanced_menu ;;
      5\ *) do_update ;; 	  
	  6\ *) do_programme_menu ;;
	  7\ *) do_Openmediavault_menu ;;
	  8\ *) do_update_bigwolf2000 ;;
	  9\ *) do_about ;;
	  10\ *) do_deinstall ;;
	  11\ *) do_reboot ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  else
    exit 1
  fi
done
}