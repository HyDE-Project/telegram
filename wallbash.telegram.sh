#!/usr/bin/env bash
# Credits:
# - Ideas from: https://github.com/guillaumeboehm/wal-telegram


set -E
trap '[ "$?" -ne 77 ] || exit 77' ERR

# Help function
help() {
    cat <<EOF
A script to create Telegram palettes that use colors from a specified palette file.

Usage: 
    $0 [-r|--restart]
    $0 -h | --help

Options:
    -h                  Show command usage.
    --help              Show this help screen.
    -r --restart        Restart the Telegram app after generation.
EOF
}

# Default values
scrDir="$(dirname "$(realpath "$0")")"
source "${scrDir}/globalcontrol.sh"

command -v zip > /dev/null || {
    printf '\e[1;31m::\e[0m \e[1;37mA zipping utility is needed for this script, consider installing zip or gzip\e[0m\n'
    exit 77
}

options=$(getopt -o hr --long help,restart -- "$@") || {
    help; exit 1
}
eval set -- "$options"

restart_on_gen=false

while true; do
    case "$1" in
        -h|--help) help; exit 0 ;;
        -r|--restart) restart_on_gen=true; shift ;;
        --) shift; break ;;
        *) break ;;
    esac
done

bg="${cacheDir}/wall.blur"
. "${cacheDir}/landing/wallbash-telegram.sh"

# Set colors from 9 to 16 if input has 16
for i in {8..15}; do
    eval "color$i=\${color$((i-8))}"
done

prepare() {
    pre="/tmp/wal-telegram/$(date +%s)"
    mkdir -p "$pre" "${cacheDir}/landing/"
    cp "$bg" "${pre}/background.jpg"
}

create_colors() {
    local colors=(0 1 2 3 4 5 7 8 9 10 11 12 13 14 15)
    local divisions=(10 20 30 40 50 60 70 80 90)
    local alphas=(00 11 22 33 44 55 66 77 88 99 aa bb cc dd ee)

    for i in "${colors[@]}"; do
        local color="color${i}"
        local c_rgb_12d=$((0x"${!color:1:2}"))
        local c_rgb_34d=$((0x"${!color:3:2}"))
        local c_rgb_56d=$((0x"${!color:5:2}"))

        for division in "${divisions[@]}"; do
            for modifier in lighter darker; do
                # Calculate the factor once per division and modifier
                local factor=$(( (c_rgb_12d * division / 100) * (modifier == "lighter" ? 1 : -1) ))
                local c_r=$(( c_rgb_12d + factor ))
                local c_g=$(( c_rgb_34d + factor ))
                local c_b=$(( c_rgb_56d + factor ))

                # Clamp values to [0,255]
                ((c_r > 255)) && c_r=255
                ((c_g > 255)) && c_g=255
                ((c_b > 255)) && c_b=255

                printf -v c_hex '#%02x%02x%02x' "$c_r" "$c_g" "$c_b"
                declare "color${i}_${modifier}_${division}=$c_hex"
            done
        done

        echo "color$i: ${!color};"
        echo "// Lighter and darker variants of the color."
        for division in "${divisions[@]}"; do
            echo "colorLighter${i}_${division}: ${!color}_lighter_${division};"
            echo "colorDarker${i}_${division}: ${!color}_darker_${division};"
        done

        echo "// Alpha colors."
        for alpha in "${alphas[@]}"; do
            echo "colorAlpha${i}_${alpha}: ${!color}${alpha};"
        done
        echo ""
    done
}

create_palette() {
    create_colors > "${pre}/colors.tdesktop-theme"

    # Extract constants from the script itself.
    const="$(sed -n '/^### TELEGRAM CONSTANTS ####/,$p' "$0" | sed '/^### TELEGRAM CONSTANTS ####/d')"
    printf '%s' "$const" >> "${pre}/colors.tdesktop-theme"

    cd "${pre}" || exit 1

    zip -q "${wallbashTheme}" colors.tdesktop-theme background.jpg

    cp "${wallbashTheme}" "${cacheDir}/landing/" || {
        printf '\e[1;31m::\e[0m \e[1;37mFailed to copy theme file\e[0m\n'
        exit 1
    }

    if [[ $restart_on_gen == true ]]; then 
        pkill -f telegram-desktop 
        hyprctl dispatch exec -- telegram-desktop 
    fi
}

main() {
    wallbashTheme="Wallbash.tdesktop-theme"
    prepare && create_palette 
}

main
exit 0



### TELEGRAM CONSTANTS ####
// vim:ft=cfg

/* TODO: 1. Translate comments from italian to english (doing copy paste from
 *          telegram official documentation is not a good idea because IMHO
 *          it doesn't explain anything, useless).
 *       2. Remove unused alpha colors.
 *       3. Add the missing alpha colors.
 *       4. Fix colors marked with [UNTESTED].
 */

// Colors for testing purposes
colorPink: #ff7fc6;
colorGreen: #0bd500;

// Basic window options
windowBg: color0;                                            // sfondo della parte sinitra più menu opzioni e menu sinistra
windowFg: color7;                                            // colore fg testo normale + opzioni menu tasto destra
windowBgOver: colorDarker8_30;                              // colore bg opzioni menu sinistra e menu tasto destro con cursore sopra
windowBgRipple: color1;                                      // colore bg opzioni menu sinistra e menu tasto destro con click premuto
windowFgOver: color15;                                        // colore fg opzioni menu tasto destra con cursore sopra
windowSubTextFg: colorDarker7_40;                            // testo in basso a sinistra nel menu sinistra + testo messo in meno risalto nel menu opzioni
windowSubTextFgOver: color7;                                 // [UNTESTED]: in teoria come all'opzione sopra ma con cursore sopra
windowBoldFg: colorLighter7_20;                              // colore testo in grassetto, che si trova nelle opzioni del menu sinstra, titoli menu opzioni e titoli descrizioni gruppo
windowBoldFgOver: colorLighter7_40;                          // uguale a sopra ma con il cursore sopra, ad esempio nelle opzioni del menu sinistra
windowBgActive: color2;                                      // sfondo dei tick e altre cose che "si riempiono di colore", vedi menu opzioni
windowFgActive: colorLighter7_40;                            // fg della parte top del menu sinistra e delle cose che hanno come sfondo l'opzione sopra, segno dei tick, titolo chat attiva ecc...
windowActiveTextFg: color10;                                  // testo online e testo sottolineato nel menu opzioni
windowShadowFg: color0;                                      // ombra di contorno menu sinistra, menu opzioni e insomma un po tutti gli elementi dotati di ombra
windowShadowFgFallback: windowBg;                            // [UNTESTED]: fallback per ombre senza opacità

