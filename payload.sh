#!/bin/bash


##
# Color  Variables
##

green='\e[32m'
blue='\e[34m'
red='\e[31m'
magenta='\e[35m'
clear='\e[0m'

##
# Color Functions
##

ColorGreen(){
	echo -ne $green$1$clear
}

ColorRed(){
	echo -ne $red$1$clear
}

ColorMagenta(){
	echo -ne $magenta$1$clear
}

ColorBlue(){
	echo -ne $blue$1$clear
}

##
# Functions start here
##

function setup_dependancies() {
    # Creating Loot Directory
if [ ! -d "Loot" ]; then
  echo "Creating Loot Directory"
  mkdir Loot
else
  echo "Loot Directory already exists"
fi

# Creating Scan Directory

if [ ! -d "Scan" ]; then
  echo "Creating Scan Directory"
  sleep 1
  mkdir Scan
  touch Scan/targetdomains.txt
  touch Scan/scanned.txt
  touch Scan/targetips.txt
else
  echo "Scan Directory already exists"
fi

# Clone the SecLists repository to the /usr/share/wordlists directory

if [ ! -d "/usr/share/wordlists/secLists" ]; then
    echo "Cloning SecLists repository..."
    git clone https://github.com/danielmiessler/SecLists.git /usr/share/wordlists/secLists
else
    echo "SecLists repository already exists."
fi
}

function init_msf() {
    # Loading metapsloit and importing the data
    echo "Starting msfdb init..."
    msfdb init
}

function import_msf(){
    # Import to Metasploit
msfconsole -x "db_import Loot/$TARGET.xml"
}

function targetinfo(){
    # Ask user for target information
echo -n "Please enter target Domain:"
read TARGET

#echo -n "Please enter external target IP Address:"
#read TARGETIP
}

function domain_enum(){
    # Updating target history
    echo "$TARGET" | sudo tee -a Scan/targetdomains.txt
    echo "Running gobuster ..."
    sleep 2
    sudo gobuster dns -q -r 8.8.8.8 -d $TARGET -w /usr/share/wordlists/secLists/Discovery/DNS/subdomains-top1million-5000.txt -o Loot/$TARGET.txt

echo "Removing 'Found: ' from Loot/$TARGET.txt... "
sed -i 's/Found: //g' Loot/$TARGET.txt

# Updating scan history log file
cat Loot/$TARGET.txt | sudo tee -a Scan/scanned.txt
}

function strict_dir_enum(){
# Enumerate directories automatically for all subdomains - STRICT on what pass'
echo "Enumerating Strict directories for $TARGET..."
cat Loot/$TARGET.txt | while read subdomain
do
    sudo gobuster dir -u $subdomain -w /usr/share/wordlists/secLists/Discovery/Web-Content/directory-list-2.3-medium.txt -k -b "307,401,403,404" --timeout 10m -o Loot/strict_$subdomain.txt
done
}

function ip_enum(){
    # Updating target history
    echo "$TARGETIP" | sudo tee -a Scan/targetips.txt
    echo "Running gobuster ..."
    sleep 2
    sudo gobuster dns -q -r 8.8.8.8 -d $TARGETIP -w /usr/share/wordlists/secLists/Discovery/DNS/subdomains-top1million-5000.txt -o Loot/$TARGET.txt

echo "Removing 'Found: ' from Loot/$TARGETIP.txt... "
sed -i 's/Found: //g' Loot/$TARGETIP.txt

# Updating scan history log file
echo "$TARGET" | sudo tee -a Loot/$TARGET.txt 
cat Loot/$TARGET.txt | sudo tee -a Scan/scanned.txt
}

function dir_enum(){
# Enumerate directories automatically for all subdomains
echo "Enumerating directories for $TARGET..."
cat Loot/$TARGET.txt | while read subdomain
do
    sudo gobuster dir -u $subdomain -w /usr/share/wordlists/secLists/Discovery/Web-Content/directory-list-2.3-medium.txt -o Loot/$subdomain.txt
done
}

function vulnscan_nmap(){
# Run vulnerability scan
echo "Scanning $TARGET for vulnerabilities..."
nmap -Pn -sV --script vuln --max-retries 3 --host-timeout 15m --script-timeout 10m -iL Loot/$TARGET.txt -oX Loot/$TARGET.xml
xsltproc ./Loot/$TARGET.xml -o ./Loot/$TARGET.html
}

##
# Sn1per Intergration functions are located here
##

