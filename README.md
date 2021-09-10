# Bitcoin bash tools

This is a set of bash functions to manipulate bitcoin addresses, but mostly to generate keys for cold storage.

When I first conceived these functions, tools like
[sx](https://sx.dyne.org/index.html) or its successor
[bx](https://github.com/libbitcoin/libbitcoin-explorer) either did not exist or
I was not aware of their existence.  Now that I look at bx, it seems this
utility does everything that I wanted to do and more, except it's not written in bash.

I like bash for its ''out-of-the-box'' availibility in a GNU system, so I will likely continue
to developp bitcoin-bash-tools, aiming at making it a translation of bx into bash.


## Synopsis

    $ git clone https://github.com/grondilu/bitcoin-bash-tools.git
    $ cd bitcoin-bash-tools/
    $ . bitcoin.sh

    $ let -i a=RANDOM b=RANDOM
    $ secp256k1 $a
    $ secp256k1 $b
    $ for i in $a $b; do secp256k1 $i; done | secp256k1
    $ secp256k1 $((a+b))

    $ newBitcoinKey |tee mykey.json

    $ openssl rand 64 > entropy
    $ bip32 m < entropy
    $ bip32 m/n < entropy
    $ bip32 m/0h/5/7 < entropy

    $ prove -e bash t/*.t.sh

## Requirements

- [bash](https://www.gnu.org/software/bash/) version 4 or above;
- [dc](https://en.wikipedia.org/wiki/Dc_\(computer_program\)), the Unix desktop calculator;
- xxd, an [hex dump](https://en.wikipedia.org/wiki/Hex_dump) utility;
- openssl, the [OpenSSL](https://en.wikipedia.org/wiki/OpenSSL) command line tool.

## TODO

- [ ] [BIP 0173](https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki)
- [ ] [BIP 0039](https://en.bitcoin.it/wiki/BIP_0039)
- [ ] [BIP 0032](https://en.bitcoin.it/wiki/BIP_0032)
- [x] use an environment variable for generating addresses on the test network.
- [ ] [BIP 0350](https://github.com/bitcoin/bips/blob/master/bip-0350.mediawiki)
- [x] [TAP](http://testanything.org/testing-with-tap/) support
- [ ] offline transactions
- [ ] copy the [Bitcoin eXplorer](https://github.com/libbitcoin/libbitcoin-explorer.git) interface as much as possible

## License

Copyright (C) 2013 Lucien Grondin (grondilu@yahoo.fr)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


