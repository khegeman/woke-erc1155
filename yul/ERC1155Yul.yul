/**
  author: Kyle Hegeman
  ERC1155 Yul implementation
 */

object "ERC1155Yul" {
  code {
    datacopy(0, dataoffset("Runtime"), datasize("Runtime"))
    return(0, datasize("Runtime"))
  }
  object "Runtime" {
    
    code {

      //storage layout - these are for the mappings
      //mapping(address => mapping(uint256 => uint256)) public balanceMap;
     function balanceSlot() -> slot {
        slot := 0x00
     }
     //mapping(address => mapping(address => bool)) public approveMap;
     function approveSlot() -> slot {
       slot := 0x01
     }
     function uriSlot() -> slot {
      slot := 0x02
     }
     function customUriSlot() -> slot {
      slot := 0x03
     }

      //set initial free memory pointer past the scratch space - following solidity conventions 
      //0x00 - 0x40 are scratch space
      mstore(0x40,0x60)

      //we should put the most used functions first
      switch selector()
      
      case 0xf242432a {  //safeTransferFrom(address,address,uint256,uint256,bytes)

        safeTransferFrom()
      }  
      case 0x2eb2c2d6 { //
        safeBatchTransferFrom() //safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
      }

      case 0x731133e9 /* "mint(address,uint256,uint256,bytes)" */ {
          mint()
      }
      case 0xb48ab8b6 {   //batchMint(address,uint256[],uint256[],bytes)
        batchMint()
      }

      case 0xa22cb465 {
        setApprovalForAll()
      }


      case 0xf5298aca {  //burn(address,uint256,uint256)
        burn()
      }
      case 0xf6eb127a {  //batchBurn(address,uint256[],uint256[])
        batchBurn()
      }      
      
      case 0x0e89341c {  //uri(uint256)
        uri()
      }   
      case 0x3adf80b4 {
        setCustomURI()
      }
      case 0x01ffc9a7 {
        supportsInterface() //supportsInterface(bytes4)
      }

      case 0x02fe5305 {  //setURI(string)
        setURI()
      }   

      case 0xe985e9c5 { /*isApprovedForAll(address,address)*/
        isApprovedForAll()
      }

      case 0x00fdd58e {
        balanceOf()
      }
      case 0x4e1273f4 {
       balanceOfBatch()
      }      



      default {
          revert(0, 0)
      }

      //ABI interface implementation

      function isApprovedForAll(/*address account, address operator*/) {
        let account := calldataload(0x04)
        let operator := calldataload(0x24)        

        mstore(0x00, sload(_approvalSlot(account, operator)))
        return (0x00, 0x20)
      }


      function safeTransferFrom(/*address from, address to, uint256 id, uint256 amount, bytes calldata data*/) {

        let from := calldataload(0x04)
        let to := calldataload(0x24)  
        let id := calldataload(0x44)  
        let amount := calldataload(0x64)  
        let data_offset := add(0x04,calldataload(0x84))

        if iszero(to) {
          _revertERC1155InvalidReceiver(to)
        }
        if iszero(from) {
          _revertERC1155InvalidSender(from)
        }
        _verifyApproval(from)                

        _safeTransferFrom(from,to,id, amount) 

        _onERC1155Received(from, to,id,amount,data_offset )

        _emitTransferSingle(caller(),from,to,id,amount)

      }


      function batchMint(/* address to, uint256[] calldata ids, uint256[] calldata amounts,bytes calldata data */) {
          
        let to := calldataload(0x04)  
        if iszero(to) {
          _revertERC1155InvalidReceiver(to)
        }
        let ids_offset := add(0x04, calldataload(0x24))        
        let amounts_offset := add(0x04, calldataload(0x44))
        let data_offset := add(0x04,calldataload(0x64))

        let alen := calldataload(amounts_offset)
        let ilen := calldataload(ids_offset)

        
        if iszero(eq(alen,ilen)) {
          _revertERC1155InvalidArrayLength(ilen,alen)
        }

        for { let i := 0} lt(i, alen) { i := add(i, 1) } 
        {
           //move to next element 
           amounts_offset := add(amounts_offset, 0x20)
           ids_offset := add(ids_offset, 0x20)
    
           let amount := calldataload(amounts_offset)
           let id := calldataload(ids_offset)
 
           _mint(to,id, amount) 
           
        }
        ids_offset := add(0x04, calldataload(0x24))        
        amounts_offset := add(0x04, calldataload(0x44))
        

        _onERC1155BatchReceived(caller(), 0x00, to,ids_offset, amounts_offset,data_offset)

        _emitTransferBatch(caller(), 0x0, to, ids_offset, amounts_offset) 
      }

      function safeBatchTransferFrom(/*address from, address to, uint256[] ids, uint256[] amounts, bytes calldata data*/) {

        let from := calldataload(0x04)
        let to := calldataload(0x24)  

        if iszero(to) {
          _revertERC1155InvalidReceiver(to)
        }
        if iszero(from) {
          _revertERC1155InvalidSender(from)
        }    
        _verifyApproval(from)    

        let ids_offset := add(0x04, calldataload(0x44))
        let amounts_offset := add(0x04, calldataload(0x64))
        let data_offset := add(0x04,calldataload(0x84))

        let alen := calldataload(amounts_offset)
        let ilen := calldataload(ids_offset)

        if iszero(eq(alen,ilen)) {
          _revertERC1155InvalidArrayLength(ilen,alen)
        }
        
        for { let i := 0} lt(i, alen) { i := add(i, 1) } 
        {
           //move to next element 
           amounts_offset := add(amounts_offset, 0x20)
           ids_offset := add(ids_offset, 0x20)
    
           let amount := calldataload(amounts_offset)
           let id := calldataload(ids_offset)
 
           _safeTransferFrom(from,to,id, amount) 
           

        }
        ids_offset := add(0x04, calldataload(0x44))        
        amounts_offset := add(0x04, calldataload(0x64))        
        _onERC1155BatchReceived(caller(), from, to,ids_offset, amounts_offset,data_offset)

        _emitTransferBatch(caller(), from, to, ids_offset, amounts_offset) 


      }

      function _revert1(signature, param1) {
          mstore(0x00,signature)
          mstore(0x04,param1)
          revert(0x00,0x24)
      }
      function _revert2(signature, param1,param2) {
        let ptr := mload(0x40)
        mstore(ptr,signature)
        mstore(add(ptr,0x04),param1)
        mstore(add(ptr,0x24),param2)    
        revert(ptr,0x44)
    }

    function _revertInvalidOperator(operator) {
      //ERC1155InvalidOperator(address)
      //ced3e100                  
      _revert1(0xced3e10000000000000000000000000000000000000000000000000000000000,operator)  
    }
    function _revertERC1155InvalidArrayLength(idsLength,valuesLength) {
      //ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength)
      //5b059991                  
      _revert2(0x5b05999100000000000000000000000000000000000000000000000000000000,idsLength,valuesLength)  
    }


    function _revertERC1155InsufficientApprovalForAll(operator, from) {
      //ERC1155InsufficientApprovalForAll(address,address)
      _revert2(0x313dd6cb00000000000000000000000000000000000000000000000000000000,operator,from)  
    }
    function _revertERC1155InvalidReceiver(receiver) {    
      //ERC1155InvalidReceiver(address receiver)
      _revert1(0x57f447ce00000000000000000000000000000000000000000000000000000000,receiver)  
    }
    function _revertERC1155InvalidSender(sender) {    
      //ERC1155InvalidSender(address sender)
      _revert1(0x01a8351400000000000000000000000000000000000000000000000000000000,sender)  
    }    
    function _revertERC1155InsufficientBalance(sender,_balance,needed,tokenId) {    
      //ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId)
      let ptr := mload(0x40)
      mstore(ptr,0x03dee4c500000000000000000000000000000000000000000000000000000000)
      mstore(add(ptr,0x04),sender)
      mstore(add(ptr,0x24),_balance)    
      mstore(add(ptr,0x44),needed)    
      mstore(add(ptr,0x64),tokenId)    
      revert(ptr,0x84)

    }        
    

      function setApprovalForAll(/* address operator, bool approved */) {

        //read in parameters 
        let operator := calldataload(0x04)
        let approved := calldataload(0x24)

        if or(eq(caller(),operator),iszero(operator)) {
          _revertInvalidOperator(operator)
        }


        //compute the slot location 
        //for account , the hash is generated from sha3 hash of 2 words.  

        //approveMap[msg.sender][operator]=approved;
      
        sstore(_approvalSlot(caller(), operator), approved)
          //event ApprovalForAll(address indexed account, address indexed operator, bool approved);
          //ApprovalForAll(address,address,bool)
          let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31
          mstore(0, approved)
          log3(0, 0x20, signatureHash, caller(),operator)
      }



      function balanceOf(/* address account, uint256 id */) {
        let account := calldataload(0x04)
        let id := calldataload(0x24)
        mstore(0x00, _balanceOf(account,id))
        return(0x00, 0x20)
      }

      function burn(/* address from, uint256 id,uint256 amount */) {
        let from := calldataload(0x04)
        let id := calldataload(0x24)
        let amount := calldataload(0x44)
        _burn(from,id,amount)
      }

      function batchBurn(/* address from, uint256[] ids,uint256[] amounts */) {
        let from := calldataload(0x04)  
        let ids_offset := add(0x04, calldataload(0x24))        
        let amounts_offset := add(0x04, calldataload(0x44))

        let alen := calldataload(amounts_offset)
        let ilen := calldataload(ids_offset)

        if iszero(eq(alen,ilen)) {
          _revertERC1155InvalidArrayLength(ilen,alen)
        }
        for { let i := 0} lt(i, alen) { i := add(i, 1) } 
        {
           //move to next element 
           amounts_offset := add(amounts_offset, 0x20)
           ids_offset := add(ids_offset, 0x20)
    
           let amount := calldataload(amounts_offset)
           let id := calldataload(ids_offset)
 
           _burn(from,id,amount)
           
        }
        
        
      }

      function balanceOfBatch(/*address[] calldata accounts, uint256[] calldata ids */) {

        let accountsOffset := add(0x04, calldataload(0x04))
        let idsOffset := add(0x04,calldataload(0x24))
        
        let alen := calldataload(accountsOffset)
        let ilen := calldataload(idsOffset)

        if iszero(eq(alen,ilen)) {
          _revertERC1155InvalidArrayLength(ilen,alen)
        }

        let return_ptr := mload(0x40)
        //offset
        mstore(return_ptr, 0x20) 
        let write_ptr := add(return_ptr ,0x20)
        //length
        mstore(write_ptr, alen)

         for { let i := 0} lt(i, alen) { i := add(i, 1) } 
         {
            //move to next element 
            accountsOffset := add(accountsOffset, 0x20)
            idsOffset := add(idsOffset, 0x20)
            write_ptr := add(write_ptr, 0x20 )

            let account := calldataload(accountsOffset)
            let id := calldataload(idsOffset)
  
            mstore(write_ptr,  _balanceOf(account,id))             

         }

        return(return_ptr, add(0x40,mul(alen,0x20)))
  
      }


      function mint(/*address to,uint256 id,uint256 amount,bytes calldata data*/) {
        
        let to := calldataload(0x04)      
        if iszero(to) {
          _revertERC1155InvalidReceiver(to)
        }
        let id := calldataload(0x24)
        let amount := calldataload(0x44)
        let data_offset := add(0x04, calldataload(0x64))

        _mint(to,id,amount)
        _onERC1155Received(0, to,id,amount,data_offset )
        _emitTransferSingle(caller(),0x0,to,id,amount)

      }

      function setURI(/*string*/) {
        _storeABIStringToSlot(uriSlot(), 0x04)     
      }
      function setCustomURI(/*uint256,string */) {
        //find the slot in the map
        let id :=calldataload(0x04)
        

        let slot := _customUriSlot(id)

        //write the string to the slot 
        _storeABIStringToSlot(slot, 0x24)

        //emit the event 
        _emitURI(id, 0x24)
      }

      function supportsInterface(/*bytes4*/) {
        //ERC165 support 

        //supported 
        //ERC165 0x01ffc9a7
        //ERC1155 0xd9b67a26
        //ERC1155MetadataURI 0x0e89341c

        //we can shift signaure right or we can compare vs padded versions
        let signature := shr(224, calldataload(0x04))

        mstore(0x00, or(eq(signature, 0x0e89341c),or(eq(signature, 0x01ffc9a7),eq(signature, 0xd9b67a26))))
        return (0x00,0x20)
      }

      function uri(/*uint256*/) {
        let id :=calldataload(0x04)      
        let cslot := _customUriSlot(id)

        let u := sload(cslot)

        if iszero(u) {
          //no custom found, load the default
          cslot := uriSlot()
          u := sload(cslot)
        }      
        
        let ptr:=mload(0x40)

        //convert from solidity encoded string to abi encoded string         

        //check the lowest order byte for a 1 .  
        let isLongString := and(u,0x1)

        mstore(ptr, 0x20)

        let next := add(ptr, 0x40)
        switch isLongString 
        case 0x00 {
            //get the length. stored in the lowest word as 2x length          
            let length :=shr(0x01,and(u,0xFF))        
            mstore(add(ptr,0x20), length)          
            mstore(next, shl(8, shr(8,u)))
            return(ptr, 0x60)
        }
        default {

            mstore(0x00,cslot)
            let slot := keccak256(0x00,0x20)

            //get the length. stored as 2x length          
            let length :=shr(0x01,u)        
            mstore(add(ptr,0x20), length)          

            let s := 0
            //loop until we have encoded the total length
            for {} gt(length,mul(s,0x20)) {} {
                //load from storage and write to memory
                mstore(next, sload(add(slot,s)))
                s := add(s,1)
                next := add(next, 0x20)
            }
            return(ptr, add(0x40,mul(s,0x20) ))
        }

      }

      //Helper functions 

      function _burn(account, id, amount) {

        let slot := _balanceSlot(account , id)
        let bal := sload(slot)
        if gt(amount, bal) {
          _revertERC1155InsufficientBalance(account,bal,amount,id)          
        }
        sstore(slot, sub(bal, amount))

      }


      function _approvalSlot(account, operator) -> ret {
        mstore(0x00, account)
        mstore(0x20, approveSlot())
        let slot := keccak256(0x00, 0x40)

        mstore(0x00, operator)
        mstore(0x20, slot)
        ret := keccak256(0x00, 0x40)
              
      }
      function _balanceSlot(account, id) -> ret {

        mstore(0x00, account)
        mstore(0x20, balanceSlot())
        let slot := keccak256(0x00, 0x40)

        mstore(0x00, id)
        mstore(0x20, slot)
        ret := keccak256(0x00, 0x40)
              
      }
      function _customUriSlot(id) -> ret {

        mstore(0x00, id)
        mstore(0x20, customUriSlot())
        ret := keccak256(0x00, 0x40)
      }

      function _balanceOf(account, id) -> bal {
        bal := sload(_balanceSlot(account,id))
      }

      //address from, address to, uint256 id, uint256 amount, bytes calldata
      function _safeTransferFrom(from,to,id, amount) {

        let slot := _balanceSlot(from, id)
        let ubalance := sload(slot)
      
        if gt(amount,ubalance) {
            _revertERC1155InsufficientBalance(from,ubalance,amount,id)
        }
        
        sstore(slot, sub(ubalance,amount))

        slot := _balanceSlot(to, id)
        ubalance := sload(slot)
        sstore(slot, _safe_add(ubalance,amount))
      }

      function _emitURI(id, offset) {
        let signatureHash := 0x6bb7ff708619ba0610cba295a58592e0451dee2622938c8755667688daf3529b

        let ptr := mload(0x40)
        let soffset:=calldataload(offset)
        let length := calldataload(add(0x04,soffset))
        mstore(ptr, 0x20)
        mstore(add(ptr,0x20), length)
        calldatacopy(add(ptr,0x40), add(soffset,0x24),length )
        //calldatacopy the string to memory*/
        log2(ptr, add(0x40,mul(add(div(length,0x20),1),0x20)), signatureHash, id)        
      }

      function _emitTransferSingle(operator,from, to,id,amount) {
        let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
        mstore(0, id)
        mstore(0x20, amount)
        //4 indexed 
        log4(0, 0x40, signatureHash, operator,from, to)        
      }

      function _abiArrayCopy(mlocation, clocation,element_size) -> end {
      //small helper to simplify copying an array from calldata into memory for passing to events and callbacks.        
        let length := calldataload(clocation)
        mstore(mlocation, length)
        let byte_count := mul(length, element_size)
        calldatacopy(add(mlocation,0x20),add(clocation,0x20), byte_count)   

        end := add(0x20, byte_count)
      }
      function _emitTransferBatch(operator,from, to,ids_offset,amounts_offset) {
        //TransferBatch(address,address,address,uint256[],uint256[])
        let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb
        let ptr := mload(0x40)
        
        let length := calldataload(ids_offset)
        mstore(ptr, 0x40)

        let id_bytes := _abiArrayCopy(add(ptr,0x40), ids_offset, 0x20)
        let next:=add(0x40, id_bytes)

        mstore(add(ptr,0x20),next )
      
        let amounts_bytes := _abiArrayCopy(add(ptr,next), amounts_offset, 0x20)

        log4(ptr, add(add(id_bytes,amounts_bytes),0x40), signatureHash, operator,from, to)        
      }

      function _safe_add(a, b) -> c {
        c := add(a,b)
        if lt(c, b) {
          //Overflow()
            //keccak256("Panic(uint256)")=4e487b71539e0164c9d29506cc725e49342bcac15e0927282bf30fedfe1c7268
          //Panic(0x11)
          mstore(0x00,0x4e487b7100000000000000000000000000000000000000000000000000000000)
          mstore(0x04,0x11)
          revert(0,0x24)
        }     
      }

      function _mint(to,id,amount) {        
        let slot := _balanceSlot(to,id)
        let ubalance := sload(slot)
 
        //check for overflow before adding
        sstore(slot, _safe_add(ubalance,amount))   
      }
      
      function _onERC1155Received(from, to,id,amount,data_offset) {
        let code := extcodesize(to)
        if gt(code, 0) {


            let ptr := mload(0x40)
            mstore(ptr,shl(0xE0, 0xf23a6e61) )
            mstore(add(ptr,0x04), caller())
            mstore(add(ptr,0x24), from)
            mstore(add(ptr,0x44), id)
            mstore(add(ptr,0x64), amount)
            mstore(add(ptr,0x84), 0xA0) //offset of bytes                

            let datalength := calldataload(data_offset)

            mstore(add(ptr,0xA4), datalength) //length of the bytes     
          
            calldatacopy(add(ptr,0xC4), add(data_offset,0x20),datalength)
            

            let success:= call(gas(), to, 0x00, ptr,add(0xC4,datalength), 0x00,0x20)
            if eq(success,0x00) {
                _revertERC1155InvalidReceiver(to)
                //forward the error back to the caller
                //returndatacopy(0, 0, returndatasize())
                //revert(0, returndatasize())
            }
        
            if iszero(eq(mload(0x00),0xf23a6e6100000000000000000000000000000000000000000000000000000000)) {
              _revertERC1155InvalidReceiver(to)
            }

        }
      }

      function _onERC1155BatchReceived(operator,from,to,ids_offset,amounts_offset,data_offset) {
        let code := extcodesize(to)
        if gt(code, 0) {

          //onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)
          //bc197c819b3e337a6f9652dd10becd7eef83032af3b9d958d3d42f6694146621

            let ptr := mload(0x40)
            mstore(ptr,shl(0xE0, 0xbc197c81) )
            mstore(add(ptr,0x04), operator)
            mstore(add(ptr,0x24), from)
            mstore(add(ptr,0x44), 0xA0)

            let id_bytes := _abiArrayCopy(add(ptr,0xA4), ids_offset, 0x20)
            let next := add(0xA4, id_bytes)

            mstore(add(ptr,0x64), sub(next,0x04))
           
            let amounts_bytes := _abiArrayCopy(add(ptr,next), amounts_offset, 0x20)
            next := add(next, amounts_bytes)

            mstore(add(ptr,0x84), sub(next,0x04))

            let data_bytes := _abiArrayCopy(add(ptr,next), data_offset, 0x01)

            let success:= call(gas(), to, 0x00, ptr,add(0xA4, add(add(id_bytes,amounts_bytes),data_bytes)), 0x00,0x20)
            if eq(success,0x00) {
              _revertERC1155InvalidReceiver(to)               
            }
        
            if iszero(eq(mload(0x00),0xbc197c8100000000000000000000000000000000000000000000000000000000)) {
              _revertERC1155InvalidReceiver(to)
            }            

        }
      }


      function _verifyApproval(from) {
        let approved := eq(caller(), from)
        if iszero(approved) {
            let slot := _approvalSlot(from, caller())  
            approved := sload(slot)
            if iszero(approved) {
              _revertERC1155InsufficientApprovalForAll(caller(), from)
            }
        }        
      }

      function _storeABIStringToSlot(slot, stringOffset) {

        let offset :=calldataload(stringOffset)
        let length:=calldataload(add(0x04, offset))
        let next := add(0x24,offset)
        switch gt(length,31)
        case 0x00  {
            let first:=calldataload(next)    
            sstore(slot, or(first, mul(length,2)))
        } 
        default {
            sstore(slot, add(mul(length, 2),1))
            
            mstore(0x00,slot)
            let sslot := keccak256(0x00,0x20)
            let s:= 0 
            for {} gt(length,mul(s,0x20)) {} {
                sstore(add(sslot,s), calldataload(next))
                s := add(s,1)                    
                next := add(next, 0x20)
            }          
        }        

      }

      //from yul erc20 example
      function selector() -> s {
        s := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
      }

    }
  }
}