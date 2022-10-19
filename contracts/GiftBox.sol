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
        string description;
    }

    struct WithdrawRequest {
        uint256 amount;
        string title;
        string description;
    }

    // Funds
    address[] fundTokenAddresses;
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
        string description,
        string symbolSuffix,
        string[] references
    );

    // Create a fund
    function createFund(
        string memory name,
        string memory description,
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
            description: description
        });
        fundReferences[fundTokenAddress] = references;

        // Emit event
        emit CreateFund({
            fundTokenAddress: fundTokenAddress,
            manager: msg.sender,
            name: name,
            description: description,
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
}