// Shadow
shadowFg: colorAlpha1_66;                                    // la maggior parte delle ombre (con opacità) (il colore del divisore tra le parti della schermata principale)

// Slide
slideFadeOutBg: colorAlpha0_33;                              // animazione che c'è quando premi sulla freccia di un mex inoltrato (dalla chat al profilo)
slideFadeOutShadowFg: windowShadowFg;                        // sempre parlando della animazione spiegata sopra, è la riga del lato destro che si sposta verso sinistra

// Image
imageBg: color2;                                             // [UNTESTED]: quando la foto è meno grande delle dimensioni max
imageBgTransparent: color7;                                  // sfondo immagine quando si tratta di una immagine con opacità, anche se questa non è richiesta

// Active
activeButtonBg: color2;                                      // colore bg bottone attivo, tipo il primo bottone in alto a sinistra nel menu opzioni
activeButtonBgOver: colorLighter2_30;                        // come sopra ma con il cursore sopra
activeButtonBgRipple: colorLighter2_50;                      // come sopra ma effetto ripple, click tenuto
activeButtonFg: color7;                                      // testo del bottone spiegato sopra
activeButtonFgOver: colorLighter7_30;                        // testo del bottone spiegato sopra ma con cursore sopra
activeButtonSecondaryFg: colorLighter7_50;                   // quando si seleziona un messaggio, i numerini vicino a inoltra ed elimina
activeButtonSecondaryFgOver: activeButtonSecondaryFg;        // uguale a sopra ma con il cursore sopra
activeLineFg: color2;                                        // tipo la linea sotto la scelta del nome quando si crea un gruppo
activeLineFgError: color1;                                   // uguale a sopra ma quando si verificano errori

// Light
lightButtonBg: color0;                                       // bottone a destra nel menu opzioni e insomma i bottoni chiari
lightButtonBgOver: colorLighter0_40;                         // uguale a sopra ma con il cursore sopra
lightButtonBgRipple: colorLighter0_60;                       // uguale a sopra ma effetto ripple, click tenuto
lightButtonFg: color2;                                       // testo del bottone spiegato sopra
lightButtonFgOver: lightButtonFg;                            // testo del bottone spiegato sopra con cursore sopra

// Attention
attentionButtonFg: color1;                                   // [UNTESTED]: default attention button text (like confirm button on log out)
attentionButtonFgOver: colorLighter1_30;                     // [UNTESTED]: default attention button text with mouse over
attentionButtonBgOver: colorLighter0_40;                     // [UNTESTED]: default attention button background with mouse over
attentionButtonBgRipple: colorLighter0_60;                   // [UNTESTED]: default attention button ripple effect

// Outline
outlineButtonBg: windowBg;                                   // [UNTESTED]: default left outlined button background (like shared media links in profiles)
outlineButtonBgOver: colorLighter0_40;                       // [UNTESTED]: default left outlined button background with mouse over
outlineButtonOutlineFg: color2;                              // [UNTESTED]: default left outlined button left outline border
outlineButtonBgRipple: colorLighter0_60;                     // [UNTESTED]: default left outlined button ripple effect

// Menu
menuBg: color0;                                              // linea superiore e inferiore dei popup menu, ad esempio i tre punti in alto a destra nelle chat
menuBgOver: colorLighter0_40;                                // [UNTESTED]: in teoria il bg degli elementi del popu menu con il cursore sopra
menuBgRipple: colorLighter0_60;                              // [UNTESTED]: in teoria lo stesso di sopra ma effetto ripple
menuIconFg: color7;                                          // icone menu opzioni e barra sopra nell'area chat
menuIconFgOver: colorLighter7_40;                            // uguale a sopra ma con cursore sopra
menuSubmenuArrowFg: color7;                                  // nel field dei mex, se premi tasto destro, nel popup menu c'è una freccia
menuFgDisabled: colorDarker7_40;                             // testo disabilitato nel popup menu (tasto destro nel field ricerca o nel field mex)
menuSeparatorFg: colorDarker7_40;                            // separatore nel menu tasto destro in input field

// Scroll
scrollBarBg: colorAlpha7_55;                                 // default scroll bar current rectangle, the bar itself (like in chats list)
scrollBarBgOver: colorAlpha7_77;                             // default scroll bar current rectangle with mouse over it
scrollBg: colorAlpha7_11;                                    // default scroll bar background
scrollBgOver: colorAlpha7_22;                                // default scroll bar background with mouse over the scroll bar

// Small
smallCloseIconFg: colorDarker7_40;                           // piccola croce ad esempio accanto all'header nel pannello emoji
smallCloseIconFgOver: color7;                                // come sopra ma con il cursore sopra

// Radial
radialFg: windowFgActive;                                    // [UNTESTED]: default radial loader line (like in Media Viewer when loading a photo)
radialBg: colorAlpha0_55;                                    // [UNTESTED]: default radial loader background (like in Media Viewer when loading a photo)

// Placeholder
placeholderFg: color7;                                       // tipo il testo placeholder di deafult della barra di ricerca e dell'inserisci testo
placeholderFgActive: colorDarker7_40;                        // uguale a sopra, ma quando il field è in focus

// Input
inputBorderFg: color7;                                       // tipo l'fg della riga alternativa quando si sta creando un canale

// Filter
filterInputBorderFg: colorLighter0_40;                        // bordo che appare quando si clicka nella barra di ricerca
filterInputInactiveBg: colorDarker8_30;                      // bg field di ricerca inattivo
filterInputActiveBg: colorDarker8_20;                        // bg field di ricerca attivo

// Checkbox
checkboxFg: colorDarker7_40;                                 // icone categorie emoji e anche caselle dei tick non "tickate"

// Slider
sliderBgInactive: colorDarker7_40;                           // slider non attiva
sliderBgActive: windowBgActive;                              // slider attiva

// Tooltip
tooltipBg: color7;                                           // bg del tooltip field, tipo quando aspetti con il cursore sopra il timestamp del mex
tooltipFg: color0;                                           // fg del tooltip
tooltipBorderFg: color7;                                     // bordi del tooltip

