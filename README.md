# Description

This is a multi-purpose smart-contract for TON blockchain implementing both an auction system and a shop. It was made by Denis Olshin as part of Telegram contest announced on 09/24/2019 (https://t.me/contest/102).

Instructions below assume that you are using TON's lite-client with FunC and Fift binaries available at PATH, and that you're familiar with those tools.

For details about building lite-client, please refer to https://github.com/ton-blockchain/ton/tree/master/lite-client-docs. For basic info about running Fift scripts and uploading messages to TON, please refer to https://github.com/ton-blockchain/ton/blob/master/doc/LiteClient-HOWTO.

# What's included

This directory contains following files:

* `common-utils.fif`
   A Fift library with some helper functions, that could be useful for creating any kind of smart contract. You don't need to run this file.
* `auction-utils.fif`
   Similarly to `common-utils.fif`, this is a library file. However, it contains only functions specific to this particular auction contract implementation. Each other Fift script here includes it. You don't need to run this file either.
* `code.fc`
   Code of this smart contract, written in FunC. Note that it does not include get-methods (except for `seqno` method).
* `getters.fc`
   Get-methods of this smart contract. They are stored separately so you can upload your wallet code without them (it will still be functional, but will take less space).
* `code.fif`
   Compiled version of `code.fc`. Below you'll find instructions how to recompile it yourself.
* `code-getters.fif`
   Compiled version of `code.fc` + `getters.fc`.
* `init.fif`, `new-auction.fif`, `cancel-auction.fif`, `place-bid.fif`, `decrypt-bid.fif`, `ping-auction.fif`, `withdraw.fif` and `show-state.fif`
   Fift scripts for creating new contract, creating new auctions, placing bids and so on. Below you'll find detailed explanations about all of them.
* `test-init.fif`
   Fift script that simulates the initialisation of a contract locally, without actually uploading it to blockchain.
* `test-external.fif`
   Fift script that simulates sending an external message to a contract locally. Loads the original contract state and returns the modified one.
* `test-internal.fif`
   Fift script that simulates sending an internal message to a contract locally. Loads the original contract state and returns the modified one.
* `test-method.fif`
   Fift script that simulates executing a get-method of a smart contract for a given state. It includes `code-getters.fif`, so it can call get-methods even if the contract was uploaded without them.

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

This contract allows you to conduct any number of simultaneous **auctions**. Each auction is defined by the initial price, (optionally) the buyout price, bidding fee, start and end time, and other configuration params. By setting the initial price equal to the buyout price, this can be turned into a **trading process**. In this case it's also very useful to set the stock size option.

While an auction is active, anyone can place a bid by sending an internal message to this contract. If the attached amount of grams is above the current price, it's accepted, and the previous top bid is cancelled (its amount, minus the bidding fee, is returned to the bidder).

Auction ends at the specified end time, or if the current price reaches the buyout price. At that moment a special internal message to a predefined "*notification address*" is generated (to notify some other contract about the completion). Note that the actual transfer of goods to the winner is the responsibility of that contract (or some off-chain script monitoring the blockchain state).

Special case: blind auctions. In this case every participant submits an internal message with a fixed amount of grams, and attaches to a signature of his actual bid. For some predefined time after the auction end, participants provide their bids (and their public keys, so the original signatures can be validated), so the winner can be determined. All non-winning bids are fully returned (minus bidding fees), and winner receives only the difference between the amount he sent and his actual bid.

Owner of the auction contract can withdraw funds at any time on condition that the remaining balance is at least equal to the sum of all currently active top bids (so they can be always returned).

## Initialising a new contract
`./init.fif <workchain-id> <notification-addr> [<filename-base>] [-C <code-fif>]`

This script is used to generate an initalisation message for your contract. It will provide you with a non-bounceable address to send some initial funds to, and after that you can upload to contract's code (using `sendfile` in your TON client).

Note that you're required to specify a "*notification address*" here. After completion of each auction, an internal message with an op = `0x27fca6b9` is generated, containing the following body:
* *op* (32 bits) = `0x27fca6b9`.
* *auction_id* (32 bits) The identifier of the auction.
* *winner_addr* (264 bits) The address of the winner (8-bit workchain and a 256-bit address). If this address is equal to 0, there's no winner (no bids were placed before auction ended).
* *winner_bid* (4-135 bits) The size of the winning bid in nanograms (serialized as usual, 4-bit length + 8*l bits number).
* *auction* (ref to a child cell) The descriptor of the auction right before the completion.

This message does not require any response (so it does not contain a *query_id* field), and can be even bounced back (bounced message will be silently ignored). The only purpose of it is to notify other contract (or outside world) of the auction's completion.

Notification message is not sent when the auction is cancelled.

## Starting a new auction
`./new-auction.fif <contract> <seqno> <auction-id> <auction-type> <end-time> [<decrypt-time> <fixed-amount>] [-s <minimum-step>] [-t <start-time>] [-f <bidding-fee>] [-i <initial-price>] [-b <buyout-price>] [-n <stock-size>] [-O <output-boc>]`

As this contract allows multiple concurrent auctions (or trades), the owner of it needs to create them first with this script.

It has many options, and almost all of them can be sensibly combined with each other. It gives lots of flexibility and covers many different use cases.

List of options:
* *contract* Basename of the contract (path to file containing its private key, without an extension).
* *seqno* Current *seqno* of the contract (can be retrieved using the *seqno* get-method).
* *auction-id* 32-bit identifier of the future auction (any unique number).
* *auction-type* Currently 3 types of auctions are supported:
* * `0`, English (open) auction;
* * `64`, Blind (sealed-bid first-price) auction;
* * `65`, Vickrey (sealed-bid second-price) auction.
* *start-time* Unixtime, the time when this auction starts.
* *end-time* Unixtime, the time when this auction ends.
* *decrypt-time* Unixtime, the time before which all bidders in a sealed-bid auction must present their actual bids.
* *fixed-amount* For sealed-bid auctions: the minimum amount in Grams to be sent with each (encrypted) bid.
* *minimum-step* For open auctions: the minimum difference between bids required to out-bid previous top bidder.
* *bidding-fee* The amount in Grams that won't be returned to losing bidders.
* *initial-price* The minimum amount in Grams, that the first bid in an open auction should be equal to.
* *buyout-price* The amount in Grams which instantly triggers the auction completion.
* *stock-size* The number of times this auction should be repeated automatically.

Some notes about *stock-size*. When the auction with a non-zero stock size completes, it automatically re-created again, but with stock size decreased by 1. So the first internal message to notification address will contain the original value of *stock-size*, the second — *stock-size* - 1, and so on. The actual number of times the auction will be conducted will be equal to *stock-size* + 1. The *start-time* and *end-time* are not updated, those options define the whole time range for all runs of the auction.

When a bid is returned (because someone placed a larger bid), by default no fees are deducted. To prevent draining funds on forwarding fees, it's recommended to always set *bidding-fee* to some small value.

## Cancelling an auction
`./cancel-auction.fif <contract> <seqno> <auction-id> [-O <output-boc>]`

The owner can cancel an auction at any moment. All current bids will be returned to their bidders.

## Placing a bid
`./place-bid.fif <auction-id> [<wallet-addr> <bid-amount> [-B <bid-filename>]] [-O <output-boc>]`

To place a bid in an auction, you need to send **an internal** message to this contract (from your wallet, for example). Such message should contain body with an *op* = 0x64, some arbitrary *query_id* and some other details. This script helps to create it.

For an open auction, the process is simple: only the *auction-id* is required here. After running `place-bid.fif`, you take the generated boc-file, and pass it to your wallet's order creation script as a body.

For blind auctions (first-price or second-price), it's a bit trickier. Your bid should remain secret until the second stage of the auction (*decryption phase*). You provide *auction-id*, your wallet's address (the internal message sender), and the intended bid amount. This script will store this data to a file named `<bid-filename>.boc`, generate a signature for it, and put it to `<output-boc>.boc` (which, again, should be passed to your wallet's order creation script). Keep the file `<bid-filename>.boc` until the auction ends, and after that use `decrypt-bid.fif` script to send a decryption message.

Remember that in a blind auction you specify **the actual bid** here, but attach (a larger) *fixed-amount*, which is specified in an auction descriptor. This allows you to hide the sum you bid (the difference will be returned to you after the auction's completion).

## Decrypt a bid
`./decrypt-bid.fif <contract-addr> <seqno> [-B <bid-filename>] [-O <output-boc>]`

If you participated in a blind auction, you're expected to present your bid after the *end-time*, but before the *decrypt-time* of the auction. You do that by using this script (and passing to it a `<bid-filename>.boc`, created by `place-bid.fif` script).

## Pinging an auction
`./ping-auction.fif <contract-addr> <seqno> <auction-id> [-O <output-boc>]`

After the auction's deadline (defined by *end-time*), anyone can trigger the actual completion event by pinging the contract.

## Withdrawing funds from the contract
`./withdraw.fif <contract> <dest-addr> <seqno> <amount> [-O <output-boc>]`

At any moment, the owner of the contract can withdraw any amount of Grams stored in it, if the remaining balance of enough to pay back all current bids.

## Inspecting cotract's state
`./show-state.fif <data-boc>`

This script will help to examine the current state of the contract. First, you need to download its state using the `saveaccountdata <filename> <addr>` command in the shell of your client. After that you can pass the generated boc-file to this script.

It should output detailed info about cotract's params, list of active auctions and bids. Alternatively, you can use get-methods to inspect those values (see the next section).

# Get methods

In case you've used the default (non-stripped down) version of the contract, it will include some get-methods. You can run them in the TON client using the `runmethod` command. Note that they return raw data, so you may prefer using `show-state.fif` instead (see "Inspecting contract's state" section). 

List of available methods:
* `seqno`
   Returns the current stored value of seqno for this wallet. This method is available in the stripped-down version too.
* `owner_pubkey`
   Returns the public key of this contract's owner.
* `notification_addr`
   Returns the notification address of this contract.
* `reserved_amount`
   Returns the amount of nanograms that are currently reserved (i.e. cannot be withdrawn).
* `auctions`
   Returns the list of currently active auctions.
* `bidders(auction_id)`
   Returns the list of bids in an auction (for an open auction, there's maximum 1 bid at any given time).

# Troubleshooting

After the request is uploaded to TON, there's no practical way to check what's happening with it (until it will be accepted). So if something goes wrong and your message is not accepted by the contract, you can only guess why.

Fortunately, there's couple of scripts that will help in this situation. First, you need to perform `saveaccountdata <filename> <addr>` command in the TON client shell. This will produce a boc-file containing current state of your contract.

Now you can inspect it using `show-state.fif`. Alternatively, you can manually call get-methods of the contract using `test-method.fif` (it should produce the same info, but in raw format).

But most importantly, you can run `test-external.fif` or `test-internal.fif` with a message file (that you were trying to upload) to simulate the execution of the smart contract, and check the TVM output. In addition to builtin errors, there are some error codes that could be thrown:

* Error **33**. *Invalid outer seqno*.
   The current stored seqno is different from the one in the incoming message.
* Error **34**. *Invalid signature*.
   The signature of this message is invalid.
* Error **35**. *Message is expired*.
   The message has a valid_until field set and it's in the past. Note that the provided Fift scripts do not set this field (you can set the expiration time for an order, but not for a message containing it).
* Error **36**. *Auction not found*.
   The auction with that identifier is not found (cancelled, completed, or never existed).
* Error **37**. *Invalid auction type*.
   Decrypting bids is possible only for blind auctions (with *auction-type* >= 64).
* Error **38**. *Auction is not yet ended*.
   It's impossible to decrypt a bid before the auction ends.
* Error **39**. *Decryption timeout*.
   It's too late to decrypt a bid, because *decrypt-time* is in the past.
* Error **40**. *Bid not found*.
   You're trying to decrypt a non-existent bid.
* Error **41**. *Wrong workchain id*.
   The workchain does not match.
* Error **42**. *Invalid bid signature*.
   The provided bid body's signature is not equal to a stored one.
* Error **43**. *This amount is too large to withdraw*.
   By withdrawing the provided amount of Grams, the remaining balance will be less than the currently reserved amount.
* Error **44**. *Duplicate auction id*.
   Auction with this id already exists.
* Error **45**. *Auction's decryption phase is not yet over*.
   You can't ping a blind auction before its decryption phase is over.
* Error **46**. *Auction is not yet started*.
   You can't participate before the auction is started.
* Error **47**. *Auction is already ended*.
   You can't participate after the auction end.
* Error **48**. *Bid is less than bidding fee*.
   Your bid should be at least equal to the bidding fee.
* Error **49**. *Bid is less than initial price*.
   Your bid should be at least equal to the initial price.
* Error **50**. *Difference is less than minimum step*.
   Difference between your bid and current top bid should be at least equal to the minimum step.
* Error **51**. *Bid is less than fixed amount*.
   In a blind auction, your bid should be at least equal to the fixed amount.
* Error **52**. *You already participated in this auction*.
   You can't participate twice in the same blind auction.

For internal messages, instead of throwing errors, the error code is returned as a 32-bit number in the body of the response, after 32-bit *op* (=`0xfffffffe`), 64-bit *query_id*, and 32-bit original *op*.

# Fift words conventions

Fift language is quite flexible, but it can be difficult to read. There's two main reasons for that: stack juggling and no strict conventions for word names. To make the code more readable, some custom conventions were introduced within this repository:

`kebab-case-words()` are helper functions (defined in `common-utils.fif` and `auction-utils.fif`). Note that the name includes the parentheses at the end. (The only exceptions are `maybe,` and `maybe@+`)

`CamelCaseWords` are constants, defined using a `=:` word.

Those styles are chosen to stand out from the builtin words and from each other as much as possible.
