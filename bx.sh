#!/usr/bin/env bash
# 
# bx.sh, an attempt at a bash port of the Bitcoin eXplorer (BX).
# Original code:  https://github.com/libbitcoin/libbitcoin-explorer

debug() { [[ $DEBUG = yes ]] && echo "$@"; } >&2

bip32_mainnet_public_version_code=0x0488B21E
bip32_mainnet_private_version_code=0x0488ADE4
bip32_testnet_public_version_code=0x043587CF
bip32_testnet_private_version_code=0x04358394

bip32_serialization_format="%08x%02x%08x%08x%64s%66s" 

declare base58="123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
unset dcr; for i in {0..57}; do dcr+="${i}s${base58:$i:1}"; done

isCompressedPoint()   [[ "$1" =~ ^0[23][[:xdigit:]]{2}{32}$ ]]
isUncompressedPoint() [[ "$1" =~    ^04[[:xdigit:]]{2}{64}$ ]]

isDecimal()        [[ "$1" =~ ^[[:digit:]]+$ ]]
isHexadecimal()    [[ "$1" =~ ^(0x)?([[:xdigit:]]{2}+)$ ]]
isBase64()         [[ "$1" =~ ^[A-Za-z0-9+/]+=*$ ]]
isBase58Check() {
  [[ "$1" =~ ^[$base58]+$ ]] &&
  bx base58-decode "$1" |
  {
    read
    [[ "$(bx wrap-encode -n "${REPLY:0:-8}")" = "$REPLY" ]]
  }
}
isExtendedKey() {
  isBase58Check "$1" &&
  bx base58-decode "$1" |
  bx base16-decode |
  wc -c |
  grep -q '^82$'
}
isDerivationPath() [[ "$1" =~ ^[mM](/[[:digit:]]+h?)*$ ]]

declare -a bx_commands=(
  seed
  ec-{new,to-{address,public,wif}}
  electrum-{new,to-seed}
  hd-{new,private,public,to-{ec,public}}
  mnemonic-{new,to-seed}
  qrcode
  uri-{de,en}code
  wif-to-{ec,public}

  address-{{de,en}code,embed}
  {wrap,base{16,58{,check},64}}-{en,de}code

  bitcoin{160,256}
  ripemd160
  sha{160,256,512}

  ec-{add,multiply}{,-secrets}
  
  hd-{parse,identifier,fingerprint}
)