// Title
titleShadow: colorAlpha0_11;                                 // [UNTESTED]: one pixel line shadow at the bottom of custom window title
titleBg: color0;                                             // [UNTESTED]: custom window title background when window is inactive
titleBgActive: titleBg;                                      // [UNTESTED]: custom window title background when window is active
titleButtonBg: titleBg;                                      // [UNTESTED]: custom window title minimize/maximize/restore button background when window is inactive (Windows only)
titleButtonFg: color7;                                       // [UNTESTED]: custom window title minimize/maximize/restore button icon when window is inactive (Windows only)
titleButtonBgOver: colorLighter0_40;                         // [UNTESTED]: custom window title minimize/maximize/restore button background with mouse over when window is inactive (Windows only)
titleButtonFgOver: colorLighter7_40;                         // [UNTESTED]: custom window title minimize/maximize/restore button icon with mouse over when window is inactive (Windows only)
titleButtonBgActive: titleButtonBg;                          // [UNTESTED]: custom window title minimize/maximize/restore button background when window is active (Windows only)
titleButtonFgActive: titleButtonFg;                          // [UNTESTED]: custom window title minimize/maximize/restore button icon when window is active (Windows only)
titleButtonBgActiveOver: titleButtonBgOver;                  // [UNTESTED]: custom window title minimize/maximize/restore button background with mouse over when window is active (Windows only)
titleButtonFgActiveOver: titleButtonFgOver;                  // [UNTESTED]: custom window title minimize/maximize/restore button icon with mouse over when window is active (Windows only)
titleButtonCloseBg: titleButtonBg;                           // [UNTESTED]: custom window title close button background when window is inactive (Windows only)
titleButtonCloseFg: titleButtonFg;                           // [UNTESTED]: custom window title close button icon when window is inactive (Windows only)
titleButtonCloseBgOver: colorLighter0_40;                    // [UNTESTED]: custom window title close button background with mouse over when window is inactive (Windows only)
titleButtonCloseFgOver: windowFgActive;                      // [UNTESTED]: custom window title close button icon with mouse over when window is inactive (Windows only)
titleButtonCloseBgActive: titleButtonCloseBg;                // [UNTESTED]: custom window title close button background when window is active (Windows only)
titleButtonCloseFgActive: titleButtonCloseFg;                // [UNTESTED]: custom window title close button icon when window is active (Windows only)
titleButtonCloseBgActiveOver: titleButtonCloseBgOver;        // [UNTESTED]: custom window title close button background with mouse over when window is active (Windows only)
titleButtonCloseFgActiveOver: titleButtonCloseFgOver;        // [UNTESTED]: custom window title close button icon with mouse over when window is active (Windows only)
titleFg: color7;                                             // [UNTESTED]: custom window title text when window is inactive (macOS only)
titleFgActive: colorLighter7_40;                             // [UNTESTED]: custom window title text when window is active (macOS only)

// Tray
trayCounterBg: color2;                                       // [UNTESTED]: tray icon counter background
trayCounterBgMute: color0;                                   // [UNTESTED]: tray icon counter background if all unread messages are muted
trayCounterFg: color7;                                       // [UNTESTED]: tray icon counter text
trayCounterBgMacInvert: color7;                              // [UNTESTED]: tray icon counter background when tray icon is pressed or when dark theme of macOS is used (macOS only)
trayCounterFgMacInvert: color2;                              // [UNTESTED]: tray icon counter text when tray icon is pressed or when dark theme of macOS is used (macOS only)

// Layer
layerBg: colorAlpha0_77;                                     // fade menu opzioni e menu sinistra

// Cancel
cancelIconFg: colorDarker7_40;                               // fg croce per chiudere il menu opzioni e altre cose
cancelIconFgOver: color7;                                    // uguale a sopra ma con cursore sopra la croce

// Box
boxBg: windowBg;                                             // bg menu opzioni
boxTextFg: windowFg;                                         // fg menu opzioni
boxTextFgGood: color2;                                       // [UNTESTED]: accepted box text (like when choosing username that is not occupied)
boxTextFgError: color1;                                      // [UNTESTED]: rejecting box text (like when choosing username that is occupied)
boxTitleFg: colorLighter7_40;                                // testo delle box, tipo conferma dopo aver cambiato tema
boxSearchBg: color0;                                         // bg field di ricerca delle box, tipo ricerca nell'opzione contatti nel menu a sinistra
boxTitleAdditionalFg: colorDarker7_40;                       // subtext del boxTitleFg, tipo dove puoi vedere il numero delle persone da aggiungere quando stai creando un gruppo
boxTitleCloseFg: cancelIconFg;                               // altre croci
boxTitleCloseFgOver: cancelIconFgOver;                       // altre croci con cursore sopra

// Members
membersAboutLimitFg: color1;                                 // testo quando si supera il limite di aggiunta membri (dato che è altissimo, impossibile da verificare XD)

// Contacts
contactsBg: colorLighter0_40;                                // bg delle box che contengono i contatti nell'apposita sezione accessibile dal menu a sinistra
contactsBgOver: color0;                                      // uguale a sopra ma con il cursore sopra
contactsNameFg: boxTextFg;                                   // fg dei nomi dei contatti nella sezione descritta sopra
contactsStatusFg: colorDarker7_40;                           // fg dello status dei nomi dei contatti
contactsStatusFgOver: colorDarker7_40;                       // uguale a sopra ma con il cursore sopra
contactsStatusFgOnline: color10;                              // fg della scritta in linea nei contatti in linea appunto

// Photo
photoCropFadeBg: layerBg;                                    // lo sfondo del crop dell'immagine scelta (quando devi impostare una immagine per il gruppo o per il tuo profilo)
photoCropPointFg: colorAlpha7_77;                            // rettangolini che delimitano l'immagine che si sta impostando

// Call
callArrowFg: color2;                                         // [UNTESTED]: received phone call arrow (in calls list box)
callArrowMissedFg: color1;                                   // [UNTESTED]: missed phone call arrow (in calls list box)

// Intro
introBg: windowBg;                                           // [UNTESTED]: login background
introTitleFg: colorLighter7_40;                              // [UNTESTED]: login title text
introDescriptionFg: color7;                                  // [UNTESTED]: login description text
introErrorFg: color1;                                        // [UNTESTED]: login error text (like when providing a wrong log in code)
introCoverTopBg: color2;                                     // [UNTESTED]: intro gradient top (from)
introCoverBottomBg: color2;                                  // [UNTESTED]: intro gradient bottom (to)
introCoverIconsFg: colorLighter2_40;                         // [UNTESTED]: intro cloud graphics
introCoverPlaneTrace: colorLighter2_40;                      // [UNTESTED]: intro plane traces
introCoverPlaneInner: colorLighter1_40;                      // [UNTESTED]: intro plane part
introCoverPlaneOuter: color1;                                // [UNTESTED]: intro plane part
introCoverPlaneTop: colorLighter7_40;                        // [UNTESTED]: intro plane part

