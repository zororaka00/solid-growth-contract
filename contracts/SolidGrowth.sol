pragma solidity ^0.8.20;

import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SolidGrowth is ERC721AQueryable, Ownable, ReentrancyGuard {
    string private defaultURI;
    uint256 public constant MIN_INVESTMENT = 50e18; // Minimum 50 USDT
    uint256 public constant MAX_INVESTMENT = 10000e18; // Maximum 10,000 USDT
    uint256 public constant PROFIT_INVESTMENT = 200; // 20%
    uint256 public constant SHARE_PROFIT_DEVELOPER = 500; // 50% from profit owner (up to ~18%)
    uint256 public constant ALLOCATED_INVESTOR = 540; // 54%
    uint256 public constant ALLOCATED_RECRUITER = 450; // 45%
    uint256 public constant ALLOCATED_OWNER = 10; // 1%
    uint256[] public sharePercentageRecruiter = [ // 45% Allocated Recruited
        100, // 10%
        50, // 5%
        30, // 3%
        25, // 2.5%
        20, // 2%
        20, // 2%
        25, // 2.5%
        30, // 3%
        50, // 5%
        100 // 10%
    ];

    IERC20 public tokenUSDT;
    uint256 public currentClaimId;
    mapping(address => address) public lineRecruiter;
    mapping(uint256 => uint256) public nftProofInvestment;

    event Invested(address indexed developerAddress, address indexed referrer, address indexed investor, uint256 amount);
    event Claim(address indexed who, uint256 indexed amount);

    constructor(address _tokenAddress) ERC721A("Solid Growth NFT", "SGNFT") Ownable(_msgSender()) {
        tokenUSDT = IERC20(_tokenAddress);
        currentClaimId = 1;
        lineRecruiter[_msgSender()] = _msgSender();
    }

    function updateBaseURI(string memory _defaultURI) external onlyOwner {
        defaultURI = _defaultURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721A, IERC721A) returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        return defaultURI;
    }

    function _startTokenId() internal override view virtual returns (uint256) {
        return 1;
    }

    /**
     * @dev Function to handle investment transactions. It allows an investor to invest a specific amount
     * and optionally specify a developer address and a referrer.
     * 
     * @param _developerAddress The address of the developer, if any, associated with this investment.
     * This address can potentially receive a share of the investment based on certain contract conditions.
     *
     * @param _referrer The address of the referrer who referred the investor to this investment opportunity.
     * However, it's important to note that if the investor has already been referred by someone in a previous
     * transaction, this parameter will not be applicable anymore. In other words, the initial referrer for 
     * an investor remains constant and cannot be changed in subsequent investments. This ensures the integrity 
     * of the referral system and prevents manipulation.
     *
     * @param _amount The amount of money, in tokens, being invested. This value is expected to comply with 
     * the minimum and maximum investment thresholds set by the contract.
     *
     * The function is marked as `nonReentrant` to prevent reentrancy attacks, ensuring the security of the 
     * transaction process.
    */
    function invest(address _developerAddress, address _referrer, uint256 _amount) public nonReentrant {
        require(lineRecruiter[_referrer] != address(0), "Referrer not found");
        require(_amount % 1000 == 0 && _amount >= MIN_INVESTMENT && _amount <= MAX_INVESTMENT, "Investment amount out of range");
        address who = _msgSender();
        address ownerAddress = owner();
        
        tokenUSDT.transferFrom(who, address(this), _amount * ALLOCATED_INVESTOR / 1000);
        uint256 shareProfitRecruiter = _amount * ALLOCATED_RECRUITER / 1000;
        address uplineAddress;
        if (lineRecruiter[who] == address(0)) {
            lineRecruiter[who] = _referrer;
            uplineAddress = _referrer;
        } else {
            uplineAddress = lineRecruiter[who];
        }

        for (uint256 i = 0; i < sharePercentageRecruiter.length; i++) {
            uint256 profit = _amount * sharePercentageRecruiter[i] / 1000;
            if (uplineAddress == ownerAddress) {
                if (_developerAddress == address(0)) {
                    tokenUSDT.transferFrom(who, ownerAddress, shareProfitRecruiter);
                    break;
                } else {
                    uint256 shareProfitDeveloper = shareProfitRecruiter * SHARE_PROFIT_DEVELOPER / 1000;
                    tokenUSDT.transferFrom(who, _developerAddress, shareProfitDeveloper);
                    tokenUSDT.transferFrom(who, ownerAddress, shareProfitRecruiter - shareProfitDeveloper);
                    break;
                }
            } else {
                shareProfitRecruiter -= profit;
                tokenUSDT.transferFrom(who, uplineAddress, profit);
                uplineAddress = lineRecruiter[uplineAddress] == address(0) ? ownerAddress : lineRecruiter[uplineAddress];
            }
        }

        _mint(who, 1);
        uint256 newTokenId = _nextTokenId() - 1;
        nftProofInvestment[newTokenId] = _amount;

        _shareOwner(ownerAddress, who, _developerAddress, _amount);
        _claim();

        emit Invested(_developerAddress, _referrer, who, _amount);
    }

    function claim() external nonReentrant {
        _claim();
    }

    function _shareOwner(address _owner, address _who, address _developerAddress, uint256 _amount) internal {
        uint256 baseProfitOwner = _amount * ALLOCATED_OWNER / 1000;
        if (_developerAddress == address(0)) {
            tokenUSDT.transferFrom(_who, _owner, baseProfitOwner);
        } else {
            uint256 shareProfitDeveloper = baseProfitOwner * SHARE_PROFIT_DEVELOPER / 1000;
            tokenUSDT.transferFrom(_who, _developerAddress, shareProfitDeveloper);
            tokenUSDT.transferFrom(_who, _owner, baseProfitOwner - shareProfitDeveloper);
        }
    }

    function _claim() internal {
        uint256 claimId = currentClaimId;
        if (_exists(claimId)) {
            address who = ownerOf(claimId);
            uint256 amount = nftProofInvestment[claimId];
            uint256 amountReceived = amount + (amount * PROFIT_INVESTMENT / 1000);
            if (tokenUSDT.balanceOf(address(this)) >= amountReceived) {
                tokenUSDT.transfer(who, amountReceived);
                nftProofInvestment[claimId] = 0;
                currentClaimId++;
                _burn(claimId);

                emit Claim(who, amountReceived);
            }
        }
    }
}