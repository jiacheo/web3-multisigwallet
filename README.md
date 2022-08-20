# web3-multisigwallet

## description
An simple example of multisigwallet working mechanism, may have many security bugs, DO NOT use this code in your products.

## what is the value of multisig-wallet?
### improve transaction security 
When you sign a transaction in a 2/3 multisig model, you hold two signer (two private keys), and the third party hold 
one in the cloud. You can create a transaction and regard the third party signer as a Multi-Factor Authentication, so 
this can improve the transaction security when some one steal away your hot wallet key.

### provide a way to find back your asset 
When you lose your hot wallet key and can't recover it from mnemonic words, don't worry, you can use the cold wallet key
as a signer and the third party signer to sign a transaction to transfer your assets in the contract to another address (account address or contract address).