function sniper_setup() {
    # Clone the SecLists repository to the /usr/share/wordlists directory
if [ ! -d "/sniper" ]; then
    echo "Installing Sniper from https://github.com/1N3/Sn1per"
    git clone https://github.com/1N3/Sn1per
    cd Sn1per
	chmod +x install.sh
    # Installing Sn1per
    bash install.sh
        echo "Setting CRONTAB schedules..."
    # min hour dom mon dow command
    echo '0 18 * * * find /usr/share/sniper/loot/workspace/ -type f -name "daily.sh" -exec bash {} \;' | sudo tee -a /etc/crontab 
    echo '0 2 * * 6 find /usr/share/sniper/loot/workspace/ -type f -name "weekly.sh" -exec bash {} \;' | sudo tee -a /etc/crontab 
    echo '0 23 1 * * find /usr/share/sniper/loot/workspace/ -type f -name "monthly.sh" -exec bash {} \;' | sudo tee -a /etc/crontab 
else
    echo "Sniper repository already exists"
fi
}

##
# Sn1per Functionality for the sub menu
##

function sn1per_workspace(){
    echo "Listing Available Sniper workspaces now..."
    sudo sniper --list
    sleep 2
    echo -n "Enter the name of an existing or new Workspace: "
    read WORKSPACE
}

function sn1per_full_port_scan(){
    echo "Running a port scan against $TARGET"
cat Loot/$TARGET.txt | while read septarget
do
    sudo sniper -t $septarget -w $WORKSPACE
done
    
}

function sn1per_discovery(){
    sudo sniper -t $TARGET -m discover -w $WORKSPACE
}

function sn1per_flyby(){
        sudo sniper -f /usr/share/sniper/loot/workspace/$WORKSPACE/domains/domains-all-sorted.txt -m flyover -w $WORKSPACE
}
function sn1per_subdomain_update(){
    cat Loot/$TARGET.txt | sudo tee -a /usr/share/sniper/loot/workspace/$WORKSPACE/domains/domains-all-sorted.txt
    cat /usr/share/sniper/loot/workspace/$WORKSPACE/ips/discover-$TARGET-sorted.txt | sudo tee -a /usr/share/sniper/loot/workspace/$WORKSPACE/domains/domains-all-sorted.txt
}

function sn1per_mass_web_scan(){
    sudo sniper -f /usr/share/sniper/loot/workspace/$WORKSPACE/domains/domains-all-sorted.txt -m masswebscan -w $WORKSPACE
}

function sn1per_mass_vuln_scan(){
    sudo sniper -f /usr/share/sniper/loot/workspace/$WORKSPACE/domains/domains-all-sorted.txt -m massvulnscan -w $WORKSPACE
}

function sn1per_nuke(){
    sudo sniper -f /usr/share/sniper/loot/workspace/$WORKSPACE/domains/domains-all-sorted.txt -m nuke -w $WORKSPACE
}

function sn1per_to_nmap(){
    nmap -Pn -sV --script vuln --max-retries 3 --host-timeout 15m --script-timeout 10m -iL /usr/share/sniper/loot/workspace/$WORKSPACE/domains/domains-all-sorted.txt -oX /usr/share/sniper/loot/workspace/$WORKSPACE/nmap/$TARGET.xml
}

function sn1per_to_metasploit(){
    msfconsole -x "db_import /usr/share/sniper/loot/workspace/$WORKSPACE/nmap/$TARGET.xml"
}

function sn1per_schedule_help(){
echo 'Select when you would like to schedule the scan. 
Just add the full sniper commands you want to run on a schedule (ie. sniper -t 127.0.0.1 -w 127.0.0.1) and save. That’s it!
For more information around sniper commands, start a new terminal windown and type * sudo sniper -h *'
sleep 5
}

function sn1per_schedule_daily(){
    sudo sniper -w $WORKSPACE -s daily
    
}

function sn1per_schedule_weekly(){
    sudo sniper -w $WORKSPACE -s weekly
}

function sn1per_schedule_monthly(){
    sudo sniper -w $WORKSPACE -s monthly
}

function sn1per_scheduled_mass_web_scan(){
    echo "sudo sniper -f /usr/share/sniper/loot/workspace/$WORKSPACE/domains/domains-all-sorted.txt -m masswebscan -w $WORKSPACE" | sudo tee -a /usr/share/sniper/loot/workspace/$WORKSPACE/scans/scheduled/$OPTION.sh
}

