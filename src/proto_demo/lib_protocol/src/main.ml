(**************************************************************************)
(*                                                                        *)
(*    Copyright (c) 2014 - 2018.                                          *)
(*    Dynamic Ledger Solutions, Inc. <contact@tezos.com>                  *)
(*                                                                        *)
(*    All rights reserved. No warranty, explicit or implicit, provided.   *)
(*                                                                        *)
(**************************************************************************)


type block_header_data = MBytes.t
type block_header = {
  shell : Block_header.shell_header ;
  protocol_data : block_header_data ;
}

let block_header_data_encoding =
  Data_encoding.(obj1 (req "random_data" Variable.bytes))

type block_header_metadata = unit
let block_header_metadata_encoding = Data_encoding.unit

type operation_data = unit
let operation_data_encoding = Data_encoding.unit

type operation_receipt = unit
let operation_receipt_encoding = Data_encoding.unit

let operation_data_and_receipt_encoding =
  Data_encoding.conv
    (function ((), ()) -> ())
    (fun () -> ((), ()))
    Data_encoding.unit

type operation = {
  shell: Operation.shell_header ;
  protocol_data: operation_data ;
}

let max_block_length = 42
let max_operation_data_length = 0
let validation_passes = []
let acceptable_passes _op = []

let compare_operations _ _ = 0

type validation_state = {
  context : Context.t ;
  fitness : Int64.t ;
}

let current_context { context ; _ } =
  return context

module Fitness = struct

  type error += Invalid_fitness
  type error += Invalid_fitness2

  let int64_to_bytes i =
    let b = MBytes.create 8 in
    MBytes.set_int64 b 0 i;
    b

  let int64_of_bytes b =
    if Compare.Int.(MBytes.length b <> 8) then
      fail Invalid_fitness2
    else
      return (MBytes.get_int64 b 0)

  let from_int64 fitness =
    [ int64_to_bytes fitness ]

  let to_int64 = function
    | [ fitness ] -> int64_of_bytes fitness
    | [] -> return 0L
    | _ -> fail Invalid_fitness

  let get { fitness ; _ } = fitness

end

let begin_application
    ~chain_id:_
    ~predecessor_context:context
    ~predecessor_timestamp:_
    ~predecessor_fitness:_
    (raw_block: block_header) =
  Fitness.to_int64 raw_block.shell.fitness >>=? fun fitness ->
  return { context ; fitness }

let begin_partial_application
    ~chain_id
    ~ancestor_context
    ~predecessor_timestamp
    ~predecessor_fitness
    block_header =
  begin_application
    ~chain_id
    ~predecessor_context:ancestor_context
    ~predecessor_timestamp
    ~predecessor_fitness
    block_header

let begin_construction
    ~chain_id:_
    ~predecessor_context:context
    ~predecessor_timestamp:_
    ~predecessor_level:_
    ~predecessor_fitness:pred_fitness
    ~predecessor:_
    ~timestamp:_
    ?protocol_data:_ () =
  Fitness.to_int64 pred_fitness >>=? fun pred_fitness ->
  let fitness = Int64.succ pred_fitness in
  return { context ; fitness }

let apply_operation ctxt _ =
  return (ctxt, ())

let finalize_block ctxt =
  let fitness = Fitness.get ctxt in
  let message = Some (Format.asprintf "fitness <- %Ld" fitness) in
  let fitness = Fitness.from_int64 fitness in
  return ({ Updater.message ; context = ctxt.context ; fitness ;
            max_operations_ttl = 0 ; last_allowed_fork_level = 0l ;
          }, ())

let rpc_services = Services.rpc_services

let init context block_header =
  return { Updater.message = None ; context ;
           fitness = block_header.Block_header.fitness ;
           max_operations_ttl = 0 ;
           last_allowed_fork_level = block_header.level ;
         }
