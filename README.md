# Description

This is a smart-contract for TON blockchain implementing an auction system (or, as a special case, a simple shop). It was made by Denis Olshin as part of Telegram contest announced on 09/24/2019 (https://t.me/contest/102).

Instructions below assume that you are using TON's lite-client with FunC and Fift binaries available at PATH, and that you're familiar with those tools.

For details about building lite-client, please refer to https://github.com/ton-blockchain/ton/tree/master/lite-client-docs. For basic info about running Fift scripts and uploading messages to TON, please refer to https://github.com/ton-blockchain/ton/blob/master/doc/LiteClient-HOWTO.

# What's included

This directory contains following files:

* `common-utils.fif`
   A Fift library with some helper functions, that could be useful for creating any kind of smart contract. You don't need to run this file.


If you wish to make modifications to the contract's code, it's better to test it using `test-...` scripts without actually uploading it to the blockchain. The same can be done in case something goes wrong (see "Troubleshooting" section below).

# (Re)building the contract code

As was mentioned above, the smart contract code is located in `code.fc` and its getters are in `getters.fc`. These files are written in FunC language, so after you make any changes to them, you need to run FunC transpiler before you can upload the updated code.

Run these commands (`<path-to-source>` here is the root directory with the TON source code):

```
func -o"code-getters.fif" -P <path-to-source>/crypto/smartcont/stdlib.fc code.fc getters.fc
func -o"code.fif" -P <path-to-source>/crypto/smartcont/stdlib.fc code.fc
```

This should rebuild files `code-getters.fif` (full version of the contract) and `code.fif` (stripped-down version, without getters).

# How to use

This contract allows you to conduct any number of simultaneous auctions. Each auction is defined by the initial price, (optionally) the buyout price, bidding fee, start and end time, and other configuration params. Note that by setting the initial price equal to the buyout price, this can be turned into a simple trading process.

While an auction is active, anyone can place a bid by sending an internal message to this contract. If the attached amount of grams is above the current price, it's accepted, and the previous top bid is cancelled (its amount, minus the bidding fee, is returned to the bidder).

Auction ends at the specified end time, or if the current price reaches the buyout price. At that moment a special internal message to a predefined "notification address" is generated (to notify some other contract about the completion). Note that the actual transfer of goods to the winner is the responsibility of that contract (or some off-chain script monitoring the blockchain state).

Special case: blind auctions. In this case every participant submits an internal message with a fixed amount of grams, and attaches to a signature of his actual bid. For some predefined time after the auction end, participants provide their bids (and their public keys, so the original signatures can be validated), so the winner can be determined. All non-winning bids are fully returned (minus bidding fees), and winner receives only the difference between the amount he sent and his actual bid.

Owner of the auction contract can withdraw funds at any time on condition that the remaining balance is at least equal to the sum of all currently active top bids (so they can be always returned).

## Initialising a new contract
`./init.fif <workchain-id> <notification-addr> [<filename-base>] [-C <code-fif>]`
(external)

## Starting a new auction
`./new-auction.fif <contract> <seqno> <auction-id> <auction-type> <end-time> [<decrypt-time> <fixed-amount>] [-s <minimum-step>] [-t <start-time>] [-f <bidding-fee>] [-i <initial-price>] [-b <buyout-price>] [-O <output-boc>]`
(external)

## Cancelling an auction
`./cancel-auction.fif <contract> <seqno> <auction-id> [-O <output-boc>]`
(external)

## Placing a bid
`./place-bid.fif <contract-addr> <auction-id> <bid-amount> [-B <bid-filename>] [-O <output-boc>]`
(internal)

## Decrypt a bid
`./decrypt-bid.fif <contract-addr> <seqno> [-B <bid-filename>] [-O <output-boc>]`
(external)

## Pinging an auction
`./ping-auction.fif <contract-addr> <seqno> <auction-id> [-O <output-boc>]`
(external)

## Withdrawing funds from the contract
`./withdraw.fif <contract> <dest-addr> <seqno> <amount> [-O <output-boc>]`
(external)

# Get methods

In case you've used the default (non-stripped down) version of the contract, it will include some get-methods. You can run them in the TON client using the `runmethod` command. Note that they return raw data, so you may prefer using `show-state.fif` instead (see "Inspecting contract's state" section). 

List of available methods:
* `seqno`
   Returns ...

# Troubleshooting

After the request is uploaded to TON, there's no practical way to check what's happening with it (until it will be accepted). So if something goes wrong and your message is not accepted by the contract, you can only guess why.

Fortunately, there's couple of scripts that will help in this situation. First, you need to perform `saveaccountdata <filename> <addr>` command in the TON client shell. This will produce a boc-file containing current state of your contract.

Now you can inspect it using `show-state.fif`. Alternatively, you can manually call get-methods of the contract using `test-method.fif` (it should produce the same info, but in raw format).

But most importantly, you can run `test-message.fif` with a message file (that you were trying to upload) to simulate the execution of the smart contract, and check the TVM output. In addition to builtin errors, there are some error codes that could be thrown:

* Error **33**. *Invalid outer seqno*.
   The current stored seqno is different from the one in the incoming message. If this is a request to add signature(s) to an existing order, you can use `sign-order.fif` or `seal-order.fif` with a `-s <seqno>` option to fix the seqno. Otherwise (if this is a message to create a new order), you need to re-create it using `new-order.fif`.

# Fift words conventions

Fift language is quite flexible, but it can be difficult to read. There's two main reasons for that: stack juggling and no strict conventions for word names. To make the code more readable, some custom conventions were introduced within this repository:

`kebab-case-words()` are helper functions (defined in `common-utils.fif` and `auction-utils.fif`). Note that the name includes the parentheses at the end. (The only exceptions are `maybe,` and `maybe@+`)

`CamelCaseWords` are constants, defined using a `=:` word.

Those styles are chosen to stand out from the builtin words and from each other as much as possible.
