# FlipIt II
Example Solidity Contract and Web3 based UI DAPP. FlipIt II is a update of my FlipIt (https://gihub.com/xactant/flipit) project and simulates a coin flip. The main update is that FlipIt II uses Provable API (https://github.com/provable-things/ethereum-api) to asynchronously request random values from an oracle.

Like the original FlipIt, a player can choose heads or tails and place a bet in eth. If the player wins the toss, the player is paid 2x te amount wagered.

![FlipIt Image](https://raw.githubusercontent.com/xactant/flipit2/master/img/flipit.png)

# Contract
The contract is written in Solidity descends from usingProvable and uses the provable_newRandomDSQuery function to integrate with the random number oracle.

# UI
The UI is a pure JavaScript dApp which uses Bootstrap and JQuery. Integration with the FlipIt contract is accomplished using Web3.
