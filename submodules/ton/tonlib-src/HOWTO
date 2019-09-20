The aim of this document is to provide step-by-step instructions for compiling and creating a simple smart contract (a simple wallet) in the TON Blockchain Test Network using the TON Blockchain Lite Client and associated software.

Download and installation instructions may be found in README. We assume here that the Lite Client is already properly downloaded, compiled and installed.

1. Smart-contract addresses
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Smart-contract addresses in the TON Network consist of two parts: (a) the workchain ID (a signed 32-bit integer) and (b) the address inside the workchain (64-512 bits depending on the workchain). Currently, only the masterchain (workchain_id=-1) and occasionally the basic workchain (workchain_id=0) are running in the TON Blockchain Test Network. Both of them have 256-bit addresses, so we henceforth assume that workchain_id is either 0 or -1 and that the address inside the workchain is exactly 256-bit.

Under the conditions stated above, the smart-contract address can be represented in the following forms:

A) "Raw": <decimal workchain_id>:<64 hexadecimal digits with address>
B) "User-friendly", which is obtained by first generating:
- one tag byte (0x11 for "bounceable" addresses, 0x51 for "non-bounceable"; add +0x80 if the address should not be accepted by software running in the production network)
- one byte containing a signed 8-bit integer with the workchain_id (0x00 for the basic workchain, 0xff for the masterchain)
- 32 bytes containing 256 bits of the smart-contract address inside the workchain (big-endian)
- 2 bytes containing CRC16-CCITT of the previous 34 bytes

In case B), the 36 bytes thus obtained are then encoded using base64 (i.e., with digits, upper- and lowercase Latin letters, '/' and '+') or base64url (with '_' and '-' instead of '/' and '+'), yielding 48 printable non-space characters.

Example:

The "test giver" (a special smart contract residing in the masterchain of the Test Network that gives up to 20 test Grams to anybody who asks) has the address

-1:fcb91a3a3816d0f7b8c2c76108b8a9bc5a6b7a55bd79f8ab101c52db29232260

in the "raw" form (notice that uppercase Latin letters 'A'..'F' may be used instead of 'a'..'f')

and

kf/8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15-KsQHFLbKSMiYIny (base64) 
kf_8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15-KsQHFLbKSMiYIny (base64url)

in the "user-friendly" form (to be displayed by user-friendly clients). Notice that both forms (base64 and base64url) are valid and must be accepted.

Incidentally, other binary data related to the TON Blockchain have similar "armored" base64 representations, differing by their first bytes. For example, the ubiquitious 256-bit Ed25519 public keys are represented by first creating a 36-byte sequence as follows:
- one tag byte 0x3E, meaning that this is a public key
- one tag byte 0xE6, meaning that this is a Ed25519 public key
- 32 bytes containing the standard binary representation of the Ed25519 public key
- 2 bytes containing the big-endian representation of CRC16-CCITT of the previous 34 bytes.

The resulting 36-byte sequence is converted into a 48-character base64 or base64url string in the standard fashion. For example, the Ed25519 public key E39ECDA0A7B0C60A7107EC43967829DBE8BC356A49B9DFC6186B3EAC74B5477D (usually represented by a sequence of 32 bytes 0xE3, 0x9E, ..., 0x7D) has the following "armored" representation:

Pubjns2gp7DGCnEH7EOWeCnb6Lw1akm538YYaz6sdLVHfRB2

2. Inspecting the state of a smart contract
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Inspecting the state of smart contracts with the aid of the TON Lite Client is easy. For the sample smart contract described above, you would run the Lite Client and enter the following commands:

> last
...
> getaccount -1:fcb91a3a3816d0f7b8c2c76108b8a9bc5a6b7a55bd79f8ab101c52db29232260
or
> getaccount kf_8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15-KsQHFLbKSMiYIny

You will see something like this:

------------------------------------
got account state for -1 : FCB91A3A3816D0F7B8C2C76108B8A9BC5A6B7A55BD79F8AB101C52DB29232260 with respect to blocks (-1,8000000000000000,2075):BFE876CE2085274FEDAF1BD80F3ACE50F42B5A027DF230AD66DCED1F09FB39A7:522C027A721FABCB32574E3A809ABFBEE6A71DE929C1FA2B1CD0DDECF3056505
account state is (account
  addr:(addr_std
    anycast:nothing workchain_id:-1 address:xFCB91A3A3816D0F7B8C2C76108B8A9BC5A6B7A55BD79F8AB101C52DB29232260)
  storage_stat:(storage_info
    used:(storage_used
      cells:(var_uint len:1 value:3)
      bits:(var_uint len:2 value:707)
      public_cells:(var_uint len:0 value:0)) last_paid:1568899526
    due_payment:nothing)
  storage:(account_storage last_trans_lt:2310000003
    balance:(currencies
      grams:(nanograms
        amount:(var_uint len:6 value:9998859500889))
      other:(extra_currencies
        dict:hme_empty))
    state:(account_active
      (
        split_depth:nothing
        special:nothing
        code:(just
          value:(raw@^Cell 
            x{}
             x{FF0020DD2082014C97BA9730ED44D0D70B1FE0A4F260D31F01ED44D0D31FD166BAF2A1F8000120D74A8E11D307D459821804A817C80073FB0201FB00DED1A4C8CB1FC9ED54}
            ))
        data:(just
          value:(raw@^Cell 
            x{}
             x{00009A15}
            ))
        library:hme_empty))))
