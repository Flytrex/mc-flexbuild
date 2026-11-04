#! /bin/bash
set -e

#block ssh on all other interfaces
ip_addr="10.78.10.1"
iptables -A INPUT -p tcp --dport 22 -j DROP

modprobe libcomposite
mkdir -p /sys/kernel/config/usb_gadget/g1
cd /sys/kernel/config/usb_gadget/g1

serial="$(cat /sys/bus/soc/devices/soc0/serial_number)"
mac_base="$(echo "${serial}" | head -c 10)"
ncm_mac_address_dev="02${mac_base}"
ncm_mac_address_host="12${mac_base}"


echo 0x0200 > bcdUSB
echo "0x0525" > idVendor # NetChip
echo "0xa4a1" > idProduct # Linux-USB Ethernet Gadget
echo "0xEF" > bDeviceClass # Multi-interface Function
echo "0x02" > bDeviceSubClass # USB Common Sub Class 2
echo "0x01" > bDeviceProtocol # USB IAD Protocol 1
echo "0x4000" > bcdDevice # Device version, should be incremented on each breaking change

# Textual representation of the device
mkdir -p strings/0x409
echo "${serial}" > strings/0x409/serialnumber
echo "Flytrex" > strings/0x409/manufacturer
echo "EMC" > strings/0x409/product

mkdir -p functions/ncm.usb0

mkdir -p configs/c.1/strings/0x409
echo "CDC Network Control Model (NCM)" > configs/c.1/strings/0x409/configuration
echo "${ncm_mac_address_host}" > functions/ncm.usb0/host_addr
echo "${ncm_mac_address_dev}" > functions/ncm.usb0/dev_addr
ln -s functions/ncm.usb0 configs/c.1
echo 0xC0 > configs/c.1/bmAttributes # self powered
echo 250 > configs/c.1/MaxPower

# Wait until device is loaded
udevadm settle -t 5 || true
ls /sys/class/udc > UDC
sleep 1

ip a add ${ip_addr}/255.255.255.0 dev usb0
ip link set dev usb0 up
iptables -I INPUT -p tcp -i usb0 --dport 22 -j ACCEPT
