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
    }

    enum WithdrawRequestStatus {
        Open,
        Passed,
        Failed
    }

    struct WithdrawRequest {
        uint256 amount;
        string title;
        WithdrawRequestStatus status;
        uint256 numVotesFor;
        uint256 numVotesAgainst;
    }

    // Funds
    address[] fundTokenAddresses;
    mapping(address => Fund) public funds;
    mapping(address => string[]) public fundReferences;
    mapping(address => mapping(address => bool)) public fundClosureHasUserVoted;

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
    ) public {
        // Deploy new ERC20 token for this fund
        GiftBoxFundToken fundToken = new GiftBoxFundToken(name, symbolSuffix);
        address fundTokenAddress = address(fundToken);
        fundTokenAddresses.push(fundTokenAddress);

        // Create new fund object
        funds[fundTokenAddress] = Fund({
            manager: msg.sender,
            name: name,
            isOpen: true
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
    }

    event DepositStableCoins(
        address fundTokenAddress,
        address depositor,
        uint256 amount
    );

    function depositStableCoins(address fundTokenAddress, uint256 amount)
        public
    {
        // Transfer stablecoins
        IERC20 stableCoin = IERC20(stableCoinAddress);
        stableCoin.transferFrom(msg.sender, address(this), amount);

        // Mint equal amount of fund tokens
        GiftBoxFundToken fundToken = GiftBoxFundToken(fundTokenAddress);
        fundToken.mint(msg.sender, amount);

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
        string[] references
    );

    function createWithdrawRequest(
        address fundTokenAddress,
        uint256 amount,
        string memory title,
        string[] memory references
    ) public {
        uint256 requestId = withdrawRequests[fundTokenAddress].length;

        // Create a new WithdrawRequest object
        withdrawRequests[fundTokenAddress].push(
            WithdrawRequest({
                title: title,
                amount: amount,
                numVotesFor: 0,
                numVotesAgainst: 0,
                status: WithdrawRequestStatus.Open
            })
        );
        withdrawRequestReferences[fundTokenAddress][requestId] = references;

        emit CreateWithdrawRequest({
            amount: amount,
            fundTokenAddress: fundTokenAddress,
            title: title,
            references: references,
            id: requestId
        });
    }

    function voteOnWithdrawRequest(
        address fundTokenAddress,
        uint256 id,
        bool vote
    ) public {
        // TODO: Check if user has voted already
        if (vote) {
            withdrawRequests[fundTokenAddress][id].numVotesFor += 1;
        } else {
            withdrawRequests[fundTokenAddress][id].numVotesAgainst += 1;
        }
        withdrawRequestHasUserVoted[fundTokenAddress][id][msg.sender] = true;
    }
}
