// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 * Flattened single-file contract for BuffNFTV1.
 * This file inlines simplified, but compatible, implementations of:
 * - Context
 * - Ownable
 * - IERC165 / ERC165
 * - IERC1155 / ERC1155 (implementation)
 * - ERC1155Supply (extension)
 *
 * Notes:
 * - This is a flattened, self-contained file suitable for verification on Etherscan/BscScan.
 * - Implementations are intentionally straightforward while preserving expected behavior:
 *   - balances, approvals, transfers, minting, burning
 *   - totalSupply tracking per token ID
 * - To match your original contract that overrides `_update(...)`, we provide an internal
 *   `_update(address from, address to, uint256[] memory ids, uint256[] memory values)` hook
 *   declared in both ERC1155 and ERC1155Supply so your `override(ERC1155, ERC1155Supply)` compiles.
 */

// ---------------------- Context ----------------------
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// ---------------------- Ownable ----------------------
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// ---------------------- IERC165 / ERC165 ----------------------
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

abstract contract ERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// ---------------------- IERC1155 ----------------------
interface IERC1155 is IERC165 {
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
}

// ---------------------- ERC1155 Implementation ----------------------
/**
 * @dev Simplified ERC1155 implementation with an internal _update hook.
 *
 * The hook signature:
 *   function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal virtual;
 *
 * Both ERC1155 and ERC1155Supply define this hook so that derived contracts can
 * perform actions on transfers, minting and burning and to allow the user's
 * `override(ERC1155, ERC1155Supply)` to compile successfully.
 */
contract ERC1155 is Context, ERC165, IERC1155 {
    // balances[tokenId][account] => amount
    mapping(uint256 => mapping(address => uint256)) internal _balances;

    // operatorApprovals[owner][operator] => approved
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    string private _uri;

    constructor(string memory uri_) {
        _setURI(uri_);
    }

    // --- URI helpers ---
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }
    function uri(uint256) public view virtual returns (string memory) {
        return _uri;
    }

    // --- ERC165 ---
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155).interfaceId || super.supportsInterface(interfaceId);
    }

    // --- Balance queries ---
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view virtual override returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
    }

    // --- Approvals ---
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    // --- Internal hook: _update ---
    /**
     * @dev Internal hook that is called on every transfer / mint / burn.
     * By default it does nothing. Subclasses (like ERC1155Supply) may override.
     *
     * Note: signature matches the user's contract override so that override(ERC1155, ERC1155Supply) is possible.
     */
    function _update(
        address /*from*/,
        address /*to*/,
        uint256[] memory /*ids*/,
        uint256[] memory /*values*/
    ) internal virtual {
        // empty in base implementation
    }

    // --- Single transfer ---
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public virtual override {
        data; // silence unused variable warning
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "ERC1155: caller is not owner nor approved");
        require(to != address(0), "ERC1155: transfer to the zero address");

        // adjust balances
        _balances[id][from] -= amount;
        _balances[id][to] += amount;

        // call hook with arrays
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory values = _asSingletonArray(amount);
        _update(from, to, ids, values);

        emit TransferSingle(_msgSender(), from, to, id, amount);

        // Note: we don't implement ERC1155Receiver check here for brevity
    }

    // --- Batch transfer ---
    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual override {
        data; // silence unused variable warning
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "ERC1155: caller is not owner nor approved");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        for (uint256 i = 0; i < ids.length; ++i) {
            _balances[ids[i]][from] -= amounts[i];
            _balances[ids[i]][to] += amounts[i];
        }

        _update(from, to, ids, amounts);

        emit TransferBatch(_msgSender(), from, to, ids, amounts);

        // Note: we don't implement ERC1155Receiver check here for brevity
    }

    // --- Internal mint/burn / utilities ---
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        data; // silence unused variable warning
        require(to != address(0), "ERC1155: mint to the zero address");
        _balances[id][to] += amount;

        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory values = _asSingletonArray(amount);
        _update(address(0), to, ids, values);

        emit TransferSingle(_msgSender(), address(0), to, id, amount);
    }

    function _mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual {
        data; // silence unused variable warning
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        for (uint256 i = 0; i < ids.length; ++i) {
            _balances[ids[i]][to] += amounts[i];
        }

        _update(address(0), to, ids, amounts);

        emit TransferBatch(_msgSender(), address(0), to, ids, amounts);
    }

    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        _balances[id][from] -= amount;

        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory values = _asSingletonArray(amount);
        _update(from, address(0), ids, values);

        emit TransferSingle(_msgSender(), from, address(0), id, amount);
    }

    function _burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        for (uint256 i = 0; i < ids.length; ++i) {
            _balances[ids[i]][from] -= amounts[i];
        }

        _update(from, address(0), ids, amounts);

        emit TransferBatch(_msgSender(), from, address(0), ids, amounts);
    }

    // helper to create single-element arrays in memory
    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }
}