// Dialogs default
dialogsMenuIconFg: menuIconFg;                               // main menu and lock telegram icon
dialogsMenuIconFgOver: menuIconFgOver;                       // main menu and lock telegram icon with mouse over
dialogsBg: windowBg;                                         // box dialoghi bg
dialogsNameFg: colorLighter7_40;                             // box dialoghi fg nomi
dialogsChatIconFg: dialogsNameFg;                            // box dialoghi icone gruppo o contatto
dialogsDateFg: colorDarker7_40;                              // box dialoghi testo data
dialogsTextFg: color7;                                       // box dialoghi testo messaggi (in piccolo sotto il nome)
dialogsTextFgService: color7;                                // box dialoghi testo messaggi del mittente
dialogsDraftFg: color1;                                      // box dialoghi colore testo bozza
dialogsVerifiedIconBg: color10;                                // bg icona profilo verificato
dialogsVerifiedIconFg: color0;                                // fg icona profilo verificato
dialogsSendingIconFg: color10;                                // icona invio messaggio (orologio)
dialogsSentIconFg: color10;                                   // singolo/doppi tick di conferma invio mex
dialogsUnreadBg: color1;                                     // [UNTESTED]: chat list unread badge background for not muted chat
dialogsUnreadBgMuted: colorDarker7_40;                       // fg icona pinned per chat fissate
dialogsUnreadFg: colorLighter7_40;                           // [UNTESTED]: chat list unread badge text

// Dialogs over
dialogsBgOver: colorDarker2_50;                             // cursore sopra dialog box
dialogsNameFgOver: windowBoldFgOver;                         // box dialoghi fg nomi con cursore sopra
dialogsChatIconFgOver: dialogsNameFgOver;                    // box dialoghi icone gruppo o contatto con cursore sopra
dialogsDateFgOver: colorDarker7_40;                          // box dialoghi testo data con cursore sopra
dialogsTextFgOver: color7;                                   // box dialoghi testo messaggi (in piccolo sotto il nome) con cursore sopra
dialogsTextFgServiceOver: color7;                            // box dialoghi testo messaggi del mittente con cursore sopra
dialogsDraftFgOver: dialogsDraftFg;                          // box dialoghi colore testo bozza con cursore sopra
dialogsVerifiedIconBgOver: color2;                            // bg icona profilo verificato con cursore sopra
dialogsVerifiedIconFgOver: color0;                            // fg icona profilo verificato con cursore sopra
dialogsSendingIconFgOver: dialogsSendingIconFg;              // icona invio messaggio (orologio) con cursore sopra
dialogsSentIconFgOver: color10;                               // singolo/doppi tick di conferma invio mex con cursore sopra
dialogsUnreadBgOver: colorDarker1_40;                        // [UNTESTED]: chat list unread badge background for not muted chat with mouse over
dialogsUnreadBgMutedOver: colorDarker7_40;                   // [UNTESTED]: chat list unread badge background for muted chat with mouse over
dialogsUnreadFgOver: dialogsUnreadFg;                        // [UNTESTED]: chat list unread badge text with mouse over

// Dialogs active
dialogsBgActive: color2;                                     // colore bg dialog box attiva
dialogsNameFgActive: windowBoldFgOver;                       // box dialoghi fg nomi attiva
dialogsChatIconFgActive: dialogsNameFgActive;                // box dialoghi icone gruppo o contatto attiva
dialogsDateFgActive: colorLighter7_40;                       // box dialoghi testo data attiva
dialogsTextFgActive: colorLighter7_40;                       // box dialoghi testo messaggi (in piccolo sotto il nome) attiva
dialogsTextFgServiceActive: colorLighter7_40;                // box dialoghi testo messaggi del mittente attiva
dialogsDraftFgActive: colorLighter7_40;                      // box dialoghi colore testo bozza attiva
dialogsVerifiedIconBgActive: dialogsTextFgActive;             // [UNTESTED]: chat list verified icon background for current (active) chat
dialogsVerifiedIconFgActive: dialogsBgActive;                 // [UNTESTED]: chat list verified icon check for current (active) chat
dialogsSendingIconFgActive: colorLighter7_40;                // icona invio messaggio (orologio) attiva
dialogsSentIconFgActive: dialogsTextFgActive;                // singolo/doppi tick di conferma invio mex attiva
dialogsUnreadBgActive: dialogsTextFgActive;                  // [UNTESTED]: chat list unread badge background for not muted chat for current (active) chat
dialogsUnreadBgMutedActive: colorLighter7_40;                // [UNTESTED]: chat list unread badge background for muted chat for current (active) chat
dialogsUnreadFgActive: colorLighter7_40;                     // [UNTESTED]: chat list unread badge text for current (active) chat

// Dialogs ripple
dialogsRippleBg: colorLighter0_60;                           // effetto ripple sulla box dialoghi non attiva
dialogsRippleBgActive: colorLighter2_40;                     // effetto ripple sulla box dialoghi attiva

// Dialogs forward
dialogsForwardBg: dialogsBgActive;                           // forwarding panel background (when forwarding messages in the smallest window size)
dialogsForwardFg: dialogsNameFgActive;                       // forwarding panel text (when forwarding messages in the smallest window size)

// Searched
searchedBarBg: colorLighter0_40;                             // bg della parte col testo quando si fa la ricerca dei messaggi in una singola chat
searchedBarFg: color7;                                       // fg del testo dell'elemento descritto sopra

// Top
topBarBg: color0;                                            // bg della barra superiore della parte destra della schermata principale (dentro le chat)

// Emoji
emojiPanBg: windowBg;                                        // bg del pannello emoji
emojiPanCategories: color0;                                  // bg della parte bassa del pannello emoji (categorie)
emojiPanHeaderFg: color7;                                    // fg header descrittivo del pannello emoji
emojiPanHeaderBg: color0;                                    // [UNTESTED]: bg dell'elemento descritto sopra
emojiIconFg: color7;                                         // fg dell'emoji non attiva (parte finale del pannello emoji)
emojiIconFgActive: color2;                                   // fg dell'emoji attiva

// Sticker
stickerPanDeleteBg: colorAlpha0_cc;                          // [UNTESTED]: delete X button background for custom sent stickers in stickers panel (legacy)
stickerPanDeleteFg: windowFgActive;                          // [UNTESTED]: delete X button icon for custom sent stickers in stickers panel (legacy)
stickerPreviewBg: colorAlpha0_bb;                            // sticker and GIF preview background (when you press and hold on a sticker)

