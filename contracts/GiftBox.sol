// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GiftBox {
    using Counters for Counters.Counter;

    address public usdcAddress;

    Counters.Counter public fundCount;

    struct Fund {
        address manager;
        string name;
        string description;
        // Links to references, preferably IPFS
        string[] references;
        // Investors and the amount each invested
        address[] investors;
        mapping(address => uint256) tokensInvested;
        WithdrawRequest[] withdrawRequests;
    }

    struct WithdrawRequest {
        string title;
        string description;
        // Links to references, preferably IPFS
        string[] references;
    }

    Fund[] public funds;

    constructor(address _usdcAddress) {
        usdcAddress = _usdcAddress;
    }

    event CreateFund(string name, string description, string[] references);

    // Create a fund
    function createFund(
        string memory name,
        string memory description,
        string[] memory references
    ) public {
        // Get the next empty fund
        Fund storage fund = funds.push();

        // Set the values of the fund
        fund.manager = msg.sender;
        fund.name = name;
        fund.description = description;
        fund.references = references;

        // Emit event
        emit CreateFund({
            name: name,
            description: description,
            references: references
        });
    }

    event DepositTokens(uint256 fundId, uint256 amount);

    function depositTokens(uint256 fundId, uint256 amount) public {
        // Add investor to array of investors if it's his first investment to this fund
        if (funds[fundId].tokensInvested[msg.sender] == 0) {
            funds[fundId].investors.push(msg.sender);
        }
        // Add amount to his total invested amount
        funds[fundId].tokensInvested[msg.sender] += amount;

        // Transfer USDC
        ERC20 usdc = ERC20(usdcAddress);
        usdc.transfer(address(this), amount);

        // Emit event
        emit DepositTokens({fundId: fundId, amount: amount});
    }
}