x{CFFFCB91A3A3816D0F7B8C2C76108B8A9BC5A6B7A55BD79F8AB101C52DB2923226020680B0C2EC1C0E300000000226BF360D8246029DFF56534_}
 x{FF0020DD2082014C97BA9730ED44D0D70B1FE0A4F260D31F01ED44D0D31FD166BAF2A1F8000120D74A8E11D307D459821804A817C80073FB0201FB00DED1A4C8CB1FC9ED54}
 x{00000003}
last transaction lt = 2310000001 hash = 73F89C6F8910F598AD84504A777E5945C798AC8C847FF861C090109665EAC6BA
------------------------------------

The first information line "got account state ... for ..." shows the account address and the masterchain block identifier with respect to which the account state has been dumped. Notice that even if the account state changes in a subsequent block, the `getaccount xxx` command will return the same result until the reference block is updated to a newer value by a `last` command. In this way one can study the state of all accounts and obtain consistent results.

The "account state is (account ... " line begins the pretty-printed deserialized view of the account state. It is a deserialization of TL-B data type Account, used to represent account states in the TON Blockchain as explained in the TON Blockchain documentation. (You can find the TL-B scheme used for deserialization in the source file crypto/block/block.tlb; notice that if the scheme is out of date, the deserialization may break down.)