// History
historyTextInFg: windowFg;                                   // inbox testo mex non selezionato
historyTextInFgSelected: colorLighter7_40;                   // inbox testo mex selezionato
historyTextOutFg: color7;                                    // outbox testo mex non selezionato
historyTextOutFgSelected: colorLighter7_40;                  // outbox testo mex selezionato
historyLinkInFg: color10;                                     // inbox testo link mex non selezionato
historyLinkInFgSelected: colorLighter7_40;                   // inbox testo link mex selezionato
historyLinkOutFg: color10;                                    // outbox testo link mex non selezionato
historyLinkOutFgSelected: colorLighter7_40;                  // outbox testo link mex selezionato
historyFileNameInFg: historyTextInFg;                        // inbox testo filename media non selezionato
historyFileNameInFgSelected: colorLighter7_40;               // inbox testo filename media selezionato
historyFileNameOutFg: historyTextOutFg;                      // outbox testo filename media non selezionato
historyFileNameOutFgSelected: colorLighter7_40;              // outbox testo filename media selezionato
historyOutIconFg: colorLighter10_70;                                    // outbox tick/doppio tick testo non selezionato 
historyOutIconFgSelected: colorLighter7_40;                  // outbox tick/doppio tick testo selezionato
historyIconFgInverted: color2;                               // outbox tick/doppio tick media
historySendingOutIconFg: color2;                             // outbox icona invio mex (orologio)
historySendingInIconFg: color2;                              // inbox icona invio mex (orologio)
historySendingInvertedIconFg: colorAlpha2_cc;                // inbox icona invio media (orologio)
historyCallArrowInFg: color1;                                // [UNTESTED]: received phone call arrow
historyCallArrowInFgSelected: colorLighter7_40;              // [UNTESTED]: received phone call arrow in a selected message
historyCallArrowMissedInFg: callArrowMissedFg;               // [UNTESTED]: missed phone call arrow
historyCallArrowMissedInFgSelected: colorLighter7_40;        // [UNTESTED]: missed phone call arrow in a selected message
historyCallArrowOutFg: colorLighter7_40;                     // [UNTESTED]: outgoing phone call arrow
historyCallArrowOutFgSelected: colorLighter7_40;             // [UNTESTED]: outgoing phone call arrow
historyUnreadBarBg: color0;                                  // [UNTESTED]: new unread messages bar background
historyUnreadBarBorder: shadowFg;                            // [UNTESTED]: new unread messages bar shadow
historyUnreadBarFg: color1;                                  // [UNTESTED]: new unread messages bar text
historyForwardChooseBg: colorAlpha0_44;                      // [UNTESTED]: forwarding messages in a large window size "choose recipient" background
historyForwardChooseFg: windowFgActive;                      // [UNTESTED]: forwarding messages in a large window size "choose recipient" text
historyPeer1NameFg: color1;                                  // nome user 1 mex non selezionato
historyPeer1NameFgSelected: colorLighter7_40;                // nome user 1 mex selezionato
historyPeer1UserpicBg: color1;                               // bg userpic 1
historyPeer2NameFg: color2;                                  // nome user 2 mex non selezionato
historyPeer2NameFgSelected: colorLighter7_40;                // nome user 2 mex selezionato
historyPeer2UserpicBg: color2;                               // bg userpic 2
historyPeer3NameFg: color3;                                  // nome user 3 mex non selezionato
historyPeer3NameFgSelected: colorLighter7_40;                // nome user 3 mex selezionato
historyPeer3UserpicBg: color3;                               // bg userpic 3
historyPeer4NameFg: color4;                                  // nome user 4 mex non selezionato
historyPeer4NameFgSelected: colorLighter7_40;                // nome user 4 mex selezionato
historyPeer4UserpicBg: color4;                               // bg userpic 4
historyPeer5NameFg: color5;                                  // nome user 5 mex non selezionato
historyPeer5NameFgSelected: colorLighter7_40;                // nome user 5 mex selezionato
historyPeer5UserpicBg: color5;                               // bg userpic 5
historyPeer6NameFg: color6;                                  // nome user 6 mex non selezionato
historyPeer6NameFgSelected: colorLighter7_40;                // nome user 6 mex selezionato
historyPeer6UserpicBg: color6;                               // bg userpic 6
historyPeer7NameFg: color7;                                  // nome user 7 mex non selezionato
historyPeer7NameFgSelected: colorLighter7_40;                // nome user 7 mex selezionato
historyPeer7UserpicBg: color7;                               // bg userpic 7
historyPeer8NameFg: color8;                                  // nome user 8 mex non selezionato
historyPeer8NameFgSelected: colorLighter7_40;                // nome user 8 mex selezionato
historyPeer8UserpicBg: color8;                               // bg userpic 8
historyPeerUserpicFg: windowFgActive;                        // fg iniziali userpic
historyScrollBarBg: colorAlpha7_77;                          // bg contenitore barra normale
historyScrollBarBgOver: colorAlpha7_bb;                      // bg contenitore barra con cursore sopra
historyScrollBg: colorAlpha7_44;                             // bg barra normale
historyScrollBgOver: colorAlpha7_66;                         // bg barra con cursore sopra

