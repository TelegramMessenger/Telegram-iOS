#!/bin/sh

set -e

typeset -A select_chats
select_chats[ar]="تحديد المحادثات"
select_chats[be]="Выберыце чаты"
select_chats[ca]="Trieu els xats"
select_chats[de]="Chats auswählen"
select_chats[en]="Select chats"
select_chats[es]="Elige los chats"
select_chats[fa]="انتخاب گفتگو"
select_chats[fr]="Sélectionnez des échanges"
select_chats[id]="Pilih Chat"
select_chats[it]="Seleziona chat"
select_chats[ko]="대화방 선택"
select_chats[ms]="Pilih bual"
select_chats[nl]="Kies chats"
select_chats[pl]="Wybierz czaty"
select_chats[pt]="Selecione os chats"
select_chats[ru]="Выберите чаты"
select_chats[tr]="Sohbet seç"
select_chats[uk]="Виберіть чати"
select_chats[uz]="Chatlarni tanlang"

for f in *.lproj; do
    if [ "$f" = "en.lproj" ]; then
        continue
    fi

    language_code=$(echo "$f" | sed -e "s/\\.lproj//")

    select_chats_string="${select_chats[$language_code]}"
    if [ -z "$select_chats_string" ]; then
        echo "Missing value for $language_code"
        exit 1
    fi

    rm -f "$f/Intents.intentdefinition"
    cp  "en.lproj/Intents.intentdefinition" "$f/Intents.intentdefinition"
    /usr/libexec/PlistBuddy -c "Set :INIntents:0:INIntentParameters:0:INIntentParameterDisplayName '$select_chats_string'" "$f/Intents.intentdefinition"
    /usr/libexec/PlistBuddy -c "Set :INIntents:1:INIntentParameters:0:INIntentParameterDisplayName '$select_chats_string'" "$f/Intents.intentdefinition"
done
