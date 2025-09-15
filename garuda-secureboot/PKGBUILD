# Maintainer: TNE <tne [at] garudalinux (dot) org>

pkgname=garuda-secureboot
pkgdesc="Configuration tool for enabling secure boot on Garuda Linux"
pkgver=1.0.1
pkgrel=1
arch=('any')
license=('GPL-3.0-or-later')
source=("garuda-secureboot")
sha512sums=('060c11e3bf78e45e3162581ab52b9836df6b3d287a044683e3af9c9dbde4f5350df3a109ed3ff200072f295c6aef1cab3f80e835a11ffd4a5dd1f3b5dc28a69d')
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