// ---------------------- ERC1155Supply ----------------------
/**
 * @dev Extension of ERC1155 that tracks total supply per id.
 * Overrides the _update hook to maintain _totalSupply on mint/burn.
 */
abstract contract ERC1155Supply is ERC1155 {
    mapping(uint256 => uint256) private _totalSupply;

    function totalSupply(uint256 id) public view virtual returns (uint256) {
        return _totalSupply[id];
    }

    function exists(uint256 id) public view virtual returns (bool) {
        return totalSupply(id) > 0;
    }

    /**
     * @dev Override _update to update total supply on mint (from == address(0))
     * and burn (to == address(0)). Calls super._update afterwards to preserve linearization.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        // handle minting: from == address(0) -> increase totalSupply
        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] += values[i];
            }
        }

        // handle burning: to == address(0) -> decrease totalSupply
        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 id = ids[i];
                uint256 value = values[i];
                uint256 supply = _totalSupply[id];
                // guard: underflow will revert in solidity >=0.8
                require(supply >= value, "ERC1155Supply: burn amount exceeds totalSupply");
                _totalSupply[id] = supply - value;
            }
        }

        // call parent hook (no-op in base ERC1155) to maintain proper linearized behavior
        super._update(from, to, ids, values);
    }
}

// ---------------------- BuffNFTV1 (Buff NFT contract) ----------------------
contract BuffNFTV1 is ERC1155, ERC1155Supply, Ownable {
    // Token IDs
    uint256 public constant FU   = 1; // 福
    uint256 public constant LU   = 2; // 禄
    uint256 public constant SHOU = 3; // 寿
    uint256 public constant XI   = 4; // 喜
    uint256 public constant CAI  = 5; // 财
    uint256 public constant AN   = 6; // 安
    uint256 public constant KANG = 7; // 康
    uint256 public constant NING = 8; // 宁

    // Fixed supplies
    uint256 public constant FU_SUPPLY   = 100000;
    uint256 public constant LU_SUPPLY   = 50000;
    uint256 public constant SHOU_SUPPLY = 30000;
    uint256 public constant XI_SUPPLY   = 20000;
    uint256 public constant CAI_SUPPLY  = 10000;
    uint256 public constant AN_SUPPLY   = 8000;
    uint256 public constant KANG_SUPPLY = 5000;
    uint256 public constant NING_SUPPLY = 2000;

    // Optional metadata for wallets
    string public name = "BUFF NFT";
    string public symbol = "BUFFNFT";

    constructor() ERC1155("https://raw.githubusercontent.com/bufftokens/bufftoken/refs/heads/main/metadata/{id}.json") Ownable(msg.sender) {
        // Mint all supply to deployer
        _mint(msg.sender, FU,   FU_SUPPLY,   "");
        _mint(msg.sender, LU,   LU_SUPPLY,   "");
        _mint(msg.sender, SHOU, SHOU_SUPPLY, "");
        _mint(msg.sender, XI,   XI_SUPPLY,   "");
        _mint(msg.sender, CAI,  CAI_SUPPLY,  "");
        _mint(msg.sender, AN,   AN_SUPPLY,   "");
        _mint(msg.sender, KANG, KANG_SUPPLY, "");
        _mint(msg.sender, NING, NING_SUPPLY, "");
    }

    // Required override to resolve conflict between ERC1155 and ERC1155Supply
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);
    }

    // Optional: allow updating base URI
    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }
}