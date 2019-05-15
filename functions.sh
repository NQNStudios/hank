t() {
    haxe hxml/$1.hxml --interp
}

ta() {
    haxe hxml/all-platforms.hxml
}

debug() {
    haxe -js js/hank.js hxml/all.hxml
    chromium-browser js/index.html
}