FROM archlinux:base
# Package an already compiled bundle; no compiler or GTK/WebKit installation.
RUN pacman -Syu --noconfirm --needed fakeroot \
    && useradd --create-home builder \
    && pacman -Scc --noconfirm \
    && printf '\nCOMPRESSZST=(zstd -c -T0 -3 -)\n' >> /etc/makepkg.conf
WORKDIR /home/builder
CMD ["bash", "-euc", "cp /build/app.tar.gz /build/PKGBUILD . && chown builder:builder app.tar.gz PKGBUILD && runuser -u builder -- makepkg --nodeps --noconfirm && cp -- *.pkg.tar.zst /build/"]