Finally, the last several lines beginning with x{CFF538... (the "raw dump") contain the same information displayed as a tree of cells. In this case, we have one root cell containing the data bits CFF...134_ (the underscore means that the last binary one and all subsequent binary zeroes are to be removed, so hexadecimal "4_" corresponds to binary "0"), and two cells that are its children (displayed with one-space indentation).

We can see that x{FF0020DD20...} is the code of this smart contract. If we consult the Appendix A of the TON Virtual Machine documentation, we can even disassemble this code: FF00 is SETCP 0, 20 is DUP, DD is IFNOTRET, 20 is DUP, and so on. (Incidentally, you can find the source code of this smartcontract in the source file crypto/block/new-testgiver.fif .)

We can also see that x{00009A15} (the actual value you see may be different) is the persistent data of this smart contract. It is actually an unsigned 32-bit integer, used by the smart contract as the counter of operations performed so far. Notice that this value is big-endian (i.e., 3 is encoded as x{00000003}, not as x{03000000}), as are all integers inside the TON Blockchain. In this case the counter is equal to 0x9A15 = 39445.

The current balance of the smart contract is easily seen in the pretty-printed portion of the output. In this case, we see ... balance:(currencies:(grams:(nanograms:(... value:1000000000000000...)))), which is the balance of the account in (test) nanograms (a million test Grams in this example; the actual number you see may be smaller). If you study the TL-B scheme provided in crypto/block/scheme.tlb, you will be able to find this number (10^15) in binary big-endian form in the raw dump portion as well (it is located near the end of the data bits of the root cell).

3. Compiling a new smart contract
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Before uploading a new smart contract into the TON Blockchain, you need to determine its code and data and save them in serialized form into a file (called a "bag-of-cells" or BOC file, usually with a .boc suffix). Let us consider the case of a simple wallet smart contract, which stores a 32-bit operations counter and a 256-bit Ed25519 public key of its owner in its persistent data.

Obviously, you'll need some tools for developing smart contracts - namely, a TON smart contract compiler. Basically, a TON smart contract compiler is a program that reads the source of a smart contract in a specialized high-level programming language and creates a .boc file from this source.

One such tool is the Fift interpreter, which is included in this distribution and can help create simple smart contracts. Larger smart contracts should be developed using more sophisticated tools (such as the FunC compiler included in this distribution, that creates Fift assembler files from FunC source files; you can find some FunC smart-contract sources in the directory `crypto/smartcont`). However, Fift is sufficient for demonstration purposes.

Consider the file `new-wallet.fif` (usually located as `crypto/smartcont/new-wallet.fif` with respect to the source directory) containing the source of a simple wallet smart contract:

------------------------------------
#!/usr/bin/env fift -s
"TonUtil.fif" include
"Asm.fif" include

{ ."usage: " @' $0 type ." <workchain-id> [<filename-base>]" cr
  ."Creates a new wallet in specified workchain, with private key saved to or loaded from <filename-base>.pk" cr
  ."('new-wallet.pk' by default)" cr 1 halt
} : usage
$# 1- -2 and ' usage if

$1 parse-workchain-id =: wc    // set workchain id from command line argument
def? $2 { @' $2 } { "new-wallet" } cond constant file-base

."Creating new wallet in workchain " wc . cr

// Create new simple wallet
<{ SETCP0 DUP IFNOTRET // return if recv_internal
   DUP 85143 INT EQUAL IFJMP:<{ // "seqno" get-method
     DROP c4 PUSHCTR CTOS 32 PLDU  // cnt
   }>
   INC 32 THROWIF  // fail unless recv_external
   512 INT LDSLICEX DUP 32 PLDU   // sign cs cnt
   c4 PUSHCTR CTOS 32 LDU 256 LDU ENDS  // sign cs cnt cnt' pubk
   s1 s2 XCPU            // sign cs cnt pubk cnt' cnt
   EQUAL 33 THROWIFNOT   // ( seqno mismatch? )
   s2 PUSH HASHSU        // sign cs cnt pubk hash
   s0 s4 s4 XC2PU        // pubk cs cnt hash sign pubk
   CHKSIGNU              // pubk cs cnt ?
   34 THROWIFNOT         // signature mismatch
   ACCEPT
   SWAP 32 LDU NIP 
   DUP SREFS IF:<{
     // 3 INT 35 LSHIFT# 3 INT RAWRESERVE    // reserve all but 103 Grams from the balance
     8 LDU LDREF         // pubk cnt mode msg cs
     s0 s2 XCHG SENDRAWMSG  // pubk cnt cs ; ( message sent )
   }>
   ENDS
   INC NEWC 32 STU 256 STU ENDC c4 POPCTR
}>c // >libref
// code
<b 0 32 u, 
   file-base +".pk" load-generate-keypair
   constant wallet_pk
   B, 
b> // data
null // no libraries
// Libs{ x{ABACABADABACABA} drop x{AAAA} s>c public_lib x{1234} x{5678} |_ s>c public_lib }Libs
<b b{0011} s, 3 roll ref, rot ref, swap dict, b>  // create StateInit
dup ."StateInit: " <s csr. cr
dup hash wc swap 2dup 2constant wallet_addr
."new wallet address = " 2dup .addr cr
2dup file-base +".addr" save-address-verbose
."Non-bounceable address (for init): " 2dup 7 .Addr cr
."Bounceable address (for later access): " 6 .Addr cr
<b 0 32 u, b>
dup ."signing message: " <s csr. cr
dup hash wallet_pk ed25519_sign_uint rot
<b b{1000100} s, wallet_addr addr, b{000010} s, swap <s s, b{0} s, swap B, swap <s s, b>
dup ."External message for initialization is " <s csr. cr
2 boc+>B dup Bx. cr
file-base +"-query.boc" tuck B>file
."(Saved wallet creating query to file " type .")" cr
--------------------------------------------

(The actual source file in your distribution may be slighly different.) Essentially, it is a complete Fift script for creating a new instance of this smart contract controlled by a newly-generated keypair. The script accepts command-line arguments, so you don't need to edit the source file each time you want to create a new wallet.

Now, provided that you have compiled Fift binary (usually located as "crypto/fift" with respect to the build directory), you can run

$ crypto/fift -I<source-directory>/crypto/fift/lib -s <source-directory>/crypto/smartcont/new-wallet.fif 0 my_wallet_name

where 0 is the workchain to contain the new wallet (0 = basechain, -1 = masterchain), `my_wallet_name` is any identifier you wish to be associated with this wallet. The address of the new wallet will be saved into file `my_wallet_name.addr`, its newly-generated private key will be saved to `my_wallet_name.pk` (unless this file already exists; then the key will be loaded from this file instead), and the external message will be saved into my_wallet_name-query.boc. If you do not indicate the name of your wallet (`my_wallet_name` in the example above), the default name `new-wallet` is used.

You may opt to set the FIFTPATH environment variable to <source-directory>/crypto/fift/lib:<source-directory>/crypto/smartcont, the directories containing Fift.fif and Asm.fif library files, and the sample smart-contract sources, respectively; then you can omit the -I argument to the Fift interpreter. If you install the Fift binary `crypto/fift` to a directory included in your PATH (e.g., /usr/bin/fift), you can simply invoke

$ fift -s new-wallet.fif 0 my_wallet_name

instead of indicating the complete search paths in the command line.

If everything worked, you'll see something like the following

--------------------------------------------
Creating new wallet in workchain 0 
Saved new private key to file my_wallet_name.pk
StateInit: x{34_}
 x{FF0020DD2082014C97BA9730ED44D0D70B1FE0A4F260810200D71820D70B1FED44D0D31FD3FFD15112BAF2A122F901541044F910F2A2F80001D31F3120D74A96D307D402FB00DED1A4C8CB1FCBFFC9ED54}
 x{00000000C59DC52962CC568AC5E72735EABB025C5BDF457D029AEEA6C2FFA5EB2A945446}

new wallet address = 0:2ee9b4fd4f077c9b223280c35763df9edab0b41ac20d36f4009677df95c3afe2 
(Saving address to file my_wallet_name.addr)
Non-bounceable address (for init): 0QAu6bT9Twd8myIygMNXY9-e2rC0GsINNvQAlnfflcOv4uVb
Bounceable address (for later access): kQAu6bT9Twd8myIygMNXY9-e2rC0GsINNvQAlnfflcOv4rie
signing message: x{00000000}

External message for initialization is x{88005DD369FA9E0EF93644650186AEC7BF3DB5616835841A6DE8012CEFBF2B875FC41190260D403E40B2EE8BEB2855D0F4447679D9B9519BE64BE421166ABA2C66BEAAAF4EBAF8E162886430243216DDA10FCE68C07B6D7DDAA3E372478D711E3E1041C00000001_}
 x{FF0020DD2082014C97BA9730ED44D0D70B1FE0A4F260810200D71820D70B1FED44D0D31FD3FFD15112BAF2A122F901541044F910F2A2F80001D31F3120D74A96D307D402FB00DED1A4C8CB1FCBFFC9ED54}
 x{00000000C59DC52962CC568AC5E72735EABB025C5BDF457D029AEEA6C2FFA5EB2A945446}

B5EE9C724104030100000000E50002CF88005DD369FA9E0EF93644650186AEC7BF3DB5616835841A6DE8012CEFBF2B875FC41190260D403E40B2EE8BEB2855D0F4447679D9B9519BE64BE421166ABA2C66BEAAAF4EBAF8E162886430243216DDA10FCE68C07B6D7DDAA3E372478D711E3E1041C000000010010200A2FF0020DD2082014C97BA9730ED44D0D70B1FE0A4F260810200D71820D70B1FED44D0D31FD3FFD15112BAF2A122F901541044F910F2A2F80001D31F3120D74A96D307D402FB00DED1A4C8CB1FCBFFC9ED54004800000000C59DC52962CC568AC5E72735EABB025C5BDF457D029AEEA6C2FFA5EB2A945446BCF59C17
(Saved wallet creating query to file my_wallet_name-query.boc)
--------------------------------------------

In a nutshell, the Fift assembler (loaded by the "Asm.fif" include line) is used to compile the source code of the smart contract (contained in <{ SETCP0 ... c4 POPCTR }> lines) into its internal representation. The initial data of the smart contract is also created (by <b 0 32 u, ... b> lines), containing a 32-bit sequence number (equal to zero) and a 256-bit public key from a newly-generated Ed25519 keypair. The corresponding private key is saved into the file `my_wallet_name.pk` unless it already exists (if you run this code twice in the same directory, the private key will be loaded from this file instead).

The code and data for the new smart contract are combined into a StateInit structure (in the next lines), the address of the new smart contract (equal to the hash of this StateInit structure) is computed and output, and then an external message with a destination address equal to that of the new smart contract is created. This external message contains both the correct StateInit for the new smart contract and a non-trivial payload (signed by the correct private key).

Finally, the external message is serialized into a bag of cells (represented by B5EE...BE63) and saved into the file `my_wallet_name-query.boc`. Essentially, this file is your compiled smart contract with all additional information necessary to upload it into the TON Blockchain.

4. Transferring some funds to the new smart contract
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You might try to upload the new smart contract immediately by running the Lite Client and typing

> sendfile new-wallet-query.boc

or

> sendfile my_wallet_name-query.boc

if you chose to name your wallet `my_wallet_name`.

Unfortunately, this won't work, because smart contracts must have a positive balance to be able to pay for storing and processing their data in the blockchain. So you have to transfer some funds to your new smart contract address first, displayed during its generation as -1:60c0...c0d0 (in raw form) and 0f9..EKD (in user-friendly form).

In a real scenario, you would either transfer some Grams from your already existing wallet, ask a friend to do so, or buy some Grams at a cryptocurrency exchange, indicating 0f9...EKD as the account to transfer the new Grams to.

In the Test Network, you have another option: you can ask the "test giver" to give you some test Grams (up to 20). Let us explain how to do it.

5. Using the test giver smart contract
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You need to know the address of the test giver smart contract. We'll assume that it is -1:fcb91a3a3816d0f7b8c2c76108b8a9bc5a6b7a55bd79f8ab101c52db29232260, or, equivalently, kf_8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15-KsQHFLbKSMiYIny, as indicated in one of the previous examples. You inspect the state of this smart contract in the Lite Client by typing

> last
> getaccount kf_8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15-KsQHFLbKSMiYIny

as explained above in Section 2. The only number you need from the output is the 32-bit sequence number stored in the smart contract data (it is 0x9A15 in the example above, but generally it will be different). A simpler way of obtaining the current value of this sequence number is by typing

> last
> runmethod kf_8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15-KsQHFLbKSMiYIny seqno

producing the correct value 39445 = 0x9A15:

--------------------------------------------
got account state for -1 : FCB91A3A3816D0F7B8C2C76108B8A9BC5A6B7A55BD79F8AB101C52DB29232260 with respect to blocks (-1,8000000000000000,2240):18E6DA7707191E76C71EABBC5277650666B7E2CFA2AEF2CE607EAFE8657A3820:4EFA2540C5D1E4A1BA2B529EE0B65415DF46BFFBD27A8EB74C4C0E17770D03B1
creating VM
starting VM to run method `seqno` (85143) of smart contract -1:FCB91A3A3816D0F7B8C2C76108B8A9BC5A6B7A55BD79F8AB101C52DB29232260
...
arguments:  [ 85143 ] 
result:  [ 39445 ] 
--------------------------------------------

Next, you create an external message to the test giver asking it to send another message to your (uninitialized) smart contract carrying a specified amount of test Grams. There is a special Fift script for generating this external message located at crypto/smartcont/testgiver.fif:

--------------------------------------------
#!/usr/bin/env fift -s
"TonUtil.fif" include

{ ."usage: " @' $0 type ." <dest-addr> <seqno> <amount> [<savefile>]" cr
  ."Creates a request to TestGiver and saves it into <savefile>.boc" cr
  ."('testgiver-query.boc' by default)" cr 1 halt
} : usage

$# 3 - -2 and ' usage if

// "testgiver.addr" load-address 
Masterchain 0xfcb91a3a3816d0f7b8c2c76108b8a9bc5a6b7a55bd79f8ab101c52db29232260
2constant giver_addr
 ."Test giver address = " giver_addr 2dup .addr cr 6 .Addr cr

$1 true parse-load-address =: bounce 2=: dest_addr
$2 parse-int =: seqno
$3 $>GR =: amount
def? $4 { @' $4 } { "testgiver-query" } cond constant savefile

."Requesting " amount .GR ."to account "
dest_addr 2dup bounce 7 + .Addr ." = " .addr
."seqno=0x" seqno x. ."bounce=" bounce . cr

// create a message (NB: 01b00.., b = bounce)
<b b{01} s, bounce 1 i, b{000100} s, dest_addr addr, 
   amount Gram, 0 9 64 32 + + 1+ 1+ u, "GIFT" $, b>
<b seqno 32 u, 1 8 u, swap ref, b>
dup ."enveloping message: " <s csr. cr
<b b{1000100} s, giver_addr addr, 0 Gram, b{00} s,
   swap <s s, b>
dup ."resulting external message: " <s csr. cr
2 boc+>B dup Bx. cr
savefile +".boc" tuck B>file
."(Saved to file " type .")" cr
---------------------------------------------

You can pass the required parameters as command-line arguments to this script

$ crypto/fift -I<include-path> -s <path-to-testgiver-fif> <dest-addr> <testgiver-seqno> <gram-amount> [<savefile>]

For instance,

$ crypto/fift -I<source-directory>/crypto/fift/lib:<source-directory>/crypto/smartcont -s testgiver.fif 0QAu6bT9Twd8myIygMNXY9-e2rC0GsINNvQAlnfflcOv4uVb 0x9A15 6.666 wallet-query

or simply

$ fift -s testgiver.fif 0QAu6bT9Twd8myIygMNXY9-e2rC0GsINNvQAlnfflcOv4uVb 0x9A15 6.666 wallet-query

provided you have set up the environment variable FIFTPATH to <source-directory>/crypto/fift/lib:<source-directory>/crypto/smartcont and installed the fift binary as /usr/bin/fift (or anywhere else in your PATH).

The newly-created message to the new smart contract must have its bounce bit clear, otherwise the transfer will be "bounced" to its sender. This is the reason we have passed the "non-bounceable" address 0QAu6bT9Twd8myIygMNXY9-e2rC0GsINNvQAlnfflcOv4uVb of our new wallet smart contract.

This Fift code creates an internal message from the test giver smart contract to the address of our new smart contract carrying 6.666 test Grams (you can enter any other amount here up to approximately 20 Grams). Then this message is enveloped into an external message addressed to the test giver; this external message must also contain the correct sequence number of the test giver. When the test giver receives such an external message, it checks whether the sequence number matches the one stored in its persistent data, and if it does, sends the embedded internal message with the required amount of test Grams to its destination (our smart contract in this case).

The external message is serialized and saved into the file `wallet-query.boc`. Some output is generated in the process:

---------------------------------------------
Test giver address = -1:fcb91a3a3816d0f7b8c2c76108b8a9bc5a6b7a55bd79f8ab101c52db29232260 
kf_8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15-KsQHFLbKSMiYIny
Requesting GR$6.666 to account 0QAu6bT9Twd8myIygMNXY9-e2rC0GsINNvQAlnfflcOv4uVb = 0:2ee9b4fd4f077c9b223280c35763df9edab0b41ac20d36f4009677df95c3afe2 seqno=0x9a15 bounce=0 
enveloping message: x{00009A1501}
 x{42001774DA7EA783BE4D91194061ABB1EFCF6D585A0D61069B7A004B3BEFCAE1D7F1280C6A98B4000000000000000000000000000047494654}

resulting external message: x{89FF02ACEEB6F264BCBAC5CE85B372D8616CA2B4B9A5E3EC98BB496327807E0E1C1A000004D0A80C_}
 x{42001774DA7EA783BE4D91194061ABB1EFCF6D585A0D61069B7A004B3BEFCAE1D7F1280C6A98B4000000000000000000000000000047494654}

B5EE9C7241040201000000006600014F89FF02ACEEB6F264BCBAC5CE85B372D8616CA2B4B9A5E3EC98BB496327807E0E1C1A000004D0A80C01007242001774DA7EA783BE4D91194061ABB1EFCF6D585A0D61069B7A004B3BEFCAE1D7F1280C6A98B4000000000000000000000000000047494654AFC17FA4
(Saved to file wallet-query.boc)
---------------------------------------------

6. Uploading the external message to the test giver smart contract
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now we can invoke the Lite Client, check the state of the test giver (if the sequence number has changed, our external message will fail), and then type

> sendfile wallet-query.boc

We will see some output:
... external message status is 1

which means that the external message has been delivered to the collator pool. Afterwards one of the collators might choose to include this external message in a block, creating a transaction for the test giver smart contract to process this external message. We can check whether the state of the test giver has changed:

> last
> getaccount kf_8uRo6OBbQ97jCx2EIuKm8Wmt6Vb15-KsQHFLbKSMiYIny

(If you forget to type `last`, you are likely to see the unchanged state of the test giver smart contract.) The resulting output would be:

---------------------------------------------
got account state for -1 : FCB91A3A3816D0F7B8C2C76108B8A9BC5A6B7A55BD79F8AB101C52DB29232260 with respect to blocks (-1,8000000000000000,2240):18E6DA7707191E76C71EABBC5277650666B7E2CFA2AEF2CE607EAFE8657A3820:4EFA2540C5D1E4A1BA2B529EE0B65415DF46BFFBD27A8EB74C4C0E17770D03B1
account state is (account
  addr:(addr_std
    anycast:nothing workchain_id:-1 address:xFCB91A3A3816D0F7B8C2C76108B8A9BC5A6B7A55BD79F8AB101C52DB29232260)
  storage_stat:(storage_info
    used:(storage_used
      cells:(var_uint len:1 value:3)
      bits:(var_uint len:2 value:707)
      public_cells:(var_uint len:0 value:0)) last_paid:0
    due_payment:nothing)
  storage:(account_storage last_trans_lt:10697000003
    balance:(currencies
      grams:(nanograms
        amount:(var_uint len:7 value:999993280210000))
      other:(extra_currencies
        dict:hme_empty))
    state:(account_active
      (
        split_depth:nothing
        special:nothing
        code:(just
          value:(raw@^Cell 
            x{}
             x{FF0020DDA4F260D31F01ED44D0D31FD166BAF2A1F80001D307D4D1821804A817C80073FB0201FB00A4C8CB1FC9ED54}
            ))
        data:(just
          value:(raw@^Cell 
            x{}
             x{00009A16}
            ))
        library:hme_empty))))
x{CFF8156775B79325E5D62E742D9B96C30B6515A5CD2F1F64C5DA4B193C03F070E0D2068086C00000000000000009F65D110DC0E35F450FA914134_}
 x{FF0020DDA4F260D31F01ED44D0D31FD166BAF2A1F80001D307D4D1821804A817C80073FB0201FB00A4C8CB1FC9ED54}
 x{00000001}
---------------------------------------------

You may notice that the sequence number stored in the persistent data has changed (in our example, to 0x9A16 = 39446), and the last_trans_lt field (the logical time of the last transaction of this account) has been increased.

Now we can inspect the state of our new smart contract:

> getaccount 0QAu6bT9Twd8myIygMNXY9-e2rC0GsINNvQAlnfflcOv4uVb
or
> getaccount 0:2ee9b4fd4f077c9b223280c35763df9edab0b41ac20d36f4009677df95c3afe2
Now we see

---------------------------------------------
got account state for 0:2EE9B4FD4F077C9B223280C35763DF9EDAB0B41AC20D36F4009677DF95C3AFE2 with respect to blocks (-1,8000000000000000,16481):890F4D549428B2929F5D5E0C5719FBCDA60B308BA4B907797C9E846E644ADF26:22387176928F7BCEF654411CA820D858D57A10BBF1A0E153E1F77DE2EFB2A3FB and (-1,8000000000000000,16481):890F4D549428B2929F5D5E0C5719FBCDA60B308BA4B907797C9E846E644ADF26:22387176928F7BCEF654411CA820D858D57A10BBF1A0E153E1F77DE2EFB2A3FB
account state is (account
  addr:(addr_std
    anycast:nothing workchain_id:0 address:x2EE9B4FD4F077C9B223280C35763DF9EDAB0B41AC20D36F4009677DF95C3AFE2)
  storage_stat:(storage_info
    used:(storage_used
      cells:(var_uint len:1 value:1)
      bits:(var_uint len:1 value:111)
      public_cells:(var_uint len:0 value:0)) last_paid:1553210152
    due_payment:nothing)
  storage:(account_storage last_trans_lt:16413000004
    balance:(currencies
      grams:(nanograms
        amount:(var_uint len:5 value:6666000000))
      other:(extra_currencies
        dict:hme_empty))
    state:account_uninit))
x{CFF60C04141C6A7B96D68615E7A91D265AD0F3A9A922E9AE9C901D4FA83F5D3C0D02025BC2E4A0D9400000000F492A0511406354C5A004_}
---------------------------------------------

Our new smart contract has some positive balance (of 6.666 test Grams), but has no code or data (reflected by `state:account_uninit`).

7. Uploading the code and data of the new smart contract
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now you can finally upload the external message with the StateInit of the new smart contract, containing its code and data:

---------------------------------------------
> sendfile my_wallet_name-query.boc
... external message status is 1
> last
...
> getaccount 0QAu6bT9Twd8myIygMNXY9-e2rC0GsINNvQAlnfflcOv4uVb
...
got account state for 0:2EE9B4FD4F077C9B223280C35763DF9EDAB0B41AC20D36F4009677DF95C3AFE2 with respect to blocks (-1,8000000000000000,16709):D223B25D8D68401B4AA19893C00221CF9AB6B4E5BFECC75FD6048C27E001E0E2:4C184191CE996CF6F91F59CAD9B99B2FD5F3AA6F55B0B6135069AB432264358E and (-1,8000000000000000,16709):D223B25D8D68401B4AA19893C00221CF9AB6B4E5BFECC75FD6048C27E001E0E2:4C184191CE996CF6F91F59CAD9B99B2FD5F3AA6F55B0B6135069AB432264358E
account state is (account
  addr:(addr_std
    anycast:nothing workchain_id:0 address:x2EE9B4FD4F077C9B223280C35763DF9EDAB0B41AC20D36F4009677DF95C3AFE2)
  storage_stat:(storage_info
    used:(storage_used
      cells:(var_uint len:1 value:3)
      bits:(var_uint len:2 value:963)
      public_cells:(var_uint len:0 value:0)) last_paid:1553210725
    due_payment:nothing)
  storage:(account_storage last_trans_lt:16625000002
    balance:(currencies
      grams:(nanograms
        amount:(var_uint len:5 value:5983177000))
      other:(extra_currencies
        dict:hme_empty))
    state:(account_active
      (
        split_depth:nothing
        special:nothing
        code:(just
          value:(raw@^Cell 
            x{}
             x{FF0020DDA4F260810200D71820D70B1FED44D0D7091FD709FFD15112BAF2A122F901541044F910F2A2F80001D7091F3120D74A97D70907D402FB00DED1A4C8CB1FCBFFC9ED54}
            ))
        data:(just
          value:(raw@^Cell 
            x{}
             x{00000001F61CF0BC8E891AD7636E0CD35229D579323AA2DA827EB85D8071407464DC2FA3}
            ))
        library:hme_empty))))
x{CFF60C04141C6A7B96D68615E7A91D265AD0F3A9A922E9AE9C901D4FA83F5D3C0D020680F0C2E4A0EB280000000F7BB57909405928024A134_}
 x{FF0020DDA4F260810200D71820D70B1FED44D0D7091FD709FFD15112BAF2A122F901541044F910F2A2F80001D7091F3120D74A97D70907D402FB00DED1A4C8CB1FCBFFC9ED54}
 x{00000001F61CF0BC8E891AD7636E0CD35229D579323AA2DA827EB85D8071407464DC2FA3}
---------------------------------------------

You will see that the smart contract has been initialized using code and data from the StateInit of the external message, and its balance has been slightly decreased because of the processing fees. Now it is up and running, and you can activate it by generating new external messages and uploading them to the TON Blockchain using the "sendfile" command of the Lite Client.

8. Using the simple wallet smart contract
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Actually, the simple wallet smart contract used in this example can be used to transfer test Grams to any other accounts. It is in this respect similar to the test giver smart contract discussed above, with the difference that it processes only external messages signed by the correct private key (of its owner). In our case, it is the private key saved into the file "my_wallet_name.pk" during the compilation of the smart contract (see Section 3).

An example of how you might use this smart contract is provided in sample file crypto/smartcont/wallet.fif :

--------------------------------------------------------
#!/usr/bin/env fift -s
"TonUtil.fif" include

{ ."usage: " @' $0 type ." <filename-base> <dest-addr> <seqno> <amount> [-B <body-boc>] [<savefile>]" cr
  ."Creates a request to simple wallet created by new-wallet.fif, with private key loaded from file <filename-base>.pk "
  ."and address from <filename-base>.addr, and saves it into <savefile>.boc ('wallet-query.boc' by default)" cr 1 halt
} : usage
$# dup 4 < swap 5 > or ' usage if
def? $6 { @' $5 "-B" $= { @' $6 =: body-boc-file [forget] $6 def? $7 { @' $7 =: $5 [forget] $7 } { [forget] $5 } cond
  @' $# 2- =: $# } if } if

true constant bounce

$1 =: file-base
$2 bounce parse-load-address =: bounce 2=: dest_addr
$3 parse-int =: seqno
$4 $>GR =: amount
def? $5 { @' $5 } { "wallet-query" } cond constant savefile

file-base +".addr" load-address
2dup 2constant wallet_addr
."Source wallet address = " 2dup .addr cr 6 .Addr cr
file-base +".pk" load-keypair nip constant wallet_pk

def? body-boc-file { @' body-boc-file file>B B>boc } { <b "TEST" $, b> } cond
constant body-cell

."Transferring " amount .GR ."to account "
dest_addr 2dup bounce 7 + .Addr ." = " .addr 
."seqno=0x" seqno x. ."bounce=" bounce . cr
."Body of transfer message is " body-cell <s csr. cr
  
// create a message
<b b{01} s, bounce 1 i, b{000100} s, dest_addr addr, amount Gram, 0 9 64 32 + + 1+ u, 
  body-cell <s 2dup s-fits? not rot over 1 i, -rot { drop body-cell ref, } { s, } cond
b>
<b seqno 32 u, 1 8 u, swap ref, b>
dup ."signing message: " <s csr. cr
dup hash wallet_pk ed25519_sign_uint
<b b{1000100} s, wallet_addr addr, 0 Gram, b{00} s,
   swap B, swap <s s, b>
dup ."resulting external message: " <s csr. cr
2 boc+>B dup Bx. cr
savefile +".boc" tuck B>file
."(Saved to file " type .")" cr
-------------------------------------

You can invoke this script as follows:

$ fift -I<source-directory>/crypto/fift/lib:<source-directory>/crypto/smartcont -s wallet.fif <your-wallet-id> <destination-addr> <your-wallet-seqno> <gram-amount>

or simply

$ fift -s wallet.fif <your-wallet-id> <destination-addr> <your-wallet-seqno> <gram-amount>

if you have correctly set up PATH and FIFTPATH.

For example,

$ fift -s wallet.fif my_wallet_name kf8Ty2EqAKfAksff0upF1gOptUWRukyI9x5wfgCbh58Pss9j 1 .666

Here `my_wallet_name` is the identifier of your wallet used before with new-wallet.fif; the address and the private key of your test wallet will be loaded from files `my_wallet_name.addr` and `my_wallet_name.pk` in the current directory.

When you run this code (by invoking the Fift interpreter), you create an external message with a destination equal to the address of your wallet smart contract, containing a correct Ed25519 signature, a sequence number, and an enveloped internal message from your wallet smart contract to the smart contract indicated in dest_addr, with an arbitrary value attached and an arbitrary payload. When your smart contract receives and processes this external message, it first checks the signature and the sequence number. If they are correct, it accepts the external message, sends the embedded internal message from itself to the intended destination, and increases the sequence number in its persistent data (this is a simple measure to prevent replay attacks, in case this sample wallet smart contract code ends up used in a real wallet application).

Of course, a true TON Blockchain wallet application would hide all the intermediate steps explained above. It would first communicate the address of the new smart contract to the user, asking them to transfer some funds to the indicated address (displayed in its non-bounceable user-friendly form) from another wallet or a cryptocurrency exchange, and then would provide a simple interface to display the current balance and to transfer funds to whatever other addresses the user wants. (The aim of this document is to explain how to create new non-trivial smart contracts and experiment with the TON Blockchain Test Network, rather than to explain how one could use the Lite Client instead of a more user-friendly wallet application.)

One final remark: The above examples used smart contracts in the basic workchain (workchain 0). They would work in exactly the same way in the masterchain (workchain -1), if one passes workchain identifier -1 instead of 0 as the first argument to `new-wallet.fif`. The only difference is that the processing and storage fees in the basic workchain are 100-1000 times lower than in the masterchain. Some smart contracts (such as the validator election smart contract) accept transfers only from masterchain smart contracts, so you'll need a wallet in the masterchain if you wish to make stakes on behalf of your own validator and participate in the elections.
