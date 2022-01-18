DISK=1
SIZE=10G
DEVICE='sdc'
for vm in $(sudo virsh list --name); do
  if echo $vm | grep -q master; then
    echo $vm is a master
    sudo qemu-img create -f raw /var/lib/libvirt/images/$vm-extra-disk-${DISK_INDEX}.img ${SIZE}
    sudo virsh attach-disk $vm /var/lib/libvirt/images/$vm-extra-disk-${DISK_INDEX}.img ${DEVICE}
  fi
done