complete -W "${bx_commands[*]}" bx
bx() 
  if
    local OPTIND OPTARG
    getopts h o
  then cat <<-ENDUSAGE
	Usage:
	  $FUNCNAME -h
	  $FUNCNAME COMMAND [options] [arguments]
	
	  COMMAND is any of: ${bx_commands[*]}
	ENDUSAGE
  else
    shift $((OPTIND - 1))
    local -l command="$1"
    shift
    case "$command" in

      # Wallet commands
      seed)
        local -i length=192
        local o
        while getopts b:h o
        do
          case "$o" in
            b) length=$OPTARG;;
            h) cat <<-seed_USAGE
	Usage: bx seed [-h] [-b VALUE]
	
	Info: Generate a pseudorandom seed.                                      
	
	Options (named):
	
	-b                   The length of the seed in bits. Must be divisible by
	                     8 and must not be less than 128, defaults to 192.   
	-h                   Get a description and instructions for this command.
	seed_USAGE
            return
            ;;
          esac
        done
        shift $((OPTIND - 1))
        if ((length >= 128 && length % 8 == 0))
        then openssl rand -hex $((length/8))
        else return 1
        fi ;;
      ec-new)
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif isDecimal "$1"
        then $FUNCNAME $command "0x$(dc -e "16o$1p")"
        elif isHexadecimal "$1"
        then
          local hex="${BASH_REMATCH[2]}"
	  if ((4*${#hex} < 128))
	  then
	    echo "The seed is less than 128 bits long." >&2
	    return 2
	  else
	    $FUNCNAME base16-decode "$hex" |
	    openssl dgst -sha512 -hmac "Bitcoin seed" -binary |
	    head -c 32 |
	    $FUNCNAME base16-encode
	  fi
        else return 1
        fi
        ;;
      ec-to-public)
        if
          local format="${BITCOIN_PUBLIC_KEY_FORMAT:-compressed}"
          getopts u o
        then
          shift $((OPTIND - 1))
          BITCOIN_PUBLIC_KEY_FORMAT=uncompressed $FUNCNAME $command "$@"
        elif (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif isDecimal "$1"
        then $FUNCNAME $command "0x$(dc -e "16o$1p")"
        elif isHexadecimal "$1"
	then
          {
	    echo "16doilG${BASH_REMATCH[2]^^}lMxlm~" 
	    if [[ "$format" = compressed ]]
	    then echo "2%2+2 2 8^^*+ P"
	    else echo "r 4 2 2 8^^*+2 2 8^^*+P"
	    fi
          } | dc -f secp256k1.dc - |
          xxd -p -c 65
        else return 1
        fi
        ;;
      ec-to-address)
	local -i version=${BITCOIN_VERSION_BYTE:-0}
        if getopts v: o
        then
          shift $((OPTIND - 1))
          BITCOIN_VERSION_BYTE=$OPTARG $FUNCNAME $command "$@"
        elif (($# == 0))
        then read; $FUNCNAME ec-to-address "$REPLY"
        elif isCompressedPoint "$1" || isUncompressedPoint "$1"
        then
          $FUNCNAME bitcoin160 "$1" |
          $FUNCNAME base58check-encode -v $version
        else return 1
        fi
        ;;
      hd-new)
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif
	  local -i version=${BITCOIN_VERSION_BYTES:-76066276}
	  getopts v: o
        then
          shift $((OPTIND - 1))
          BITCOIN_VERSION_BYTES=$OPTARG $FUNCNAME $command "$@"
        elif isHexadecimal "$1"
        then
          local seed="${BASH_REMATCH[2]}"
          if ((4*${#seed} < 128))
          then
            echo "Seed is less than 128 bits long" >&2
            return 2
          else
	    $FUNCNAME base16-decode "$seed" |
	    openssl dgst -sha512 -hmac "Bitcoin seed" -binary |
	    $FUNCNAME base16-encode |
	    {
	      read
	      printf "$bip32_serialization_format\n" $version 0 0 0 "${REPLY:64:64}" "00${REPLY:0:64}"
	    } |
	    $FUNCNAME wrap-encode -n |
	    $FUNCNAME base58-encode
          fi
        else
          echo "unknow argument format for '$1'" >&2
	  return 1
        fi
        ;;
      hd-to-public)
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif
          local -i version=${BIP32_EXTENDED_KEY_VERSION:-$bip32_mainnet_public_version_code}
          getopts v: o
        then shift $((OPTIND - 1))
          BIP32_EXTENDED_KEY_VERSION=$OPTARG $FUNCNAME $command "$@"
        elif isExtendedKey "$1"
        then
          $FUNCNAME hd-parse "$1" |
          {
             local -i oldversion depth parentfp childnumber
             local chaincode key
             read oldversion depth parentfp childnumber chaincode key
	     key="$($FUNCNAME ec-to-public "$key")"
             printf "$bip32_serialization_format\n" $version $depth $parentfp $childnumber $chaincode $key |
             $FUNCNAME wrap-encode -n |
             $FUNCNAME base58-encode
          }
        else return 1
        fi
        ;;
      hd-parse)
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif isExtendedKey "$1"
        then
          $FUNCNAME base58-decode "$1" |
          {
            read
	    local -i version="0x${REPLY:0:8}" \
	               depth="0x${REPLY:8:2}" \
	            parentfp="0x${REPLY:10:8}" \
	         childnumber="0x${REPLY:18:8}"
            local chaincode="${REPLY:26:64}" key="${REPLY:90:66}"
            echo "$version $depth $parentfp $childnumber $chaincode $key"
          }
        else return 1
        fi
        ;;
      hd-identifier)
	if (($# == 0))
	then read; $FUNCNAME $command "$REPLY"
	elif isExtendedKey "$1"
	then
	  if [[ "$1" =~ ^[tx]prv ]]
	  then $FUNCNAME hd-to-public "$1" | $FUNCNAME $command
	  elif [[ "$1" =~ ^[tx]pub ]]
	  then
	    $FUNCNAME hd-parse "$1" |
	    cut -d' ' -f 6 |
	    $FUNCNAME bitcoin160
	  else return 2
	  fi
	else return 1
	fi
        ;;
      hd-fingerprint)
	if (($# == 0))
	then read; $FUNCNAME $command "$REPLY"
        else $FUNCNAME hd-identifier "$1" | head -c 8
        fi
        ;;
      hd-public)
        local -i index=${BIP32_DERIVATION_INDEX:-0}
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif getopts di: o
        then
          shift $((OPTIND - 1))
          case $o in
	    d) BIP32_DERIVATION_TYPE=hardened $FUNCNAME $command "$@" ;;
            i) BIP32_DERIVATION_INDEX=$OPTARG $FUNCNAME $command "$@" ;;
          esac
	elif [[ "$1" =~ ^[tx]prv ]]
	then $FUNCNAME hd-private "$1" | $FUNCNAME hd-to-public
        elif [[ "$BIP32_DERIVATION_TYPE" = hardened ]]
        then echo "Hard key derivation requires private key" >&2; return 2
        elif isExtendedKey "$1"
        then
          $FUNCNAME hd-parse "$1" |
          {
            local -i version depth parentfp childnumber
            local chaincode key
            read version depth parentfp childnumber chaincode key
            ((depth++, childnumber=index))
            parentfp="0x$($FUNCNAME hd-fingerprint "$1")"

	    printf "%66s%08x\n" $key $index |
	    $FUNCNAME base16-decode |
	    openssl dgst -sha512 -mac hmac -macopt hexkey:$chaincode -binary |
	    $FUNCNAME base16-encode |
            {
              read
              local ki ci="${REPLY:64:64}"
              ki="$($FUNCNAME ec-add $key ${REPLY:0:64})"
              
	      printf "$bip32_serialization_format\n" $version $depth $parentfp $childnumber $ci $ki
            } |
            $FUNCNAME wrap-encode -n |
            $FUNCNAME base58-encode
          }
        else echo "$1 does not look like an extended key" >&2; return 1
        fi
        ;;
      hd-private)
        local -i index=${BIP32_DERIVATION_INDEX:-0}
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif getopts di: o
        then
          shift $((OPTIND - 1))
          case $o in
	    d) BIP32_DERIVATION_TYPE=hardened $FUNCNAME $command "$@" ;;
            i) BIP32_DERIVATION_INDEX=$OPTARG $FUNCNAME $command "$@" ;;
          esac
	elif [[ "$1" =~ ^[tx]pub ]]
	then echo "private key derivation can't be done from a public key" >&2; return 2
        elif isExtendedKey "$1"
        then
	  debug "BIP32_DERIVATION_INDEX=$BIP32_DERIVATION_INDEX"
          debug "BIP32_DERIVATION_TYPE=$BIP32_DERIVATION_TYPE"
          if [[ "$BIP32_DERIVATION_TYPE" = hardened ]]
          then
            if ((index >= 1 << 31))
            then echo "derivation index already looks hardened" >&2; return 3
            else ((index += 1 << 31)) 
            fi
          fi
 
          $FUNCNAME hd-parse "$1" |
          {
            local -i version depth parentfp childnumber
            local chaincode key
            read version depth parentfp childnumber chaincode key
            ((depth++, childnumber=index))
            parentfp="0x$($FUNCNAME hd-fingerprint "$1")"

            local parent_pubkey="$($FUNCNAME ec-to-public "${key:2}")"
            {
	      if ((index < 1<<31))
	      then echo "$parent_pubkey"
	      else echo "$key"
	      fi
	      printf "%08x\n" $index
	    } |
	    while read; do $FUNCNAME base16-decode "$REPLY"; done |
	    openssl dgst -sha512 -mac hmac -macopt hexkey:$chaincode -binary |
	    $FUNCNAME base16-encode |
            {
              read
              local ki ci="${REPLY:64:64}"
              ki="00$($FUNCNAME ec-add-secrets ${REPLY:0:64} ${key:2})"
              
	      printf "$bip32_serialization_format\n" $version $depth $parentfp $childnumber $ci $ki
            } |
            $FUNCNAME wrap-encode -n |
            $FUNCNAME base58-encode
          }
        else echo "$1 does not look like an extended key" >&2; return 1
        fi
        ;;

      # Encoding commands
      address-decode)
        ;;
      address-embed)
        ;;
      address-encode)
        ;;
      base16-encode)
        if (($# == 0))
        then xxd -p -c 256
        else echo -n "$1" | $FUNCNAME $command
        fi
        ;;
      base16-decode)
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif isHexadecimal "$1"
        then xxd -p -r <<<"${BASH_REMATCH[2]}"
        else return 1
        fi;;
      base58-decode)
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif [[ "$1" =~ ^1 ]]
        then echo -n 00; $FUNCNAME $command "${1:1}"
        elif [[ "$1" =~ ^[$base58]+$ ]]
        then
	  sed -e "i$dcr 0" -e 's/./ 58*l&+/g' -e "aP" <<<"$1" |
	  dc |
          $FUNCNAME base16-encode
        else return 1
        fi
        ;;
      base58-encode)
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif [[ "$1" =~ ^00.+ ]]
        then echo -n 1; $FUNCNAME $command "${1:2}"
        elif isHexadecimal "$1"
        then
          {
	    echo 16i 0
	    echo -n "${BASH_REMATCH[2]^^}" |
	    fold -w 2 |
	    sed 's/$/r100*+/'
	    echo '[3A~rd0<x]dsxx+f'
          } | dc |
	  while read; do echo -n "${base58:$REPLY:1}"; done
          echo
        else return 1
        fi
        ;;
      base64-encode)
        openssl base64
        ;;
      base64-decode)
        if (($# == 0))
        then openssl base64 -d
        elif isBase64 "$1"
        then echo "$1" | $FUNCNAME $command
        else return 1
        fi
        ;;
      wrap-encode)
        local -i version=${BITCOIN_VERSION_BYTE:-0}
        if getopts nv: o
        then
          debug "parsing option -$o in $command"
          shift $((OPTIND - 1))
          if [[ "$o" = v ]]
          then BITCOIN_VERSION_BYTE=$OPTARG $FUNCNAME $command "$@"
          elif [[ "$o" = n ]]
          then BITCOIN_VERSION_BYTE=none $FUNCNAME $command "$@"
          else echo "unexpected option -$o" >&2; return 2
          fi
        elif (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif isHexadecimal "$1"
        then
          local payload="${BASH_REMATCH[2]}"
          debug payload is $payload
          {
            if [[ ! "$BITCOIN_VERSION_BYTE" = "none" ]]
	    then printf "%02x" $version
            fi
            printf "%s\n" "$payload"
          } |
          {
            read
            echo -n $REPLY
	    $FUNCNAME base16-decode "$REPLY" |
	    openssl sha256 -binary |
	    openssl sha256 -binary |
	    head -c 4 |
	    $FUNCNAME base16-encode
          }
        else
          debug "unknown argument '$1'"
	  return 1
        fi
        ;;
      base58check-encode)
	local -i version=${BITCOIN_VERSION_BYTE:-0}
        if getopts v: o
        then
          debug "parsing option in $command : -$o $OPTARG"
          shift $((OPTIND - 1))
          BITCOIN_VERSION_BYTE=$OPTARG $FUNCNAME $command "$@"
        elif ((version < 0 || version > 255))
        then return 2
        elif (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif isHexadecimal "$1"
        then
          $FUNCNAME wrap-encode -v $version "${BASH_REMATCH[2]}" |
          $FUNCNAME base58-encode
        else return 1
        fi
        ;;
      # Hash commands
      bitcoin160)
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif isHexadecimal "$1"
        then
          $FUNCNAME base16-decode "${BASH_REMATCH[2]}" |
          openssl dgst -sha256 -binary |
          openssl dgst -rmd160 -binary |
          $FUNCNAME base16-encode
        else return 1
        fi
	;;
      bitcoin256)
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif isHexadecimal "$1"
        then
          $FUNCNAME base16-decode "${BASH_REMATCH[2]}" |
          openssl dgst -sha256 -binary |
          openssl dgst -sha256 -binary |
          $FUNCNAME base16-encode |
          fold -w 2 | tac |tr -d "\n"
        else return 1
        fi
        ;;
      ripemd160)
        if (($# == 0))
        then read; $FUNCNAME $command "$REPLY"
        elif isHexadecimal "$1"
        then $FUNCNAME base16-decode "${BASH_REMATCH[2]}" |
          openssl rmd160 -binary |
          $FUNCNAME base16-encode
        else return 1
        fi
        ;;

      # Math commands
      ec-add)
        if (($# == 0))
        then return 1
        elif (($# == 1))
        then read; $FUNCNAME $command "$1" "$REPLY"
        elif local -u point="$1"
          ! isCompressedPoint "$point"
        then return 1
        elif isHexadecimal "$2"
        then dc -f secp256k1.dc -e "16doi$point dlYxr2 2 8^^%lm*+lG${BASH_REMATCH[2]^^}lMxlAxlEx"
        else return 2
        fi
        ;;
      ec-add-secrets)
        local dc_script
        for arg
        do
	  if isHexadecimal "$arg"
	  then dc_script+="${BASH_REMATCH[2]^^}+"
	  else return 1
	  fi
        done
        dc -f secp256k1.dc -e "16doi0 $dc_script ln% 2 2 8^^+P" |
        tail -c 32 |
        $FUNCNAME base16-encode
        ;;
      *)
        echo "$command NYI" >&2
        ;;
    esac
  fi