// Msg
msgInBg: colorDarker7_70;                                             // inbox mex bg non selezionato
msgInBgSelected: color2;                                     // inbox mex bg selezionato
msgOutBg: colorDarker8_60;                                            // outbox mex bg non selezionato
msgOutBgSelected: color2;                                    // outbox mex bg selezionato
msgSelectOverlay: colorAlpha2_44;                            // overlay sopra il mex selezionato
msgStickerOverlay: colorAlpha2_77;                           // overlay sopra lo sticker selezionato
msgInServiceFg: windowActiveTextFg;                          // inbox colore testo informazioni tipo inoltrato da... non selezionato
msgInServiceFgSelected: colorLighter7_40;                    // inbox colore testo informazioni tipo inoltrato da... selezionato
msgOutServiceFg: color10;                                     // outbox colore testo informazioni tipo inoltrato da... non selezionato
msgOutServiceFgSelected: colorLighter7_40;                   // outbox colore testo informazioni tipo inoltrato da... selezionato
msgInShadow: colorAlpha0_00;                                 // inbox ombre mex non selezionato
msgInShadowSelected: colorAlpha2_00;                         // inbox ombra mex selezionato
msgOutShadow: colorAlpha0_00;                                // outbox ombra mex non selezionato
msgOutShadowSelected: colorAlpha2_00;                        // outbox ombra mex selezionato
msgInDateFg: colorDarker7_40;                                // inbox ore invio mex non selezionato
msgInDateFgSelected: colorLighter7_40;                       // inbox ore invio mex selezionato
msgOutDateFg: colorDarker7_40;                               // outbox ore invo mex non selezionato
msgOutDateFgSelected: colorLighter7_40;                      // outbox ore invio mex selezionato
msgServiceFg: windowFgActive;                                // fg mex di servizio (tipo data mex, titolo del gruppo cambiato e così via)
msgServiceBg: color0;                                        // bg mex di servizio non selezionato
msgServiceBgSelected: color10;                                // bg mex di servizio selezionato
msgInReplyBarColor: color10;                                  // inbox colore testo tipo inoltrato da ecc... non selezionato
msgInReplyBarSelColor: colorLighter7_40;                     // inbox colore testo tipo inoltrato da ecc.... selezionato
msgOutReplyBarColor: color10;                                 // outbox colore testo tipo inoltrato da ecc.... non selezionato 
msgOutReplyBarSelColor: colorLighter7_40;                     // outbox colore testo tipo inoltrato da ecc.... selezionato 
msgImgReplyBarColor: msgServiceFg;                           // [UNTESTED]: colore testo inoltrato qunado si tratta di immagini
msgInMonoFg: color7;                                         // inbox mex monospace non selezionato
msgInMonoFgSelected: colorLighter7_40;                       // inbox mex monospace selezionato
msgOutMonoFg: color7;                                        // outbox mex monospace non selezionato
msgOutMonoFgSelected: colorLighter7_40;                      // outbox mex monospace selezionato
msgDateImgFg: msgServiceFg;                                  // mex media fg bolla ore invio
msgDateImgBg: colorAlpha0_55;                                // mex media bg bolla ore invio
msgDateImgBgOver: colorAlpha0_77;                            // mex media bg bolla ore invio con cursore sopra
msgDateImgBgSelected: colorAlpha2_88;                        // mex media bg bolla ore invio selezionato
msgFileThumbLinkInFg: lightButtonFg;                         // inbox file media file mex scarica non selezionato
msgFileThumbLinkInFgSelected: lightButtonFgOver;             // inbox file media file mex scarica selezionato
msgFileThumbLinkOutFg: color10;                               // outbox file media file mex scarica non selezionato
msgFileThumbLinkOutFgSelected: colorLighter7_40;             // outbox file media file mex scarica selezionato
msgFileInBg: color2;                                         // inbox bg file audio cerchio download 
msgFileInBgOver: colorLighter2_30;                           // inbox bg file audio cerchio download con cursore sopra
msgFileInBgSelected: colorLighter2_50;                       // inbox bg file audio cerchio download selezionato
msgFileOutBg: color2;                                        // outbox bg file audio cerchio download
msgFileOutBgOver: colorLighter2_30;                          // outbox bg file audio cerchio download con cursore sopra
msgFileOutBgSelected: colorLighter2_50;                      // outbox bg file audio cerchio download selezionato
msgFile1Bg: color1;                                          // [UNTESTED]: blue shared links / files without image square thumbnail
msgFile1BgDark: colorDarker1_30;                             // [UNTESTED]: blue shared files without image download circle background
msgFile1BgOver: colorLighter1_40;                            // [UNTESTED]: blue shared files without image download circle background with mouse over
msgFile1BgSelected: colorLighter7_40;                        // [UNTESTED]: blue shared files without image download circle background if file is selected
msgFile2Bg: color2;                                          // [UNTESTED]: green shared links / shared files without image square thumbnail
msgFile2BgDark: colorDarker2_30;                             // [UNTESTED]: green shared files without image download circle background
msgFile2BgOver: colorLighter2_40;                            // [UNTESTED]: green shared files without image download circle background with mouse over
msgFile2BgSelected: colorLighter7_40;                        // [UNTESTED]: green shared files without image download circle background if file is selected
msgFile3Bg: color3;                                          // [UNTESTED]: red shared links / shared files without image square thumbnail
msgFile3BgDark: colorDarker7_30;                             // [UNTESTED]: red shared files without image download circle background
msgFile3BgOver: colorLighter7_40;                            // [UNTESTED]: red shared files without image download circle background with mouse over
msgFile3BgSelected: colorLighter7_40;                        // [UNTESTED]: red shared files without image download circle background if file is selected
msgFile4Bg: color3;                                          // [UNTESTED]: yellow shared links / shared files without image square thumbnail
//FIXME(Seems to be gone): msgFile4BgDark: colorDarker3_30;                             // [UNTESTED]: yellow shared files without image download circle background
//FIXME(Seems to be gone): msgFile4BgOver: colorLighter3_40;                            // [UNTESTED]: yellow shared files without image download circle background with mouse over
msgFile4BgSelected: colorLighter7_40;                        // [UNTESTED]: yellow shared files without image download circle background if file is selected
msgWaveformInActive: windowBgActive;                         // inbox ondina audio inattivo non selezionato
msgWaveformInActiveSelected: colorLighter7_40;               // inbox ondina audio inattivo selezionato
msgWaveformInInactive: colorDarker7_30;                      // inbox ondina audio attivo non selezionato
msgWaveformInInactiveSelected: colorLighter2_40;             // inbox ondina audio attivo selezionato
msgWaveformOutActive: color2;                                // outbox ondina audio inattivo non selezionato
msgWaveformOutActiveSelected: colorLighter7_40;              // outbox ondina audio inattivo selezionato
msgWaveformOutInactive: colorDarker7_30;                     // outbox ondina audio attivo non selezionato
msgWaveformOutInactiveSelected: colorLighter2_40;            // outbox ondina audio attivo selezionato
msgBotKbOverBgAdd: colorAlpha7_11;                           // [UNTESTED]: this is painted over a bot inline keyboard button (which has msgServiceBg background) when mouse is over that button
msgBotKbIconFg: msgServiceFg;                                // [UNTESTED]: bot inline keyboard button icon in the top-right corner (like in @vote bot when a poll is ready to be shared)
msgBotKbRippleBg: colorAlpha1_11;                            // [UNTESTED]: bot inline keyboard button ripple effect

// Download animations
historyFileInIconFg: color0;                                 // inbox freccia scaricamento file non selezionato
historyFileInIconFgSelected: color10;                         // inbox freccia scaricamento file selezionato
historyFileInRadialFg: color0;                               // inbox particella animazione scaricamento file non selezionato
historyFileInRadialFgSelected: historyFileInIconFgSelected;  // inbox particella animazione scaricamento file selezionato
historyFileOutIconFg: color0;                                // outbox freccia scaricamento file non selezionato
historyFileOutIconFgSelected: color10;                        // outbox freccia scaricamento file selezionato
historyFileOutRadialFg: historyFileOutIconFg;                // outbox particella animazione scaricamento file non selezionato
historyFileOutRadialFgSelected: color10;                      // outbox particella animazione scaricamento file selezionato
historyFileThumbIconFg: colorLighter7_40;                    // fg freccia scaricamento foto/video non selezionato
historyFileThumbIconFgSelected: colorLighter7_40;            // fg freccia scariamento foto/video selezionato
historyFileThumbRadialFg: historyFileThumbIconFg;            // fg particella animazione scaricamento foto/video non selezionato
historyFileThumbRadialFgSelected: colorLighter7_40;          // fg particella animazione scaricamento foto/video selezionato
historyVideoMessageProgressFg: historyFileThumbIconFg;       // [UNTESTED]: radial playback progress in round video messages

