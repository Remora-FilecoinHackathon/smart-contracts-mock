// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "./mocks/MinerMockAPI.sol";
import "./ILenderManager.sol";
import "./Escrow.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/utils/Actor.sol";
import "@zondax/filecoin-solidity/contracts/v0.8/utils/Misc.sol";

/**
 * @title LenderManager Contract implements methods for the lender marketplace
 * @notice Implements the functions for the lenders to publish deals
 * @author Remora
 **/

contract LenderManager is ILenderManager {

    //-------------------------------- LenderManager state variables start --------------------------------//

    // Mapping to store lending positions
    mapping(uint256 => LendingPosition) public positions;

    // Mapping to store Escrow contracts of a Borrower
    mapping(address => address[]) public borrowerPositions;

    // Mapping to store the addresses of the escrow contracts deployed
    mapping(uint256 => address[]) public escrowContracts;

    // Mapping to store the reputation requests for the borrowers
    mapping(uint256 => address) public reputationRequest;

    // Mapping to store the reputations of the borrowers
    mapping(address => uint256) public reputationResponse;

    // Mapping to store the mock miner actor used
    mapping(address => address) public ownerToMinerActor;

    // identifiers for the lending positions
    uint256[] public loanKeys;

    // Current id counter
    uint256 public currentId = 0;

    // Address of the oracle
    address public oracle;
    //-------------------------------- LenderManager state variables end --------------------------------//

    //-------------------------------- Constants start --------------------------------//

    // Deafult reputation value
    uint256 constant MINER_REPUTATION_DEFAULT = 0;

    // Bad reputation value
    uint256 constant MINER_REPUTATION_BAD = 1;

    // Good reputation value
    uint256 constant MINER_REPUTATION_GOOD = 2;

    // Loan repayment interval
    uint256 constant REPAY_LOAN_INTERVAL = 30 days;

    // bytes private constant ALPHABET = "0123456789abcdef";

    //-------------------------------- Constants end --------------------------------//

    //-------------------------------- Modifiers start --------------------------------//

    /**
     * @dev checks if called by oracle
     **/
    modifier onlyOracle() {
        require(msg.sender == oracle);
        _;
    }

    //-------------------------------- Modifiers end --------------------------------//

    //-------------------------------- Initialize code start --------------------------------//

    /**
    * @dev Used to initialize variables in the contract
    * @param _oracle the address of the oracle
    */
    constructor(address _oracle) {
        oracle = _oracle;
    }

    //-------------------------------- Initialize code end --------------------------------//

    /**
    * @dev Used to create lending deals
    * @param duration the duration of the loan deal
    * @param loanInterestRate the ineterst rate for the loan deal
    */
    function createLendingPosition(uint256 duration, uint256 loanInterestRate)
        public
        payable
    {
        if (msg.value <= 0) revert Empty_Amount();
        if (block.timestamp >= duration) revert Loan_Period_Excedeed();
        if (loanInterestRate >= 10000) revert InterestRate_Too_High(10000);

        // generate pseudo-random key used to manage Lending positions
        uint256 key = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    msg.sender,
                    blockhash(block.number - 1)
                )
            )
        );
        positions[key] = LendingPosition(
            msg.sender,
            msg.value,
            duration,
            loanInterestRate
        );
        loanKeys.push(key);
        emit LenderPosition(
            msg.sender,
            msg.value,
            key,
            duration,
            loanInterestRate
        );
    }

    /**
    * @dev Used by the borrower to accept lending deals
    * @param loanKey the identifier of the loan
    * @param amount the amount to loan from the lender
    * @param minerActorAddress the address of the miner 
    */
    function createBorrow(
        uint256 loanKey,
        uint256 amount,
        address payable minerActorAddress
    ) public {
        if (positions[loanKey].lender == address(0)) revert Empty_Lender();
        if (msg.sender == positions[loanKey].lender)
            revert Impossible_Borrower(msg.sender);
        if (
            amount > positions[loanKey].availableAmount ||
            block.timestamp > positions[loanKey].endTimestamp
        ) revert Loan_No_More_Available();
        if (reputationResponse[minerActorAddress] != MINER_REPUTATION_GOOD) {
            revert Miner_Bad_Reputation();
        }
        if (!isControllingAddress(minerActorAddress))
            revert No_Borrower_Permissions();
        (uint256 rate, uint256 amountToRepay) = calculateInterest(
            amount,
            positions[loanKey].interestRate
        );
        Escrow escrow = new Escrow{
            salt: bytes32(abi.encodePacked(uint40(block.timestamp)))
        }(
            positions[loanKey].lender,
            msg.sender,
            minerActorAddress,
            amountToRepay,
            rate,
            REPAY_LOAN_INTERVAL,
            positions[loanKey].endTimestamp
        );
        (bool sent, ) = address(escrow).call{value: amount}("");
        require(sent, "Failed send to escrow");
        positions[loanKey].availableAmount -= amount;
        escrowContracts[loanKey].push(payable(address(escrow)));
        borrowerPositions[msg.sender].push(payable(address(escrow)));
        
        emit BorrowOrder(
            address(escrow),
            amount,
            amountToRepay,
            positions[loanKey].availableAmount,
            block.timestamp,
            rate,
            loanKey,
            minerActorAddress
        );
    }

    /**
    * @dev Used to deploy the mock miner
    */
    function deployMockMinerActor() public {
        MinerMockAPI mock = new MinerMockAPI{
            salt: bytes32(abi.encodePacked(uint40(block.timestamp)))
        }(msg.sender);

        ownerToMinerActor[msg.sender] = address(mock);
        emit MinerMockAPIDeployed(address(mock), msg.sender);
    }

    /**
    * @dev Used to check reputation of the miner address
    * @param minerActorAddress address of the miner
    */
    function checkReputation(address minerActorAddress) public {
        uint256 id = currentId;
        reputationRequest[id] = minerActorAddress;
        incrementId();
        emit CheckReputation(id, minerActorAddress);
    }

    /**
    * @dev Used to receive the reputation score of a miner
    * @param requestId identifier for the reputation requestof the miner
    * @param response the reputation score
    */
    function receiveReputationScore(uint256 requestId, uint256 response)
        external
        onlyOracle
    {
        if (
            response != MINER_REPUTATION_GOOD &&
            response != MINER_REPUTATION_BAD
        ) revert Miner_Reputation_Value();
        address miner = reputationRequest[requestId];
        reputationResponse[miner] = response;
        emit ReputationReceived(requestId, response, miner);
    }

    /**
    * @dev Used to check if miner is the controlling address
    * @param minerActorAddress address of the miner
    * @return is_controlling boolen implying if miner is controlling address 
    */
    function isControllingAddress(address payable minerActorAddress)
        public
        returns (bool)
    {
        MinerTypes.IsControllingAddressParam memory params = MinerTypes
            .IsControllingAddressParam(abi.encodePacked(msg.sender));
        MinerTypes.IsControllingAddressReturn memory returnValue = MinerMockAPI(
            minerActorAddress
        ).isControllingAddress(params);
        return returnValue.is_controlling;
    }

    /**
    * @dev Used to calculate the interest of the loan
    * @param amount the loan amount to calculate interest on
    * @param bps the interest rate of the loan, if 10% then bps = 10 * 100
    * @return rateAmount the monthly payable amount
    * @return loanAmount the total loan amount, including the interest
    */
    function calculateInterest(uint256 amount, uint256 bps)
        public
        pure
        returns (uint256, uint256)
    {
        uint256 computedAmount = amount * bps;
        require(computedAmount >= 10_000, "wrong math");
        uint256 computed = (computedAmount / 10_000);
        // using 833 bps returns the monthly rate to pay
        return (
            calculatePeriodicaInterest(
                ((computedAmount + amount) / 10_00),
                833
            ),
            ((computed + amount))
        );
    }

    /**
    * @dev Used to calculate the periodical interest payable
    * @param amount the loan amount to calculate interest on
    * @param bps the interest rate of the loan, if 10% then bps = 10 * 100
    * @return rateAmount the monthly payable amount
    */
    function calculatePeriodicaInterest(uint256 amount, uint256 bps)
        private
        pure
        returns (uint256)
    {
        require((amount * bps) >= 10_000, "wrong math");
        return ((amount * bps) / 10_000);
    }

    /**
    * @dev Used to increment he current id counter
    * @return currentId updated value of the current id
    */
    function incrementId() private returns (uint256) {
        return currentId += 1;
    }

    /**
    * @dev Used to get the total number of available leanding deals in the market place
    * @return deals the number of lending deals available
    */
    function getLoanKeysLength() public view returns (uint256) {
        return loanKeys.length;
    }
}
