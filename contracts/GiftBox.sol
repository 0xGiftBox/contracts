// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./GiftBoxToken.sol";

contract GiftBox {
    address public usdcAddress;

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

    address[] fundTokens;
    mapping(address => Fund) public funds;

    constructor(address _usdcAddress) {
        usdcAddress = _usdcAddress;
    }

    event CreateFund(
        address fundToken,
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
        GiftBoxToken fundTokenContract = new GiftBoxToken(name, symbolSuffix);
        address fundToken = address(fundTokenContract);

        // Set the values of the fund
        Fund storage fund = funds[fundToken];
        fund.manager = msg.sender;
        fund.name = name;
        fund.description = description;
        fund.references = references;

        // Emit event
        emit CreateFund({
            fundToken: fundToken,
            name: name,
            description: description,
            symbolSuffix: symbolSuffix,
            references: references
        });
    }

    event DepositTokens(address fundToken, uint256 amount);

    function depositTokens(address fundToken, uint256 amount) public {
        // Transfer USDC
        IERC20 usdcContract = IERC20(usdcAddress);
        usdcContract.transferFrom(msg.sender, address(this), amount);

        // Mint equal amount of fund tokens
        GiftBoxToken fundTokenContract = GiftBoxToken(fundToken);
        fundTokenContract.mint(msg.sender, amount);

        // Emit event
        emit DepositTokens({fundToken: fundToken, amount: amount});
    }
}