function sn1per_scheduled_mass_vuln_scan(){
    echo "sudo sniper -f /usr/share/sniper/loot/workspace/$WORKSPACE/domains/domains-all-sorted.txt -m massvulnscan -w $WORKSPACE" | sudo tee -a /usr/share/sniper/loot/workspace/$WORKSPACE/scans/scheduled/$OPTION.sh
}

function sn1per_scheduled_nuke(){
    echo "sudo sniper -f /usr/share/sniper/loot/workspace/$WORKSPACE/domains/domains-all-sorted.txt -m nuke -w $WORKSPACE" | sudo tee -a /usr/share/sniper/loot/workspace/$WORKSPACE/scans/scheduled/$OPTION.sh
}

function sn1per_scheduled_to_nmap(){
    echo "nmap -Pn -sV --script vuln --max-retries 3 --host-timeout 15m --script-timeout 10m -iL /usr/share/sniper/loot/workspace/$WORKSPACE/domains/domains-all-sorted.txt -oX /usr/share/sniper/loot/workspace/$WORKSPACE/nmap/$TARGET.xml" | sudo tee -a /usr/share/sniper/loot/workspace/$WORKSPACE/scans/scheduled/$OPTION.sh
}

function scanoption(){
    # Ask user for scan options
echo "Please type what type of scan you want to schedule"
echo -n "daily | weekly | monthly"
read OPTION
}

function scanviewoption(){
    # Ask user for scan options
echo "Please type what type of schedule you want view for $WORKSPACE"
echo -n "daily | weekly | monthly"
read OPTION2
sleep 2
sudo nano /usr/share/sniper/loot/workspace/$WORKSPACE/scans/scheduled/$OPTION2.sh
}

##
# Interactive Menu starts here :)
##

menu(){
echo -ne "
~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~
~#*#~  $(ColorRed 'Unit98 Guided Vulnerability Assessment tool')  ~#*#~
~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~

$(ColorBlue 'Current Target: ')$(ColorRed $TARGET)

$(ColorBlue '                  ~#*#~ Staging ~#*#~')

$(ColorBlue '00') $(ColorRed 'Lazy') $(ColorMagenta 'Mode')
$(ColorRed '1)') Setup dependancies
$(ColorRed '2)') Install Sniper 
$(ColorRed '3)') Initialise Metasploit database
$(ColorMagenta '4)') Set Target Information

$(ColorRed '                  ~#*#~ Attack ~#*#~')

$(ColorGreen '5)') Sub-Domain Enumeration
$(ColorGreen '6)') Strict Directory Enumeration
$(ColorGreen '7)') Directory Enumeration
$(ColorBlue '8)') Vulnerability Scan using Nmap
$(ColorRed '9)') Vulnerability Scan with Sn1per

$(ColorMagenta '                  ~#*#~ Reporting ~#*#~')

$(ColorBlue '10)') Import into Metasploit 
$(ColorRed '0)') Exit

$(ColorBlue 'Choose an option:') "
        read a
        case $a in
	        00) echo "Lazy Mode Activated!" ; setup_dependancies ; sniper_setup ; init_msf ; clear ; targetinfo ; clear ; domain_enum ; clear ; sn1per_workspace ; clear ; sn1per_menu ;;
	        1) clear ; setup_dependancies ; menu ;;
	        2) clear ; sniper_setup ; menu ;;
	        3) clear ; init_msf ; menu ;;
	        4) targetinfo ; clear ; menu ;;
	        5) clear ; domain_enum; menu ;;
	        6) clear ; strict_dir_enum ; menu ;;
	        7) clear ; dir_enum ; menu ;;
	        8) clear ; vulnscan_nmap ; menu ;;
	        9) clear ; sn1per_menu ; menu ;;
	        10) clear ; import_msf ; menu ;;
			0) exit 0 ;;
			*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

##
# Sn1per Optional scanning menu
##

