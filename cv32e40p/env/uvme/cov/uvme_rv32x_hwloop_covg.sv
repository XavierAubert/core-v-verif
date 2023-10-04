///////////////////////////////////////////////////////////////////////////////
// Copyright 2020 OpenHW Group
// Copyright 2023 Dolphin Design
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//      http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 
///////////////////////////////////////////////////////////////////////////////

// Note: 
// 1) This coverage model complements Imperas coverage XPULPV2 with addtional coverage collection on hwloop feature and its csr registers
// 2) It uses RVVItrace interface
// 3) Currently implementation only covers for NHART=1 and RETIRE=1 (e.g rvvi_vif.<sig>[0][0])

`ifndef UVME_RV32X_HWLOOP_COVG
`define UVME_RV32X_HWLOOP_COVG

class uvme_rv32x_hwloop_covg #(
  parameter int NHART   = 1,
  parameter int RETIRE  = 1
) extends uvm_component;

  localparam SKIP_RVVI_INIT_VALID_CNT = 1;
  localparam HWLOOP_NB = 2;
  localparam CSR_LPSTART0_ADDR = 32'hCC0;
  localparam CSR_LPEND0_ADDR   = 32'hCC1;
  localparam CSR_LPCOUNT0_ADDR = 32'hCC2;

  typedef enum bit [1:0] {NULL_TYPE=0, SINGLE, NESTED}  hwloop_type_t;
  typedef enum bit [1:0] {NULL_SETUP=0, SHORT, LONG}    hwloop_setup_t;
  typedef struct {
    bit [31:0] lp_start     [HWLOOP_NB];
    bit [31:0] lp_end       [HWLOOP_NB];
    bit [31:0] lp_count     [HWLOOP_NB];
    bit        lp_start_wb  [HWLOOP_NB];
    bit        lp_end_wb    [HWLOOP_NB];
    bit        lp_count_wb  [HWLOOP_NB];
  } s_csr_hwloop;
  typedef struct {
    hwloop_type_t   hwloop_type;
    hwloop_setup_t  hwloop_setup [HWLOOP_NB];
    s_csr_hwloop    hwloop_csr;
    bit             execute_instr_in_hwloop [HWLOOP_NB];
    bit [31:0]      track_lp_count [HWLOOP_NB];
  } s_hwloop_stat;

  local s_csr_hwloop  csr_hwloop_init   = '{default:0};
  local s_csr_hwloop  csr_hwloop        = '{default:0};
  local s_hwloop_stat hwloop_stat_init  = '{default:0, hwloop_type:NULL_TYPE, hwloop_setup:'{default:NULL_SETUP}};
  local s_hwloop_stat hwloop_stat       = '{default:0, hwloop_type:NULL_TYPE, hwloop_setup:'{default:NULL_SETUP}};
  local bit [31:0]    insn_list_in_hwloop     [HWLOOP_NB][$];
  local bit           done_insn_list_capture  [HWLOOP_NB] = '{default:0};
  local bit           done_hwloop_stat_assign [HWLOOP_NB] = '{default:0};

  virtual rvviTrace #( .NHART(NHART), .RETIRE(RETIRE)) rvvi_vif;
  string  _header = "XPULPV2_HWLOOP_COV";

  // COVERGROUPS DEFINE HERE - START

  // todo: more organize way is to use `define macro to define covergroup
  covergroup cg_csr_hwloop with function sample(s_csr_hwloop csr_hwloop);
    option.per_instance         = 1;
    option.get_inst_coverage    = 1;
    type_option.merge_instances = 1;

    cp_lpstart_0 : coverpoint (csr_hwloop.lp_start[0]) iff (csr_hwloop.lp_start_wb[0] && csr_hwloop.lp_end_wb[0] && csr_hwloop.lp_count_wb[0]) {
      bins lpstart_zero         = {32'h0};
      bins lpstart_range_0      = {[32'h0000_01FC : 32'h0000_0004]};
      bins lpstart_range_1      = {[32'h0000_03FC : 32'h0000_0200]};
      bins lpstart_range_2      = {[32'h0000_07FC : 32'h0000_0400]};
      bins lpstart_range_3      = {[32'h0000_0FFC : 32'h0000_0800]};
      illegal_bins  others_grp  = default; // higher range is not covered now due to limited generated codespace (amend if needed)
    }
    cp_lpstart_1 : coverpoint (csr_hwloop.lp_start[1]) iff (csr_hwloop.lp_start_wb[1] && csr_hwloop.lp_end_wb[1] && csr_hwloop.lp_count_wb[1]) {
      bins lpstart_zero         = {32'h0};
      bins lpstart_range_0      = {[32'h0000_01FC : 32'h0000_0004]};
      bins lpstart_range_1      = {[32'h0000_03FC : 32'h0000_0200]};
      bins lpstart_range_2      = {[32'h0000_07FC : 32'h0000_0400]};
      bins lpstart_range_3      = {[32'h0000_0FFC : 32'h0000_0800]};
      illegal_bins  others_grp  = default; // higher range is not covered now due to limited generated codespace (amend if needed)
    }

    cp_lpend_0 : coverpoint (csr_hwloop.lp_end[0]) iff (csr_hwloop.lp_start_wb[0] && csr_hwloop.lp_end_wb[0] && csr_hwloop.lp_count_wb[0]) {
      bins lpend_zero           = {32'h0};
      bins lpend_range_0        = {[32'h0000_01FC : 32'h0000_0004]};
      bins lpend_range_1        = {[32'h0000_03FC : 32'h0000_0200]};
      bins lpend_range_2        = {[32'h0000_07FC : 32'h0000_0400]};
      bins lpend_range_3        = {[32'h0000_0FFC : 32'h0000_0800]};
      illegal_bins  others_grp  = default; // higher range is not covered now due to limited generated codespace (amend if needed)
    }
    cp_lpend_1 : coverpoint (csr_hwloop.lp_end[1]) iff (csr_hwloop.lp_start_wb[1] && csr_hwloop.lp_end_wb[1] && csr_hwloop.lp_count_wb[1]) {
      bins lpend_zero           = {32'h0};
      bins lpend_range_0        = {[32'h0000_01FC : 32'h0000_0004]};
      bins lpend_range_1        = {[32'h0000_03FC : 32'h0000_0200]};
      bins lpend_range_2        = {[32'h0000_07FC : 32'h0000_0400]};
      bins lpend_range_3        = {[32'h0000_0FFC : 32'h0000_0800]};
      illegal_bins  others_grp  = default; // higher range is not covered now due to limited generated codespace (amend if needed)
    }

    cp_lpcount_0 : coverpoint (csr_hwloop.lp_count[0]) iff (csr_hwloop.lp_start_wb[0] && csr_hwloop.lp_end_wb[0] && csr_hwloop.lp_count_wb[0]) {
      bins lpcount_zero           = {32'h0};
      bins lpcount_range_low      = {[32'h0000_FFFF : 32'h0000_0001]};
      bins lpcount_range_middle   = {[32'h00FF_FFFF : 32'h0001_0000]};
      bins lpcount_range_high     = {[32'hFFFF_FFFF : 32'h0100_0000]};
      illegal_bins other_range    = default;
    }
    cp_lpcount_1 : coverpoint (csr_hwloop.lp_count[1]) iff (csr_hwloop.lp_start_wb[1] && csr_hwloop.lp_end_wb[1] && csr_hwloop.lp_count_wb[1]) {
      bins lpcount_zero           = {32'h0};
      bins lpcount_range_low      = {[32'h0000_FFFF : 32'h0000_0001]};
      bins lpcount_range_middle   = {[32'h00FF_FFFF : 32'h0001_0000]};
      bins lpcount_range_high     = {[32'hFFFF_FFFF : 32'h0100_0000]};
      illegal_bins other_range    = default;
    }

    // todo: is crossing lpcount==0 is necessary to make sure hwloop body instruction will not executed? (not a normal usecase) 
    ccp_lpstart_lpend_lpcount_0 : cross cp_lpstart_0, cp_lpend_0, cp_lpcount_0 {
     ignore_bins ignore__lpstart_zero = binsof (cp_lpstart_0) intersect {32'h0};
     ignore_bins ignore__lpend_zero   = binsof (cp_lpend_0)   intersect {32'h0};
    }

    ccp_lpstart_lpend_lpcount_1 : cross cp_lpstart_1, cp_lpend_1, cp_lpcount_1 {
     ignore_bins ignore__lpstart_zero = binsof (cp_lpstart_1) intersect {32'h0};
     ignore_bins ignore__lpend_zero   = binsof (cp_lpend_1)   intersect {32'h0};
    }

  endgroup : cg_csr_hwloop

  `define CG_FEATURES_OF_HWLOOP(LOOP_IDX) cg_features_of_hwloop_``LOOP_IDX``
  `define DEF_CG_FEATURES_OF_HWLOOP(LOOP_IDX) covergroup cg_features_of_hwloop_``LOOP_IDX with function sample(s_hwloop_stat hwloop_stat, bit [31:0] insn); \
    option.per_instance         = 1; \
    option.get_inst_coverage    = 1; \
    type_option.merge_instances = 1; \
    cp_hwloop_type : coverpoint (hwloop_stat.hwloop_type) iff (hwloop_stat.execute_instr_in_hwloop[``LOOP_IDX``]) { \
      bins single_hwloop      = {SINGLE}; \
      bins nested_hwloop      = {NESTED}; \
      illegal_bins invalid    = default; \
    } \
    cp_hwloop_setup : coverpoint (hwloop_stat.hwloop_setup[``LOOP_IDX``]) iff (hwloop_stat.execute_instr_in_hwloop[``LOOP_IDX``]) { \
      bins short_hwloop_setup = {SHORT}; \
      bins long_hwloop_setup  = {LONG}; \
      illegal_bins invalid    = default; \
    } \
    // refer to cv32e40p_tracer_pkg.sv for instructions list \
    // note: hwloop setup custom instructions are not allow in hwloop_0 (manual exclusion needed) \
    cp_insn_list_in_hwloop : coverpoint (insn) iff (hwloop_stat.execute_instr_in_hwloop[``LOOP_IDX``]) { \
      wildcard bins instr_lui = {{25'b?, OPCODE_LUI}}; \
      wildcard bins instr_auipc = {{25'b?, OPCODE_AUIPC}}; \
      // OPIMM \
      wildcard bins instr_addi = {{17'b?, 3'b000, 5'b?, OPCODE_OPIMM}}; \
      wildcard bins instr_slti = {{17'b?, 3'b010, 5'b?, OPCODE_OPIMM}}; \
      wildcard bins instr_sltiu = {{17'b?, 3'b011, 5'b?, OPCODE_OPIMM}}; \
      wildcard bins instr_xori = {{17'b?, 3'b100, 5'b?, OPCODE_OPIMM}}; \
      wildcard bins instr_ori = {{17'b?, 3'b110, 5'b?, OPCODE_OPIMM}}; \
      wildcard bins instr_andi = {{17'b?, 3'b111, 5'b?, OPCODE_OPIMM}}; \
      wildcard bins instr_slli = {{7'b0000000, 10'b?, 3'b001, 5'b?, OPCODE_OPIMM}}; \
      wildcard bins instr_srli = {{7'b0000000, 10'b?, 3'b101, 5'b?, OPCODE_OPIMM}}; \
      wildcard bins instr_srai = {{7'b0100000, 10'b?, 3'b101, 5'b?, OPCODE_OPIMM}}; \
      // OP \
      wildcard bins instr_add = {{7'b0000000, 10'b?, 3'b000, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_sub = {{7'b0100000, 10'b?, 3'b000, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_sll = {{7'b0000000, 10'b?, 3'b001, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_slt = {{7'b0000000, 10'b?, 3'b010, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_sltu = {{7'b0000000, 10'b?, 3'b011, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_xor = {{7'b0000000, 10'b?, 3'b100, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_srl = {{7'b0000000, 10'b?, 3'b101, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_sra = {{7'b0100000, 10'b?, 3'b101, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_or = {{7'b0000000, 10'b?, 3'b110, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_and = {{7'b0000000, 10'b?, 3'b111, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_pavg = {{7'b0000010, 10'b?, 3'b000, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_pavgu = {{7'b0000010, 10'b?, 3'b001, 5'b?, OPCODE_OP}}; \
      // SYSTEM \
      wildcard bins instr_csrrw = {{17'b?, 3'b001, 5'b?, OPCODE_SYSTEM}}; \
      wildcard bins instr_csrrs = {{17'b?, 3'b010, 5'b?, OPCODE_SYSTEM}}; \
      wildcard bins instr_csrrc = {{17'b?, 3'b011, 5'b?, OPCODE_SYSTEM}}; \
      wildcard bins instr_csrrwi = {{17'b?, 3'b101, 5'b?, OPCODE_SYSTEM}}; \
      wildcard bins instr_csrrsi = {{17'b?, 3'b110, 5'b?, OPCODE_SYSTEM}}; \
      wildcard bins instr_csrrci = {{17'b?, 3'b111, 5'b?, OPCODE_SYSTEM}}; \
      wildcard bins instr_ecall = {{12'b000000000000, 13'b0, OPCODE_SYSTEM}}; \
      wildcard bins instr_ebreak = {{12'b000000000001, 13'b0, OPCODE_SYSTEM}}; \
      // RV32M \
      wildcard bins instr_div = {{7'b0000001, 10'b?, 3'b100, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_divu = {{7'b0000001, 10'b?, 3'b101, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_rem = {{7'b0000001, 10'b?, 3'b110, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_remu = {{7'b0000001, 10'b?, 3'b111, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_pmul = {{7'b0000001, 10'b?, 3'b000, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_pmuh = {{7'b0000001, 10'b?, 3'b001, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_pmulhsu = {{7'b0000001, 10'b?, 3'b010, 5'b?, OPCODE_OP}}; \
      wildcard bins instr_pmulhu = {{7'b0000001, 10'b?, 3'b011, 5'b?, OPCODE_OP}}; \
      // RV32F \
      wildcard bins instr_fmadd = {{5'b?, 2'b00, 10'b?, 3'b?, 5'b?, OPCODE_OP_FMADD}}; \
      wildcard bins instr_fmsub = {{5'b?, 2'b00, 10'b?, 3'b?, 5'b?, OPCODE_OP_FMSUB}}; \
      wildcard bins instr_fnmsub = {{5'b?, 2'b00, 10'b?, 3'b?, 5'b?, OPCODE_OP_FNMSUB}}; \
      wildcard bins instr_fnmadd = {{5'b?, 2'b00, 10'b?, 3'b?, 5'b?, OPCODE_OP_FNMADD}}; \
      wildcard bins instr_fadd = {{5'b00000, 2'b00, 10'b?, 3'b?, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fsub = {{5'b00001, 2'b00, 10'b?, 3'b?, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fmul = {{5'b00010, 2'b00, 10'b?, 3'b?, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fdiv = {{5'b00011, 2'b00, 10'b?, 3'b?, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fsqrt = {{5'b01011, 2'b00, 5'b0, 5'b?, 3'b?, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fsgnjs = {{5'b00100, 2'b00, 10'b?, 3'b000, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fsgnjns = {{5'b00100, 2'b00, 10'b?, 3'b001, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fsgnjxs = {{5'b00100, 2'b00, 10'b?, 3'b010, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fmin = {{5'b00101, 2'b00, 10'b?, 3'b000, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fmax = {{5'b00101, 2'b00, 10'b?, 3'b001, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fcvtws = {{5'b11000, 2'b00, 5'b0, 5'b?, 3'b?, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fcvtwus = {{5'b11000, 2'b00, 5'b1, 5'b?, 3'b?, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fmvxs = {{5'b11100, 2'b00, 5'b0, 5'b?, 3'b000, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_feqs = {{5'b10100, 2'b00, 10'b?, 3'b010, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_flts = {{5'b10100, 2'b00, 10'b?, 3'b001, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fles = {{5'b10100, 2'b00, 10'b?, 3'b000, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fclass = {{5'b11100, 2'b00, 5'b0, 5'b?, 3'b001, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fcvtsw = {{5'b11010, 2'b00, 5'b0, 5'b?, 3'b?, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fcvtswu = {{5'b11010, 2'b00, 5'b1, 5'b?, 3'b?, 5'b?, OPCODE_OP_FP}}; \
      wildcard bins instr_fmvsx = {{5'b11110, 2'b00, 5'b0, 5'b?, 3'b000, 5'b?, OPCODE_OP_FP}}; \
      // CUSTOM_0 \
      wildcard bins instr_beqimm = {{17'b?, 3'b110, 5'b?, OPCODE_CUSTOM_0}}; \
      wildcard bins instr_bneimm = {{17'b?, 3'b111, 5'b?, OPCODE_CUSTOM_0}}; \
      // CUSTOM_1 \
      wildcard bins instr_ff1 = {{7'b0100001, 5'b0, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_fl1 = {{7'b0100010, 5'b0, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_clb = {{7'b0100011, 5'b0, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cnt = {{7'b0100100, 5'b0, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_exths = {{7'b0110000, 5'b0, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_exthz = {{7'b0110001, 5'b0, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_extbs = {{7'b0110010, 5'b0, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_extbz = {{7'b0110011, 5'b0, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_paddnr = {{7'b1000000, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_paddunr = {{7'b1000001, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_paddrnr = {{7'b1000010, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_paddurnr = {{7'b1000011, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_psubnr = {{7'b1000100, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_psubunr = {{7'b1000101, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_psubrnr = {{7'b1000110, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_psuburnr = {{7'b1000111, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pabs = {{7'b0101000, 5'b0, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pclip = {{7'b0111000, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pclipu = {{7'b0111001, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pclipr = {{7'b0111010, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pclipur = {{7'b0111011, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pslet = {{7'b0101001, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_psletu = {{7'b0101010, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pmin = {{7'b0101011, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pminu = {{7'b0101100, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pmax = {{7'b0101101, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pmaxu = {{7'b0101110, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_ror = {{7'b0100000, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pbextr = {{7'b0011000, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pbextur = {{7'b0011001, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pbinsr = {{7'b0011010, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pbclrr = {{7'b0011100, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pbsetr = {{7'b0011101, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pmac = {{7'b1001000, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_pmsu = {{7'b1001001, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      // CUSTOM_2 \
      wildcard bins instr_pbext = {{2'b00, 5'b?, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pbextu = {{2'b01, 5'b?, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pbins = {{2'b10, 5'b?, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pbclr = {{2'b00, 5'b?, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pbset = {{2'b01, 5'b?, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pbrev = {{2'b11, 5'b?, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_paddn = {{2'b00, 15'b?, 3'b010, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_paddun = {{2'b01, 15'b?, 3'b010, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_paddrn = {{2'b10, 15'b?, 3'b010, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_paddurn = {{2'b11, 15'b?, 3'b010, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_psubn = {{2'b00, 15'b?, 3'b011, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_psubun = {{2'b01, 15'b?, 3'b011, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_psubrn = {{2'b10, 15'b?, 3'b011, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_psuburn = {{2'b11, 15'b?, 3'b011, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmulsn = {{2'b00, 5'b?, 10'b?, 3'b100, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmulhhsn = {{2'b01, 5'b?, 10'b?, 3'b100, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmulsrn = {{2'b10, 5'b?, 10'b?, 3'b100, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmulhhsrn = {{2'b11, 5'b?, 10'b?, 3'b100, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmulun = {{2'b00, 5'b?, 10'b?, 3'b101, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmulhhun = {{2'b01, 5'b?, 10'b?, 3'b101, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmulurn = {{2'b10, 5'b?, 10'b?, 3'b101, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmulhhurn = {{2'b11, 5'b?, 10'b?, 3'b101, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmacsn = {{2'b00, 5'b?, 10'b?, 3'b110, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmachhsn = {{2'b01, 5'b?, 10'b?, 3'b110, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmacsrn = {{2'b10, 5'b?, 10'b?, 3'b110, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmachhsrn = {{2'b11, 5'b?, 10'b?, 3'b110, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmacun = {{2'b00, 5'b?, 10'b?, 3'b111, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmachhun = {{2'b01, 5'b?, 10'b?, 3'b111, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmacurn = {{2'b10, 5'b?, 10'b?, 3'b111, 5'b?, OPCODE_CUSTOM_2}}; \
      wildcard bins instr_pmachhurn = {{2'b11, 5'b?, 10'b?, 3'b111, 5'b?, OPCODE_CUSTOM_2}}; \
      // CUSTOM_3 - SIMD ALU \
      wildcard bins instr_cvaddh = {{5'b00000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvaddsch = {{5'b00000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvaddscih = {{5'b00000, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvaddb = {{5'b00000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvaddscb = {{5'b00000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvaddscib = {{5'b00000, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubh = {{5'b00001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubsch = {{5'b00001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubscih = {{5'b00001, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubb = {{5'b00001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubscb = {{5'b00001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubscib = {{5'b00001, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavgh = {{5'b00010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavgsch = {{5'b00010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavgscih = {{5'b00010, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavgb = {{5'b00010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavgscb = {{5'b00010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavgscib = {{5'b00010, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavguh = {{5'b00011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavgusch = {{5'b00011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavguscih = {{5'b00011, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavgub = {{5'b00011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavguscb = {{5'b00011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvavguscib = {{5'b00011, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminh = {{5'b00100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminsch = {{5'b00100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminscih = {{5'b00100, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminb = {{5'b00100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminscb = {{5'b00100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminscib = {{5'b00100, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminuh = {{5'b00101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminusch = {{5'b00101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminuscih = {{5'b00101, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminub = {{5'b00101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminuscb = {{5'b00101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvminuscib = {{5'b00101, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxh = {{5'b00110, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxsch = {{5'b00110, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxscih = {{5'b00110, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxb = {{5'b00110, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxscb = {{5'b00110, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxscib = {{5'b00110, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxuh = {{5'b00111, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxusch = {{5'b00111, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxuscih = {{5'b00111, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxub = {{5'b00111, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxuscb = {{5'b00111, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvmaxuscib = {{5'b00111, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrlh = {{5'b01000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrlsch = {{5'b01000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrlscih = {{5'b01000, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrlb = {{5'b01000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrlscb = {{5'b01000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrlscib = {{5'b01000, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrah = {{5'b01001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrasch = {{5'b01001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrascih = {{5'b01001, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrab = {{5'b01001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrascb = {{5'b01001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsrascib = {{5'b01001, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsllh = {{5'b01010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsllsch = {{5'b01010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsllscih = {{5'b01010, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsllb = {{5'b01010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsllscb = {{5'b01010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsllscib = {{5'b01010, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvorh = {{5'b01011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvorsch = {{5'b01011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvorscih = {{5'b01011, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvorb = {{5'b01011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvorscb = {{5'b01011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvorscib = {{5'b01011, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvxorh = {{5'b01100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvxorsch = {{5'b01100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvxorscih = {{5'b01100, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvxorb = {{5'b01100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvxorscb = {{5'b01100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvxorscib = {{5'b01100, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvandh = {{5'b01101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvandsch = {{5'b01101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvandscih = {{5'b01101, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvandb = {{5'b01101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvandscb = {{5'b01101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvandscib = {{5'b01101, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvabsh = {{5'b01110, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvabsb = {{5'b01110, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvextracth = {{5'b10111, 1'b0, 6'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvextractb = {{5'b10111, 1'b0, 6'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvextractuh = {{5'b10111, 1'b0, 6'b?, 5'b?, 3'b010, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvextractub = {{5'b10111, 1'b0, 6'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvinserth = {{5'b10111, 1'b0, 6'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvinsertb = {{5'b10111, 1'b0, 6'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotuph = {{5'b10000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotupsch = {{5'b10000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotupscih = {{5'b10000, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotupb = {{5'b10000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotupscb = {{5'b10000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotupscib = {{5'b10000, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotusph = {{5'b10001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotuspsch = {{5'b10001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotuspscih = {{5'b10001, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotuspb = {{5'b10001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotuspscb = {{5'b10001, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotuspscib = {{5'b10001, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotsph = {{5'b10010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotspsch = {{5'b10010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotspscih = {{5'b10010, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotspb = {{5'b10010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotspscb = {{5'b10010, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvdotspscib = {{5'b10010, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotuph = {{5'b10011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotupsch = {{5'b10011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotupscih = {{5'b10011, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotupb = {{5'b10011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotupscb = {{5'b10011, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotupscib = {{5'b10011, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotusph = {{5'b10100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotuspsch = {{5'b10100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotuspscih = {{5'b10100, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotuspb = {{5'b10100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotuspscb = {{5'b10100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotuspscib = {{5'b10100, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotsph = {{5'b10101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotspsch = {{5'b10101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotspscih = {{5'b10101, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotspb = {{5'b10101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotspscb = {{5'b10101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsdotspscib = {{5'b10101, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvshuffleh = {{5'b11000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvshufflescih = {{5'b11000, 1'b0, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvshuffleb = {{5'b11000, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvshufflel0scib = {{5'b11000, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvshufflel1scib = {{5'b11001, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvshufflel2scib = {{5'b11010, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvshufflel3scib = {{5'b11011, 1'b0, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvshuffle2h = {{5'b11100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvshuffle2b = {{5'b11100, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvpack = {{5'b11101, 1'b0, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvpackh = {{5'b11101, 1'b0, 1'b1, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvpackhib = {{5'b11111, 1'b0, 1'b1, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvpacklob = {{5'b11111, 1'b0, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      // CUSTOM_3 - SIMD COMPARISON \
      wildcard bins instr_cvcmpeqh = {{5'b00000, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpeqsch = {{5'b00000, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpeqscih = {{5'b00000, 1'b1, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpeqb = {{5'b00000, 1'b1, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpeqscb = {{5'b00000, 1'b1, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpeqscib = {{5'b00000, 1'b1, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpneh = {{5'b00001, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpnesch = {{5'b00001, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpnescih = {{5'b00001, 1'b1, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpneb = {{5'b00001, 1'b1, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpnescb = {{5'b00001, 1'b1, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpnescib = {{5'b00001, 1'b1, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgth = {{5'b00010, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgtsch = {{5'b00010, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgtscih = {{5'b00010, 1'b1, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgtb = {{5'b00010, 1'b1, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgtscb = {{5'b00010, 1'b1, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgtscib = {{5'b00010, 1'b1, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgeh = {{5'b00011, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgesch = {{5'b00011, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgescih = {{5'b00011, 1'b1, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgeb = {{5'b00011, 1'b1, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgescb = {{5'b00011, 1'b1, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgescib = {{5'b00011, 1'b1, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmplth = {{5'b00100, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpltsch = {{5'b00100, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpltscih = {{5'b00100, 1'b1, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpltb = {{5'b00100, 1'b1, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpltscb = {{5'b00100, 1'b1, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpltscib = {{5'b00100, 1'b1, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpleh = {{5'b00101, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmplesch = {{5'b00101, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmplescih = {{5'b00101, 1'b1, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpleb = {{5'b00101, 1'b1, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmplescb = {{5'b00101, 1'b1, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmplescib = {{5'b00101, 1'b1, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgtuh = {{5'b00110, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgtusch = {{5'b00110, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgtuscih = {{5'b00110, 1'b1, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgtub = {{5'b00110, 1'b1, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgtuscb = {{5'b00110, 1'b1, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgtuscib = {{5'b00110, 1'b1, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgeuh = {{5'b00111, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgeusch = {{5'b00111, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgeuscih = {{5'b00111, 1'b1, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgeub = {{5'b00111, 1'b1, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgeuscb = {{5'b00111, 1'b1, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpgeuscib = {{5'b00111, 1'b1, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpltuh = {{5'b01000, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpltusch = {{5'b01000, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpltuscih = {{5'b01000, 1'b1, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpltub = {{5'b01000, 1'b1, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpltuscb = {{5'b01000, 1'b1, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpltuscib = {{5'b01000, 1'b1, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpleuh = {{5'b01001, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpleusch = {{5'b01001, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpleuscih = {{5'b01001, 1'b1, 6'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpleub = {{5'b01001, 1'b1, 1'b0, 5'b?, 5'b?, 3'b001, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpleuscb = {{5'b01001, 1'b1, 1'b0, 5'b?, 5'b?, 3'b101, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcmpleuscib = {{5'b01001, 1'b1, 6'b?, 5'b?, 3'b111, 5'b?, OPCODE_CUSTOM_3}}; \
      // CUSTOM_3 - SIMD CPLX \
      wildcard bins instr_cvcplxmulr = {{5'b01010, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcplxmulrdiv2 = {{5'b01010, 1'b1, 1'b0, 5'b?, 5'b?, 3'b010, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcplxmulrdiv4 = {{5'b01010, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcplxmulrdiv8 = {{5'b01010, 1'b1, 1'b0, 5'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcplxmuli = {{5'b01010, 1'b1, 1'b1, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcplxmulidiv2 = {{5'b01010, 1'b1, 1'b1, 5'b?, 5'b?, 3'b010, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcplxmulidiv4 = {{5'b01010, 1'b1, 1'b1, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcplxmulidiv8 = {{5'b01010, 1'b1, 1'b1, 5'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvcplxconj = {{5'b01011, 1'b1, 1'b0, 5'b00000, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubrotmj = {{5'b01100, 1'b1, 1'b0, 5'b?, 5'b?, 3'b000, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubrotmjdiv2 = {{5'b01100, 1'b1, 1'b0, 5'b?, 5'b?, 3'b010, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubrotmjdiv4 = {{5'b01100, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubrotmjdiv8 = {{5'b01100, 1'b1, 1'b0, 5'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvaddiv2 = {{5'b01101, 1'b1, 1'b0, 5'b?, 5'b?, 3'b010, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvaddiv4 = {{5'b01101, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvaddiv8 = {{5'b01101, 1'b1, 1'b0, 5'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubiv2 = {{5'b01110, 1'b1, 1'b0, 5'b?, 5'b?, 3'b010, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubiv4 = {{5'b01110, 1'b1, 1'b0, 5'b?, 5'b?, 3'b100, 5'b?, OPCODE_CUSTOM_3}}; \
      wildcard bins instr_cvsubiv8 = {{5'b01110, 1'b1, 1'b0, 5'b?, 5'b?, 3'b110, 5'b?, OPCODE_CUSTOM_3}}; \
      // Custom  Post-Incr Load-Store \
      wildcard bins instr_cv_lb_imm   = {{17'b?, 3'b000, 5'b?, OPCODE_CUSTOM_0}}; \
      wildcard bins instr_cv_lbu_imm  = {{17'b?, 3'b100, 5'b?, OPCODE_CUSTOM_0}}; \
      wildcard bins instr_cv_lh_imm   = {{17'b?, 3'b001, 5'b?, OPCODE_CUSTOM_0}}; \
      wildcard bins instr_cv_lhu_imm  = {{17'b?, 3'b101, 5'b?, OPCODE_CUSTOM_0}}; \
      wildcard bins instr_cv_lw_imm   = {{17'b?, 3'b010, 5'b?, OPCODE_CUSTOM_0}}; \
      wildcard bins instr_cv_lb_rs    = {{7'b0000000, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_lbu_rs   = {{7'b0001000, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_lh_rs    = {{7'b0000001, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_lhu_rs   = {{7'b0001001, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_lw_rs    = {{7'b0000010, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_lb       = {{7'b0000100, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_lbu      = {{7'b0001100, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_lh       = {{7'b0000101, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_lhu      = {{7'b0001101, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_lw       = {{7'b0000110, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_sb_imm = {{17'b?, 3'b000, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_sh_imm = {{17'b?, 3'b001, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_sw_imm = {{17'b?, 3'b010, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_sb_rs  = {{7'b0010000, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_sh_rs  = {{7'b0010001, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_sw_rs  = {{7'b0010010, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_sb     = {{7'b0010100, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_sh     = {{7'b0010101, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_cv_sw     = {{7'b0010110, 5'b?, 5'b?, 3'b011, 5'b?, OPCODE_CUSTOM_1}}; \
      // Custom - Event load \
      wildcard bins instr_cv_elw    = {{17'b?, 3'b011, 5'b?, OPCODE_CUSTOM_0}}; \
      // Custom - hwloop setup \
      wildcard bins instr_starti  = {{17'b?, 3'b100, 4'b0000, 1'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_start   = {{17'b?, 3'b100, 4'b0001, 1'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_endi    = {{17'b?, 3'b100, 4'b0010, 1'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_end     = {{17'b?, 3'b100, 4'b0011, 1'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_counti  = {{17'b?, 3'b100, 4'b0100, 1'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_count   = {{17'b?, 3'b100, 4'b0101, 1'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_setupi  = {{17'b?, 3'b100, 4'b0110, 1'b?, OPCODE_CUSTOM_1}}; \
      wildcard bins instr_setup   = {{17'b?, 3'b100, 4'b0111, 1'b?, OPCODE_CUSTOM_1}}; \
      // Load-Store (RV32I and RV32F) \
      wildcard bins instr_lb  = {{17'b?, 3'b000, 5'b?, OPCODE_LOAD}}; \
      wildcard bins instr_lh  = {{17'b?, 3'b001, 5'b?, OPCODE_LOAD}}; \
      wildcard bins instr_lw  = {{17'b?, 3'b010, 5'b?, OPCODE_LOAD}}; \
      wildcard bins instr_lbu = {{17'b?, 3'b100, 5'b?, OPCODE_LOAD}}; \
      wildcard bins instr_lhu = {{17'b?, 3'b101, 5'b?, OPCODE_LOAD}}; \
      wildcard bins instr_sb  = {{17'b?, 3'b000, 5'b?, OPCODE_STORE}}; \
      wildcard bins instr_sh  = {{17'b?, 3'b001, 5'b?, OPCODE_STORE}}; \
      wildcard bins instr_sw  = {{17'b?, 3'b010, 5'b?, OPCODE_STORE}}; \
      wildcard bins instr_flw  = {{17'b?, 3'b010, 5'b?, OPCODE_LOAD_FP}}; \
      wildcard bins instr_fsw  = {{17'b?, 3'b010, 5'b?, OPCODE_STORE_FP}}; \
      // Others \
      illegal_bins other_instr = default; \
    } \
    ccp_hwloop_type_setup_insn_list : cross cp_hwloop_type, cp_hwloop_setup, cp_insn_list_in_hwloop; \
  endgroup : cg_features_of_hwloop_``LOOP_IDX``

  `DEF_CG_FEATURES_OF_HWLOOP(0)
  `DEF_CG_FEATURES_OF_HWLOOP(1)

  // COVERGROUPS DEFINE HERE - START

  `uvm_component_utils(uvme_rv32x_hwloop_covg)

  function new(string name="uvme_rv32x_hwloop_covg", uvm_component parent=null);
    super.new(name, parent);
    cg_csr_hwloop = new();             cg_csr_hwloop.set_inst_name($sformatf("cg_csr_hwloop"));
    `CG_FEATURES_OF_HWLOOP(0) = new(); cg_features_of_hwloop_0.set_inst_name($sformatf("cg_features_of_hwloop_0"));
    `CG_FEATURES_OF_HWLOOP(1) = new(); cg_features_of_hwloop_1.set_inst_name($sformatf("cg_features_of_hwloop_1"));
  endfunction: new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!(uvm_config_db#( virtual rvviTrace #( .NHART(NHART), .RETIRE(RETIRE)))::get(this, "", "rvvi_vif", rvvi_vif))) begin
        `uvm_fatal(_header, "rvvi_vif no found in uvm_config_db");
    end
  endfunction : build_phase

  task run_phase(uvm_phase phase);
    int skip_cnt = 0;
    super.run_phase(phase);
    forever begin
      @(posedge rvvi_vif.clk);
      if (rvvi_vif.valid[0][0]) begin : VALID_DETECTED
        check_n_sample_csr_hwloop();
        check_n_sample_hwloop();
      end // VALID_DETECTED
    end

  endtask : run_phase

  task check_n_sample_csr_hwloop();
    for (int i=0; i<HWLOOP_NB; i++) begin : CSR_CHECK_THEN_SAMPLE
      int csr_update_cnt = 0;
      if (rvvi_vif.csr_wb[0][0][CSR_LPSTART0_ADDR+i*4]) begin
        assert(csr_hwloop.lp_start_wb[i] == 0);
        csr_hwloop.lp_start[i]    = rvvi_vif.csr[0][0][CSR_LPSTART0_ADDR+i*4];
        csr_hwloop.lp_start_wb[i] = rvvi_vif.csr_wb[0][0][CSR_LPSTART0_ADDR+i*4];
        csr_update_cnt++;
      end
      if (rvvi_vif.csr_wb[0][0][CSR_LPEND0_ADDR+i*4]) begin
        assert(csr_hwloop.lp_end_wb[i] == 0);
        csr_hwloop.lp_end[i]      = rvvi_vif.csr[0][0][CSR_LPEND0_ADDR+i*4];
        csr_hwloop.lp_end_wb[i]   = rvvi_vif.csr_wb[0][0][CSR_LPEND0_ADDR+i*4];
        csr_update_cnt++;
      end
      if (rvvi_vif.csr_wb[0][0][CSR_LPCOUNT0_ADDR+i*4]) begin
        csr_hwloop.lp_count[i]    = rvvi_vif.csr[0][0][CSR_LPCOUNT0_ADDR+i*4];
        csr_hwloop.lp_count_wb[i] = rvvi_vif.csr_wb[0][0][CSR_LPCOUNT0_ADDR+i*4];
        csr_update_cnt++;
      end
      if (csr_hwloop.lp_start_wb[i] && csr_hwloop.lp_end_wb[i] && csr_hwloop.lp_count_wb[i]) begin
        cg_csr_hwloop.sample(csr_hwloop);
        // assign hwloop_csr
        hwloop_stat.hwloop_csr.lp_start[i] = csr_hwloop.lp_start[i];
        hwloop_stat.hwloop_csr.lp_end[i]   = csr_hwloop.lp_end[i];
        hwloop_stat.hwloop_csr.lp_count[i] = csr_hwloop.lp_count[i];
        // assign hwloop_setup
        if (csr_update_cnt == 3)  hwloop_stat.hwloop_setup[i] = SHORT;
        else                      hwloop_stat.hwloop_setup[i] = LONG;
        // `uvm_info(_header, $sformatf("cg_csr_hwloop[%0d] - sampling csr_hwloop is %p", i, csr_hwloop), UVM_DEBUG);
        // `uvm_info(_header, $sformatf("cg_csr_hwloop[%0d] - get_inst_coverage = %.2f, get_coverage = %.2f", i, cg_csr_hwloop.get_inst_coverage(), cg_csr_hwloop.get_coverage), UVM_DEBUG);
        csr_hwloop = csr_hwloop_init;
      end
    end
  endtask : check_n_sample_csr_hwloop

  task check_n_sample_hwloop();
    /*
    *   - compare with the lpstart and lpend-4
    *   - capture hwloop0 instructions if pc condition is "lpstart[hwloop0] =< pc =< lpend-4[heloop0]" AND "lpcount != 0"
    *     - should not contains any hwloop setup instruction such as cv.start/end/count and cv.setup of its loop (manual exclusion for cp and ccp is needed)
    *   - capture hwloop1 instructions if pc condition is "lpstart[hwloop1] =< pc =< lpend-4[hwloop1] && lpstart[hwloop0] !=< pc !=< lpend-4[hwloop0]"
    *   - capture one iteration for series of hwloop instructions within hwloop (for first lpcount) to reduce overhead bin hit
    *     - the remaining "lpcount-1...1" will be go through checking to ensure each loop always contains the same instructions list. flag error if different (tbd: such check is nice to have?)
    * */
    for (int i=0; i<HWLOOP_NB; i++) begin : PREPARE
      if (hwloop_stat.hwloop_csr.lp_count[i] != 0) begin
        if (is_pc_equal_lpstart(hwloop_stat.hwloop_csr, i) && !done_hwloop_stat_assign[i]) begin
          // assign execute_instr_in_hwloop, track_lp_count, hwloop_type
          hwloop_stat.execute_instr_in_hwloop[i] = 1'b1;
          hwloop_stat.track_lp_count[i]          = hwloop_stat.hwloop_csr.lp_count[i];
          if (hwloop_stat.execute_instr_in_hwloop      == '{1,1}) hwloop_stat.hwloop_type = NESTED;
          else if (hwloop_stat.execute_instr_in_hwloop == '{1,0}) hwloop_stat.hwloop_type = SINGLE;
          else if (hwloop_stat.execute_instr_in_hwloop == '{0,1}) hwloop_stat.hwloop_type = SINGLE;
          done_hwloop_stat_assign[i] = 1;
        end
      end
    end // PREPARE
    for (int i=0; i<HWLOOP_NB; i++) begin : COLLECT
      if (hwloop_stat.execute_instr_in_hwloop[i]) begin
        unique case (i)
          0 : begin // nested or single is the same
                if (!done_insn_list_capture[i]) insn_list_in_hwloop[i].push_back(rvvi_vif.insn[0][0]);
                if (is_pc_equal_lpend(hwloop_stat.hwloop_csr, i)) begin
                  hwloop_stat.track_lp_count[i]--;
                end
                if (hwloop_stat.track_lp_count[i] != hwloop_stat.hwloop_csr.lp_count[i]) done_insn_list_capture[i] = 1;
              end
          1 : begin // in nested should not capture insns within hwloop0 
                if (hwloop_stat.hwloop_type == NESTED && hwloop_stat.track_lp_count[0] != 0) continue;
                if (!done_insn_list_capture[i]) insn_list_in_hwloop[i].push_back(rvvi_vif.insn[0][0]);
                if (is_pc_equal_lpend(hwloop_stat.hwloop_csr, i)) begin
                  hwloop_stat.track_lp_count[i]--;
                end
                if (hwloop_stat.track_lp_count[i] != hwloop_stat.hwloop_csr.lp_count[i]) done_insn_list_capture[i] = 1;
              end
        endcase 
      end
    end // COLLECT
    if (
      (hwloop_stat.hwloop_type == NESTED && hwloop_stat.track_lp_count[0] == 0 && hwloop_stat.track_lp_count[1] == 0) ||
      (hwloop_stat.hwloop_type == SINGLE && hwloop_stat.track_lp_count[0] == 0 && hwloop_stat.track_lp_count[1] == 0)
    ) begin : SAMPLE
      for (int i=0; i<HWLOOP_NB; i++) begin
        while (insn_list_in_hwloop[i].size() != 0) begin
          unique case (i)
            0:  begin
                  `CG_FEATURES_OF_HWLOOP(0).sample(hwloop_stat, insn_list_in_hwloop[i].pop_front());
                end
            1:  begin 
                  `CG_FEATURES_OF_HWLOOP(1).sample(hwloop_stat, insn_list_in_hwloop[i].pop_front());
                end
          endcase
        end
        done_insn_list_capture[i]  = 0;
        done_hwloop_stat_assign[i] = 0;
      end
      hwloop_stat = hwloop_stat_init;
    end // SAMPLE
  endtask : check_n_sample_hwloop

  function bit is_pc_equal_lpstart(s_csr_hwloop csr_hwloop, int idx=0);
    if (rvvi_vif.pc_rdata[0][0] == csr_hwloop.lp_start[idx]) return 1;
    else return 0; 
  endfunction: is_pc_equal_lpstart

  function bit is_pc_equal_lpend(s_csr_hwloop csr_hwloop, int idx=0);
    if (rvvi_vif.pc_rdata[0][0] == csr_hwloop.lp_end[idx]-4) return 1;
    else return 0; 
  endfunction: is_pc_equal_lpend

endclass : uvme_rv32x_hwloop_covg

`endif
