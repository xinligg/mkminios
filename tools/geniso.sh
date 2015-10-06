#!/bin/sh

mkisofs -R -l -V 'StarOS' -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../staros-3.0.0.1.iso .
