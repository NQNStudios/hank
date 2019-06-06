t() {
    haxe -cp hank -lib utest -lib hscript hxml/$1.hxml --interp > test-output.txt
    $VISUAL test-output.txt
}

ta() {
    haxe -cp hank -lib utest -lib hscript hxml/all-platforms.hxml > test-output.txt
    $VISUAL test-output.txt
}

tas() {
    haxe -D stop_on_error -cp hank -lib utest -lib hscript hxml/all-platforms.hxml > test-output.txt
    $VISUAL test-output.txt
}

debug() {
    haxe -js js/hank.js hxml/all.hxml
    chromium-browser js/index.html
}
