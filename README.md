## Remora - FVM Space Warp Hackathon Project 👋

## Demo
https://frontend-remora.vercel.app/

## Inspiration
Storage providers (SPs) have to post $FIL collateral to onboard network storage capacity and accept storage deals. This collateral incentivizes the storage provider to behave
correctly, by presenting timely proofs of the health of the data (PoRep, PoSt), or they risk getting slashed.
While important, the need to pledge collateral creates friction and an immediate barrier that
throttles SP participation and growth. On the other hand, the Filecoin network has a large base
of long-term token holders that would like to see the network grow, and are willing to lend their
FIL to reputable and growth-oriented SPs.
A lending protocol can solve this issue. Storage providers can borrow collateral from lenders and
the smart contract will lock the future income until the storage providers have repaid their loan.

Remora allows a user with liquidity to lend out his $FILs and enhance the network and an SP to borrow collateral-free $FILs and become an SP (or improve its $FIL collateral) by repaying his debt through the rewards it gets from his storage-providing activity.

The idea comes from the following: [https://fvm-forum.filecoin.io/t/lending-pool-cookbook/114](https://fvm-forum.filecoin.io/t/lending-pool-cookbook/114)

## What it does
Remora is a collateral-free $FIL lending and borrowing protocol to facilitate network storage providing. Remora works following an order book model where lenders create loan positions making $FIL available with a certain interest rate and borrowers can take a designated amount based on pledging and collateral requirements in offering computer storage services.

The borrower must repay its debt and the loan interest through the rewards it gets from its storage-providing activity. 

Under the hood, Remora smart contracts interact with the built-in Miner Actor using Filecoin Solidity API libraries.


## Smart contract
There are two smart contracts:

- LenderManager
- Escrow

LenderManager is the core of our lending/borrowing protocol. It is a singleton contract that allows lenders to create lending positions and borrowers to fill them. The contract keeps track of all operations.

When a borrower wants to borrow $FILs, funds are transferred from the LenderManager contract to a new Escrow contract. The LenderManager acts as a factory, using the CREATE2 operation to clone and deploy the Escrow contract for each loan. The Escrow contract is where the $FILs are sent when a borrower takes out a loan.

Before allowing a borrower to take a loan, the LenderManager verifies their reputation using the Filecoin Reputation API ([https://filrep.io/api](https://filrep.io/api)). The API are called using a custom oracle we built for the hackathon.

Once the Escrow contract is deployed, the borrower must set this contract as the owner and beneficiary of their Miner actor. The Escrow contract then confirms it is the owner and beneficiary of the Miner actor. Once confirmed, Escrow sends all $FIL to the Miner actor and the storage provider can begin their activity on the Filecoin blockchain.

## A note for the Miner actor
During the hackathon, we encountered multiple issues using the Filecoin Solidity API. We decided to switch to the mock API. As such, we simulated the behavior of the Miner actor customizing the MinerMockAPI.sol smart contract provided by the library.

## Smart contract address
Lender Manager: 0xaE7eD725f5053471DB2Fc7254dBB2766615f7064 (Hyperspace)

## Backend
The backend built on Lambda is used to implement the Miner reputation control. Specifically, the LenderManager smart contract provides a checkReputation function that takes a Miner Actor address as input and emits the checkReputation(uint256 requestId, uint256 response) event. The backend is listening for the event and does a check of the Miner Actor using the filrep API (https://filrep.io/api). Once checked, the backend calls receiveReputation on the LenderManager smart contract writing the Miner Actor's reputation (Not found, Bad reputation, or Good reputation) on the chain storage.

# Project Setup

Run the following command to setup the project:

```shell
git clone https://github.com/Remora-FilecoinHackathon/smart-contracts
cd smart-contracts
npm i
touch .env
```

Insert your private keys inside the .env file, in a variable called PRIVATE_KEY_LENDER and a variable called PRIVATE_KEY_BORROWER (must be 2 different private keys)
(See here for tutorial on how to export private key from metamask: https://metamask.zendesk.com/hc/en-us/articles/360015289632-How-to-export-an-account-s-private-key)

```properties
PRIVATE_KEY_LENDER=<private_key_exported>
PRIVATE_KEY_BORROWER=<private_key_exported>
ORACLE_PRIVATE_KEY=<private_key_exported>
```

Fund the address related with the private key here: https://hyperspace.yoga/#faucet

Inside the root directory, run the following command:

```shell
npx hardhat run scripts/deploy.ts
```

You should see the following output

<kbd>
<img width="870" alt="Screenshot 2023-01-26 alle 17 47 59" src="https://user-images.githubusercontent.com/56132403/214896991-330bcf0b-1055-4b2a-8e60-e0e0d760527a.png">
</kbd>

# Test

To run the tests run the following command. Add tests to the test directory.

```shell
npx hardhat test --network hardhat
```
