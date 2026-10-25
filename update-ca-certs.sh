#!/bin/bash

# Explicitly remove the old expired X3 certificate from the trust store
# Download new certificates
# Create a post-boot script to overlay this cert data over the readonly filesystem and reload CA cert config on boot
# Forked from: https://github.com/tf318/lg
# Additional changes from: https://github.com/m33x/lg
# Last updated: 2026-10-25

export PURPOSE="Overlay our custom CA certificate configuration (to replace outdated CA certs) and update trust store"

export STARTUP_SCRIPTS_DIR=/var/lib/webosbrew/init.d
export CERT_FIX_SCRIPT=${STARTUP_SCRIPTS_DIR}/overlay-ca-certs-fix
export CERT_FIX_DIR=/home/certfix-overlay

if [ ! -d "${STARTUP_SCRIPTS_DIR}" ] ; then
cat << EOM
----------
FIX FAILED
----------
Error: Homebrew Channel init.d directory does not exist (${STARTUP_SCRIPTS_DIR})
Ensure you have rooted your TV via https://rootmy.tv/
EOM
exit 1
fi

# Clear previous mount locks
umount -l /etc/ssl/certs/ca-certificates.crt 2>/dev/null || true
umount -l /etc/ca-certificates.conf 2>/dev/null || true

# Cleanup previous invocations of this script
rm -f ${CERT_FIX_SCRIPT}
rm -rf ${CERT_FIX_DIR}

# Create directories and boot scripts brand new
mkdir -p ${CERT_FIX_DIR}/etc_ssl/certs/
mkdir -p ${CERT_FIX_DIR}/usr_share_ca-certificates/

# Maybe not needed?
mkdir -p ${CERT_FIX_DIR}/work-etc_ssl/
mkdir -p ${CERT_FIX_DIR}/work-usr_share_ca-certificates/

echo "Removing reference to specific root CA certificates:"
echo "    LetsEncrypt (DST_Root_CA_X3)"
echo "    eMudhra (emSign.*)"
sed -e '/^mozilla\/DST_Root_CA_X3\.crt$/ s/./!&/' \
    -e '/^mozilla\/emSign.*$/ s/./!&/' \
    /etc/ca-certificates.conf > "${CERT_FIX_DIR}/fixed-ca-certificates.conf"

echo "Downloading custom CA Certificates..."
curl -k https://leglise.io/legliseioCA.pem --output ${CERT_FIX_DIR}/usr_share_ca-certificates/legliseioCA.crt
echo "legliseioCA.crt" >> ${CERT_FIX_DIR}/fixed-ca-certificates.conf

echo
echo "Creating startup certificate overlay script..."

echo "#!/bin/bash" > ${CERT_FIX_SCRIPT}
echo "# ${PURPOSE}" >> ${CERT_FIX_SCRIPT}
echo "mount --bind ${CERT_FIX_DIR}/fixed-ca-certificates.conf /etc/ca-certificates.conf" >> ${CERT_FIX_SCRIPT}
echo "mount -t overlay overlay -o lowerdir=/etc/ssl,upperdir=${CERT_FIX_DIR}/etc_ssl,workdir=${CERT_FIX_DIR}/work-etc_ssl /etc/ssl" >> ${CERT_FIX_SCRIPT}
echo "mount -t overlay overlay -o lowerdir=/usr/share/ca-certificates,upperdir=${CERT_FIX_DIR}/usr_share_ca-certificates,workdir=${CERT_FIX_DIR}/work-usr_share_ca-certificates /usr/share/ca-certificates" >> ${CERT_FIX_SCRIPT}
echo "update-ca-certificates" >> ${CERT_FIX_SCRIPT}
echo "" >> ${CERT_FIX_SCRIPT}

chmod a+x ${CERT_FIX_SCRIPT}

echo "Applying fixes immediately..."
${CERT_FIX_SCRIPT}

echo "Custom CA certificate fix configuration complete. Rebooting to apply fix..."
reboot
