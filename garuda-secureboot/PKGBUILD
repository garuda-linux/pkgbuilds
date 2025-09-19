# Maintainer: TNE <tne [at] garudalinux (dot) org>

pkgname=garuda-secureboot
pkgdesc="Configuration tool for enabling secure boot on Garuda Linux"
pkgver=1.0.2
pkgrel=1
arch=('any')
license=('GPL-3.0-or-later')
source=("garuda-secureboot")
sha512sums=('e23e8fd8f30b216dfc3c2773698c99258ae9ea88a5e19c425bb8136775273417ab9f45a8119e08e5bdfd86c542588a8740083102295afcfc8ba363587290d856')
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
