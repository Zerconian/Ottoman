# Ottoman installer kickstart for the netinstall ISO (scripts/make-netinst-iso.sh fills @IMAGE_REF@).
# Same shape as the kickstart bootc-image-builder generates for the offline ISO, with the image pulled from the
# public registry during the install instead of read from the ISO. Unattended: every answer is here.
ostreecontainer --url=@IMAGE_REF@ --transport=registry --no-signature-verification
rootpw --lock
lang en_US.UTF-8
keyboard us
timezone UTC
clearpart --all
autopart --nohome --type=plain --fstype=xfs
network --device=link --bootproto=dhcp --onboot=on --activate
%post --erroronfail
set -e
# the installed system updates from the same reference it was installed from
bootc switch --mutate-in-place --transport registry @IMAGE_REF@
# finished marker for automated installs (scripts/test-install.sh watches the serial console)
if [ -c /dev/ttyS0 ]; then echo "Install finished" > /dev/ttyS0 || true; fi
%end
reboot --eject