// YouTube
youtubePlayIconBg: #83131c88;                                 // [UNTESTED]: youtube play icon background (when a link to a youtube video with a webpage preview is sent)
youtubePlayIconFg: windowFgActive;                           // [UNTESTED]: youtube play icon arrow (when a link to a youtube video with a webpage preview is sent)

// Video
videoPlayIconBg: colorAlpha0_77;                             // [UNTESTED]: other video play icon background (like when a link to a vimeo video with a webpage preview is sent)
videoPlayIconFg: colorLighter7_40;                           // [UNTESTED]: other video play icon arrow (like when a link to a vimeo video with a webpage preview is sent)

// Toast
toastBg: colorAlpha0_bb;                                     // [UNTESTED]: toast notification background (like when you click on your t.me link when editing your username)
toastFg: windowFgActive;                                     // [UNTESTED]: toast notification text (like when you click on your t.me link when editing your username)

// Report
reportSpamBg: color0;                                        // [UNTESTED]: report spam panel background (like a non contact user writes your for the first time)
reportSpamFg: windowFg;                                      // [UNTESTED]: report spam panel text (when you send a report from that panel)

// Composition area
historyToDownBg: color0;                                     // bg bottone a freccia per scorrere in fondo alla chat
historyToDownBgOver: colorLighter0_40;                       // bg bottone a freccia per scorrere in fondo alla chat con cursore sopra
historyToDownBgRipple: colorLighter0_60;                     // bg bottone a freccia per scorrere in fondo alla chat selezionato
historyToDownFg: color7;                                     // fg bottone a freccia per scorrere in fondo alla chat
historyToDownFgOver: menuIconFgOver;                         // fg bottone a freccia per scorrere in fondo alla chat con cursore sopra
historyToDownShadow: colorAlpha0_44;                         // ombra del bottone
historyComposeAreaBg: color0;                                // bg area di composizione in basso a destra della schermata principale
historyComposeAreaFg: historyTextInFg;                       // fg dell'area appena citata
historyComposeAreaFgService: msgInDateFg;                    // testo mex selezionato nell'area di composizione
historyComposeIconFg: menuIconFg;                            // fg icone dell'area composizione 
historyComposeIconFgOver: menuIconFgOver;                    // fg icone dell'area composizione con cursore sopra
historySendIconFg: windowBgActive;                           // fg icona invio messaggio
historySendIconFgOver: windowBgActive;                       // fg icona invio messaggio con cursore sopra
historyPinnedBg: historyComposeAreaBg;                       // [UNTESTED]: pinned message area background
historyReplyBg: historyComposeAreaBg;                        // bg area rispondi, inoltra, modfica mex
historyReplyIconFg: windowBgActive;                          // fg icona freccia verso sinistra in area rispondi, inoltra, modifica mex
historyReplyCancelFg: cancelIconFg;                          // fg icona croce in area rispondi, inoltra, modifica mex
historyReplyCancelFgOver: cancelIconFgOver;                  // fg icona croce in area rispondi, inoltra, modifica mex con cursore sopra
historyComposeButtonBg: historyComposeAreaBg;                // [UNTESTED]: unblock / join channel / mute channel button background
historyComposeButtonBgOver: colorLighter0_40;                // [UNTESTED]: unblock / join channel / mute channel button background with mouse over
historyComposeButtonBgRipple: colorLighter0_60;              // [UNTESTED]: unblock / join channel / mute channel button ripple effect

// Overview
overviewCheckBg: colorAlpha0_44;                             // [UNTESTED]: shared files / links checkbox background for not selected rows when some rows are selected
overviewCheckFg: colorLighter7_40;                           // [UNTESTED]: shared files / links checkbox icon for not selected rows when some rows are selected
overviewCheckFgActive: colorLighter7_40;                     // [UNTESTED]: shared files / links checkbox icon for selected rows
overviewPhotoSelectOverlay: colorAlpha1_33;                  // [UNTESTED]: shared photos / videos / links fill for selected rows

// Profile
profileStatusFgOver: color1;                                  // [UNTESTED]: group members list in group profile user last seen text with mouse over
profileVerifiedCheckBg: windowBgActive;                        // [UNTESTED]: profile verified check icon background
profileVerifiedCheckFg: windowFgActive;                        // [UNTESTED]: profile verified check icon tick
profileAdminStartFg: windowBgActive;                          // [UNTESTED]: group members list admin star icon

// Notifications
notificationsBoxMonitorFg: windowFg;                          // [UNTESTED]: custom notifications settings box monitor color
notificationsBoxScreenBg: dialogsBgActive;                    // [UNTESTED]: #6389a8; // custom notifications settings box monitor screen background
notificationSampleUserpicFg: windowBgActive;                  // [UNTESTED]: custom notifications settings box small sample userpic placeholder
notificationSampleCloseFg: color7;                            // [UNTESTED]: custom notifications settings box small sample close button placeholder
notificationSampleTextFg: color7;                             // [UNTESTED]: custom notifications settings box small sample text placeholder
notificationSampleNameFg: colorLighter0_40;                   // [UNTESTED]: custom notifications settings box small sample name placeholder

// Change
changePhoneSimcardFrom: notificationSampleTextFg;             // [UNTESTED]: change phone number box left simcard icon
changePhoneSimcardTo: notificationSampleNameFg;               // [UNTESTED]: change phone number box right simcard and plane icons

// Main
mainMenuBg: windowBg;                                        // bg menu a sinstra
mainMenuCoverBg: color2;                                     // bg top cover menu a sinistra (parte sopra)
mainMenuCoverFg: windowFgActive;                             // fg top cover menu a sinistra
mainMenuCloudFg: colorLighter7_40;                           // fg icona nuvoletta nel menu a sinistra
mainMenuCloudBg: color4;                                     // bg icona nuvoletta nel menu a sinistra

// Media
mediaInFg: msgInDateFg;                                      // inbox testo di status (tipo peso del file audio) non selezionato
mediaInFgSelected: msgInDateFgSelected;                      // inbox testo di status (tipo peso del file audio) selezionato
mediaOutFg: msgOutDateFg;                                    // outbox testo di status (tipo peso del file audio) non selezionato
mediaOutFgSelected: msgOutDateFgSelected;                    // outbox testo di status (tipo peso del file audio) selezionato
mediaPlayerBg: windowBg;                                     // [UNTESTED]: audio file player background
mediaPlayerActiveFg: windowBgActive;                         // [UNTESTED]: audio file player playback progress already played part
mediaPlayerInactiveFg: sliderBgInactive;                     // [UNTESTED]: audio file player playback progress upcoming (not played yet) part with mouse over
mediaPlayerDisabledFg: color1;                               // [UNTESTED]: audio file player loading progress (when you're playing an audio file and switch to the previous one which is not loaded yet)

