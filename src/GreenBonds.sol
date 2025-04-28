// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title GreenBonds
/// @notice A smart contract implementing a green bond to support climate and environmental projects
/// @dev Uses AccessControl for role-based permissions
contract GreenBonds is AccessControl, ReentrancyGuard {
    /// @notice Custom errors for better gas efficiency and clearer error messages
    error BondMatured();
    error BondNotMatured();
    error InsufficientBondsAvailable();
    error InvalidBondAmount();
    error NoCouponAvailable();
    error NoBondsToRedeem();
    error PaymentFailed();
    error ReportDoesNotExist();
    error ReportAlreadyVerified();
    error TooEarlyForWithdrawal();
    error InsufficientFunds();
    
    /// @notice Role definitions
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    
    /// @notice Bond details
    /// @dev Core financial parameters of the bond
    string public name;
    string public symbol;
    uint256 public faceValue;
    uint256 public totalSupply;
    uint256 public availableSupply;
    uint256 public couponRate; // in basis points (e.g., 500 = 5.00%)
    uint256 public couponPeriod; // in seconds
    uint256 public maturityDate;
    uint256 public issuanceDate;
    
    // Payment token (e.g., USDC, DAI)
    IERC20 public paymentToken;
    
    // Green project details
    string public projectDescription;
    string public impactMetrics;
    string[] public greenCertifications;
    
    // Environmental impact reports
    struct ImpactReport {
        string reportURI;
        string reportHash;
        uint256 timestamp;
        string impactMetrics;
        bool verified;
    }
    ImpactReport[] public impactReports;
    
    // Bond holdings
    mapping(address => uint256) public bondHoldings;
    
    // Coupon claim tracking
    mapping(address => uint256) public lastCouponClaimDate;
    
    // Events
    event BondPurchased(address indexed investor, uint256 amount, uint256 tokensSpent);
    event CouponClaimed(address indexed investor, uint256 amount);
    event BondRedeemed(address indexed investor, uint256 amount, uint256 tokensReceived);
    event ImpactReportAdded(uint256 indexed reportId, string reportURI);
    event ImpactReportVerified(uint256 indexed reportId);
    event FundsAllocated(string projectComponent, uint256 amount);
    
    /// @notice Constructor initializes the green bond
    /// @param _name Name of the bond
    /// @param _symbol Bond symbol identifier
    /// @param _faceValue Face value of each bond unit
    /// @param _totalSupply Total number of bonds issued
    /// @param _couponRate Annual interest rate in basis points (e.g., 500 = 5.00%)
    /// @param _couponPeriod Time between coupon payments in seconds
    /// @param _maturityPeriod Time until bond matures in seconds
    /// @param _paymentTokenAddress Address of ERC20 token used for payments
    /// @param _projectDescription Description of the green project
    /// @param _impactMetrics Description of environmental impact metrics tracked
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _faceValue,
        uint256 _totalSupply,
        uint256 _couponRate,
        uint256 _couponPeriod,
        uint256 _maturityPeriod,
        address _paymentTokenAddress,
        string memory _projectDescription,
        string memory _impactMetrics
    ) {
        name = _name;
        symbol = _symbol;
        faceValue = _faceValue;
        totalSupply = _totalSupply;
        availableSupply = _totalSupply;
        couponRate = _couponRate;
        couponPeriod = _couponPeriod;
        issuanceDate = block.timestamp;
        maturityDate = block.timestamp + _maturityPeriod;
        paymentToken = IERC20(_paymentTokenAddress);
        projectDescription = _projectDescription;
        impactMetrics = _impactMetrics;
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ISSUER_ROLE, msg.sender);
    }
    
    /// @notice Add a verifier who can validate impact reports
    /// @param verifier Address to be granted verifier role
    /// @dev Only callable by admin
    function addVerifier(address verifier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(VERIFIER_ROLE, verifier);
    }
    
    /// @notice Add a green certification
    /// @param certification String describing the certification (e.g., "LEED Gold")
    /// @dev Only callable by issuer
    function addGreenCertification(string memory certification) external onlyRole(ISSUER_ROLE) {
        greenCertifications.push(certification);
    }
    
    /// @notice Purchase bonds with payment tokens
    /// @param bondAmount The number of bonds to purchase
    /// @dev Transfers payment tokens from buyer to contract
    function purchaseBonds(uint256 bondAmount) external nonReentrant {
        if (block.timestamp >= maturityDate) revert BondMatured();
        if (bondAmount == 0) revert InvalidBondAmount();
        if (bondAmount > availableSupply) revert InsufficientBondsAvailable();
        
        uint256 cost = bondAmount * faceValue;
        
        // Transfer payment tokens from buyer to contract
        if (!paymentToken.transferFrom(msg.sender, address(this), cost)) revert PaymentFailed();
        
        // Update bond holdings
        bondHoldings[msg.sender] = bondHoldings[msg.sender] + bondAmount;
        availableSupply = availableSupply - bondAmount;
        lastCouponClaimDate[msg.sender] = block.timestamp;
        
        emit BondPurchased(msg.sender, bondAmount, cost);
    }
    
    /// @notice Calculate claimable coupon amount for an investor
    /// @param investor The address of the investor
    /// @return uint256 The amount of payment tokens claimable as coupon interest
    /// @dev Returns 0 if investor has no bonds or no time has passed since last claim
    function calculateClaimableCoupon(address investor) public view returns (uint256) {
        if (bondHoldings[investor] == 0) return 0;
        
        uint256 lastClaim = lastCouponClaimDate[investor];
        if (lastClaim == 0) return 0;
        
        // Calculate periods since last claim
        uint256 timeSinceLastClaim = block.timestamp - lastClaim;
        uint256 periods = timeSinceLastClaim / couponPeriod;
        
        if (periods == 0) return 0;
        
        // Calculate coupon amount
        uint256 bondValue = bondHoldings[investor] * faceValue;
        uint256 annualCoupon = bondValue * couponRate / 10000; // Convert basis points to percentage
        uint256 couponPerPeriod = annualCoupon * couponPeriod / 365 days;
        
        return couponPerPeriod * periods;
    }
    
    /// @notice Claim accumulated coupon payments
    /// @dev Calculates claimable amount and transfers payment tokens to the investor
    function claimCoupon() external nonReentrant {
        uint256 claimableAmount = calculateClaimableCoupon(msg.sender);
        if (claimableAmount == 0) revert NoCouponAvailable();
        
        // Update last claim date
        lastCouponClaimDate[msg.sender] = block.timestamp;
        
        // Transfer coupon payment
        if (!paymentToken.transfer(msg.sender, claimableAmount)) revert PaymentFailed();
        
        emit CouponClaimed(msg.sender, claimableAmount);
    }
    
    /// @notice Redeem bonds at maturity
    /// @dev Transfers principal and any outstanding coupon payments to the investor
    function redeemBonds() external nonReentrant {
        if (block.timestamp < maturityDate) revert BondNotMatured();
        if (bondHoldings[msg.sender] == 0) revert NoBondsToRedeem();
        
        uint256 bondAmount = bondHoldings[msg.sender];
        uint256 redemptionValue = bondAmount * faceValue;
        
        // Claim any outstanding coupons first
        uint256 claimableAmount = calculateClaimableCoupon(msg.sender);
        uint256 totalPayment = redemptionValue + claimableAmount;
        
        // Update bond holdings before transfer to prevent reentrancy
        bondHoldings[msg.sender] = 0;
        lastCouponClaimDate[msg.sender] = 0;
        
        // Transfer redemption amount + final coupon
        if (!paymentToken.transfer(msg.sender, totalPayment)) revert PaymentFailed();
        
        emit BondRedeemed(msg.sender, bondAmount, totalPayment);
    }
    
    /// @notice Add environmental impact report for the green project
    /// @param reportURI URI pointing to the full report document
    /// @param reportHash Hash of the report for verification
    /// @param metrics Summary of key environmental metrics
    /// @dev Only callable by issuer
    function addImpactReport(string memory reportURI, string memory reportHash, string memory metrics) 
        external 
        onlyRole(ISSUER_ROLE) 
    {
        ImpactReport memory newReport = ImpactReport({
            reportURI: reportURI,
            reportHash: reportHash,
            timestamp: block.timestamp,
            impactMetrics: metrics,
            verified: false
        });
        
        impactReports.push(newReport);
        emit ImpactReportAdded(impactReports.length - 1, reportURI);
    }
    
    /// @notice Verify an environmental impact report
    /// @param reportId ID of the report to verify
    /// @dev Only callable by addresses with verifier role
    function verifyImpactReport(uint256 reportId) external onlyRole(VERIFIER_ROLE) {
        if (reportId >= impactReports.length) revert ReportDoesNotExist();
        if (impactReports[reportId].verified) revert ReportAlreadyVerified();
        
        impactReports[reportId].verified = true;
        emit ImpactReportVerified(reportId);
    }
    
}