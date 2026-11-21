#!/usr/bin/bash

check() {
    require_binaries bootvine || return 1
    return 255
}

depends() {
    echo systemd
}

install() {
    inst_binary bootvine
    inst_simple "$systemdsystemunitdir/bootvine.service"
    inst_simple "$systemdsystemunitdir/systemd-hibernate-resume.service.d/bootvine.conf"

    if [[ -f /etc/bootvine.toml ]]; then
        inst_simple /etc/bootvine.toml
    fi

    $SYSTEMCTL -q --root "$initdir" enable bootvine.service
}
