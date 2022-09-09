#!/bin/sh

#Configuring Automated tasks
echo "  Configuring Automated Tasks ..."

#Setup crond
echo "   Installing cronie ..."
sudo tdnf install -y cronie > /dev/null 2>&1
sudo systemctl enable --now crond > /dev/null 2>&1

#Create OS Patching Shell Script
echo "   Creating OS Patching Shell Script ..."
cat > /etc/cron.hourly/ospatch.sh <<EOL
#!/bin/sh

tdnf update -y photon-repos
tdnf update -y
tdnf update -y --security
EOL
chmod +x /etc/cron.hourly/ospatch.sh > /dev/null 2>&1

#Create Crontab scheduled event to run script
echo "   Creating Crontab scheduled event for OS Patching ..."
sudo crontab -l > cron_bkp
sudo echo "0 * * * * sudo /etc/cron.hourly/ospatch.sh >/dev/null 2>&1" >> cron_bkp
sudo crontab cron_bkp
sudo rm cron_bkp

