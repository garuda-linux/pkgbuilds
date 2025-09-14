# Maintainer: TNE <tne [at] garudalinux (dot) org>

pkgname=garuda-secureboot
pkgdesc="Configuration tool for enabling secure boot on Garuda Linux"
pkgver=1.0.0
pkgrel=1
arch=('any')
license=('GPL-3.0-or-later')
source=("garuda-secureboot")
sha512sums=('d9cf91155213cdcb0622ad112f4891504232dd02a6f80c31a263377677c111722e999d03d97b2ad7c2530a5275f37f742ca9478232b542ddf821b5fc3c03600a')
install=garuda-secureboot.install

package() {
  depends=("python" "shim-signed" "sbsigntools" "garuda-dracut-support>=1.6.0" "garuda-hooks>=2.15.0" "mokutil" "grub")
  optdepends=()

  install -Dm755 garuda-secureboot "$pkgdir"/usr/bin/garuda-secureboot

  # Create required directories
  mkdir -p "$pkgdir"/var/lib/garuda/secureboot/
  mkdir -p "$pkgdir"/etc/garuda/secureboot/
  echo "1" > "$pkgdir"/etc/garuda/secureboot/installed
}