sn1per_menu(){
echo -ne "
~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~
~#*#~  $(ColorRed 'Unit98 Guided Vulnerability Assessment tool')  ~#*#~
~#*#~          Sn1per Configuration options         ~#*#~
~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~

$(ColorRed '*  Please start by selecting a workspace *')
$(ColorBlue 'Current Target: ')$(ColorRed $TARGET)
$(ColorBlue 'Current Workspace: ')$(ColorRed $WORKSPACE)

$(ColorBlue '                  ~#*#~ Staging ~#*#~')

$(ColorRed '00)') List Workspaces & Select a Workspace
$(ColorRed '01)') Perform Discovery on $TARGET
$(ColorRed '                  ~#*#~ Attack ~#*#~')

$(ColorMagenta '1)') Schedule a scan (Daily|Weekly|Monthly)
$(ColorGreen '2)') Mass Web Scan
$(ColorGreen '3)') Mass Vulnerability Scan
$(ColorRed '4)') NUKE MODE: USE WITH CAUTION & AUTHORISATION!!
$(ColorGreen '5)') Pass Sn1per domains to NMAP for vuln scan

$(ColorMagenta '                  ~#*#~ Reporting ~#*#~')

$(ColorMagenta '6)') Export NMAP Scan results to Metasploit
$(ColorGreen '7)') Back to main menu
$(ColorRed '0)') Exit

$(ColorBlue 'Choose an option:') "
        read b
        case $b in
	        00) sn1per_workspace ; clear ; sn1per_menu ;;
	        01) sn1per_discovery ; domain_enum ; sn1per_subdomain_update ; sn1per_flyby ; sn1per_menu ;;
	        1) clear ; sn1per_schedule_menu ;;
	        2) clear ; sn1per_mass_web_scan ; sn1per_menu ;;
	        3) clear ; sn1per_mass_vuln_scan ; sn1per_menu ;;
	        4) clear ; sn1per_nuke ; sn1per_menu ;;
	        5) clear ; sn1per_to_nmap ; sn1per_menu ;;
	        6) clear ; sn1per_to_metasploit ; menu;;
	        7) menu ;;
			0) exit 0 ;;
			*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

sn1per_schedule_menu(){
echo -ne "
~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~
~#*#~  $(ColorRed 'Unit98 Guided Vulnerability Assessment tool')  ~#*#~
~#*#~          Sn1per Scheduled Scan Options        ~#*#~
~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~

$(ColorBlue 'Current Target: ')$(ColorRed $TARGET)
$(ColorBlue 'Current Workspace: ')$(ColorRed $WORKSPACE)

$(ColorRed '*  Scheduling a scan will require knowledge of Sn1per!  *')
$(ColorBlue 'For more information read this help file')
$(ColorRed '00)') Help with Sn1per scheduled commands

$(ColorRed '           ~#*#~ Schedule Assistant ~#*#~')

$(ColorMagenta '1)') Choose your schedule
$(ColorMagenta '2)') View current schedules
$(ColorRed '3)') List & Change Workspaces
$(ColorGreen '5)') Back to main menu
$(ColorRed '0)') Exit

$(ColorBlue 'Choose an option:') "
        read c
        case $c in
	        00) sn1per_schedule_help ; sn1per_menu ;;
	        1) scanoption ; clear ; sn1per_schedule_module_menu ;;
	        2) scanviewoption ; clear ; sn1per_schedule_menu ;;
	        3) clear ; sniper_workspace ; sn1per_schedule_menu ;;
	        4) clear ; sn1per_menu ;;
			0) exit 0 ;;
			*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}

sn1per_schedule_module_menu(){
echo -ne "
~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~
~#*#~  $(ColorRed 'Unit98 Guided Vulnerability Assessment tool')  ~#*#~
~#*#~          Sn1per Scheduled Scan Options        ~#*#~
~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~#*#~

$(ColorBlue 'Current Target: ')$(ColorRed $WORKSPACE)
$(ColorBlue 'Current Workspace: ')$(ColorRed $WORKSPACE)
$(ColorBlue 'Current Schedule: ')$(ColorRed $OPTION)$(ColorRed '.sh')

$(ColorRed '           ~#*#~ Schedule Assistant ~#*#~')

$(ColorRed '*  Choose what type of scan you want to schedule:  *')

$(ColorBlue '1)') Mass Web Scan
$(ColorBlue '2)') Mass Vulnerability Scan
$(ColorRed '3)') NMAP Vulnerability Scan
$(ColorGreen '4)') NUKE MODE
$(ColorGreen '5)') Back
$(ColorRed '0)') Exit

$(ColorBlue 'Choose an option:') "
        read d
        case $d in
	        1) sn1per_scheduled_mass_web_scan ; clear ; sn1per_schedule_menu ;;
	        2) sn1per_scheduled_mass_vuln_scan ; clear ;sn1per_schedule_menu ;;
	        3) sn1per_scheduled_to_nmap ; clear ; sn1per_schedule_menu ;;
	        4) sniper_scheduled_nuke ; clear ; sn1per_schedule_menu ;;
	        5) clear ; sn1per_schedule_menu ;;
			0) exit 0 ;;
			*) echo -e $red"Wrong option."$clear; WrongCommand;;
        esac
}


# Call the menu function
menu
