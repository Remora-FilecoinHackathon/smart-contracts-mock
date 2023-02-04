// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ILenderManager {

    //-------------------------------- Custom Errors start --------------------------------//
    
    error Empty_Amount();

    error Loan_Period_Excedeed();

    error InterestRate_Too_High(uint256 max);

    error Empty_Lender();

    error Impossible_Borrower(address);

    error Loan_No_More_Available();

    error Miner_Reputation_Value();

    error Miner_Bad_Reputation();

    error No_Borrower_Permissions();

    //-------------------------------- Custom Errors end --------------------------------//

    //-------------------------------- Events start --------------------------------//

    /**
    * @dev Emitted when a new lending deals is added to the market place
    * @param lender address of the lender
    * @param amount the amount of funds put up for the lendind deal
    * @param key the identifier of the lending deal
    * @param endTimestamp the timestamp of the end of the loan
    * @param interestRate the interest rate of the loan
    */
    event LenderPosition(
        address indexed lender,
        uint256 amount,
        uint256 key,
        uint256 endTimestamp,
        uint256 interestRate
    );

    /**
    * @dev Emitted when a borrower accepts a deal
    * @param escrow the address of the contract that handles all transfers for the loan duration
    * @param loanAmount the amount requested by the borrower for the loan
    * @param amountToReapy the total loan amount to repay including the interest
    * @param lenderAmountAvailable the total amount of the loan given by the lender
    * @param startBlock the timestamp of the start of the loan
    * @param amountToPay the periodic amount to repay for the loan
    * @param key identifier of the lending position
    * @param minerActor address of the miner actor
    */
    event BorrowOrder(
        address escrow,
        uint256 loanAmount,
        uint256 amountToReapy,
        uint256 lenderAmountAvailable,
        uint256 startBlock,
        uint256 amountToPay,
        uint256 indexed key,
        address indexed minerActor
    );

    /**
    * @dev Emitted when the reputation of the miner is requested
    * @param requestId the identifier of the request for reputation check of the miner
    * @param minerActor address of the miner
    */
    event CheckReputation(uint256 requestId, address minerActor);

    /**
    * @dev Emitted when the reputation of the miner is received
    * @param requestId the identifier of the request for reputation check of the miner
    * @param response  the reputation of the miner
    * @param minerAddress address of the miner
    */
    event ReputationReceived(uint256 requestId, uint256 response, address minerAddress);

    /**
    * @dev Emitted when the mock miner is deployed
    * @param contractAddress address of the mock miner contract
    * @param owner the owner of the mock miner contract
    */
    event MinerMockAPIDeployed(address contractAddress, address owner);

    //-------------------------------- Events start --------------------------------//

    //-------------------------------- Structs start --------------------------------//

    /**
    * @dev Used to store details about the loans accepted by the borrower
    * @param borrower address of the borrower 
    * @param loanAmount the amount of loan accepted by the borrower
    * @param amountToRepay total amount to repay for the loan including the interest
    * @param startBlock the start timestamp of the loan
    * @param amountToPayEveryBlock the periodic amount to be repaid for the loan
    * @param escrow the address of the escrow contract
    */
    struct BorrowerOrders {
        address borrower;
        uint256 loanAmount;
        uint256 amountToRepay;
        uint256 startBlock;
        uint256 amountToPayEveryBlock;
        address escrow;
    }

    /**
    * @dev Emitted when a new lending position is added to the market place
    * @param lender the address of the lender
    * @param availableAmount the total amount availabel for the loan
    * @param endTimestamp the timestamp of the end of the loan
    * @param interestRate the ineterst rate for the loan
    */
    struct LendingPosition {
        address lender;
        uint256 availableAmount;
        uint256 endTimestamp;
        uint256 interestRate;
    }

    //-------------------------------- Structs end --------------------------------//
}
