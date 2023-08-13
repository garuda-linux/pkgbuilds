# Maintainer: Librewish <librewish@gmail.com>
# Maintainer: dr460nf1r3 <dr460nf1r3 at garudalinux dot org>

pkgname=garuda-qtile-settings
pkgdesc='Garuda Linux Qtile settings'
pkgver=3.2.0
pkgrel=1
arch=('any')
url="https://gitlab.com/garuda-linux/themes-and-settings/settings/$pkgname"
license=('GPL')
makedepends=('coreutils')
source=("$pkgname-$pkgver.tar.gz::$url/-/archive/$pkgver/$pkgname-$pkgver.tar.gz")
sha256sums=('SKIP')
provides=('garuda-desktop-settings')
conflicts=('garuda-desktop-settings')
install=$pkgname.install

package() {
    install -d $pkgdir/etc
    cp -rf $srcdir/$pkgname-$pkgver/etc $pkgdir
    install -d $pkgdir/usr
    cp -rf $srcdir/$pkgname-$pkgver/usr $pkgdir
}