// Mediaview
mediaviewFileBg: windowBg;                                   // [UNTESTED]: file rectangle background (when you view a png file in Media Viewer and go to a previous, not loaded yet, file)
mediaviewFileNameFg: windowFg;                               // [UNTESTED]: file name in file rectangle
mediaviewFileSizeFg: windowSubTextFg;                        // [UNTESTED]: file size text in file rectangle
mediaviewFileRedCornerFg: color1;                            // [UNTESTED]: red file thumbnail placeholder corner in file rectangle (for a file without thumbnail, like .pdf)
mediaviewFileYellowCornerFg: color2;                         // [UNTESTED]: yellow file thumbnail placeholder corner in file rectangle (for a file without thumbnail, like .zip)
mediaviewFileGreenCornerFg: color3;                          // [UNTESTED]: green file thumbnail placeholder corner in file rectangle (for a file without thumbnail, like .exe)
mediaviewFileBlueCornerFg: color4;                           // [UNTESTED]: blue file thumbnail placeholder corner in file rectangle (for a file without thumbnail, like .dmg)
mediaviewFileExtFg: activeButtonFg;                          // [UNTESTED]: file extension text in file thumbnail placeholder in file rectangle
mediaviewMenuBg: color0;                                     // [UNTESTED]: context menu in Media Viewer background
mediaviewMenuBgOver: colorLighter0_40;                       // [UNTESTED]: context menu item background with mouse over
mediaviewMenuBgRipple: colorLighter0_60;                     // [UNTESTED]: context menu item ripple effect
mediaviewMenuFg: windowFgActive;                             // [UNTESTED]: context menu item text
mediaviewBg: colorDarker0_30;                                // [UNTESTED]: media viewer background
mediaviewVideoBg: imageBg;                                   // [UNTESTED]: media viewer background when viewing a video in full screen
mediaviewControlBg: colorDarker0_50;                         // [UNTESTED]: controls background (like next photo / previous photo)
mediaviewControlFg: windowFgActive;                          // [UNTESTED]: controls icon (like next photo / previous photo)
mediaviewCaptionBg: colorDarker0_50;                         // [UNTESTED]: caption text background (when viewing photo with caption)
mediaviewCaptionFg: mediaviewControlFg;                      // [UNTESTED]: caption text
mediaviewTextLinkFg: color7;                                 // [UNTESTED]: caption text link
mediaviewSaveMsgBg: toastBg;                                 // [UNTESTED]: save to file toast message background in Media Viewer
mediaviewSaveMsgFg: toastFg;                                 // [UNTESTED]: save to file toast message text
mediaviewPlaybackActive: color7;                             // [UNTESTED]: video playback progress already played part
mediaviewPlaybackInactive: colorDarker7_50;                  // [UNTESTED]: video playback progress upcoming (not played yet) part
mediaviewPlaybackActiveOver: colorLighter7_40;               // [UNTESTED]: video playback progress already played part with mouse over
mediaviewPlaybackInactiveOver: colorDarker7_30;              // [UNTESTED]: video playback progress upcoming (not played yet) part with mouse over
mediaviewPlaybackProgressFg: colorLighter7_40;               // [UNTESTED]: video playback progress text
mediaviewPlaybackIconFg: mediaviewPlaybackActive;            // [UNTESTED]: video playback controls icon
mediaviewPlaybackIconFgOver: mediaviewPlaybackActiveOver;    // [UNTESTED]: video playback controls icon with mouse over
mediaviewTransparentBg: colorLighter7_40;                    // [UNTESTED]: transparent filling part (when viewing a transparent .png file in Media Viewer)
mediaviewTransparentFg: color7;                              // [UNTESTED]: another transparent filling part
notificationBg: windowBg;                                     // [UNTESTED]: custom notification window background

// Call
callBg: colorAlpha0_ff;                                      // [UNTESTED]: phone call popup background
callNameFg: colorLighter7_40;                                // [UNTESTED]: phone call popup name text
callFingerprintBg: colorAlpha0_66;                           // [UNTESTED]: phone call popup emoji fingerprint background
callStatusFg: color7;                                        // [UNTESTED]: phone call popup status text
callIconFg: colorLighter7_40;                                // [UNTESTED]: phone call popup answer, hangup and mute mic icon
callAnswerBg: color2;                                        // [UNTESTED]: phone call popup answer button background
callAnswerRipple: colorDarker2_30;                           // [UNTESTED]: phone call popup answer button ripple effect
callAnswerBgOuter: colorLighter2_30;                         // [UNTESTED]: phone call popup answer button outer ripple effect
callHangupBg: color1;                                        // [UNTESTED]: phone call popup hangup button background
callHangupRipple: colorDarker1_30;                           // [UNTESTED]: phone call popup hangup button ripple effect
callCancelBg: colorLighter7_40;                              // [UNTESTED]: phone call popup line busy cancel button background
callCancelFg: colorDarker7_40;                               // [UNTESTED]: phone call popup line busy cancel button icon
callCancelRipple: colorLighter7_40;                          // [UNTESTED]: phone call popup line busy cancel button ripple effect
callMuteRipple: #ffffff12;                                      // [UNTESTED]: phone call popup mute mic ripple effect
callBarBg: dialogsBgActive;                                  // [UNTESTED]: active phone call bar background
callBarMuteRipple: dialogsRippleBgActive;                    // [UNTESTED]: active phone call bar mute and hangup button ripple effect
callBarBgMuted: colorLighter0_40;                            // [UNTESTED]: phone call bar with muted mic background
callBarUnmuteRipple: colorLighter0_40;                       // [UNTESTED]: phone call bar with muted mic mute and hangup button ripple effect
callBarFg: dialogsNameFgActive;                              // [UNTESTED]: phone call bar text and icons

// Important
importantTooltipBg: toastBg;                                 // [UNTESTED]:
importantTooltipFg: toastFg;                                 // [UNTESTED]:
importantTooltipFgLink: color2;                              // [UNTESTED]:

// Bot
botKbBg: color0;                                             // [UNTESTED]:
botKbDownBg: colorLighter0_40;                               // [UNTESTED]:

// Overview
overviewCheckBorder: color2;                                 // [UNTESTED]:

// Sidebar
sideBarBg: color0;
sideBarBgActive: color2;
sideBarBgRipple: color1;
sideBarTextFg: color1;
sideBarTextFgActive: color7;
sideBarIconFg: color7;
sideBarIconFgActive: colorLighter7_40;
sideBarBadgeBg: color1;
sideBarBadgeBgMuted: colorDarker7_40;
sideBarBadgeFg: colorLighter7_40;

// DUNNO
profileOtherAdminStarFg: color7;                             // [UNTESTED]:
