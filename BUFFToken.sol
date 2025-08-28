// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BUFFToken {
    string public name = "BUFF";        // Token name
    string public symbol = "BUFF";      // Token symbol
    uint8 public decimals = 18;         // Decimals (standard: 18)
    uint256 public totalSupply;         // Total supply of tokens

    mapping(address => uint256) private balances;                         // Mapping for account balances
    mapping(address => mapping(address => uint256)) private allowances;   // Mapping for allowances

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        // Total supply = 1,000,000,000 * 10^18
        totalSupply = 1_000_000_000 * 10 ** uint256(decimals);
        // Assign all tokens to the contract deployer
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(balances[sender] >= amount, "Insufficient balance");
        require(allowances[sender][msg.sender] >= amount, "Allowance exceeded");

        balances[sender] -= amount;
        balances[recipient] += amount;
        allowances[sender][msg.sender] -= amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }
}
