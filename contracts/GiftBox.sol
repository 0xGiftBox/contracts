// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./GiftBoxFundToken.sol";

contract GiftBox {
    address public stableCoinAddress;

    struct Fund {
        address manager;
        string name;
        string description;
        // Links to references, preferably IPFS
        string[] references;
        WithdrawRequest[] withdrawRequests;
    }

    struct WithdrawRequest {
        string title;
        string description;
        // Links to references, preferably IPFS
        string[] references;
    }

    address[] fundTokenAddresses;
    mapping(address => Fund) public funds;

    constructor(address _stableCoinAddress) {
        stableCoinAddress = _stableCoinAddress;
    }

    event CreateFund(
        address fundTokenAddress,
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

        // Set the values of the fund
        Fund storage fund = funds[fundTokenAddress];
        fund.manager = msg.sender;
        fund.name = name;
        fund.description = description;
        fund.references = references;

        // Emit event
        emit CreateFund({
            fundTokenAddress: fundTokenAddress,
            name: name,
            description: description,
            symbolSuffix: symbolSuffix,
            references: references
        });
    }

    event DepositStableCoins(address fundTokenAddress, uint256 amount);

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
            amount: amount
        });
    }
}
