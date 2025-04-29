// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/GreenBonds.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1 million tokens to deployer
    }
}

contract GreenBondsTest is Test {
    GreenBonds public greenBonds;
    MockToken public paymentToken;
    
    address public admin = address(1);
    address public issuer = address(2);
    address public verifier = address(3);
    address public investor1 = address(4);
    address public investor2 = address(5);
    
    // Bond parameters
    string public name = "Green Energy Bond";
    string public symbol = "GEB";
    uint256 public faceValue = 1000 * 10**18; // 1000 tokens per bond
    uint256 public totalSupply = 1000; // 1000 bonds
    uint256 public couponRate = 500; // 5.00%
    uint256 public couponPeriod = 90 days; // Quarterly payments
    uint256 public maturityPeriod = 3 * 365 days; // 3 years
    string public projectDescription = "Solar farm in California";
    string public impactMetrics = "CO2 reduction, renewable energy production";
    
    event BondPurchased(address indexed investor, uint256 amount, uint256 tokensSpent);
    event CouponClaimed(address indexed investor, uint256 amount);
    event BondRedeemed(address indexed investor, uint256 amount, uint256 tokensReceived);
    event ImpactReportAdded(uint256 indexed reportId, string reportURI);
    event ImpactReportVerified(uint256 indexed reportId);
    event FundsAllocated(string projectComponent, uint256 amount);
    
    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy mock token and mint some to test accounts
        paymentToken = new MockToken();
        
        // Deploy GreenBonds contract
        greenBonds = new GreenBonds(
            name,
            symbol,
            faceValue,
            totalSupply,
            couponRate,
            couponPeriod,
            maturityPeriod,
            address(paymentToken),
            projectDescription,
            impactMetrics
        );
        
        // Setup roles
        greenBonds.grantRole(greenBonds.ISSUER_ROLE(), issuer);
        greenBonds.addVerifier(verifier);
        
        // Transfer tokens to investors
        paymentToken.transfer(investor1, 5000 * 10**18);
        paymentToken.transfer(investor2, 5000 * 10**18);
        
        vm.stopPrank();
    }
    
    function test_Initialization() public view{
        assertEq(greenBonds.name(), name);
        assertEq(greenBonds.symbol(), symbol);
        assertEq(greenBonds.faceValue(), faceValue);
        assertEq(greenBonds.totalSupply(), totalSupply);
        assertEq(greenBonds.availableSupply(), totalSupply);
        assertEq(greenBonds.couponRate(), couponRate);
        assertEq(greenBonds.couponPeriod(), couponPeriod);
        assertEq(greenBonds.projectDescription(), projectDescription);
        assertEq(greenBonds.impactMetrics(), impactMetrics);
        
        // Check roles
        assertTrue(greenBonds.hasRole(greenBonds.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(greenBonds.hasRole(greenBonds.ISSUER_ROLE(), admin));
        assertTrue(greenBonds.hasRole(greenBonds.ISSUER_ROLE(), issuer));
        assertTrue(greenBonds.hasRole(greenBonds.VERIFIER_ROLE(), verifier));
    }
    

}