#!/usr/bin/env bash

. bitcoin.sh

echo 1..5

declare -i n=0

# Example 6 from the bitcoin book, chap. 04
prv=3aba4162c7251c891207b747840551a71939b0de081f85c4e44cf7c13e41daa6
point="$(dc -e "$secp256k1 16doilG${prv^^}lMx lEx")"
point_uncompressed="$(dc -e "$secp256k1 16doilG${prv^^}lMx lUxP" |basenc --base16 -w 260)"

((n++))
if [[ "$point" = 025C0DE3B9C8AB18DD04E3511243EC2952002DBFADC864B9628910169D9B9B00EC ]]
then echo ok $n
else echo not ok $n
fi

((n++))
if [[ "$(bitcoinAddress "$point")" = 14cxpo3MBCYYWCgF74SWTdcmxipnGUsPw3 ]]
then echo ok $n
else echo not ok $n
fi

((n++))
if [[ "$(bitcoinAddress "$point_uncompressed")" = 1thMirt546nngXqyPEz532S8fLwbozud8 ]]
then echo ok $n
else echo not ok $n
fi

((n++))
if [[ "$(basenc --base16 -d <<<"${prv^^}" |wif -u)" = 5JG9hT3beGTJuUAmCQEmNaxAuMacCTfXuw1R3FCXig23RQHMr4K ]]
then echo ok $n
else echo not ok $n
fi

((n++))
if [[ "$(basenc --base16 -d <<<"${prv^^}"|wif)" = KyBsPXxTuVD82av65KZkrGrWi5qLMah5SdNq6uftawDbgKa2wv6S ]]
then echo ok $n
else echo not ok $n
fi

# vi: ft=bash
