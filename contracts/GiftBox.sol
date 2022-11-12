// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./GiftBoxFundToken.sol";

contract GiftBox {
    // Address of the stablecoin GiftBox accepts as funding
    address public stableCoinAddress;

    struct Fund {
        address manager;
        string name;
        bool isOpen;
        uint256 amountDeposited;
        uint256 balance;
    }

    enum WithdrawRequestStatus {
        Open,
        Executed,
        Failed
    }

    struct WithdrawRequest {
        uint256 amount;
        string title;
        WithdrawRequestStatus status;
        uint256 deadline;
        uint256 numVotesFor;
        uint256 numVotesAgainst;
    }

    // Funds
    address[] public fundTokenAddresses;
    mapping(address => Fund) public funds;
    mapping(address => string[]) public fundReferences;

    function numFunds() public view returns (uint256) {
        return fundTokenAddresses.length;
    }

    function numFundReferences(address fundTokenAddress)
        public
        view
        returns (uint256)
    {
        return fundReferences[fundTokenAddress].length;
    }

    // Withdraw requests for each fund
    mapping(address => WithdrawRequest[]) public withdrawRequests;
    mapping(address => mapping(uint256 => string[]))
        public withdrawRequestReferences;
    mapping(address => mapping(uint256 => mapping(address => bool)))
        public withdrawRequestHasUserVoted;

    function numWithdrawRequests(address fundTokenAddress)
        public
        view
        returns (uint256)
    {
        return withdrawRequests[fundTokenAddress].length;
    }

    function numWithdrawRequestReferences(
        address fundTokenAddress,
        uint256 withdrawRequestId
    ) public view returns (uint256) {
        return
            withdrawRequestReferences[fundTokenAddress][withdrawRequestId]
                .length;
    }

    constructor(address _stableCoinAddress) {
        stableCoinAddress = _stableCoinAddress;
    }

    event CreateFund(
        address fundTokenAddress,
        address manager,
        string name,
        string symbolSuffix,
        string[] references
    );

    // Create a fund
    function createFund(
        string memory name,
        string memory symbolSuffix,
        string[] memory references
    ) public returns (address) {
        // Deploy new ERC20 token for this fund
        GiftBoxFundToken fundToken = new GiftBoxFundToken(name, symbolSuffix);
        address fundTokenAddress = address(fundToken);
        fundTokenAddresses.push(fundTokenAddress);

        // Create new fund object
        funds[fundTokenAddress] = Fund({
            manager: msg.sender,
            name: name,
            isOpen: true,
            amountDeposited: 0,
            balance: 0
        });
        fundReferences[fundTokenAddress] = references;

        // Emit event
        emit CreateFund({
            fundTokenAddress: fundTokenAddress,
            manager: msg.sender,
            name: name,
            symbolSuffix: symbolSuffix,
            references: references
        });

        // Return fund token address for the client
        return fundTokenAddress;
    }

    event DepositStableCoins(
        address fundTokenAddress,
        address depositor,
        uint256 amount
    );

    function depositStableCoins(address fundTokenAddress, uint256 amount)
        public
    {
        // Fund manager cannot deposit money into the fund
        require(
            msg.sender != funds[fundTokenAddress].manager,
            "Fund manager cannot deposit coins into the fund"
        );

        // Transfer stablecoins
        IERC20 stableCoin = IERC20(stableCoinAddress);
        stableCoin.transferFrom(msg.sender, address(this), amount);

        // Mint equal amount of fund tokens
        GiftBoxFundToken fundToken = GiftBoxFundToken(fundTokenAddress);
        fundToken.mint(msg.sender, amount);

        // Increment counters
        funds[fundTokenAddress].amountDeposited += amount;
        funds[fundTokenAddress].balance += amount;

        // Emit event
        emit DepositStableCoins({
            fundTokenAddress: fundTokenAddress,
            depositor: msg.sender,
            amount: amount
        });
    }

    event CreateWithdrawRequest(
        address fundTokenAddress,
        uint256 id,
        uint256 amount,
        string title,
        uint256 deadline,
        string[] references
    );

    function createWithdrawRequest(
        address fundTokenAddress,
        uint256 amount,
        string memory title,
        uint256 deadline,
        string[] memory references
    ) public returns (uint256) {
        // Only the fund manager can create withdraw requests
        require(
            msg.sender == funds[fundTokenAddress].manager,
            "Only the fund manager can create withdraw requests"
        );
        // Deadline must be ahead in the future
        require(deadline > block.timestamp, "Deadline must be in the future");

        uint256 requestId = withdrawRequests[fundTokenAddress].length;

        // Create a new WithdrawRequest object
        withdrawRequests[fundTokenAddress].push(
            WithdrawRequest({
                title: title,
                amount: amount,
                numVotesFor: 0,
                numVotesAgainst: 0,
                status: WithdrawRequestStatus.Open,
                deadline: deadline
            })
        );
        withdrawRequestReferences[fundTokenAddress][requestId] = references;

        emit CreateWithdrawRequest({
            amount: amount,
            fundTokenAddress: fundTokenAddress,
            title: title,
            deadline: deadline,
            references: references,
            id: requestId
        });

        // Return withdraw request ID for the client
        return requestId;
    }

    function voteOnWithdrawRequest(
        address fundTokenAddress,
        uint256 id,
        bool vote
    ) public {
        // Fund manager cannot vote
        require(
            msg.sender != funds[fundTokenAddress].manager,
            "Fund manager cannot vote on withdraw requests"
        );
        // A user cannot vote twice on an withdraw request
        require(
            !withdrawRequestHasUserVoted[fundTokenAddress][id][msg.sender],
            "You have already voted on this withdraw request"
        );
        // Check if voting is open
        require(
            withdrawRequests[fundTokenAddress][id].status ==
                WithdrawRequestStatus.Open,
            "The withdraw request is not open"
        );
        // Make sure deadline hasn't passed
        require(
            withdrawRequests[fundTokenAddress][id].deadline > block.timestamp,
            "The deadline for voting on this withdraw request has passed"
        );

        // Count vote according to fund tokens held by user
        IERC20 fundToken = IERC20(fundTokenAddress);
        uint256 fundTokenBalance = fundToken.balanceOf(msg.sender);
        if (vote) {
            withdrawRequests[fundTokenAddress][id]
                .numVotesFor += fundTokenBalance;
        } else {
            withdrawRequests[fundTokenAddress][id]
                .numVotesAgainst += fundTokenBalance;
        }
        withdrawRequestHasUserVoted[fundTokenAddress][id][msg.sender] = true;
    }

    function executeWithdrawRequest(address fundTokenAddress, uint256 id)
        public
    {
        // Only the fund manager can execute withdraw requests
        require(
            msg.sender == funds[fundTokenAddress].manager,
            "Only the fund manager can execute withdraw requests"
        );
        // Deadline must have passed
        require(
            withdrawRequests[fundTokenAddress][id].deadline < block.timestamp,
            "The withdraw request is still open for voting"
        );
        // Request should be open and not already executed
        require(
            withdrawRequests[fundTokenAddress][id].status ==
                WithdrawRequestStatus.Open,
            "The withdraw request is already either executed or failed"
        );

        // Check if votes are against the request, and mark the request as failed and return if so
        if (
            withdrawRequests[fundTokenAddress][id].numVotesFor <=
            withdrawRequests[fundTokenAddress][id].numVotesAgainst
        ) {
            withdrawRequests[fundTokenAddress][id]
                .status = WithdrawRequestStatus.Failed;
            return;
        }

        // Transfer stablecoins
        IERC20 stableCoin = IERC20(stableCoinAddress);
        stableCoin.transferFrom(
            address(this),
            msg.sender,
            withdrawRequests[fundTokenAddress][id].amount
        );

        // Set withdraw request status and counter
        withdrawRequests[fundTokenAddress][id].status = WithdrawRequestStatus
            .Executed;
        funds[fundTokenAddress].balance -= withdrawRequests[fundTokenAddress][
            id
        ].amount;
    }
}
