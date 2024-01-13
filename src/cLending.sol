// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Foundry {
    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public loanBalance;
    mapping(address => bool) public isBorrowerLiquidated;
    
    ERC20 public collateralToken;
    ERC20 public loanToken;
    uint256 public loanToValueRatio;
    uint256 public liquidationThreshold;
    
    event CollateralDeposited(address indexed user, uint256 amount);
    event LoanIssued(address indexed user, uint256 amount);
    event LoanRepaid(address indexed user, uint256 amount);
    event CollateralLiquidated(address indexed borrower, uint256 amount);
    
    constructor(address _collateralToken, address _loanToken, uint256 _loanToValueRatio, uint256 _liquidationThreshold) {
        collateralToken = ERC20(_collateralToken);
        loanToken = ERC20(_loanToken);
        loanToValueRatio = _loanToValueRatio;
        liquidationThreshold = _liquidationThreshold;
    }
    
    function depositCollateral(uint256 amount) external {
        require(collateralToken.transferFrom(msg.sender, address(this), amount), "Collateral transfer failed");
        collateralBalance[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }
    
    function borrowAsset(uint256 amount) external {
        require(!isBorrowerLiquidated[msg.sender], "Borrower is liquidated");
        uint256 maxLoanAmount = (collateralBalance[msg.sender] * loanToValueRatio) / 100;
        require(loanBalance[msg.sender] + amount <= maxLoanAmount, "Loan amount exceeds collateral value");
        require(loanToken.transfer(msg.sender, amount), "Loan transfer failed");
        loanBalance[msg.sender] += amount;
        emit LoanIssued(msg.sender, amount);
    }
    
    function repayLoan(uint256 amount) external {
        require(loanBalance[msg.sender] >= amount, "Loan balance insufficient");
        require(loanToken.transferFrom(msg.sender, address(this), amount), "Loan repayment failed");
        loanBalance[msg.sender] -= amount;
        emit LoanRepaid(msg.sender, amount);
    }
    
    function liquidateCollateral(address borrower) external {
        require(isBorrowerLiquidated[borrower] == false, "Borrower is already liquidated");
        uint256 collateralValue = (collateralBalance[borrower] * loanToValueRatio) / 100;
        if (collateralValue < liquidationThreshold) {
            isBorrowerLiquidated[borrower] = true;
            uint256 loanAmount = loanBalance[borrower];
            require(collateralToken.transfer(msg.sender, collateralBalance[borrower]), "Collateral transfer failed");
            require(loanToken.transferFrom(msg.sender, address(this), loanAmount), "Loan repayment failed");
            collateralBalance[borrower] = 0;
            loanBalance[borrower] = 0;
            emit CollateralLiquidated(borrower, collateralBalance[borrower]);
        }
    }
}