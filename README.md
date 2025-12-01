# netbox-offline

On the online server

cd /opt/netbox

pip download --dest wheelhouse -r local_requirements.txt

pip download --dest wheelhouse -r base_requirements.txt

pip download --dest wheelhouse -r requirements.txt





cd /opt/netbox

nano local_requirements.txt 

scp -r pwli@sftp.management.local:/FTPData-TEMP/PWLI/wheelhouse/* /opt/netbox/wheelhouse/

sudo systemctl restart netbox netbox-rq

chown -R netbox:netbox /opt/netbox

PYTHON=python3.11 ./upgrade_offline.sh

