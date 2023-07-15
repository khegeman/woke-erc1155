pragma solidity ^0.8.15;

import "./IERC1155.sol";
//import "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

contract ERC1155Impl is IERC1155Errors {
    mapping(address => mapping(uint256 => uint256)) balanceMap;
    mapping(address => mapping(address => bool)) approveMap;
    string internal defaultURI;
    mapping(uint256 => string) customUri;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256) {
        require(account != address(0));
        return balanceMap[account][id];
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory)
    {
        if (ids.length != accounts.length) {
            revert ERC1155InvalidArrayLength(ids.length, accounts.length);
        }
        uint256[] memory balances = new uint[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            balances[i] = balanceMap[accounts[i]][ids[i]];
        }
        return balances;
    }

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external {
        // require(msg.sender != operator);
        if (msg.sender == operator || operator == address(0)) {
            revert ERC1155InvalidOperator(operator);
        }
        approveMap[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool) {
        return approveMap[account][operator];
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) public {
        _safeTransferFrom(from, to, id, amount, data);

        if (to.code.length > 0) {
            if (
                ERC1155TokenReceiver(to).onERC1155Received(msg.sender, from, id, amount, data)
                    != ERC1155TokenReceiver.onERC1155Received.selector
            ) {
                revert ERC1155InvalidReceiver(to);
            }
        }
        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    function _safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata) internal {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(to);
        }
        if (from == address(0)) {
            revert ERC1155InvalidSender(from);
        }
        bool approved = msg.sender == from;
        if (approved == false) {
            approved = approveMap[from][msg.sender];
        }
        if (approved == false) {
            revert ERC1155InsufficientApprovalForAll(msg.sender, from);
        }

        uint256 balance = balanceMap[from][id];

        if (amount > balance) {
            revert ERC1155InsufficientBalance(from, balance, amount, id);
        }
        balanceMap[from][id] -= amount;
        balanceMap[to][id] += amount;
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(to);
        }
        if (ids.length != amounts.length) {
            revert ERC1155InvalidArrayLength(ids.length, amounts.length);
        }
        for (uint256 i = 0; i < ids.length; ++i) {
            _safeTransferFrom(from, to, ids[i], amounts[i], data);
        }
        if (to.code.length > 0) {
            if (
                ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data)
                    != ERC1155TokenReceiver.onERC1155BatchReceived.selector
            ) {
                revert ERC1155InvalidReceiver(to);
            }
        }
        emit TransferBatch(msg.sender, from, to, ids, amounts);
    }

    //ERC 165 support 0x0e89341c
    function supportsInterface(bytes4 signature) external pure returns (bool) {
        return (signature == bytes4(0x01ffc9a7)) || (signature == bytes4(0xd9b67a26)) || (signature == 0x0e89341c);
    }

    function _mint(address to, uint256 id, uint256 amount, bytes calldata data) internal {
        balanceMap[to][id] += amount;
    }

    function mint(address to, uint256 id, uint256 amount, bytes calldata data) public {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(to);
        }
        _mint(to, id, amount, data);
        if (to.code.length > 0) {
            try ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), id, amount, data) returns (
                bytes4 result
            ) {
                if (result != ERC1155TokenReceiver.onERC1155Received.selector) {
                    revert ERC1155InvalidReceiver(to);
                }
            } catch {
                //Exception happens in the event that onERC1155Received isn't implemented on the contract
                revert ERC1155InvalidReceiver(to);
            }
        }

        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }

    function batchMint(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external {
        if (to == address(0)) {
            revert ERC1155InvalidReceiver(to);
        }
        if (ids.length != amounts.length) {
            revert ERC1155InvalidArrayLength(ids.length, amounts.length);
        }
        for (uint256 i = 0; i < ids.length; ++i) {
            _mint(to, ids[i], amounts[i], data);
        }
        if (to.code.length > 0) {
            try ERC1155TokenReceiver(to).onERC1155BatchReceived(msg.sender, address(0), ids, amounts, data) returns (
                bytes4 result
            ) {
                if (result != ERC1155TokenReceiver.onERC1155BatchReceived.selector) {
                    revert ERC1155InvalidReceiver(to);
                }
            } catch {
                //Exception happens in the event that onERC1155BatchReceived isn't implemented on the contract
                revert ERC1155InvalidReceiver(to);
            }
        }
        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
    }

    function batchBurn(address from, uint256[] memory ids, uint256[] memory amounts) external {
        if (from == address(0)) {
            revert ERC1155InvalidSender(from);
        }
        if (ids.length != amounts.length) {
            revert ERC1155InvalidArrayLength(ids.length, amounts.length);
        }
        for (uint256 i = 0; i < ids.length; ++i) {
            burn(from, ids[i], amounts[i]);
        }
    }

    function burn(address from, uint256 id, uint256 amount) public {
        if (from == address(0)) {
            revert ERC1155InvalidSender(from);
        }
        uint256 balance = balanceMap[from][id];
        require(amount <= balance);
        balanceMap[from][id] -= amount;
    }

    function setURI(string memory _uri) external {
        defaultURI = _uri;
    }

    function setCustomURI(uint256 _tokenId, string memory _newURI) external {
        customUri[_tokenId] = _newURI;
        emit URI(_newURI, _tokenId);
    }

    function uri(uint256 _id) external view returns (string memory) {
        // We have to convert string to bytes to check for existence
        bytes memory customUriBytes = bytes(customUri[_id]);
        if (customUriBytes.length > 0) {
            return customUri[_id];
        } else {
            return defaultURI;
        }
    }
}
